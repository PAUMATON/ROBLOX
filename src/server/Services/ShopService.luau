--!strict

-- ShopService — Dig & Co., la botiga d'eines d'arqueòleg de la plaça (estil Fisch).
--
-- Les eines estan exposades soltes davant la botiga: t'hi acostes, mantens
-- E i el client obre la fitxa de l'eina (ShopController); des d'allà es
-- compra amb ShopRequest("buy"). Hi ha un botiguer, en Rex, per parlar-hi.
-- No hi ha estoc: tot està sempre a la venda. Les eines només donen sort.
-- També aquí: el desbloqueig de la platja, a les portes de la platja.
--
-- Contracte amb el mapa (tools/world/09_toolshop.luau i 06_beach.luau):
--   · parts "ToolStand" amb atribut ToolId (un sòcol per eina)
--   · part "ShopkeeperSpot" (on es posa en Rex, mirant endavant)
--   · parts "ZoneUnlock" amb atribut Zone (portes de la platja)
--
-- Comprar només es pot al costat de l'eina: el servidor torna a mirar la
-- distància al sòcol i el preu. Tot és en monedes: res aleatori es ven per Robux.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Tools = require(Config:WaitForChild("Tools"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Zones = require(Config:WaitForChild("Zones"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local ToolModels = require(Util:WaitForChild("ToolModels"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ToolService = require(script.Parent.ToolService)

local log = Logger.new("ShopService")

local ShopService = {}

local limiter = RateLimiter.new(2)
local MAX_DISTANCE = 18 -- la fitxa es tanca a 16; una mica de marge pel ping
local standOf: { [string]: BasePart } = {} -- toolId -> el seu sòcol
local sellerSpots: { BasePart } = {} -- on és la parada del Fossil Buyer
local SELL_DISTANCE = 24

local function reply(player: Player, ok: boolean, message: string, icon: string?)
	Remotes.Notify:FireClient(player, { kind = "shop", ok = ok, message = message, icon = icon })
end

local function near(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - part.Position).Magnitude <= MAX_DISTANCE
end

-- ─────────────────────────── COMPRES ───────────────────────────

local function buyOrEquip(player: Player, toolId: string)
	local profile = DataService.Get(player)
	local def = Tools.ById[toolId]
	if not profile or not def then
		return
	end
	if table.find(profile.ownedTools, def.id) then
		if profile.equippedTool ~= def.id then
			profile.equippedTool = def.id
			ToolService.RefreshShovel(player)
			InventoryService.Push(player)
			reply(player, true, `{def.name} equipped`)
		end
		return
	end
	if profile.coins < def.price then
		reply(player, false, `You need {math.ceil(def.price - profile.coins)} more coins`)
		return
	end
	-- a partir d'aquí, cap yield: o es fa tot o no es fa res
	profile.coins -= def.price
	table.insert(profile.ownedTools, def.id)
	profile.equippedTool = def.id
	ToolService.RefreshShovel(player)
	InventoryService.Push(player)
	reply(player, true, `{def.name} unlocked!`)
	log:Info(`{player.Name} ha comprat {def.id}`)
	task.spawn(DataService.Save, player)
end

local function unlockZone(player: Player, zoneId: string)
	local profile = DataService.Get(player)
	local zone = Zones.ById[zoneId]
	if not profile or not zone or zone.unlockCost <= 0 then
		return
	end
	if Zones.IsUnlocked(profile.unlockedZones, zone.id) then
		reply(player, true, `{zone.name} is already open`)
		return
	end
	if profile.coins < zone.unlockCost then
		reply(player, false, `You need {math.ceil(zone.unlockCost - profile.coins)} more coins`)
		return
	end
	profile.coins -= zone.unlockCost
	table.insert(profile.unlockedZones, zone.id)
	InventoryService.Push(player)
	reply(player, true, `{zone.name} is open! Go dig there`)
	log:Info(`{player.Name} ha obert {zone.id}`)
	task.spawn(DataService.Save, player)
end

-- ─────────────────────────── VENDRE FÒSSILS ───────────────────────────
-- A la parada de la Bonnie. "one" = una peça concreta (des de la motxilla),
-- "dupes" = totes les repetides (en queda una de cada), "all" = totes les
-- peces soltes. El que és al museu i els esquelets muntats no es venen mai.

local function nearSeller(player: Player): boolean
	for _, spot in sellerSpots do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - spot.Position).Magnitude <= SELL_DISTANCE then
			return true
		end
	end
	return false
end

local function sell(player: Player, action: any, payload: any)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if not nearSeller(player) then
		reply(player, false, "Go to the Fossil Buyer at the plaza to sell", "🦴")
		return
	end
	local plan: { [string]: number } = {}
	if action == "one" then
		if not Bones.IsPieceKey(payload) or InventoryService.CountBone(profile, payload) < 1 then
			return
		end
		plan[payload] = 1
	elseif action == "dupes" or action == "all" then
		for key, n in profile.ownedBones do
			if Bones.IsPieceKey(key) and type(n) == "number" and n > 0 then
				local amount = if action == "dupes" then n - 1 else n
				if amount > 0 then
					plan[key] = math.floor(amount)
				end
			end
		end
	else
		return
	end
	-- a partir d'aquí, cap yield: o es fa tot o no es fa res
	local sold, coins = 0, 0
	for key, amount in plan do
		for _ = 1, amount do
			if InventoryService.TakeBone(profile, key) then
				sold += 1
				coins += Bones.SellValue(key)
			end
		end
	end
	if sold == 0 then
		reply(player, false, if action == "dupes" then "You have no duplicate fossils" else "You have no fossils to sell", "🦴")
		return
	end
	coins = math.floor(coins * Monetization.MoneyMultiplier(profile.gamepasses, profile.boostUntil) * (if profile.gamepasses.sell2 then Monetization.SELL_MULT else 1))
	profile.coins += coins
	profile.stats.totalSold += sold
	InventoryService.Push(player)
	reply(player, true, if sold == 1 then `Sold for {coins} coins!` else `Sold {sold} fossils for {coins} coins!`, "💰")
	log:Info(`{player.Name} ha venut {sold} fòssils per {coins}`)
	task.spawn(DataService.Save, player)
end

-- ─────────────────────────── EL MAPA ───────────────────────────

local function setupStand(stand: BasePart)
	local def = Tools.ById[stand:GetAttribute("ToolId") :: any]
	if not def then
		log:Warn(`ToolStand amb ToolId desconegut: {stand:GetFullName()}`)
		return
	end
	-- l'eina, dreta i surant una mica sobre el sòcol
	local top = stand.CFrame * CFrame.new(0, stand.Size.Y / 2 + 2.6, 0) * CFrame.Angles(0, 0, math.rad(12))
	local display = ToolModels.MakeDisplay(def, top)
	display:SetAttribute("ToolId", def.id)
	CollectionService:AddTag(display, "ToolDisplay")
	display.Parent = stand
	-- mantenir E obre la fitxa (al client); comprar va per ShopRequest
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyTool"
	prompt.ObjectText = def.name
	prompt.ActionText = "View"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand
	standOf[def.id] = stand
end

-- Un botiguer: un avatar de Roblox normal, quiet, amb barret. En Rex (eines)
-- i la Bonnie (compra fòssils) surten d'aquí.
type Keeper = { name: string, title: string, shirt: Color3, hat: Color3, prompt: string, action: string }
local REX: Keeper = { name = "Rex", title = "Rex · Dig & Co.", shirt = Color3.fromRGB(196, 170, 120), hat = Color3.fromRGB(206, 182, 128), prompt = "TalkShopkeeper", action = "Talk" }
local BONNIE: Keeper = { name = "Bonnie", title = "Bonnie · Fossil Buyer", shirt = Color3.fromRGB(90, 170, 120), hat = Color3.fromRGB(240, 200, 90), prompt = "TalkSeller", action = "Sell fossils" }

local function spawnShopkeeper(spot: BasePart, keeper: Keeper?)
	local k = keeper or REX
	local ok, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Color3.fromRGB(234, 184, 146)
		desc.LeftArmColor = desc.HeadColor
		desc.RightArmColor = desc.HeadColor
		desc.TorsoColor = k.shirt
		desc.LeftLegColor = Color3.fromRGB(110, 84, 56)
		desc.RightLegColor = Color3.fromRGB(110, 84, 56)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		log:Warn("no s'ha pogut crear el botiguer:", rig)
		return
	end
	local npc = rig :: Model
	npc.Name = k.name
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	root.Anchored = true
	npc:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
	-- barret d'explorador
	local head = npc:FindFirstChild("Head") :: BasePart?
	if head then
		local function hatPart(size: Vector3, offset: CFrame, shape: Enum.PartType?)
			local p = Instance.new("Part")
			p.Size = size
			if shape then
				p.Shape = shape
			end
			p.Color = k.hat
			p.Material = Enum.Material.Fabric
			p.CanCollide = false
			p.Massless = true
			p.CFrame = head.CFrame * offset
			p.Parent = npc
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = p
			w.Parent = p
		end
		-- ala (un cilindre pla) i copa
		hatPart(Vector3.new(0.2, 2.6, 2.6), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
		hatPart(Vector3.new(1.4, 0.8, 1.4), CFrame.new(0, 0.95, 0))
	end
	-- nom a sobre del cap
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(200, 50)
	tag.StudsOffset = Vector3.new(0, 3.6, 0)
	tag.MaxDistance = 60
	tag.Adornee = head or root
	tag.Parent = npc
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = k.title
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 110)
	label.TextStrokeTransparency = 0.2
	label.Parent = tag
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = k.prompt
	prompt.ActionText = k.action
	prompt.ObjectText = k.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	npc.Parent = spot.Parent
end

local function setupZoneUnlock(part: BasePart)
	local zoneId = part:GetAttribute("Zone")
	local zone = if Zones.IsZoneId(zoneId) then Zones.ById[zoneId :: string] else nil
	if not zone or zone.unlockCost <= 0 then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockZone"
	prompt.ObjectText = zone.name
	prompt.ActionText = `Unlock · {zone.unlockCost} 💰`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		if limiter:Check(player) and near(player, part) then
			unlockZone(player, zone.id)
		end
	end)
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function ShopService.Init()
	-- Perfils antics o tocats: l'eina equipada ha de ser una que es té.
	-- A Init perquè un perfil pot carregar abans d'arribar a Start.
	DataService.ProfileLoaded:Connect(function(_player: Player, profile: DataService.Profile)
		if not table.find(profile.ownedTools, Tools.DEFAULT) then
			table.insert(profile.ownedTools, Tools.DEFAULT)
		end
		if not table.find(profile.ownedTools, profile.equippedTool) or not Tools.ById[profile.equippedTool] then
			profile.equippedTool = Tools.DEFAULT
		end
	end)
end

function ShopService.Start()
	for _, stand in CollectionService:GetTagged("ToolStand") do
		if stand:IsA("BasePart") then
			setupStand(stand)
		end
	end
	for _, spot in CollectionService:GetTagged("ShopkeeperSpot") do
		if spot:IsA("BasePart") then
			spawnShopkeeper(spot, REX)
		end
	end
	for _, spot in CollectionService:GetTagged("SellerSpot") do
		if spot:IsA("BasePart") then
			table.insert(sellerSpots, spot)
			spawnShopkeeper(spot, BONNIE)
		end
	end
	local sellLimiter = RateLimiter.new(2)
	Remotes.SellRequest.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if sellLimiter:Check(player) then
			sell(player, action, payload)
		end
	end)
	for _, part in CollectionService:GetTagged("ZoneUnlock") do
		if part:IsA("BasePart") then
			setupZoneUnlock(part)
		end
	end
	-- "buy": des de la fitxa de l'eina, al costat del seu sòcol.
	-- "equip": una eina que ja tens, des d'on sigui (motxilla o fitxa).
	Remotes.ShopRequest.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if type(payload) ~= "string" or not Tools.ById[payload] or not limiter:Check(player) then
			return
		end
		if action == "buy" then
			local stand = standOf[payload]
			if stand and near(player, stand) then
				buyOrEquip(player, payload)
			end
		elseif action == "equip" then
			local profile = DataService.Get(player)
			if profile and table.find(profile.ownedTools, payload) then
				buyOrEquip(player, payload)
			end
		end
	end)
end

return ShopService
