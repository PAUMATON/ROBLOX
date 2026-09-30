--!strict

-- TutorialController — el tutorial curt: una targeta gran a dalt de la
-- pantalla (icona que bota, títol, què has de fer i un consell), tres punts
-- de progrés i un raig de llum que assenyala on anar (UI/Guide).
--
-- No guarda cap estat: el pas es DEDUEIX del perfil (has cavat? n'has
-- exposat?). Així un jugador que ja en sap no el veu, i un que torna a
-- mitges continua on era. Tampoc dona cap premi: és només guia, i no hi ha
-- res a explotar. Quan s'acaba, agafen el relleu les missions
-- (QuestController), al mateix lloc de la pantalla.

local Players = game:GetService("Players")

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Guide = require(UI:WaitForChild("Guide"))
local Widgets = require(UI:WaitForChild("Widgets"))
local ProfileController = require(script.Parent.ProfileController)
local HudController = require(script.Parent.HudController)

local C = Theme.C
local player = Players.LocalPlayer

local TutorialController = {}

local TOTAL_STEPS = 3
local NEAR_SITE = 70 -- studs: a partir d'aquí ja ets "a l'obra"
local W, H = 640, 132 -- mida de la targeta (disseny a 1920x1080; al mòbil no toca les rajoles)

type Step = {
	n: number,
	icon: string,
	title: string,
	text: string,
	hint: string,
	target: string?, -- "site" (entrada de l'obra) o "mound" (munt més proper)
	badge: string?, -- rajola del HUD que s'ha d'assenyalar
}

local holder: Frame? = nil
local card: Frame
local iconLabel: TextLabel
local titleLabel: TextLabel
local textLabel: TextLabel
local hintLabel: TextLabel
local dots: { Frame } = {}
local dotMarks: { TextLabel } = {}
local burst: Frame? = nil
local current: Step? = nil
local celebrated = false

-- ─────────────────────────── PASSOS ───────────────────────────

local function nearSite(): boolean
	-- l'entrada és a la vora de l'obra: el centre queda uns 55 studs cap a l'oest
	return Guide.Near(Guide.TravelPoint("construction"), NEAR_SITE)
end

local function stepFor(s: ProfileController.Snapshot): Step?
	for slot = 1, s.slots do
		if s.museum[tostring(slot)] then
			return nil -- ja té alguna cosa exposada: tutorial acabat
		end
	end
	if (s.digs or 0) > 0 or next(s.bones) ~= nil then
		return {
			n = 3,
			icon = "🏛️",
			title = "Show it in your museum!",
			text = "Open 🎒 Backpack, tap your fossil and press SHOW",
			hint = "💡 Fossils on display earn $ every second",
			badge = "Backpack",
		}
	end
	if nearSite() then
		return {
			n = 2,
			icon = "⛏️",
			title = "Dig up a fossil!",
			text = "Walk to a dirt mound and press E (or tap Dig)",
			hint = "💡 Click when the line is on GREEN for more $",
			target = "mound",
		}
	end
	return {
		n = 1,
		icon = "✈️",
		title = "Go to the Dig Site!",
		text = "Tap ✈️ Travel, then 🏗️ Dig Site",
		hint = "💡 Or follow the golden beam on the ground",
		target = "site",
		badge = "GoConstruction",
	}
end

-- ─────────────────────────── PANTALLA ───────────────────────────

-- Punts de progrés: fets en verd amb ✓, l'actual groc (i bategant), la resta gris
local function paintDots(stepN: number)
	for i, dot in dots do
		local done = i < stepN
		local now = i == stepN
		dot.BackgroundColor3 = if done then C.green elseif now then C.yellow else C.panelLight
		dotMarks[i].Text = if done then "✓" else tostring(i)
		dotMarks[i].TextColor3 = if now then C.ink else C.white
		if now then
			Effects.Pop(dot, 0.35)
		end
	end
end

local function setBurst(on: boolean)
	local h = holder :: Frame
	if on and not burst then
		local b = Effects.Sunburst(h, C.yellow, 520)
		b.ZIndex = 0
		burst = b
	elseif not on and burst then
		(burst :: Frame):Destroy()
		burst = nil
	end
end

local function hide()
	local h = holder :: Frame
	Effects.Tween(Effects.ScaleOf(card), 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.32, function()
		setBurst(false)
		h.Visible = false
		Effects.ScaleOf(card).Scale = 1
	end)
end

local function show(step: Step?)
	local h = holder :: Frame
	local previous = current
	current = step
	-- la rajola del pas anterior deixa d'assenyalar-se
	if previous and previous.badge and (not step or step.badge ~= previous.badge) then
		HudController.SetBadge(previous.badge, nil)
	end
	if not step then
		Guide.Clear("tutorial")
		if previous and not celebrated then
			-- acabat ara mateix: celebració i fora
			celebrated = true
			card.BackgroundColor3 = C.green
			iconLabel.Text = "🎉"
			titleLabel.Text = "TUTORIAL COMPLETE!"
			textLabel.Text = "Your museum earns $ every second now"
			hintLabel.Text = "💡 Collect ALL the pieces and BUILD a skeleton: it earns x5!"
			paintDots(TOTAL_STEPS + 1)
			setBurst(true)
			Effects.PopIn(card, 0.45)
			Effects.Confetti(card, 70)
			Theme.Play("reward", 0.7)
			task.delay(5, hide)
		elseif not previous then
			h.Visible = false
		end
		return
	end
	h.Visible = true
	card.BackgroundColor3 = C.purple
	if not previous or previous.n ~= step.n then
		iconLabel.Text = step.icon
		titleLabel.Text = step.title
		textLabel.Text = step.text
		hintLabel.Text = step.hint
		paintDots(step.n)
		Effects.PopIn(card, 0.35)
		if previous then
			-- pas superat
			Effects.Confetti(card, 25)
			Theme.Play("pop", 0.5, 1.2)
		end
	end
	if step.badge then
		HudController.SetBadge(step.badge, "👆", C.green)
	end
end

local function update()
	local snapshot = ProfileController.Get()
	if not snapshot then
		return
	end
	local step = stepFor(snapshot)
	show(step)
	if step and step.target == "site" then
		Guide.PointAt("tutorial", Guide.TravelPoint("construction"))
	elseif step and step.target == "mound" then
		Guide.PointAt("tutorial", Guide.NearestMound("construction"))
	else
		Guide.Clear("tutorial")
	end
end

-- El tutorial és a la pantalla (també mentre celebra que s'ha acabat).
-- Mentrestant, les missions (QuestController) esperen.
function TutorialController.IsActive(): boolean
	return holder ~= nil and (holder :: Frame).Visible
end

-- ─────────────────────────── CONSTRUCCIÓ ───────────────────────────

local function build()
	local gui = Theme.Screen("TutorialGui", 4)
	local h = Instance.new("Frame")
	h.Name = "Tutorial"
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0.5, 0)
	h.Position = UDim2.new(0.5, 0, 0, 22)
	h.Size = UDim2.fromOffset(W, H)
	h.Visible = false
	h.Parent = gui
	Theme.AutoScale(h)
	holder = h

	card = Widgets.Card(h, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, C.purple, 30)
	Theme.Shade(card, 1, 0.68)

	-- etiqueta "TUTORIAL" que treu el cap per damunt de la targeta
	local ribbon = Widgets.Card(card, {
		Size = UDim2.fromOffset(164, 36),
		Position = UDim2.fromOffset(124, -20),
		ZIndex = 4,
	}, C.yellow, 18)
	Theme.Shade(ribbon, 1, 0.8)
	Theme.Text(ribbon, "⭐ TUTORIAL", {
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		ZIndex = 5,
		StrokeThickness = 2.5,
	})

	-- la icona grossa, en una bombolla blanca que bota
	local bubble = Instance.new("Frame")
	bubble.Name = "IconBubble"
	bubble.Size = UDim2.fromOffset(100, 100)
	bubble.Position = UDim2.fromOffset(14, 16)
	bubble.BackgroundColor3 = C.cream
	bubble.ZIndex = 3
	bubble.Parent = card
	Theme.Corner(bubble, 50)
	Theme.Stroke(bubble, 3.5)
	Theme.Shade(bubble, 1, 0.85)
	iconLabel = Theme.Icon(bubble, "✈️", {
		Size = UDim2.new(1, -22, 1, -22),
		Position = UDim2.fromOffset(11, 11),
		ZIndex = 4,
	})
	Effects.Pulse(bubble, 0.07, 1.1)

	-- títol, què fer i el consell
	titleLabel = Theme.Text(card, "", {
		Size = UDim2.new(1, -262, 0, 40),
		Position = UDim2.fromOffset(130, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.yellow,
		StrokeThickness = 3.5,
		ZIndex = 3,
	})
	textLabel = Theme.Text(card, "", {
		Size = UDim2.new(1, -148, 0, 34),
		Position = UDim2.fromOffset(130, 56),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 3,
	})
	hintLabel = Theme.Text(card, "", {
		Size = UDim2.new(1, -148, 0, 24),
		Position = UDim2.fromOffset(130, 96),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.mint,
		StrokeThickness = 2,
		ZIndex = 3,
	})

	-- punts de progrés, a dalt a la dreta
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, -16, 0, 16)
	row.Size = UDim2.fromOffset(TOTAL_STEPS * 34 + (TOTAL_STEPS - 1) * 8, 34)
	row.ZIndex = 3
	row.Parent = card
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	for i = 1, TOTAL_STEPS do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(34, 34)
		dot.LayoutOrder = i
		dot.BackgroundColor3 = C.panelLight
		dot.ZIndex = 3
		dot.Parent = row
		Theme.Corner(dot, 17)
		Theme.Stroke(dot, 2.5)
		dotMarks[i] = Theme.Text(dot, tostring(i), {
			Size = UDim2.new(1, -10, 1, -10),
			Position = UDim2.fromOffset(5, 5),
			ZIndex = 4,
			StrokeThickness = 2,
		})
		dots[i] = dot
	end
end

function TutorialController.Start()
	build()

	ProfileController.Changed:Connect(update)
	-- la distància a l'obra i el munt més proper canvien sense que canviï el perfil
	task.spawn(function()
		while true do
			task.wait(0.5)
			if current and current.target then
				update()
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		Guide.Clear("tutorial")
		task.wait(1)
		update()
	end)
	update()
end

return TutorialController
