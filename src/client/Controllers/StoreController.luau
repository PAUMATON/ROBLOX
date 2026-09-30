--!strict

-- StoreController — la finestra STORE (Robux), estil "+1 Speed Keyboard
-- Escape": targetes grosses i brillants, la cadena de diners x2 → x128 on
-- només es pot comprar el següent, boosts, VIP i productes que es repeteixen.
-- Comprar ho fa el servidor (MonetizationService): aquí només es demana.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)
local HudController = require(script.Parent.HudController)

local C = Theme.C

local StoreController = {}

local window: Widgets.Window
local scroll: ScrollingFrame
local order = 0

local GROUP_COLORS = { money = C.gold, boost = C.cyan, vip = C.pink }

local function nextOrder(): number
	order += 1
	return order
end

local function section(title: string, color: Color3)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -16, 0, 40)
	f.LayoutOrder = nextOrder()
	f.Parent = scroll
	Theme.Text(f, title, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		StrokeThickness = 3,
	})
end

local function grid(): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -16, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = nextOrder()
	f.Parent = scroll
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(250, 250)
	g.CellPadding = UDim2.fromOffset(14, 14)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return f
end

-- Una targeta: icona gran amb raigs, nom, què fa i el botó de preu
local function card(parent: Instance, i: number, color: Color3, icon: string, name: string, desc: string, state: string, price: number, best: boolean?, onBuy: () -> ())
	local owned = state == "owned"
	local locked = state == "locked"
	local c = Widgets.Card(parent, { LayoutOrder = i, ClipsDescendants = true }, if owned then C.panelLight else color, 20)
	Theme.Shade(c, 1, 0.55)
	if not owned and not locked then
		Effects.Sunburst(c, C.white, 360).Position = UDim2.fromScale(0.5, 0.3)
	end
	Theme.Icon(c, icon, {
		Size = UDim2.fromOffset(84, 84),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		ZIndex = 3,
		TextTransparency = if locked then 0.5 else 0,
	})
	Theme.Text(c, name, {
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 96),
		ZIndex = 3,
		StrokeThickness = 3,
	})
	Theme.Text(c, desc, {
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.fromOffset(10, 130),
		TextColor3 = C.cream,
		TextWrapped = true,
		ZIndex = 3,
		StrokeThickness = 1.5,
	})
	if best then
		local tag = Widgets.Card(c, { Size = UDim2.fromOffset(110, 28), Position = UDim2.fromOffset(6, 6), ZIndex = 4 }, C.red, 14)
		Theme.Text(tag, "🔥 BEST", { Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), ZIndex = 5 })
	end
	local b = Widgets.Button({
		Parent = c,
		Size = UDim2.new(1, -24, 0, 52),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Color = if owned then C.grey elseif locked then C.panel else C.green,
		Text = if owned then "OWNED ✅" elseif locked then "🔒 LOCKED" else `R$ {price}`,
		Radius = 16,
		ZIndex = 3,
		OnClick = if owned then nil else onBuy,
	})
	if not owned and not locked then
		Effects.Shine(b.button, 16, 2.4)
	end
end

local function redraw()
	if not Windows.IsOpen("Store") then
		return
	end
	local keep = scroll.CanvasPosition
	Widgets.Clear(scroll)
	order = 0
	local snapshot = ProfileController.Get()
	local owned: { [string]: boolean } = (snapshot and (snapshot :: any).passes) or {}

	-- 1) les cadenes de sort i de diners: només el següent es pot comprar
	local g: Frame
	local i = 0
	for _, chain in { { "luck", "🍀 LUCK MULTIPLIERS · rare fossils way more often!", C.green, "luck2" }, { "money", "$ MONEY MULTIPLIERS · ALL coins x2, x4, x8", C.gold, "money2" } } do
	section(chain[2], chain[3])
	g = grid()
	i = 0
	for _, p in Monetization.PASSES do
		if p.group == chain[1] then
			i += 1
			local state = if owned[p.key] then "owned" elseif p.requires and not owned[p.requires] then "locked" else "buy"
			local desc = if state == "locked" then `Buy {Monetization.PassByKey[p.requires :: string].name} first` else p.desc
			card(g, i, chain[3], p.icon, p.name, desc, state, p.price, p.key == chain[4], function()
				Remotes.PurchaseRequest:FireServer("pass", p.key)
			end)
		end
	end
	end
	-- 2) boosts i VIP
	section("⚡ BOOSTS & VIP", C.cyan)
	g = grid()
	i = 0
	for _, p in Monetization.PASSES do
		if p.group ~= "money" and p.group ~= "luck" then
			i += 1
			card(g, i, GROUP_COLORS[p.group] or C.blue, p.icon, p.name, p.desc, if owned[p.key] then "owned" else "buy", p.price, p.key == "vip", function()
				Remotes.PurchaseRequest:FireServer("pass", p.key)
			end)
		end
	end
	-- 3) productes que es poden comprar tants cops com vulguis
	local left = (snapshot and (snapshot :: any).boostLeft) or 0
	section(if left > 0 then `🎁 SHOP · x2 Money active: {math.ceil(left / 60)} min left` else "🎁 SHOP · buy as many as you want", C.pink)
	g = grid()
	for k, p in Monetization.PRODUCTS do
		card(g, k, if p.boostMinutes then C.purple else C.orange, p.icon, p.name, p.desc, "buy", p.price, p.key == "coinsM", function()
			Remotes.PurchaseRequest:FireServer("product", p.key)
		end)
	end
	scroll.CanvasPosition = keep
end

-- ─────────────────────────── VIP ───────────────────────────
-- Etiqueta daurada sobre el cap i [VIP] al xat. L'atribut VIP el posa el servidor.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local function vipTag(player: Player)
	local function apply()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			return
		end
		local old = head:FindFirstChild("VipTag")
		if player:GetAttribute("VIP") ~= true then
			if old then
				old:Destroy()
			end
			return
		end
		if old then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "VipTag"
		bb.Size = UDim2.fromOffset(90, 30)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 80
		bb.Parent = head
		local t = Theme.Text(bb, "⭐ VIP", { TextColor3 = C.gold, StrokeThickness = 2.5 })
		t.Size = UDim2.fromScale(1, 1)
	end
	player:GetAttributeChangedSignal("VIP"):Connect(apply)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		apply()
	end)
	apply()
end

function StoreController.Start()
	Players.PlayerAdded:Connect(vipTag)
	for _, p in Players:GetPlayers() do
		task.spawn(vipTag, p)
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local from = source and Players:GetPlayerByUserId(source.UserId)
		if from and from:GetAttribute("VIP") == true then
			props.PrefixText = `<font color="#FFBE1E">[VIP]</font> ` .. message.PrefixText
		end
		return props
	end

	window = Widgets.Window({
		Name = "Store",
		Title = "STORE",
		Icon = "🛒",
		Color = C.gold,
		Size = Vector2.new(860, 620),
	})
	window.onOpen = redraw
	window.footer.Text = "Thank you for supporting the game! 💛"
	scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = C.muted
	scroll.Parent = window.body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = scroll

	ProfileController.Changed:Connect(function(snapshot: ProfileController.Snapshot)
		redraw()
		-- insígnia: el següent multiplicador de diners està disponible
		local owned = (snapshot :: any).passes or {}
		local nextMoney = false
		for _, p in Monetization.PASSES do
			if (p.group == "money" or p.group == "luck") and not owned[p.key] and (not p.requires or owned[p.requires]) then
				nextMoney = true
				break
			end
		end
		HudController.AutoBadge("Store", if nextMoney then "!" else nil, C.red)
	end)
end

return StoreController
