--!strict

-- DigController — la barra del minijoc i la carta de recompensa.
-- No calcula cap resultat: nomes intencio ("vull cavar aqui", "he clicat").
-- La linia es la mateixa ona que calcula el servidor (Config/Dig.MarkerAt),
-- a partir de l'instant d'inici que ell ens dona.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Dig = require(Config:WaitForChild("Dig"))
local Potions = require(Config:WaitForChild("Potions"))
local Tools = require(Config:WaitForChild("Tools"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local PieceView = require(UI:WaitForChild("PieceView"))
local Widgets = require(UI:WaitForChild("Widgets"))

local C = Theme.C
local player = Players.LocalPlayer

local DigController = {}

local BAR_W, BAR_H = 660, 74

local gui: ScreenGui
local holder: Frame
local panel: Frame
local marker: Frame
local bonusLabel: TextLabel
local toolLuck = 1 -- la de l'eina amb què has començat a cavar (la diu el servidor)
local feedback: TextLabel
local pips: { Frame } = {}
local rewardGui: ScreenGui

local active = false
local startTime = 0
local bandCenter = 0 -- on és la franja verda de l'intent actual (la diu el servidor)
local markerSpeed = Dig.SPEED
local localAttempt = 0 -- cops ja fets en aquesta excavació (per mostrar-los a l'instant)
local shown: { [number]: number } = {} -- intent -> punts que s'han ensenyat
local showHit: (number, number) -> ()
local renderConn: RBXScriptConnection? = nil
local lastSpot: BasePart? = nil
local hideToken = 0

-- ─────────────────────────── BARRA ───────────────────────────

local goodBand: Frame
local perfectBand: Frame

local function band(parent: Frame, halfWidth: number, color: Color3): Frame
	local f = Instance.new("Frame")
	-- La barra va de -1 a 1: una franja de mig ample h ocupa h de l'ample total.
	f.Size = UDim2.new(halfWidth, 0, 1, -16)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.Corner(f, 10)
	Theme.Stroke(f, 2.5)
	Theme.Shade(f, 1, 0.8)
	return f
end

-- Amplada i lloc de les franges (iguals per a tothom: l'eina només dona sort).
-- Després de cada cop la franja salta a un altre lloc.
local function setBands(animate: boolean?)
	local perfect, good = Dig.Bands()
	goodBand.Size = UDim2.new(good, 0, 1, -16)
	perfectBand.Size = UDim2.new(perfect, 0, 1, -16)
	local pos = UDim2.fromScale((bandCenter + 1) / 2, 0.5)
	for _, b in { goodBand, perfectBand } do
		if animate then
			Effects.Tween(b, 0.25, { Position = pos }, Enum.EasingStyle.Back)
		else
			b.Position = pos
		end
	end
end

local function buildBar()
	gui = Theme.Screen("DigGui", 5)
	gui.Enabled = false

	holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.56)
	holder.Size = UDim2.fromOffset(BAR_W, 170)
	holder.Parent = gui
	Theme.AutoScale(holder)

	Theme.Text(holder, "⛏️ DIGGING!", {
		Size = UDim2.fromOffset(300, 40),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.yellow,
		StrokeThickness = 3,
	})
	bonusLabel = Theme.Text(holder, "🍀 Luck x1", {
		Size = UDim2.fromOffset(240, 34),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		TextColor3 = C.green,
	})

	-- Tres intents: rodones que s'omplen de color
	local pipHolder = Instance.new("Frame")
	pipHolder.BackgroundTransparency = 1
	pipHolder.AnchorPoint = Vector2.new(1, 0)
	pipHolder.Position = UDim2.new(1, -4, 0, 2)
	pipHolder.Size = UDim2.fromOffset(Dig.ATTEMPTS * 42, 36)
	pipHolder.Parent = holder
	for i = 1, Dig.ATTEMPTS do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(34, 34)
		pip.Position = UDim2.fromOffset((i - 1) * 42, 0)
		pip.BackgroundColor3 = C.panel
		pip.Parent = pipHolder
		Theme.Corner(pip, 17)
		Theme.Stroke(pip, 3)
		pips[i] = pip
	end

	panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(BAR_W, BAR_H)
	panel.Position = UDim2.fromOffset(0, 48)
	panel.BackgroundColor3 = C.panel
	panel.Parent = holder
	Theme.Corner(panel, 18)
	Theme.Stroke(panel, 4.5)

	goodBand = band(panel, Dig.GOOD_HALF, C.yellow)
	perfectBand = band(panel, Dig.PERFECT_HALF, C.green)

	marker = Instance.new("Frame")
	marker.Size = UDim2.fromOffset(12, BAR_H + 18)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.BackgroundColor3 = C.white
	marker.ZIndex = 5
	marker.Parent = panel
	Theme.Corner(marker, 6)
	Theme.Stroke(marker, 3)

	Theme.Text(holder, "TAP WHEN THE LINE IS IN THE GREEN!", {
		Size = UDim2.fromOffset(BAR_W, 30),
		Position = UDim2.fromOffset(0, 48 + BAR_H + 12),
		TextColor3 = C.cream,
	})

	feedback = Theme.Text(holder, "", {
		Size = UDim2.fromOffset(360, 64),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		ZIndex = 8,
		StrokeThickness = 4,
		Visible = false,
	})
end

local function stopBar()
	active = false
	ProximityPromptService.Enabled = true
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

local function hideBarSoon(seconds: number)
	hideToken += 1
	local token = hideToken
	task.delay(seconds, function()
		if token == hideToken and not active then
			gui.Enabled = false
		end
	end)
end

local function shake(obj: GuiObject)
	local base = obj.Position
	task.spawn(function()
		for i = 1, 6 do
			obj.Position = base + UDim2.fromOffset(if i % 2 == 0 then 8 else -8, 0)
			task.wait(0.03)
		end
		obj.Position = base
	end)
end

-- ─────────────────────── CARTA DE RECOMPENSA ───────────────────────

local RARITY_TITLE = {
	Common = "COMMON",
	Uncommon = "UNCOMMON",
	Rare = "RARE!",
	Epic = "EPIC!!",
	Legendary = "LEGENDARY!!",
	Mythic = "MYTHIC!!!",
	Secret = "✨ SECRET ✨",
}
-- de Legendary cap amunt és una celebració grossa
local BIG = { Legendary = true, Mythic = true, Secret = true }

local function showReward(key: string, text: string, rarity: string, stored: boolean, isNew: boolean)
	local color = Bones.RARITY_COLORS[rarity] or C.grey
	rewardGui.Enabled = true
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.45)
	root.Size = UDim2.fromOffset(380, 460)
	root.Parent = rewardGui
	Theme.AutoScale(root)

	local burst = Effects.Sunburst(root, if rarity == "Secret" then C.white else color, if BIG[rarity] then 1000 elseif rarity == "Common" then 560 else 820)

	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = false
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(340, 420)
	card.BackgroundColor3 = color
	card.ZIndex = 5
	card.Parent = root
	Theme.Corner(card, 26)
	Theme.Stroke(card, 5)
	Theme.Shade(card, 1, 0.6)

	local info = Bones.PieceInfo[key]
	local def = info and Bones.ById[info.skeleton]
	Theme.Text(card, if BIG[rarity] then "WOW!!" else "NEW FOSSIL!", {
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 16),
		ZIndex = 6,
		StrokeThickness = 4,
	})
	-- la peça de veritat, en 3D i girant (la mateixa que anirà al museu)
	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0)
	stage.Position = UDim2.new(0.5, 0, 0, 70)
	stage.Size = UDim2.fromOffset(250, 170)
	stage.BackgroundColor3 = C.ink
	stage.BackgroundTransparency = 0.55
	stage.ZIndex = 6
	stage.Parent = card
	Theme.Corner(stage, 20)
	PieceView.New(stage, key, { spin = true, zIndex = 7 })
	if def then
		Theme.Icon(stage, def.icon, {
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.fromOffset(6, 6),
			ZIndex = 8,
		})
	end
	Theme.Text(card, text, {
		Size = UDim2.new(1, -36, 0, 64),
		Position = UDim2.fromOffset(18, 244),
		ZIndex = 6,
		StrokeThickness = 3,
	})
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 320)
	pill.Size = UDim2.fromOffset(220, 56)
	pill.BackgroundColor3 = C.ink
	pill.ZIndex = 6
	pill.Parent = card
	Theme.Corner(pill, 28)
	local rarityLabel = Theme.Text(pill, RARITY_TITLE[rarity] or rarity, {
		Size = UDim2.new(1, -24, 1, -14),
		Position = UDim2.fromOffset(12, 7),
		TextColor3 = if rarity == "Secret" then C.white else color,
		ZIndex = 7,
	})
	-- el Secret és d'arc de Sant Martí i la carta fa pampallugues
	if rarity == "Secret" then
		local g = Instance.new("UIGradient")
		g.Color = Theme.RAINBOW
		g.Parent = rarityLabel
		Effects.Spin(g, 120)
		-- un sol UIGradient per objecte: fora l'ombrejat, i fons blanc perquè es vegin els colors
		local shade = card:FindFirstChildOfClass("UIGradient")
		if shade then
			shade:Destroy()
		end
		card.BackgroundColor3 = C.white
		local cg = Instance.new("UIGradient")
		cg.Color = Theme.RAINBOW
		cg.Parent = card
		Effects.Spin(cg, 60)
	end
	-- primer cop que la trobes: entra a l'índex
	if isNew then
		local tag = Instance.new("Frame")
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.new(1, -30, 0, 26)
		tag.Size = UDim2.fromOffset(150, 44)
		tag.Rotation = 12
		tag.BackgroundColor3 = C.pink
		tag.ZIndex = 8
		tag.Parent = card
		Theme.Corner(tag, 22)
		Theme.Stroke(tag, 3)
		Theme.Text(tag, "NEW IN INDEX!", { Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), ZIndex = 9 })
		Effects.Pulse(tag, 0.12, 0.6)
	end
	if not stored then
		Theme.Text(card, "⚠️ NOT SAVED (Studio)", {
			Size = UDim2.new(1, -40, 0, 24),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			TextColor3 = C.cream,
			ZIndex = 6,
		})
	end

	Effects.PopIn(card, 0.45)
	-- les monedes de l'excavació (totes les troballes en donen)
	Theme.Note("coinBounce", 0.45, 1.1)
	-- com més rara, més festa: so, confeti, flaix del color i sacsejada
	if BIG[rarity] then
		Effects.Confetti(root, if rarity == "Secret" then 160 elseif rarity == "Mythic" then 120 else 90)
		Theme.Fanfare(3)
		Effects.Flash(if rarity == "Secret" then C.white else color, if rarity == "Secret" then 0.8 else 0.55)
		Effects.ShakeCamera(if rarity == "Secret" then 0.9 elseif rarity == "Mythic" then 0.65 else 0.45, 0.6)
		task.delay(0.5, function()
			Effects.Confetti(root, 60)
		end)
	elseif rarity == "Epic" then
		Effects.Confetti(root, 60)
		Theme.Fanfare(2)
		Effects.Flash(color, 0.3)
	elseif rarity == "Rare" then
		Effects.Confetti(root, 30)
		Theme.Fanfare(1)
		Theme.Note("sparkle", 0.5, 1.15)
	else
		Theme.Arpeggio("pop", { 1, 1.26 }, 0.07, 0.5)
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Effects.Tween(Effects.ScaleOf(card), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Effects.Tween(burst, 0.2, { Size = UDim2.fromOffset(0, 0) })
		task.delay(0.22, function()
			root:Destroy()
		end)
	end
	card.Activated:Connect(close)
	-- ✕ a la cantonada: la targeta es tanca tocant-la, però així es veu
	Widgets.CloseButton({ Parent = card, Size = 50, ZIndex = 9, OnClick = close })
	local stay = if BIG[rarity] then 5 elseif rarity == "Common" or rarity == "Uncommon" then 1.8 else 3
	task.delay(if Theme.QuickRewards then math.min(stay, 1.2) else stay, close)
end

-- "+1 💀" que surt del munt al mon 3D
local function worldPop(spot: BasePart, text: string, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 70)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = spot
	bb.Parent = player:WaitForChild("PlayerGui")
	local label = Theme.Text(bb, text, { TextColor3 = color, StrokeThickness = 3 })
	Effects.PopIn(label, 0.3)
	Effects.Tween(bb, 1.2, { StudsOffset = Vector3.new(0, 7, 0) })
	task.delay(0.8, function()
		Effects.Tween(label, 0.4, { TextTransparency = 1 })
	end)
	task.delay(1.3, function()
		bb:Destroy()
	end)
end

-- ─────────────────────────── MISSATGES ───────────────────────────

-- ─────────────────────── EFECTES DEL COP ───────────────────────

local DIG_SOUND = "rbxassetid://9114083746" -- Dirt Dig (ProSoundEffects, lliure a Roblox)
local DIRT = {
	construction = Color3.fromRGB(128, 98, 62),
	beach = Color3.fromRGB(226, 206, 160),
}

-- Animacio de cop de l'eina (la de Roblox per defecte), terra que salta i so.
local function swing()
	local character = player.Character
	local tool: Instance? = nil
	for _, child in (if character then character:GetChildren() else {}) do
		if child:IsA("Tool") and child:GetAttribute(Dig.TOOL_ATTRIBUTE) then
			tool = child
		end
	end
	if tool then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.3, function()
			anim:Destroy()
		end)
	end
	local spot = lastSpot
	if not spot or not spot.Parent then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = spot.Position + Vector3.new(0, spot.Size.Y * 0.35, 0)
	attachment.Parent = workspace.Terrain
	local zone = spot:GetAttribute("Zone")
	local dirt = Instance.new("ParticleEmitter")
	dirt.Color = ColorSequence.new(if zone == "construction" then DIRT.construction else DIRT.beach)
	dirt.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
	dirt.Lifetime = NumberRange.new(0.5, 0.9)
	dirt.Speed = NumberRange.new(10, 18)
	dirt.SpreadAngle = Vector2.new(40, 40)
	dirt.EmissionDirection = Enum.NormalId.Top
	dirt.Acceleration = Vector3.new(0, -45, 0)
	dirt.Rate = 0
	dirt.Parent = attachment
	dirt:Emit(16)
	local sound = Instance.new("Sound")
	sound.SoundId = DIG_SOUND
	sound.Volume = 0.6
	sound.PlaybackSpeed = 0.9 + math.random() * 0.2
	sound.Parent = attachment
	sound:Play()
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

