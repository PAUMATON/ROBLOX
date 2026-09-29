--!strict

-- TutorialController — el tutorial curt (Fase 3): un objectiu a dalt de la
-- pantalla i un raig de llum que assenyala on anar (UI/Guide).
--
-- No guarda cap estat: el pas es DEDUEIX del perfil (has cavat? tens un
-- esquelet complet? n'has muntat? n'has exposat?). Així un jugador que ja
-- en sap no el veu, i un que torna a mitges continua on era. Tampoc dona
-- cap premi: és només guia, i no hi ha res a explotar. Quan s'acaba, agafen
-- el relleu les missions (QuestController), al mateix lloc de la pantalla.

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

type Step = {
	n: number,
	text: string,
	target: string?, -- "site" (entrada de l'obra) o "mound" (munt més proper)
	badge: string?, -- rajola del HUD que s'ha d'assenyalar
}

local card: Frame
local label: TextLabel
local counter: TextLabel
local holder: Frame? = nil
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
		return { n = 3, text = "Open 🎒 Backpack, tap your fossil and press SHOW", badge = "Backpack" }
	end
	if nearSite() then
		return { n = 2, text = "Walk to a dirt mound and press E (or tap Dig)", target = "mound" }
	end
	return { n = 1, text = "Go to the Dig Site: tap ✈️ Travel, then 🏗️ Dig Site", target = "site", badge = "GoConstruction" }
end

-- ─────────────────────────── PANTALLA ───────────────────────────

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
			celebrated = true
			label.Text = "🎉 Your museum earns coins now! Tip: BUILD full skeletons for x2"
			counter.Text = "✓"
			card.BackgroundColor3 = C.green
			Effects.PopIn(card, 0.4)
			Theme.Play("reward", 0.6)
			task.delay(5, function()
				h.Visible = false
			end)
		elseif not previous then
			h.Visible = false
		end
		return
	end
	h.Visible = true
	card.BackgroundColor3 = C.purple
	counter.Text = `{step.n}/{TOTAL_STEPS}`
	if not previous or previous.n ~= step.n then
		label.Text = step.text
		Effects.PopIn(card, 0.35)
		if previous then
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

function TutorialController.Start()
	local gui = Theme.Screen("TutorialGui", 4)
	local h = Instance.new("Frame")
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(0.5, 0)
	h.Position = UDim2.new(0.5, 0, 0, 14)
	h.Size = UDim2.fromOffset(640, 66)
	h.Visible = false
	h.Parent = gui
	Theme.AutoScale(h)
	holder = h

	card = Widgets.Card(h, { Size = UDim2.fromScale(1, 1) }, C.purple, 33)
	Theme.Shade(card)
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromOffset(74, 50)
	bubble.Position = UDim2.fromOffset(8, 8)
	bubble.BackgroundColor3 = C.ink
	bubble.Parent = card
	Theme.Corner(bubble, 25)
	counter = Theme.Text(bubble, "1/5", {
		Size = UDim2.new(1, -14, 1, -14),
		Position = UDim2.fromOffset(7, 7),
		TextColor3 = C.yellow,
	})
	label = Theme.Text(card, "", {
		Size = UDim2.new(1, -110, 0, 40),
		Position = UDim2.fromOffset(96, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	})

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
