--!strict

-- RewardsController — les recompenses gratis, a dalt a la dreta sota el ⚙️:
--   🎁 DAILY  · calendari de 7 dies (s'obre sol en entrar si pots cobrar)
--   ⏱️ GIFTS  · 6 regals que s'obren jugant (5, 10, 15, 25, 40 i 60 min)
--   💌 INVITE · convida amics: si entren amb la teva invitació, premi per a tots dos
-- I un recordatori de "like" (SENSE premi: les normes de Roblox ho prohibeixen)
-- després de trobar un fòssil molt rar, un cop per sessió.
-- Cobrar ho decideix el servidor (RewardsService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rewards = require(Config:WaitForChild("Rewards"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C
local player = Players.LocalPlayer

local RewardsController = {}

local state: { [string]: any }? = nil
local stateAt = os.clock() -- quan ha arribat l'estat (per comptar els minuts jugats)
local badges: { [string]: Widgets.Badge } = {}
local giftTimer: TextLabel
local boostPill: TextLabel
local dailyWin: Widgets.Window
local giftsWin: Widgets.Window
local inviteWin: Widgets.Window
local openedDailyOnce = false
local likeShown = false

local function played(): number
	if not state then
		return 0
	end
	return (state.played or 0) + (os.clock() - stateAt)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- ─────────────────────────── TARGETA ───────────────────────────

local function rewardCard(parent: Instance, order: number, title: string, reward: Rewards.Reward, status: string, color: Color3, onClaim: (() -> ())?)
	local done = status == "done"
	local ready = status == "ready"
	local c = Widgets.Card(parent, { LayoutOrder = order, ClipsDescendants = true }, if done then C.panelLight elseif ready then color else C.panel, 18)
	Theme.Shade(c, 1, 0.6)
	if ready then
		Effects.Sunburst(c, C.white, 300).Position = UDim2.fromScale(0.5, 0.42)
	end
	Theme.Text(c, title, { Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 6), ZIndex = 3 })
	Theme.Icon(c, reward.icon, {
		Size = UDim2.fromOffset(62, 62),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		ZIndex = 3,
		TextTransparency = if done then 0.5 else 0,
	})
	Theme.Text(c, reward.label, {
		Size = UDim2.new(1, -10, 0, 24),
		Position = UDim2.fromOffset(5, 100),
		TextColor3 = C.cream,
		ZIndex = 3,
		StrokeThickness = 2,
	})
	local b = Widgets.Button({
		Parent = c,
		Size = UDim2.new(1, -16, 0, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Color = if ready then C.green elseif done then C.grey else C.panelLight,
		Text = if ready then "CLAIM!" elseif done then "✅" else status,
		Radius = 12,
		ZIndex = 3,
		OnClick = if ready then onClaim else nil,
	})
	if ready then
		Effects.Shine(b.button, 12, 1.6)
		Effects.Pulse(c, 0.04, 1.2)
	end
end

local function cardGrid(parent: Instance, cell: Vector2): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = parent
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	g.CellPadding = UDim2.fromOffset(12, 12)
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return f
end

-- ─────────────────────────── FINESTRES ───────────────────────────

local function drawDaily()
	if not Windows.IsOpen("Daily") or not state then
		return
	end
	Widgets.Clear(dailyWin.body)
	local g = cardGrid(dailyWin.body, Vector2.new(170, 190))
	local day = state.dailyDay or 1
	for i, reward in Rewards.DAILY do
		local status
		if i < day or (i == day and not state.dailyCan) then
			status = "done"
		elseif i == day then
			status = "ready"
		else
			status = `Day {i}`
		end
		rewardCard(g, i, `DAY {i}`, reward, status, if i == #Rewards.DAILY then C.purple else C.orange, function()
			Remotes.RewardRequest:FireServer("daily")
		end)
	end
	dailyWin.footer.Text = if state.dailyCan
		then "Come back every day! Miss a day and the streak restarts 🔥"
		else `Next reward in {clock((state.dailyNextIn or 0) - (os.clock() - stateAt))} 🔥 Streak: day {day}`
end

local function drawGifts()
	if not Windows.IsOpen("Gifts") or not state then
		return
	end
	Widgets.Clear(giftsWin.body)
	local g = cardGrid(giftsWin.body, Vector2.new(170, 190))
	local t = played()
	for i, gift in Rewards.GIFTS do
		local status
		if state.gifts[tostring(i)] then
			status = "done"
		elseif t >= gift.at * 60 then
			status = "ready"
		else
			status = clock(gift.at * 60 - t)
		end
		rewardCard(g, i, `{gift.at} MIN`, gift.reward, status, C.cyan, function()
			Remotes.RewardRequest:FireServer("gift", i)
		end)
	end
	giftsWin.footer.Text = "Gifts restart every time you join. Keep playing! ⏱️"
end

local function drawInvite()
	if not Windows.IsOpen("Invite") then
		return
	end
	Widgets.Clear(inviteWin.body)
	local body = inviteWin.body
	Theme.Text(body, "Invite a friend to dig with you!", {
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 6),
		StrokeThickness = 3,
	})
	local lines = {
		`💌 When a friend joins from your invite:`,
		`   YOU get {Rewards.INVITER.label} + {Rewards.INVITER_COINS.minutes} min of coins`,
		`   THEY get {Rewards.INVITEE.minutes} min of coins to start`,
		`🤝 Friends make trading WAY easier!`,
	}
	for i, line in lines do
		Theme.Text(body, line, {
			Size = UDim2.new(1, -40, 0, 30),
			Position = UDim2.fromOffset(20, 50 + (i - 1) * 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if i == 1 or i == 4 then C.cream else C.green,
			StrokeThickness = 2,
		})
	end
	local count = if state then state.invites or 0 else 0
	Theme.Text(body, `Friends invited: {count} / {Rewards.MAX_INVITES}`, {
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(20, 196),
		TextColor3 = C.yellow,
	})
	local b = Widgets.Button({
		Parent = body,
		Size = UDim2.fromOffset(320, 72),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Color = C.pink,
		Icon = "💌",
		Text = "INVITE FRIENDS",
		OnClick = function()
			local options = Instance.new("ExperienceInviteOptions")
			options.LaunchData = tostring(player.UserId) -- així el servidor sap qui ha convidat
			options.PromptMessage = "Come dig fossils with me!"
			local ok = pcall(function()
				SocialService:PromptGameInvite(player, options)
			end)
			if not ok then
				Effects.Toast("Invites don't work here (try in the real game)", C.grey)
			end
		end,
	})
	Effects.Shine(b.button, 18, 2)
end

local function redrawAll()
	drawDaily()
	drawGifts()
	drawInvite()
end

-- ─────────────────────────── INSÍGNIES I TEMPORITZADOR ───────────────────────────

local function refreshBadges()
	if not state then
		return
	end
	badges.Daily.set(if state.dailyCan then "!" else nil, C.red)
	local ready, nextIn = 0, math.huge
	local t = played()
	for i, gift in Rewards.GIFTS do
		if not state.gifts[tostring(i)] then
			if t >= gift.at * 60 then
				ready += 1
			else
				nextIn = math.min(nextIn, gift.at * 60 - t)
			end
		end
	end
	badges.Gifts.set(if ready > 0 then tostring(ready) else nil, C.green)
	giftTimer.Text = if ready > 0 then "READY!" elseif nextIn < math.huge then clock(nextIn) else "DONE"
end

-- ─────────────────────────── LIKE (sense premi) ───────────────────────────

local function showLikeReminder()
	if likeShown then
		return
	end
	likeShown = true
	local gui = Theme.Screen("LikeGui", 14)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 90)
	holder.Size = UDim2.fromOffset(520, 110)
	holder.Parent = gui
	Theme.AutoScale(holder, "menu")
	local card = Widgets.Card(holder, { Size = UDim2.fromScale(1, 1) }, C.blue, 22)
	Theme.Shade(card)
	Theme.Text(card, "Having fun? 👍 Like the game on its page!", {
		Size = UDim2.new(1, -90, 0, 40),
		Position = UDim2.fromOffset(20, 14),
		StrokeThickness = 3,
	})
	Theme.Text(card, "It really helps more people find it. Thank you! 💛", {
		Size = UDim2.new(1, -90, 0, 28),
		Position = UDim2.fromOffset(20, 60),
		TextColor3 = C.cream,
	})
	Widgets.Button({
		Parent = card,
		Size = UDim2.fromOffset(52, 52),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Color = C.red,
		Text = "✕",
		OnClick = function()
			gui:Destroy()
		end,
	})
	Effects.PopIn(card, 0.4)
	task.delay(12, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- ─────────────────────────── INICI ───────────────────────────

function RewardsController.Start()
	dailyWin = Widgets.Window({ Name = "Daily", Title = "DAILY REWARDS", Icon = "🎁", Color = C.orange, Size = Vector2.new(780, 520) })
	giftsWin = Widgets.Window({ Name = "Gifts", Title = "PLAYTIME GIFTS", Icon = "⏱️", Color = C.cyan, Size = Vector2.new(620, 520) })
	inviteWin = Widgets.Window({ Name = "Invite", Title = "INVITE FRIENDS", Icon = "💌", Color = C.pink, Size = Vector2.new(600, 400) })
	dailyWin.onOpen = drawDaily
	giftsWin.onOpen = drawGifts
	inviteWin.onOpen = drawInvite

	-- els tres botons, en fila a dalt, a l'esquerra del ⚙️
	local gui = Theme.Screen("RewardsButtonsGui", 4)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	-- just a l'esquerra del ⚙️ (64 d'ample, a 18 del marge), a qualsevol escala
	Theme.OnScale(function(s: number)
		holder.Position = UDim2.new(1, -(18 + (64 + 12) * s), 0, 12)
	end)
	holder.Size = UDim2.fromOffset(3 * 72 + 2 * 10, 110)
	holder.Parent = gui
	Theme.AutoScale(holder)
	local buttons = {
		{ id = "Daily", icon = "🎁", text = "Daily", color = C.orange },
		{ id = "Gifts", icon = "⏱️", text = "Gifts", color = C.cyan },
		{ id = "Invite", icon = "💌", text = "Invite", color = C.pink },
	}
	for i, def in buttons do
		local b = Widgets.Button({
			Parent = holder,
			Size = UDim2.fromOffset(72, 72),
			Position = UDim2.fromOffset((i - 1) * 82, 0),
			Color = def.color,
			Icon = def.icon,
			Text = def.text,
			Layout = "tile",
			Radius = 16,
			OnClick = function()
				Windows.Toggle(def.id)
			end,
		})
		badges[def.id] = Widgets.Badge(b.button, 30)
		if def.id == "Gifts" then
			giftTimer = Theme.Text(b.button, "", {
				Size = UDim2.new(1, 0, 0, 22),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				TextColor3 = C.yellow,
				StrokeThickness = 2,
			})
		end
	end
	-- boosts actius (x2 diners / x2 sort) amb el temps que queda
	boostPill = Theme.Text(holder, "", {
		Size = UDim2.fromOffset(300, 24),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 84, 0, 102),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.green,
		StrokeThickness = 2,
	})

	Remotes.RewardUpdate.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		state = data
		stateAt = os.clock()
		refreshBadges()
		redrawAll()
		-- en entrar, si hi ha la diària per cobrar, s'obre sola (un cop)
		if data.dailyCan and not openedDailyOnce then
			openedDailyOnce = true
			task.spawn(function()
				-- després de la targeta de "welcome back", si n'hi ha
				task.wait(3)
				local waited = 0
				while player.PlayerGui:FindFirstChild("WelcomeGui") and waited < 60 do
					waited += task.wait(0.5)
				end
				if state and state.dailyCan and not Windows.IsOpen("Daily") then
					Windows.Open("Daily")
				end
			end)
		end
	end)
	Remotes.RewardRequest:FireServer("state")

	-- el like es demana després d'una gran troballa (Legendary o més)
	Remotes.DigUpdate.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and data.phase == "result" then
			local r = data.rarity
			if r == "Legendary" or r == "Mythic" or r == "Secret" then
				task.delay(6, showLikeReminder)
			end
		end
	end)

	-- rellotges (un cop per segon)
	local acc = 0
	local boostAt = os.clock()
	local snapshotBoosts = { money = 0, luck = 0 }
	ProfileController.Changed:Connect(function(s: any)
		snapshotBoosts.money = s.boostLeft or 0
		snapshotBoosts.luck = s.luckBoostLeft or 0
		boostAt = os.clock()
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		refreshBadges()
		if Windows.IsOpen("Gifts") then
			drawGifts()
		end
		local since = os.clock() - boostAt
		local parts = {}
		if snapshotBoosts.money - since > 0 then
			table.insert(parts, `💰 x2 {clock(snapshotBoosts.money - since)}`)
		end
		if snapshotBoosts.luck - since > 0 then
			table.insert(parts, `🍀 x2 {clock(snapshotBoosts.luck - since)}`)
		end
		boostPill.Text = table.concat(parts, "  ")
	end)
end

return RewardsController