local HIT = {
	[Dig.PERFECT_BONUS] = { "PERFECT!", C.green, 1.3 },
	[Dig.GOOD_BONUS] = { "GOOD!", C.yellow, 1.1 },
}

-- Ensenya el resultat d'un cop (a l'instant en clicar, i el servidor el confirma)
showHit = function(attempt: number, gained: number)
	shown[attempt] = gained
	local hit = HIT[gained]
	local pip = pips[attempt]
	feedback.Visible = true
	if hit then
		feedback.Text = hit[1]
		feedback.TextColor3 = hit[2]
		-- cop de pala + un "pop" que puja de to a cada intent (enganxa)
		Theme.Dig(if gained == Dig.PERFECT_BONUS then 2 else 1)
		Theme.Note("pop", 0.5, hit[3] + (attempt - 1) * 0.14)
		if gained == Dig.PERFECT_BONUS then
			Theme.Note("hover", 0.35, 1.6 + attempt * 0.12)
		end
		if pip then
			pip.BackgroundColor3 = hit[2]
			Effects.Pop(pip, 0.4)
		end
		-- tots els cops PERFECT: combo!
		if attempt == Dig.ATTEMPTS then
			local all = true
			for i = 1, Dig.ATTEMPTS do
				if shown[i] ~= Dig.PERFECT_BONUS then
					all = false
				end
			end
			if all then
				feedback.Text = "PERFECT x3!"
				feedback.TextColor3 = C.yellow
				Theme.Fanfare(1)
				Effects.Pop(feedback, 0.6)
			end
		end
	else
		feedback.Text = "MISS!"
		feedback.TextColor3 = C.red
		Theme.Dig(0)
		Theme.Play("error", 0.35)
		shake(panel)
		if pip then
			pip.BackgroundColor3 = C.red
		end
	end
	Effects.Pop(feedback, 0.35)
