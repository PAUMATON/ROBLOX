--!strict

-- MuseumService — la parcel·la de cada jugador, muntar esquelets, exposar
-- fòssils i esquelets, i cobrar-ne la renda. El client només demana; cada
-- petició es revalida.
--
-- A cada vitrina hi va UNA cosa: un fòssil sol ("Rat_Skull") o un esquelet
-- muntat ("Rat"). La renda la diu Bones.IncomeOf (un esquelet rendeix x2).
--
-- Contracte amb el mapa (tools/world/04_museums.luau):
--   · Workspace.Museums.Plot<n> amb etiqueta "MuseumPlot"
--   · Slot1..SlotN (sòcols), Plaque1..N (plaques), Glow1..N (llum de raresa)
--   · OwnerSign (TextLabel), Entry (on apareixes)
-- Les portes i els viatges són de TravelService.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Constants = require(Config:WaitForChild("Constants"))
local Museum = require(Config:WaitForChild("Museum"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local BoneBuilder = require(Util:WaitForChild("BoneBuilder"))
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local Monetization = require(Config:WaitForChild("Monetization"))

local log = Logger.new("MuseumService")

local MuseumService = {}

local plotOf: { [Player]: Model } = {}
local freePlots: { Model } = {}
local totalPlots = 0
local actionLimiter = RateLimiter.new(3)

local EMPTY_GLOW = Color3.fromRGB(120, 124, 132)

-- ─────────────────────────── VITRINES ───────────────────────────

local function setText(container: Instance?, text: string, color: Color3?)
	local label = container and container:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
end

-- El model d'una cosa exposada, a la mida que cap dins el vidre
local function exhibitModel(item: string): Model?
	local maxSpan, maxHeight
	local model: Model
	local info = Bones.PieceInfo[item]
	if info then
		model = BoneBuilder.Piece(info.skeleton, info.piece)
		maxSpan, maxHeight = Museum.FOSSIL_MAX_SPAN, Museum.FOSSIL_MAX_SPAN
	elseif Bones.ById[item] then
		model = BoneBuilder.Assembled(item)
		maxSpan, maxHeight = Museum.SKELETON_MAX_SPAN, Museum.SKELETON_MAX_HEIGHT
	else
		return nil
	end
	local _, raw = model:GetBoundingBox()
	local fit = math.min(maxSpan / math.max(raw.X, raw.Z, 0.1), maxHeight / math.max(raw.Y, 0.1))
	model:ScaleTo(fit)
	return model
end

local function exhibitName(item: string): string
	local info = Bones.PieceInfo[item]
	if info then
		return string.upper((Bones.Describe(item)))
	end
	local def = Bones.ById[item]
	return if def then string.upper(def.name) .. " SKELETON" else "?"
end

-- Rètol flotant sobre la vitrina: nom (del color de la raresa), quant fa
-- per segon i una frase curta. Petit i només de prop: no ha de tapar res.
local function infoSign(base: BasePart, item: string, rarity: Bones.Rarity): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "ExhibitInfo"
	bb.Adornee = base
	bb.Size = UDim2.fromScale(7.5, 2.4) -- en studs: s'encongeix amb la distància
	bb.StudsOffsetWorldSpace = Vector3.new(0, Museum.INFO_HEIGHT, 0)
	bb.MaxDistance = Museum.INFO_DISTANCE
	bb.LightInfluence = 0

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
	panel.BackgroundTransparency = 0.25
	panel.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Color = Bones.RARITY_COLORS[rarity]
	edge.Thickness = 2
	edge.Parent = panel

	local function line(text: string, y: number, h: number, color: Color3, bold: boolean)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, h)
		label.Font = if bold then Enum.Font.FredokaOne else Enum.Font.GothamMedium
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = panel
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = if bold then 1.5 else 1
		stroke.Parent = label
	end
	line(`{exhibitName(item)} · {string.upper(rarity)}`, 0.06, 0.3, Bones.RARITY_COLORS[rarity], true)
	line(`+{Museum.PerSecondText(Bones.IncomeOf(item))} $/s`, 0.37, 0.28, Color3.fromRGB(90, 230, 110), true)
	line(Bones.FactOf(item), 0.68, 0.24, Color3.fromRGB(245, 236, 215), false)
	return bb
end

local function refreshDisplays(plot: Model, museumLayout: { [string]: any }?)
	for slot = 1, Museum.SLOTS do
		local base = plot:FindFirstChild("Slot" .. slot)
		if base and base:IsA("BasePart") then
			local old = base:FindFirstChild("Exhibit")
			if old then
				old:Destroy()
			end
			local item = museumLayout and museumLayout[tostring(slot)]
			local model = if type(item) == "string" then exhibitModel(item) else nil
			if model then
				model.Name = "Exhibit"
				-- De perfil respecte del passadís (el sòcol ja està girat al mapa)
				model:PivotTo(base.CFrame * CFrame.Angles(0, math.rad(-90), 0))
				local box, size = model:GetBoundingBox()
				local top = base.Position.Y + base.Size.Y / 2
				local lift = top + Museum.EXHIBIT_GAP - (box.Position.Y - size.Y / 2)
				model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
				model.Parent = base
			end
			local rarity: Bones.Rarity? = if model then Bones.RarityOf(item :: string) else nil
			if model and rarity then
				infoSign(base, item :: string, rarity).Parent = model
			end
			local color = if rarity then Bones.RARITY_COLORS[rarity] else EMPTY_GLOW
			local glow = plot:FindFirstChild("Glow" .. slot)
			if glow and glow:IsA("BasePart") then
				glow.Color = if rarity == "Secret" then Color3.fromRGB(255, 255, 255) else color
			end
			setText(
				plot:FindFirstChild("Plaque" .. slot),
				if model and rarity then `{exhibitName(item :: string)} · {string.upper(rarity)}` else Museum.EMPTY_PLAQUE
			)
		end
	end
end

local function assignPlot(player: Player)
	if plotOf[player] then
		return
	end
	local plot = table.remove(freePlots, 1)
	if not plot then
		-- El servidor ha d'admetre com a molt tants jugadors com museus hi ha
		-- al mapa (Game Settings > Places > Max Players).
		log:Warn(`no queden museus lliures per a {player.Name}: Max Players ha de ser com a molt {totalPlots}`)
		return
	end
	plotOf[player] = plot
	plot:SetAttribute("OwnerId", player.UserId)
	setText(plot:FindFirstChild("OwnerSign", true), string.upper(player.DisplayName) .. "'S MUSEUM")
	local profile = DataService.Get(player)
	refreshDisplays(plot, profile and profile.museumLayout)
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	plotOf[player] = nil
	if not plot then
		return
	end
	plot:SetAttribute("OwnerId", nil)
	refreshDisplays(plot, nil)
	setText(plot:FindFirstChild("OwnerSign", true), Museum.FREE_SIGN)
	table.insert(freePlots, plot)
	table.sort(freePlots, function(a, b)
		return a.Name < b.Name
	end)
end

-- ─────────────────────────── RENDA ───────────────────────────

-- Cobra la renda des de lastIncomeAt fins ara. Serveix igual per a la renda
-- en línia (cada TICK) com per a l'offline (en carregar), amb el sostre
-- d'hores offline del CLAUDE.md. Torna quant s'ha cobrat i quants segons.
local function collect(profile: DataService.Profile, capSeconds: number?, extra: number?): (number, number)
	local now = os.time()
	local elapsed = math.max(0, now - profile.lastIncomeAt)
	if capSeconds then
		elapsed = math.min(elapsed, capSeconds)
	end
	-- el sostre de renda és del museu; els passis multipliquen el que en surt
	local mult = Monetization.MoneyMultiplier(profile.gamepasses, profile.boostUntil) * (extra or 1)
	local earned = Museum.IncomeRate(profile.museumLayout) * mult * (elapsed / 60)
	profile.coins += earned
	profile.lastIncomeAt = now
	return earned, elapsed
end

-- ─────────────────────────── ACCIONS ───────────────────────────

local actions: { [string]: (Player, DataService.Profile, any) -> boolean } = {}

function actions.assemble(player, _profile, skeletonId)
	if not Bones.IsSkeletonId(skeletonId) then
		return false
	end
	return InventoryService.Assemble(player, skeletonId)
end

-- Exposa una peça ("Rat_Skull") o un esquelet muntat ("Rat") a la primera vitrina lliure
function actions.display(player, profile, item)
	if not Bones.IsPieceKey(item) and not Bones.IsSkeletonId(item) then
		return false
	end
	local free: string? = nil
	for slot = 1, Museum.SLOTS do
		if profile.museumLayout[tostring(slot)] == nil then
			free = tostring(slot)
			break
		end
	end
	if not free then
		Remotes.Notify:FireClient(player, {
			kind = "shop",
			ok = false,
			icon = "🏛️",
			message = `Your museum is full ({Museum.SLOTS}/{Museum.SLOTS})! Take something out first`,
		})
		return false
	end
	-- La renda de fins ara es cobra amb el museu d'abans del canvi.
	collect(profile)
	local ok, wasLocked = false, false
	if Bones.IsPieceKey(item) then
		ok, wasLocked = InventoryService.TakeBone(profile, item)
	else
		ok = InventoryService.TakeSkeleton(profile, item)
	end
	if not ok then
		return false
	end
	profile.museumLayout[free] = item
	-- la vitrina recorda si la peça era de recompensa (veure withdraw)
	profile.museumLocked[free] = if wasLocked then true else nil
	return true
end

function actions.withdraw(_player, profile, slot)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > Museum.SLOTS then
		return false
	end
	local key = tostring(slot)
	local item = profile.museumLayout[key]
	if type(item) ~= "string" then
		return false
	end
	collect(profile)
	profile.museumLayout[key] = nil
	local wasLocked = profile.museumLocked[key] == true
	profile.museumLocked[key] = nil
	if Bones.IsPieceKey(item) then
		-- torna igual de bloquejada: exposar-la no la fa comerciable
		InventoryService.GiveBone(profile, item, wasLocked)
	elseif Bones.IsSkeletonId(item) then
		InventoryService.GiveSkeleton(profile, item)
	end
	return true
end

local function onAction(player: Player, action: any, payload: any)
	if not actionLimiter:Check(player) then
		return
	end
	if type(action) ~= "string" then
		return
	end
	local handler = actions[action]
	local profile = DataService.Get(player)
	if not handler or not profile then
		return
	end
	if handler(player, profile, payload) then
		local plot = plotOf[player]
		if plot and action ~= "assemble" then
			refreshDisplays(plot, profile.museumLayout)
		end
		InventoryService.Push(player)
	end
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

local function onProfileLoaded(player: Player, profile: DataService.Profile)
	-- Renda offline, amb sostre (Constants.OFFLINE_CAP_HOURS, o 24h amb el passi)
	local capHours = if profile.gamepasses.offline24 then Monetization.OFFLINE_LONG_HOURS else Constants.OFFLINE_CAP_HOURS
	local earned, seconds = collect(profile, capHours * 3600, if profile.gamepasses.offline2 then Monetization.OFFLINE_MULT else 1)
	assignPlot(player)
	InventoryService.Push(player)
	-- "Mentre no hi eres, el museu ha guanyat X": només si val la pena dir-ho
	if earned >= 1 then
		Remotes.Notify:FireClient(player, {
			kind = "offline",
			coins = math.floor(earned),
			seconds = seconds,
			capped = seconds >= capHours * 3600,
			capHours = capHours,
		})
	end
end

function MuseumService.GetPlot(player: Player): Model?
	return plotOf[player]
end

function MuseumService.Init()
	for _, plot in CollectionService:GetTagged("MuseumPlot") do
		if plot:IsA("Model") and plot:IsDescendantOf(workspace) then
			table.insert(freePlots, plot)
			refreshDisplays(plot, nil)
			setText(plot:FindFirstChild("OwnerSign", true), Museum.FREE_SIGN)
		end
	end
	table.sort(freePlots, function(a, b)
		return a.Name < b.Name
	end)
	totalPlots = #freePlots
	if totalPlots == 0 then
		log:Warn("no hi ha cap MuseumPlot al mapa: construeix el món amb el plugin")
	end

	-- A Init, no a Start: un perfil pot carregar abans que arribem a Start.
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	DataService.ProfileReleased:Connect(releasePlot)
end

function MuseumService.Start()
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile and not plotOf[player] then
			onProfileLoaded(player, profile)
		end
	end

	Remotes.MuseumAction.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(releasePlot)

	-- Renda en línia: es cobra cada TICK (1 s) i el client veu pujar les
	-- monedes cada segon (CoinsUpdate, només el número). El perfil sencer
	-- (ProfileUpdate) només cada PUSH_EVERY ticks: enviar-lo cada segon faria
	-- redibuixar la motxilla, el comerç... a tothom sense parar.
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(Museum.TICK)
			ticks += 1
			local full = ticks % Museum.PUSH_EVERY == 0
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					collect(profile)
					if full then
						InventoryService.Push(player)
					else
						Remotes.CoinsUpdate:FireClient(player, math.floor(profile.coins))
					end
				end
			end
		end
	end)
end

return MuseumService
