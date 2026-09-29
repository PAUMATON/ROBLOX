--!strict

-- IndexController — l'índex: TOTS els fòssils que existeixen, zona per
-- zona i esquelet per esquelet, amb els que has descobert algun cop.
-- No depèn del que tens ara (això és la motxilla): un fòssil que has
-- exposat, muntat o intercanviat continua comptant com a descobert.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Dig = require(Config:WaitForChild("Dig"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Tools = require(Config:WaitForChild("Tools"))
local Zones = require(Config:WaitForChild("Zones"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C

local IndexController = {}

local window: Widgets.Window
local scroll: ScrollingFrame
local progress: Widgets.Bar

local ZONE_ICONS = { construction = "🏗️", beach = "🏖️" }

function IndexController.Count(snapshot: ProfileController.Snapshot): (number, number)
	local found = 0
	for _, key in Bones.ALL_KEYS do
		if snapshot.discovered and snapshot.discovered[key] then
			found += 1
		end
	end
	return found, #Bones.ALL_KEYS
end

-- La sort que té ara (paleta × passis × boost), igual que la calcula el
-- servidor en excavar (DigService): és per ensenyar les probabilitats.
local function currentLuck(snapshot: ProfileController.Snapshot): number
	local s = snapshot :: any
	local tool = Tools.Get(snapshot.equippedTool)
	local boost = if (tonumber(s.luckBoostLeft) or 0) > 0 then 2 else 1
	return Dig.LuckMultiplier(0, tool.luck * Monetization.LuckMultiplier(s.passes or {}) * boost)
end

-- "1 in 1.2K": la probabilitat d'una raresa, com la veu el jugador
local function oneIn(p: number?): string
	if not p or p <= 0 then
		return "—"
	end
	return `1 in {Theme.Short(math.max(1, math.floor(1 / p + 0.5)))}`
end

local function row(snapshot: ProfileController.Snapshot, def: Bones.SkeletonDef, order: number, chances: { [string]: number })
	local discovered = snapshot.discovered or {}
	local found = 0
	for _, piece in Bones.PIECES do
		if discovered[Bones.PieceKey(def.id, piece.id)] then
			found += 1
		end
	end
	local complete = found == #Bones.PIECES
	local color = Bones.RARITY_COLORS[def.rarity]
	local card = Widgets.Card(scroll, {
		Size = UDim2.new(1, -16, 0, 86),
		LayoutOrder = order,
	}, if complete then Color3.fromRGB(70, 62, 30) else C.panelLight, 16)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke and complete then
		stroke.Color = C.gold
	end

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(120, 28)
	pill.Position = UDim2.fromOffset(12, 10)
	pill.BackgroundColor3 = color
	pill.Parent = card
	Theme.Corner(pill, 14)
	Theme.Stroke(pill, 2)
	Theme.Text(pill, string.upper(def.rarity), { Size = UDim2.new(1, -14, 1, -8), Position = UDim2.fromOffset(7, 4) })
	-- probabilitat de treure una peça d'aquesta raresa en una excavació
	-- (les normes de Roblox volen que es vegi, i dona emoció a les rares)
	Theme.Text(card, `🎲 {oneIn(chances[def.rarity])}`, {
		Size = UDim2.fromOffset(150, 24),
		Position = UDim2.fromOffset(142, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.cream,
		StrokeThickness = 1.5,
	})

	-- el nom no es veu fins que en trobes alguna peça
	local known = found > 0
	Theme.Text(card, if known then `{def.icon} {string.upper(def.name)}` else "❔ ???", {
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.fromOffset(12, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if known then C.white else C.muted,
	})

	local slots = Instance.new("Frame")
	slots.BackgroundTransparency = 1
	slots.AnchorPoint = Vector2.new(1, 0.5)
	slots.Position = UDim2.new(1, -150, 0.5, 0)
	slots.Size = UDim2.fromOffset(5 * 62 + 4 * 8, 62)
	slots.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = slots
	for i, piece in Bones.PIECES do
		local key = Bones.PieceKey(def.id, piece.id)
		Widgets.PieceTile(slots, key, if discovered[key] then 1 else 0, 62, nil, i)
	end

	Theme.Text(card, if complete then "COMPLETE ✓" else `{found}/{#Bones.PIECES}`, {
		Size = UDim2.fromOffset(130, 34),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		TextColor3 = if complete then C.gold else C.cream,
	})
end

local function redraw()
	local snapshot = ProfileController.Get()
	if not snapshot or not Windows.IsOpen("Index") then
		return
	end
	Widgets.Clear(scroll)
	local found, total = IndexController.Count(snapshot)
	progress.set(found / total, `📖 Discovered`, `{found} / {total}`, C.purple)
	local order = 0
	for _, zone in Zones.LIST do
		order += 1
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, -16, 0, 34)
		f.LayoutOrder = order
		f.Parent = scroll
		local lock = if Zones.IsUnlocked(snapshot.zones, zone.id) then "" else "  🔒"
		Theme.Text(f, `{ZONE_ICONS[zone.id] or "📍"} {string.upper(zone.name)}{lock}`, {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.yellow,
		})
		-- de la raresa més alta a la més baixa: el Secret, a dalt de tot
		local defs = {}
		for _, id in zone.skeletons do
			table.insert(defs, Bones.ById[id])
		end
		table.sort(defs, function(a, b)
			return Bones.RARITY_ORDER[a.rarity] > Bones.RARITY_ORDER[b.rarity]
		end)
		local chances = Dig.RarityChances(currentLuck(snapshot), Zones.PiecesByRarity[zone.id])
		for _, def in defs do
			order += 1
			row(snapshot, def, order, chances)
		end
	end
	window.footer.Text = `🎲 = chance per dig with your luck (x{string.format("%g", math.floor(currentLuck(snapshot) * 10 + 0.5) / 10)}) · found fossils stay here forever`
end

function IndexController.Start()
	window = Widgets.Window({
		Name = "Index",
		Title = "INDEX",
		Icon = "📖",
		Color = C.purple,
		Size = Vector2.new(820, 600),
	})
	progress = Widgets.Bar(window.body, UDim2.new(1, -8, 0, 50), UDim2.fromOffset(4, 0))
	scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 62)
	scroll.Size = UDim2.new(1, 0, 1, -62)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.Parent = window.body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = scroll

	window.onOpen = redraw
	ProfileController.Changed:Connect(redraw)
end

return IndexController