end

local function onUpdate(data: any)
	if type(data) ~= "table" then
		return
	end
	local phase = data.phase
	if phase == "start" then
		stopBar()
		startTime = data.startTime
		if typeof(data.spot) == "Instance" and data.spot:IsA("BasePart") then
			lastSpot = data.spot
		end
		bandCenter = tonumber(data.center) or 0
		markerSpeed = tonumber(data.speed) or Dig.SPEED
		localAttempt = 0
		shown = {}
		setBands()
		toolLuck = tonumber(data.toolLuck) or 1
		active = true
		-- Mentre es cava, els botons "Dig" dels munts molesten (i la E es el clic)
		ProximityPromptService.Enabled = false
		hideToken += 1
		gui.Enabled = true
		feedback.Visible = false
		bonusLabel.Text = `🍀 Luck {Tools.LuckText(Dig.LuckMultiplier(0, toolLuck))}`
		for _, pip in pips do
			pip.BackgroundColor3 = C.panel
		end
		Effects.PopIn(panel, 0.3)
		Theme.Play("open", 0.35, 1.3)
		renderConn = RunService.RenderStepped:Connect(function()
			local pos = Dig.MarkerAt(workspace:GetServerTimeNow() - startTime, markerSpeed)
			marker.Position = UDim2.fromScale((pos + 1) / 2, 0.5)
		end)
	elseif phase == "hit" then
		local attempt = tonumber(data.attempt) or 0
		-- el servidor mana: si no coincideix amb el que ja s'ha ensenyat, es corregeix
		if shown[attempt] ~= data.gained then
			showHit(attempt, data.gained)
		end
		bonusLabel.Text = `🍀 Luck {Tools.LuckText(Dig.LuckMultiplier(tonumber(data.total) or 0, toolLuck))}`
		Effects.Pop(bonusLabel, 0.2)
		if data.nextStart then
			startTime = data.nextStart
			bandCenter = tonumber(data.nextCenter) or 0
			markerSpeed = tonumber(data.nextSpeed) or markerSpeed
			setBands(true)
		end
	elseif phase == "result" then
		stopBar()
		hideBarSoon(0.5)
		if data.key then
			local rarity = data.rarity or "Common"
			showReward(data.key, tostring(data.text), rarity, data.stored == true, data.new == true)
			if lastSpot and lastSpot.Parent then
				local info = Bones.PieceInfo[data.key]
				worldPop(lastSpot, "+1 " .. (if info then Bones.PIECE_ICONS[info.piece] else "🦴"), Bones.RARITY_COLORS[rarity] or C.white)
			end
		else
			Effects.Toast("Nothing this time... dig again!", C.grey)
		end
		-- poció de regal (de tant en tant, o sempre al munt daurat)
		local potion = if type(data.potion) == "string" then Potions.ById[data.potion] else nil
		if potion then
			task.delay(0.8, function()
				Effects.Toast(`🧪 BONUS! You found a {potion.name} {potion.icon}`, potion.color, "")
				Theme.Arpeggio("pop", { 1.3, 1.6, 2 }, 0.06, 0.45)
				Theme.Note("sparkle", 0.55, 1.2)
				if lastSpot and lastSpot.Parent then
					worldPop(lastSpot, `+1 🧪`, potion.color)
				end
			end)
		end
	elseif phase == "denied" then
		Effects.Toast("🔒 " .. tostring(data.reason or "You can't dig here"), C.red, "error")
	elseif phase == "cancel" then
		stopBar()
		gui.Enabled = false
		Effects.Toast("Dig cancelled", C.grey)
	end
