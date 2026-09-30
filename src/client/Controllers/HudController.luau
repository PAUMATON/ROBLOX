--!strict

-- HudController — la pantalla principal: monedes, rajoles de l'esquerra,
-- intercanvi i renda a la dreta, i el progrés de l'índex a baix.
-- Nomes ensenya el que diu el servidor i demana coses (finestres, viatges).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Tools = require(Config:WaitForChild("Tools"))
local Museum = require(Config:WaitForChild("Museum"))
local Zones = require(Config:WaitForChild("Zones"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C

local HudController = {}

local badges: { [string]: Widgets.Badge } = {}
local coinLabel: TextLabel
local coinIcon: TextLabel
local rateLabel: TextLabel
local incomeBig: TextLabel
local incomeSmall: TextLabel
local leftInfo: TextLabel
local rightInfo: TextLabel
local indexBar: Widgets.Bar
local pipRow: Frame
local barButton: TextButton
local leftColumn: Frame
local tileButtons: { TextButton } = {}
local travelMenu: Frame
local travelButtons: { TextButton } = {}
local setTravelMenu: (boolean) -> ()
local rightFrame: Frame
local incomeCard: Frame
local bottomFrame: Frame

local shownCoins = 0
local coinValue: NumberValue
local lastCoins: number? = nil
local lastBoneTotal: number? = nil
local newBones = 0
local lastDiscovered: number? = nil
local newDiscoveries = 0
local lastTravel = 0

-- ─────────────────────────── AJUDES ───────────────────────────

-- Els destins de viatge viuen dins del menú ✈️ Travel: la seva insígnia es
-- veu al botó del menú i, resumida, a la rajola de Travel (👆 mana sobre "!";
-- el 🔒 de la platja no cal que surti a fora).
local TRAVEL_ITEMS = { GoMuseum = true, GoCity = true, GoConstruction = true, GoBeach = true, GoEgypt = true, Shop = true }
local travelBadges: { [string]: { text: string?, color: Color3? } } = {}

local function refreshTravelBadge()
	local pick: { text: string?, color: Color3? }? = nil
	for _, b in travelBadges do
		if b.text == "👆" then
			pick = b
			break
		elseif b.text == "!" and not pick then
			pick = b
		end
	end
	local badge = badges.Travel
	if badge then
		badge.set(pick and pick.text, pick and pick.color)
	end
end

-- Rajoles on la guia (tutorial o missió) hi ha posat 👆: les insígnies
-- automàtiques (comptadors, "!") no les trepitgen fins que la guia les treu.
local pointed: { [string]: boolean } = {}

local function applyBadge(name: string, text: string?, color: Color3?)
	local badge = badges[name]
	if badge then
		badge.set(text, color)
	end
	if TRAVEL_ITEMS[name] then
		travelBadges[name] = { text = text, color = color }
		refreshTravelBadge()
	end
end

-- La guia (tutorial i missions): 👆 mana sobre les automàtiques
function HudController.SetBadge(name: string, text: string?, color: Color3?)
	pointed[name] = text == "👆"
	applyBadge(name, text, color)
end

-- Insígnies automàtiques (comptadors, avisos): no treuen el 👆 de la guia
function HudController.AutoBadge(name: string, text: string?, color: Color3?)
	if not pointed[name] then
		applyBadge(name, text, color)
	end
end

local function travel(destination: string, message: string)
	local now = os.clock()
	if now - lastTravel < 2 then
		Effects.Toast("⏳ One moment...", C.grey)
		return
	end
	lastTravel = now
	Remotes.TravelRequest:FireServer(destination)
	Theme.Play("open", 0.5)
	local snapshot = ProfileController.Get()
	local zone = Zones.ById[destination]
	if zone and snapshot and not Zones.IsUnlocked(snapshot.zones, destination) then
		Effects.Toast(`🔒 {zone.name}: you can visit, but digging is still locked`, C.purple)
	else
		Effects.Toast(message, C.cyan, "pop")
	end
end

-- ─────────────────────────── CONSTRUCCIO ───────────────────────────

local TILE, GAP = 108, 12 -- rajoles de l'esquerra

setTravelMenu = function(open: boolean)
	if travelMenu and travelMenu.Visible ~= open then
		travelMenu.Visible = open
		if open then
			Effects.PopIn(travelMenu, 0.25)
			Theme.Play("open", 0.35)
		end
	end
end

local function buildLeft(gui: ScreenGui)
	leftColumn = Instance.new("Frame")
	leftColumn.Name = "Left"
	leftColumn.BackgroundTransparency = 1
	-- On va la posa layout() (depèn de si és mòbil)
	leftColumn.Size = UDim2.fromOffset(236, 560)
	leftColumn.Parent = gui
	Theme.AutoScale(leftColumn)

	-- Monedes
	local coinPill = Widgets.Card(leftColumn, {
		Size = UDim2.fromOffset(232, 70),
		Position = UDim2.fromOffset(0, 0),
	}, C.panel, 35)
	coinIcon = Theme.Icon(coinPill, "$", {
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.fromOffset(6, 4),
		ZIndex = 3,
	})
	coinLabel = Theme.Text(coinPill, "0", {
		Size = UDim2.new(1, -86, 0, 50),
		Position = UDim2.fromOffset(74, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.yellow,
		StrokeThickness = 3.5,
		ZIndex = 3,
	})
	rateLabel = Theme.Text(leftColumn, "+0 $/s", {
		Size = UDim2.fromOffset(200, 26),
		Position = UDim2.fromOffset(22, 74),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.green,
	})

	-- Rajoles: 4 i prou (un provador va dir que la UI era massa). Els 5
	-- viatges van dins del menú ✈️ Travel.
	local tiles = {
		{ id = "Backpack", text = "Backpack", icon = "🎒", color = C.orange, click = function()
			setTravelMenu(false)
			Windows.Toggle("Backpack")
		end },
		{ id = "Index", text = "Index", icon = "📖", color = C.purple, click = function()
			setTravelMenu(false)
			Windows.Toggle("Index")
		end },
		{ id = "Museum", text = "Museum", icon = "🏛️", color = C.blue, click = function()
			setTravelMenu(false)
			Windows.Toggle("Museum")
		end },
		{ id = "Travel", text = "Travel", icon = "✈️", color = C.green, click = function()
			setTravelMenu(not travelMenu.Visible)
		end },
	}
	for i, t in tiles do
		local b = Widgets.Button({
			Parent = leftColumn,
			Size = UDim2.fromOffset(TILE, TILE),
			Color = t.color,
			Icon = t.icon,
			Text = t.text,
			Layout = "tile",
			Radius = 18,
			OnClick = t.click,
		})
		tileButtons[i] = b.button
		badges[t.id] = Widgets.Badge(b.button, 34)
	end

	-- el menú de viatges: una fila de rajoles que surt al costat de Travel
	travelMenu = Instance.new("Frame")
	travelMenu.Name = "TravelMenu"
	travelMenu.BackgroundTransparency = 1
	-- la mida i on va cada rajola ho posa layout() (una fila o dues)
	travelMenu.Size = UDim2.fromOffset(6 * TILE + 5 * GAP, TILE)
	travelMenu.Visible = false
	travelMenu.ZIndex = 5
	travelMenu.Parent = leftColumn
	local items = {
		{ id = "GoMuseum", text = "My Museum", icon = "🌀", color = C.pink, dest = "museum", msg = "✈️ Off to your museum!" },
		{ id = "GoCity", text = "Plaza", icon = "⛲", color = C.green, dest = "city", msg = "✈️ Off to the plaza!" },
		{ id = "GoConstruction", text = "Dig Site", icon = "🏗️", color = C.yellow, dest = "construction", msg = "✈️ Off to the dig site!" },
		{ id = "GoBeach", text = "Beach", icon = "🏖️", color = C.cyan, dest = "beach", msg = "✈️ Off to the beach!" },
		-- Egipte és una illa: només s'hi arriba volant (no hi ha camí)
		{ id = "GoEgypt", text = "Egypt", icon = "PYRAMIDS", color = C.orange, dest = "egypt", msg = "✈️ Flying to Egypt!" },
		{ id = "Shop", text = "Tool Shop", icon = "🛠️", color = C.red, dest = "shop", msg = "✈️ Off to Dig & Co.!" },
	}
	for i, t in items do
		local b = Widgets.Button({
			Parent = travelMenu,
			Size = UDim2.fromOffset(TILE, TILE),
			Position = UDim2.fromOffset((i - 1) * (TILE + GAP), 0),
			Color = t.color,
			Icon = t.icon,
			Text = t.text,
			Layout = "tile",
			Radius = 18,
			ZIndex = 6,
			OnClick = function()
				setTravelMenu(false)
				travel(t.dest, t.msg)
			end,
		})
		travelButtons[i] = b.button
		badges[t.id] = Widgets.Badge(b.button, 34)
	end
end

local function buildRight(gui: ScreenGui)
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Size = UDim2.fromOffset(310, 396)
	right.Parent = gui
	rightFrame = right
	Theme.AutoScale(right)

	-- la botiga de Robux: el botó més vistós de la pantalla
	local store = Widgets.Button({
		Parent = right,
		Size = UDim2.fromOffset(310, 92),
		Color = C.gold,
		Icon = "🛒",
		Text = "STORE",
		Radius = 20,
		OnClick = function()
			Windows.Toggle("Store")
		end,
	})
	Effects.Shine(store.button, 20, 2)
	Effects.Pulse(store.button, 0.04, 1.6)
	badges.Store = Widgets.Badge(store.button, 40)

	local trade = Widgets.Button({
		Parent = right,
		Position = UDim2.fromOffset(0, 106),
		Size = UDim2.fromOffset(310, 92),
		Gradient = Theme.RAINBOW,
		Icon = "🤝",
		Text = "~Trade~",
		Radius = 20,
		OnClick = function()
			Windows.Toggle("Trade")
		end,
	})
	if trade.gradient then
		Effects.Spin(trade.gradient, 45)
	end
	Effects.Shine(trade.button, 20, 3)
	badges.Trade = Widgets.Badge(trade.button, 40)

	local card = Widgets.Card(right, {
		Size = UDim2.fromOffset(310, 170),
		Position = UDim2.fromOffset(0, 218),
	}, C.blue, 20)
	incomeCard = card
	Theme.Shade(card)
	Theme.Text(card, "MUSEUM INCOME", {
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 10),
	})
	local inner = Widgets.Card(card, {
		Size = UDim2.new(1, -28, 0, 70),
		Position = UDim2.fromOffset(14, 46),
	}, C.white, 14)
	incomeBig = Theme.Text(inner, "+0 $/s", {
		Size = UDim2.new(1, -20, 1, -14),
		Position = UDim2.fromOffset(10, 7),
		TextColor3 = C.green,
		StrokeThickness = 3,
	})
	incomeSmall = Theme.Text(card, "0/10 cases", {
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 128),
		TextColor3 = C.cream,
	})
end

local function buildBottom(gui: ScreenGui)
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	-- Deixa lloc a la motxilla de Roblox (la fila d'eines de baix)
	bottom.Position = UDim2.new(0.5, 0, 1, -86)
	bottom.Size = UDim2.fromOffset(840, 150)
	bottom.Parent = gui
	bottomFrame = bottom
	Theme.AutoScale(bottom)

	leftInfo = Theme.Text(bottom, "", {
		Size = UDim2.fromOffset(400, 30),
		Position = UDim2.fromOffset(6, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.green,
	})
	rightInfo = Theme.Text(bottom, "", {
		Size = UDim2.fromOffset(400, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.pink,
	})

	-- Les 7 rareses, en petit: s'encenen quan n'has trobat alguna peça
	pipRow = Instance.new("Frame")
	pipRow.BackgroundTransparency = 1
	pipRow.AnchorPoint = Vector2.new(0.5, 0)
	pipRow.Position = UDim2.new(0.5, 0, 0, 32)
	pipRow.Size = UDim2.fromOffset(7 * 40 + 6 * 8, 40)
	pipRow.Parent = bottom
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pipRow

	indexBar = Widgets.Bar(bottom, UDim2.fromOffset(840, 70), UDim2.new(0.5, 0, 1, 0), Vector2.new(0.5, 1))
	-- La barra és clicable: obre l'índex
	barButton = Instance.new("TextButton")
	barButton.BackgroundTransparency = 1
	barButton.Text = ""
	barButton.Size = UDim2.fromScale(1, 1)
	barButton.ZIndex = 10
	barButton.Parent = indexBar.frame
	barButton.Activated:Connect(function()
		Theme.Play("click", 0.5)
		Windows.Open("Index")
	end)
end

-- ─────────────────────────── DISPOSICIO ───────────────────────────
-- Ordinador i tauleta: rajoles 2x4 a baix a l'esquerra, botiga i comerç a
-- la dreta i la barra de l'índex a baix.
-- Mòbil (Theme.IsCompact): a baix a l'esquerra hi ha el joystick i a baix
-- a la dreta el botó de saltar, i el que hi hagi a sobre no es pot fer
-- servir. Rajoles 4x2 a dalt a l'esquerra, botiga i comerç a dalt a la
-- dreta (sota els premis) i fora la barra de l'índex i la targeta de renda
-- (la renda ja surt sota les monedes; l'índex té la seva rajola).

local function layout(s: number)
	local compact = Theme.IsCompact()
	local cols = if compact then 4 else 2
	for i, b in tileButtons do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		b.Position = UDim2.fromOffset(col * (TILE + GAP), 108 + row * (TILE + GAP))
	end
	local rows = math.ceil(#tileButtons / cols)
	leftColumn.Size = UDim2.fromOffset(cols * TILE + (cols - 1) * GAP, 108 + rows * (TILE + GAP))
	-- el menú de viatges: a la dreta de les rajoles, a l'altura de la de
	-- Travel (ordinador), o just a sota de la fila (mòbil)
	local travelTile = tileButtons[#tileButtons]
	-- al mòbil, els destins en dues files de 3 (sis en fila no hi caben)
	local perRow = if compact then 3 else #travelButtons
	for i, b in travelButtons do
		b.Position = UDim2.fromOffset(((i - 1) % perRow) * (TILE + GAP), math.floor((i - 1) / perRow) * (TILE + GAP))
	end
	local travelRows = math.ceil(#travelButtons / perRow)
	travelMenu.Size = UDim2.fromOffset(perRow * TILE + (perRow - 1) * GAP, travelRows * TILE + (travelRows - 1) * GAP)
	if compact then
		travelMenu.Position = UDim2.fromOffset(0, 108 + rows * (TILE + GAP))
	else
		travelMenu.Position = UDim2.fromOffset(cols * (TILE + GAP), travelTile.Position.Y.Offset)
	end

	if compact then
		leftColumn.AnchorPoint = Vector2.new(0, 0)
		leftColumn.Position = UDim2.fromOffset(12, 8)
		rightFrame.AnchorPoint = Vector2.new(1, 0)
		-- sota la fila de premis (Daily/Gifts/Invite), que fa 110 d'alt
		rightFrame.Position = UDim2.new(1, -12, 0, 12 + 110 * s)
		rightFrame.Size = UDim2.fromOffset(310, 198)
		incomeCard.Visible = false
		bottomFrame.Visible = false
	else
		-- Ancorada just a sobre de la barra de baix (a dalt a l'esquerra hi
		-- ha el xat de Roblox). La barra fa 150 d'alt i és a 86 del marge.
		leftColumn.AnchorPoint = Vector2.new(0, 1)
		leftColumn.Position = UDim2.new(0, 18, 1, -(86 + 160 * s))
		rightFrame.AnchorPoint = Vector2.new(1, 0.5)
		rightFrame.Position = UDim2.new(1, -18, 0.5, 30)
		rightFrame.Size = UDim2.fromOffset(310, 396)
		incomeCard.Visible = true
		bottomFrame.Visible = true
	end
end

-- ─────────────────────────── REFRESC ───────────────────────────

-- Fites de diners: en passar-ne una, festa. Només les noves d'aquesta
-- partida (la primera instantània fixa on ets i no es celebra).
local MILESTONES: { { at: number, text: string } } = {
	{ at = 1e3, text = "Your first 1K $!" },
	{ at = 1e4, text = "10K $! Nice!" },
	{ at = 1e5, text = "100K $! You're rich!" },
	{ at = 1e6, text = "💎 MILLIONAIRE! 1M $" },
	{ at = 1e7, text = "💎 10M $! Big shot!" },
	{ at = 1e8, text = "👑 100M $! Tycoon!" },
	{ at = 1e9, text = "👑 BILLIONAIRE! 1B $" },
	{ at = 1e10, text = "🌟 10B $! LEGEND!" },
	{ at = 1e11, text = "🌟 100B $! UNSTOPPABLE!" },
	{ at = 1e12, text = "🚀 TRILLIONAIRE!" },
}
local milestoneReached = 0 -- índex de l'última fita passada

local function checkMilestones(coins: number, first: boolean)
	local reached = milestoneReached
	for i, m in MILESTONES do
		if coins >= m.at then
			reached = i
		end
	end
	if not first and reached > milestoneReached then
		local m = MILESTONES[reached]
		task.delay(0.3, function()
			Effects.Toast(`🎉 {m.text}`, C.gold, "")
			Theme.Fanfare(2)
			Effects.Confetti(leftColumn, 90)
			Effects.Pop(coinIcon, 0.8)
		end)
	end
	milestoneReached = math.max(milestoneReached, reached)
end

-- Monedes: compten cap amunt i salta un "+N $". `passive` = la renda del
-- museu de cada segon: sense so (si no, sonaria un "pop" cada segon).
local function showCoins(coins: number, passive: boolean?)
	checkMilestones(coins, lastCoins == nil)
	if lastCoins and coins > lastCoins then
		local gain = coins - lastCoins
		Effects.Float(leftColumn, "+" .. Theme.Short(gain) .. " $", C.green, UDim2.fromOffset(170, 20), 130)
		Effects.Pop(coinIcon, if passive then 0.12 else 0.3)
		if not passive then
			Theme.Play("pop", 0.3, 1.3)
		end
	end
	lastCoins = coins
	Effects.Tween(coinValue, if passive then 0.9 else 0.6, { Value = coins })
end

local function refresh(snapshot: ProfileController.Snapshot)
	showCoins(snapshot.coins)

	local money = (snapshot :: any).money or 1
	local rate = snapshot.rate * money
	rateLabel.Text = `+{Museum.PerSecondText(rate)} $/s`
	incomeBig.Text = `+{Museum.PerSecondText(rate)} $/s`
	local used = 0
	for slot = 1, snapshot.slots do
		if snapshot.museum[tostring(slot)] then
			used += 1
		end
	end
	incomeSmall.Text = if money > 1
		then `{used}/{snapshot.slots} cases · $ x{string.format("%g", math.floor(money * 10 + 0.5) / 10)} money`
		else `{used}/{snapshot.slots} cases on display`

	-- Fòssils nous des de l'últim cop que es va obrir la motxilla
	local total = 0
	for _, n in snapshot.bones do
		total += n
	end
	if lastBoneTotal and total > lastBoneTotal then
		newBones += total - lastBoneTotal
	end
	lastBoneTotal = total
	-- Descobriments nous des de l'últim cop que es va obrir l'índex
	local found = 0
	local rarityFound: { [string]: boolean } = {}
	for key in snapshot.discovered or {} do
		local info = Bones.PieceInfo[key]
		if info then
			found += 1
			rarityFound[info.rarity] = true
		end
	end
	if lastDiscovered and found > lastDiscovered then
		newDiscoveries += found - lastDiscovered
	end
	lastDiscovered = found

	local canAssemble = false
	for _, def in Bones.SKELETONS do
		if Bones.CanAssemble(snapshot.bones, def.id) then
			canAssemble = true
		end
	end
	local haveItems = total > 0 or next(snapshot.skeletons) ~= nil
	HudController.AutoBadge("Backpack", if canAssemble then "🔨" elseif newBones > 0 then tostring(math.min(newBones, 99)) else nil, if canAssemble then C.gold else nil)
	HudController.AutoBadge("Index", if newDiscoveries > 0 then "NEW" else nil, C.purple)
	HudController.AutoBadge("Museum", if haveItems and used < snapshot.slots then "!" else nil)
	HudController.AutoBadge("GoBeach", if Zones.IsUnlocked(snapshot.zones, "beach") then nil else "🔒", C.grey)
	HudController.AutoBadge("GoEgypt", if Zones.IsUnlocked(snapshot.zones, "egypt") then nil else "🔒", C.grey)
	-- botiga: "!" si pots pagar una eina que encara no tens
	local canBuy = false
	for _, def in Tools.LIST do
		-- (les d'Egipte, només si Egipte és obert: es compren a l'illa)
		local reachable = not def.zone or Zones.IsUnlocked(snapshot.zones, def.zone)
		if reachable and def.price > 0 and snapshot.coins >= def.price and not table.find(snapshot.tools or {}, def.id) then
			canBuy = true
		end
	end
	HudController.AutoBadge("Shop", if canBuy then "!" else nil, C.green)

	-- Barra de baix: progrés de l'índex i les rareses que ja has vist
	Widgets.Clear(pipRow)
	for i, rarity in Bones.RARITIES do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(40, 40)
		pip.LayoutOrder = i
		pip.BackgroundColor3 = if rarityFound[rarity] then Bones.RARITY_COLORS[rarity] else Color3.fromRGB(40, 36, 54)
		pip.Parent = pipRow
		Theme.Corner(pip, 10)
		local st = Theme.Stroke(pip, 2.5)
		if rarityFound[rarity] and rarity == "Secret" then
			st.Color = C.white
			local g = Instance.new("UIGradient")
			g.Color = Theme.RAINBOW
			g.Parent = st
		end
		Theme.Text(pip, if rarityFound[rarity] then string.sub(rarity, 1, 1) else "?", {
			Size = UDim2.fromScale(0.7, 0.7),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
	end
	local all = #Bones.ALL_KEYS
	if found == 0 then
		indexBar.set(0, "🦴 Dig to find your first fossil!", `0 / {all}`, C.gold)
	else
		indexBar.set(found / all, "📖 INDEX", `{found} / {all} fossils`, C.purple)
	end

	local tool = Tools.Get(snapshot.equippedTool)
	leftInfo.Text = `🍀 {tool.name}: {Tools.LuckText(tool.luck)} luck`
	rightInfo.Text = `🏛️ Museum {used}/{snapshot.slots} cases`
	if not snapshot.persisted then
		rightInfo.Text ..= "  ·  ⚠️ NOT SAVED"
	end
end

-- ─────────────────────── BENVINGUDA (renda offline) ───────────────────────

local function formatDuration(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return if m > 0 then `{h}h {m}m` else `{h}h`
	elseif m > 0 then
		return `{m}m`
	end
	return `{math.floor(seconds)}s`
end

-- Carta de "mentre no hi eres, el museu ha guanyat X". Les monedes ja son
-- al perfil (les ha sumat el servidor); el boto nomes es la celebracio.
local function showWelcomeBack(data: any)
	local gui = Theme.Screen("WelcomeGui", 16)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromOffset(480, 340)
	holder.Parent = gui
	Theme.AutoScale(holder)

	Effects.Sunburst(holder, C.yellow, 760)
	local card = Widgets.Card(holder, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, C.purple, 28)
	Theme.Shade(card, 1, 0.65)
	Theme.Text(card, "WELCOME BACK!", {
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.fromOffset(20, 18),
		ZIndex = 3,
		StrokeThickness = 4,
	})
	Theme.Text(card, "Your museum earned", {
		Size = UDim2.new(1, -60, 0, 30),
		Position = UDim2.fromOffset(30, 82),
		TextColor3 = C.cream,
		ZIndex = 3,
	})
	local amount = Theme.Text(card, `+{Theme.Short(tonumber(data.coins) or 0)} $`, {
		Size = UDim2.new(1, -60, 0, 78),
		Position = UDim2.fromOffset(30, 114),
		TextColor3 = C.yellow,
		ZIndex = 3,
		StrokeThickness = 4.5,
	})
	local away = `while you were away ({formatDuration(tonumber(data.seconds) or 0)})`
	if data.capped then
		away ..= ` · max {data.capHours}h`
	end
	Theme.Text(card, away, {
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.fromOffset(30, 196),
		TextColor3 = C.cream,
		ZIndex = 3,
	})

	local closed = false
	local function collectNow()
		if closed then
			return
		end
		closed = true
		Effects.Confetti(holder, 50)
		Effects.Pop(coinIcon, 0.5)
		Effects.Tween(Effects.ScaleOf(card), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.9, function()
			gui:Destroy()
		end)
	end
	local collect = Widgets.Button({
		Parent = card,
		Size = UDim2.fromOffset(260, 70),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Color = C.green,
		Icon = "$",
		Text = "COLLECT!",
		Sound = "reward",
		ZIndex = 3,
		OnClick = collectNow,
	})
	-- les monedes ja són teves: tancar-la també les cobra
	Widgets.CloseButton({ Parent = card, OnClick = collectNow })
	Effects.Shine(collect.button, 14, 1.2)
	Effects.PopIn(card, 0.5)
	Effects.Pop(amount, 0.3)
	Theme.Play("reward", 0.6)
end

-- ─────────────────────────── CICLE DE VIDA ───────────────────────────

function HudController.Start()
	local gui = Theme.Screen("HudGui", 1)
	buildLeft(gui)
	buildRight(gui)
	buildBottom(gui)
	Theme.OnScale(layout)

	coinValue = Instance.new("NumberValue")
	coinValue.Changed:Connect(function(v: number)
		if math.floor(v) ~= shownCoins then
			shownCoins = math.floor(v)
			coinLabel.Text = Theme.Short(shownCoins)
		end
	end)

	-- Obrir la motxilla (o l'índex) vol dir que ja has vist el que és nou
	Windows.OnChanged(function(name: string?)
		-- una finestra oberta tapa el menú de viatges
		if name then
			setTravelMenu(false)
		end
		if name == "Backpack" or name == "Index" then
			if name == "Backpack" then
				newBones = 0
			else
				newDiscoveries = 0
			end
			local snapshot = ProfileController.Get()
			if snapshot then
				refresh(snapshot)
			end
		end
	end)

	ProfileController.Changed:Connect(refresh)
	ProfileController.CoinsChanged:Connect(function(coins: number)
		if lastCoins and coins > lastCoins then
			Theme.CoinTick()
		end
		showCoins(coins, true)
	end)
	-- Capa per al confeti de les compres
	local fx = Instance.new("Frame")
	fx.Name = "Fx"
	fx.BackgroundTransparency = 1
	fx.Size = UDim2.fromScale(1, 1)
	fx.ZIndex = 50
	fx.Parent = gui
	Remotes.Notify.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		if data.kind == "offline" then
			-- Espera que la pantalla hagi carregat abans de celebrar-ho
			task.delay(1.5, showWelcomeBack, data)
		elseif data.kind == "event" then
			-- munt daurat: tothom ho sap i hi corre
			Effects.Toast(tostring(data.message), C.gold, "")
			Theme.Fanfare(1)
			Theme.Note("sparkle", 0.6, 1)
			Effects.Confetti(fx, 40)
		elseif data.kind == "announce" and data.userId ~= game:GetService("Players").LocalPlayer.UserId then
			-- algú del servidor ha trobat una cosa grossa
			local color = Bones.RARITY_COLORS[data.rarity] or C.purple
			Effects.Toast(`📣 {tostring(data.message)}`, color, "")
			if data.rarity == "Secret" then
				Theme.Fanfare(2)
				Effects.Flash(C.white, 0.35)
			else
				Theme.Note("notify", 0.5, 1.2)
			end
		elseif data.kind == "shop" then
			if data.ok then
				-- la festa que toca (ho diu el servidor): diners, fanfàrria o gran
				local kind = data.fx
				Effects.Toast((data.icon or "🎉") .. " " .. tostring(data.message), C.green, if kind then "" else "reward") -- ("": sense so, ja sona la festa)
				if kind == "cash" then
					Theme.Cash(tonumber(data.amount))
					Effects.Confetti(fx, 40)
					Effects.Pop(coinIcon, 0.5)
				elseif kind == "big" then
					Theme.Fanfare(2)
					Effects.Confetti(fx, 140)
					Effects.Flash(C.yellow, 0.35)
				elseif kind == "fanfare" then
					Theme.Fanfare(1)
					Effects.Confetti(fx, 80)
				else
					Effects.Confetti(fx, 60)
				end
			else
				Effects.Toast((data.icon or "$") .. " " .. tostring(data.message), C.red, "error")
			end
		end
	end)
	local snapshot = ProfileController.Get()
	if snapshot then
		refresh(snapshot)
	else
		indexBar.set(0, "Loading...", "", C.gold)
	end
end

return HudController
