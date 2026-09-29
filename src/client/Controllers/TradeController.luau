--!strict

-- TradeController — la finestra d'intercanvi i l'avis d'invitacio.
-- Nomes ensenya i demana: que es pot oferir i quan es fa el canvi ho
-- decideix el servidor (escrow atomic a TradeService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Constants = require(Config:WaitForChild("Constants"))
local Museum = require(Config:WaitForChild("Museum"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)
local HudController = require(script.Parent.HudController)

local C = Theme.C
local player = Players.LocalPlayer

local TradeController = {}

local window: Widgets.Window
local content: Frame
local inviteGui: ScreenGui
local state: any = { state = "idle" }
local invite: string? = nil
local readyAt = 0 -- os.clock() a partir del qual pots comerciar (ho diu el servidor)
local acceptAt = 0 -- os.clock() a partir del qual ACCEPT funciona (compte enrere)
local tick = 0 -- per no encadenar més d'un compte enrere

local function send(action: string, payload: any?)
	Remotes.TradeRequest:FireServer(action, payload)
end

-- Renda al museu d'una oferta: la mesura de "quant val" que fa servir la UI
local function worth(offer: { [string]: number }?): (number, number)
	local n, income = 0, 0
	for key, c in offer or {} do
		n += c
		income += Bones.IncomeOf(key) * c
	end
	return n, income
end

-- Avís si dones molt més del que reps (el servidor no ho impedeix: pot ser
-- un regal a un amic, però que sigui a consciència).
local function unfairText(): string?
	local _, mine = worth(state.myOffer)
	local _, theirs = worth(state.theirOffer)
	if mine <= 0 or mine < Constants.TRADE_UNFAIR_RATIO * theirs then
		return nil
	end
	if theirs <= 0 then
		return "⚠️ You get NOTHING back in this trade!"
	end
	return `⚠️ You give {math.floor(mine / theirs)}x more than you get. Are you sure?`
end

-- Tothom del servidor, estigui on estigui (per ordre alfabètic)
local function serverPlayers(): { Player }
	local out = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(out, other)
		end
	end
	table.sort(out, function(a, b)
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	return out
end

local function sectionTitle(text: string, x: number, y: number, color: Color3)
	Theme.Text(content, text, {
		Size = UDim2.fromOffset(370, 28),
		Position = UDim2.fromOffset(x, y),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
	})
end

-- Safata d'ofertes: rajoles de peça, clicables si es la teva (per treure).
local function offerTray(offer: { [string]: number }?, x: number, mine: boolean)
	local tray = Widgets.Card(content, {
		Size = UDim2.fromOffset(370, 150),
		Position = UDim2.fromOffset(x, 34),
		ClipsDescendants = true,
	}, Color3.fromRGB(36, 32, 52), 16)
	local grid = Widgets.Grid(tray, Vector2.new(66, 66), UDim2.fromScale(1, 1), nil, 8)
	local any = false
	for key, n in offer or {} do
		any = true
		Widgets.PieceTile(grid, key, n, 66, if mine then function()
			send("offer", { key = key, delta = -1 })
		end else nil)
	end
	if not any then
		Theme.Text(tray, "empty", {
			Size = UDim2.fromOffset(200, 30),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			TextColor3 = C.muted,
		})
	end
end

local function drawIdle()
	local wait = readyAt - os.clock()
	local banner = state.reason
	if wait > 0 then
		local m = math.ceil(wait / 60)
		banner = `⏳ You can trade after {Constants.TRADE_MIN_PLAY_MINUTES} min of play ({m} min left)`
	end
	if banner then
		Theme.Text(content, banner, {
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.fromOffset(10, 0),
			TextColor3 = C.yellow,
		})
	end
	local others = serverPlayers()
	sectionTitle(`PLAYERS IN THIS SERVER ({#others})`, 10, 44, C.cream)
	local grid = Widgets.Grid(content, Vector2.new(360, 70), UDim2.new(1, 0, 1, -80), UDim2.fromOffset(0, 76))
	if #others == 0 then
		Theme.Text(content, "Nobody else is in this server yet. Invite a friend!", {
			Size = UDim2.new(1, -40, 0, 32),
			Position = UDim2.fromOffset(20, 110),
			TextColor3 = C.muted,
		})
	end
	for i, other in others do
		local card = Widgets.Card(grid, { LayoutOrder = i }, C.panelLight, 16)
		Theme.Text(card, other.DisplayName, {
			Size = UDim2.new(1, -170, 0, 36),
			Position = UDim2.fromOffset(16, 17),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Widgets.Button({
			Parent = card,
			Size = UDim2.fromOffset(140, 50),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Color = C.pink,
			Icon = "🤝",
			Text = "TRADE",
			OnClick = function()
				send("request", other.UserId)
				Effects.Toast(`💌 Trade request sent to {other.DisplayName}`, C.pink, "pop")
			end,
		})
	end
end

local redraw: () -> () -- (més avall; el compte enrere la crida)

local function drawActive()
	sectionTitle("YOUR OFFER", 10, 0, C.yellow)
	sectionTitle(`{string.upper(state.other or "")}'S OFFER`, 404, 0, C.cyan)
	offerTray(state.myOffer, 0, not state.locked)
	offerTray(state.theirOffer, 394, false)

	-- el valor de cada oferta, perquè es vegi què s'hi posa
	for _, side in { { state.myOffer, 10 }, { state.theirOffer, 404 } } do
		local n, income = worth(side[1])
		Theme.Text(content, `{n} fossil{if n == 1 then "" else "s"} · {Museum.PerSecondText(income)} $/s in a museum`, {
			Size = UDim2.fromOffset(370, 22),
			Position = UDim2.fromOffset(side[2], 186),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.muted,
			StrokeThickness = 1.5,
		})
	end

	local unfair = unfairText()
	if not state.locked then
		local snapshot = ProfileController.Get()
		local locked = if snapshot then snapshot.locked or {} else {}
		sectionTitle(if next(locked) then "YOUR BONES (tap to offer · 🔒 gifts can't be traded)" else "YOUR BONES (tap to offer)", 10, 208, C.cream)
		local inv = Widgets.Card(content, {
			Size = UDim2.new(1, 0, 0, 96),
			Position = UDim2.fromOffset(0, 238),
			ClipsDescendants = true,
		}, Color3.fromRGB(36, 32, 52), 16)
		local row = Instance.new("ScrollingFrame")
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.fromScale(1, 1)
		row.CanvasSize = UDim2.new()
		row.AutomaticCanvasSize = Enum.AutomaticSize.X
		row.ScrollingDirection = Enum.ScrollingDirection.X
		row.ScrollBarThickness = 6
		row.Parent = inv
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 8)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.Parent = row
		local order = 0
		for _, def in Bones.SKELETONS do
			for _, piece in Bones.PIECES do
				local key = Bones.PieceKey(def.id, piece.id)
				local n = if snapshot then snapshot.bones[key] or 0 else 0
				-- només les comerciables: les de regal no surten
				local left = n - (locked[key] or 0) - ((state.myOffer or {})[key] or 0)
				if left > 0 then
					order += 1
					Widgets.PieceTile(row, key, left, 66, function()
						send("offer", { key = key, delta = 1 })
					end, order)
				end
			end
		end
	else
		Theme.Text(content, unfair or "🔒 Offers locked: check them and accept", {
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.fromOffset(10, 230),
			TextColor3 = if unfair then C.orange else C.yellow,
		})
	end
	-- l'avís també a baix, visible mentre muntes l'oferta
	window.footer.Text = unfair or "Any change to an offer resets both confirmations"
	window.footer.TextColor3 = if unfair then C.orange else C.muted

	local mine = if state.myConfirmed then "✅ You" else "⏳ You"
	local theirs = if state.theirConfirmed then `✅ {state.other}` else `⏳ {state.other}`
	Theme.Text(content, `{mine}   ·   {theirs}`, {
		Size = UDim2.fromOffset(360, 30),
		Position = UDim2.fromOffset(10, 340),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local main = if not state.locked
		then {
			text = if state.myConfirmed then "UNCONFIRM" else "CONFIRM OFFER",
			color = if state.myConfirmed then C.grey else C.blue,
			click = function()
				send("confirm", not state.myConfirmed)
			end,
		}
		elseif acceptAt > os.clock() then {
			-- uns segons per mirar l'oferta final abans de poder acceptar
			text = `CHECK THE OFFER... {math.ceil(acceptAt - os.clock())}`,
			color = C.grey,
			click = function() end,
		}
		else {
			text = if state.myAccepted then "WAITING..." else "ACCEPT TRADE!",
			color = C.green,
			click = function()
				send("accept")
			end,
		}
	local b = Widgets.Button({
		Parent = content,
		Size = UDim2.fromOffset(330, 64),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -176, 0, 330),
		Color = main.color,
		Text = main.text,
		OnClick = main.click,
	})
	if state.locked and not state.myAccepted and acceptAt <= os.clock() then
		Effects.Shine(b.button, 14, 1.4)
	end
	-- compte enrere: es torna a dibuixar cada segon fins que es pot acceptar
	if state.locked and acceptAt > os.clock() then
		tick += 1
		local mine = tick
		task.delay(math.min(1, acceptAt - os.clock()) + 0.02, function()
			if mine == tick and state.state == "active" then
				redraw()
			end
		end)
	end
	Widgets.Button({
		Parent = content,
		Size = UDim2.fromOffset(160, 64),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 330),
		Color = C.red,
		Text = "CANCEL",
		OnClick = function()
			send("cancel")
		end,
	})
end

function redraw()
	HudController.AutoBadge("Trade", if invite or state.state == "active" then "!" else nil)
	if not Windows.IsOpen("Trade") then
		return
	end
	Widgets.Clear(content)
	if state.state == "active" then
		window.title.Text = `TRADING WITH {string.upper(state.other or "")}`
		drawActive()
	else
		window.title.Text = "TRADE"
		window.footer.Text = "Swap your duplicate bones for the ones you are missing 🦴"
		window.footer.TextColor3 = C.muted
		drawIdle()
	end
end

-- ─────────────────────── AVIS D'INVITACIO ───────────────────────

local function showInvite(from: string)
	for _, child in inviteGui:GetChildren() do
		child:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 90)
	holder.Size = UDim2.fromOffset(520, 150)
	holder.Parent = inviteGui
	Theme.AutoScale(holder, "menu")
	local card = Widgets.Card(holder, { Size = UDim2.fromScale(1, 1) }, C.pink, 22)
	Theme.Shade(card)
	Theme.Text(card, `💌 {from} wants to trade with you!`, {
		Size = UDim2.new(1, -30, 0, 44),
		Position = UDim2.fromOffset(15, 12),
		StrokeThickness = 3,
	})
	local function close()
		holder:Destroy()
	end
	Widgets.Button({
		Parent = card,
		Size = UDim2.fromOffset(220, 60),
		Position = UDim2.fromOffset(24, 72),
		Color = C.green,
		Text = "ACCEPT",
		OnClick = function()
			send("accept_invite")
			invite = nil
			close()
		end,
	})
	Widgets.Button({
		Parent = card,
		Size = UDim2.fromOffset(220, 60),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 72),
		Color = C.red,
		Text = "DECLINE",
		OnClick = function()
			send("decline_invite")
			invite = nil
			close()
			redraw()
		end,
	})
	Effects.PopIn(card, 0.4)
	Theme.Play("notify", 0.6)
	-- Si no contesta, l'avis marxa sol
	task.delay(15, function()
		if holder.Parent then
			close()
		end
	end)
end

function TradeController.Start()
	window = Widgets.Window({
		Name = "Trade",
		Title = "TRADE",
		Icon = "🤝",
		Color = C.pink,
		Size = Vector2.new(820, 560),
	})
	content = window.body
	window.onOpen = redraw
	inviteGui = Theme.Screen("TradeInviteGui", 18)

	Remotes.TradeUpdate.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		if data.state == "invite" then
			invite = data.from
			showInvite(tostring(data.from))
		else
			local wasActive = state.state == "active"
			state = data
			invite = nil
			acceptAt = if type(data.acceptIn) == "number" then os.clock() + data.acceptIn else 0
			if data.state == "active" and not wasActive then
				Windows.Open("Trade")
				Theme.Play("reward", 0.5)
			elseif data.state == "idle" and wasActive and data.reason then
				local good = data.done == true
				Effects.Toast(if good then "🎉 Trade complete!" else "❌ " .. data.reason, if good then C.green else C.red, if good then "reward" else "error")
			elseif data.state == "idle" and data.reason then
				Effects.Toast(tostring(data.reason), C.grey)
			end
		end
		redraw()
	end)

	local function onProfile(snapshot: ProfileController.Snapshot)
		local wasWaiting = readyAt > os.clock()
		readyAt = os.clock() + (snapshot.tradeWait or 0)
		if state.state == "active" or wasWaiting then
			redraw()
		end
	end
	ProfileController.Changed:Connect(onProfile)
	local first = ProfileController.Get()
	if first then
		onProfile(first)
	end

	-- La llista del servidor canvia quan algú entra o surt
	local function playersChanged()
		if state.state ~= "active" and Windows.IsOpen("Trade") then
			redraw()
		end
	end
	Players.PlayerAdded:Connect(playersChanged)
	Players.PlayerRemoving:Connect(function()
		task.defer(playersChanged)
	end)
end

return TradeController