end

-- El munt que hi ha sota el ratolí: el mateix munt, o qualsevol peça del
-- seu forat (el model del forat té el munt com a PrimaryPart).
local function spotFrom(target: BasePart?, hit: Vector3?): BasePart?
	if not target then
		return nil
	end
	-- el clot és terreny: val el munt que hi hagi a prop d'on has clicat
	if target:IsA("Terrain") and hit then
		local best, bestDist = nil, 4.5
		for _, spot in CollectionService:GetTagged("DigSpot") do
			if spot:IsA("BasePart") then
				local d = (Vector3.new(spot.Position.X, 0, spot.Position.Z) - Vector3.new(hit.X, 0, hit.Z)).Magnitude
				if d < bestDist then
					best, bestDist = spot, d
				end
			end
		end
		return best
	end
	if CollectionService:HasTag(target, "DigSpot") then
		return target
	end
	local model = target:FindFirstAncestorOfClass("Model")
	local primary = model and model.PrimaryPart
	if primary and CollectionService:HasTag(primary, "DigSpot") then
		return primary
	end
	return nil
end

-- Durant el minijoc qualsevol clic, toc o tecla compta (ho gestiona
-- onInput). L'eina nomes serveix per COMENÇAR clicant un munt.
local function onActivate()
	if active then
		return
	end
	local mouse = player:GetMouse()
	local spot = spotFrom(mouse.Target, mouse.Hit.Position)
	if spot then
		lastSpot = spot
		Remotes.DigRequest:FireServer("start", spot)
	else
		Effects.Toast("⛏️ Click a dirt or sand mound to dig", C.orange, "pop")
	end
end

local function hook(child: Instance)
	if child:IsA("Tool") and child:GetAttribute(Dig.TOOL_ATTRIBUTE) and not child:GetAttribute("DigHooked") then
		child:SetAttribute("DigHooked", true)
		child.Activated:Connect(onActivate)
	end
end

local function watch(container: Instance)
	container.ChildAdded:Connect(hook)
	for _, child in container:GetChildren() do
		hook(child)
	end
end

-- (l'espai no: és saltar)
local CLICK_KEYS = {
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonA] = true,
}

local function onInput(input: InputObject, processed: boolean)
	if not active or processed then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or CLICK_KEYS[input.KeyCode] then
		local now = workspace:GetServerTimeNow()
		if now < startTime or localAttempt >= Dig.ATTEMPTS then
			return -- la línia encara no ha sortit
		end
		localAttempt += 1
		-- resultat a l'instant (sense esperar el servidor, que el confirmarà)
		local pos = Dig.MarkerAt(now - startTime, markerSpeed)
		showHit(localAttempt, Dig.ScoreFor(pos, bandCenter))
		swing()
		Remotes.DigRequest:FireServer("click", now)
	end
end

function DigController.Start()
	buildBar()
	rewardGui = Theme.Screen("RewardGui", 15)
	Remotes.DigUpdate.OnClientEvent:Connect(onUpdate)
	UserInputService.InputBegan:Connect(onInput)

	-- La motxilla i el personatge es refan a cada reaparicio
	local function onCharacter(character: Model)
		watch(character)
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			watch(backpack)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return DigController
