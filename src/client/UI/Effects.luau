--!strict

-- Effects — el que fa que la UI "piqui": rebots, numeros que salten,
-- avisos, lluentors, raigs i confeti. Nomes visual: cap efecte decideix res.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)

local Effects = {}

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
Effects.Tween = tween

-- L'UIScale d'animacio d'un objecte (n'hi ha d'haver un de sol per objecte).
function Effects.ScaleOf(obj: GuiObject): UIScale
	local s = obj:FindFirstChild("FxScale")
	if s and s:IsA("UIScale") then
		return s
	end
	local created = Instance.new("UIScale")
	created.Name = "FxScale"
	created.Parent = obj
	return created
end

-- Rebot: creix de cop i torna amb molla.
function Effects.Pop(obj: GuiObject, amount: number?)
	local s = Effects.ScaleOf(obj)
	s.Scale = 1 + (amount or 0.18)
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Entrada: des de petit fins a la mida real, passant-se una mica.
function Effects.PopIn(obj: GuiObject, time: number?)
	local s = Effects.ScaleOf(obj)
	s.Scale = 0.4
	tween(s, time or 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Botons: creix en passar-hi per sobre, s'enfonsa en clicar.
function Effects.Hoverable(button: GuiButton)
	local s = Effects.ScaleOf(button)
	button.MouseEnter:Connect(function()
		tween(s, 0.12, { Scale = 1.07 })
		Theme.Play("hover", 0.25)
	end)
	button.MouseLeave:Connect(function()
		tween(s, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(s, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(s, 0.25, { Scale = 1.07 }, Enum.EasingStyle.Back)
	end)
end

-- Una lluentor que creua el boto de tant en tant (per als botons d'accio).
function Effects.Shine(button: GuiObject, radius: number?, every: number?)
	local overlay = Instance.new("Frame")
	overlay.Name = "Shine"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.C.white
	overlay.BorderSizePixel = 0
	overlay.ZIndex = button.ZIndex + 3
	overlay.Parent = button
	Theme.Corner(overlay, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = overlay
	task.spawn(function()
		while overlay.Parent do
			g.Offset = Vector2.new(-1, 0)
			tween(g, 0.7, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			task.wait(every or 2.2)
		end
	end)
end

-- Fa girar un degradat sense parar (botó arc de Sant Marti).
function Effects.Spin(gradient: UIGradient, speed: number?)
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		if not gradient.Parent then
			conn:Disconnect()
			return
		end
		gradient.Rotation = (gradient.Rotation + dt * (speed or 60)) % 360
	end)
end

-- Respiracio suau (per a insignies i avisos).
function Effects.Pulse(obj: GuiObject, amount: number?, period: number?)
	local s = Effects.ScaleOf(obj)
	local info = TweenInfo.new((period or 0.9) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(s, info, { Scale = 1 + (amount or 0.12) }):Play()
end

-- Numero que salta i puja fins que s'esvaeix ("+18", "+1 🦴").
function Effects.Float(parent: GuiObject, text: string, color: Color3?, from: UDim2?, size: number?)
	local label = Theme.Text(parent, text, {
		Size = UDim2.fromOffset(size or 150, (size or 150) * 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = from or UDim2.fromScale(0.5, 0.5),
		TextColor3 = color or Theme.C.yellow,
		ZIndex = 50,
		Rotation = math.random(-12, 12),
	})
	Effects.PopIn(label, 0.25)
	local rise = UDim2.new(0, math.random(-30, 30), 0, -70)
	tween(label, 1.1, { Position = label.Position + rise, Rotation = 0 }, Enum.EasingStyle.Quad)
	task.delay(0.6, function()
		tween(label, 0.5, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.5, { Transparency = 1 })
		end
	end)
	task.delay(1.2, function()
		label:Destroy()
	end)
end

-- ─────────────────────────── AVISOS ───────────────────────────

local toastGui: ScreenGui? = nil
local toastHolder: Frame? = nil
local toastCount = 0

-- Pastilla de colors a dalt al mig. Se'n poden apilar unes quantes.
function Effects.Toast(text: string, color: Color3?, sound: string?)
	if not toastHolder then
		toastGui = Theme.Screen("ToastGui", 20)
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 92) -- a sota de l'objectiu del tutorial
		holder.Size = UDim2.fromOffset(620, 300)
		holder.Parent = toastGui
		Theme.AutoScale(holder)
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder
		toastHolder = holder
	end
	local holder = toastHolder :: Frame
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(560, 54)
	pill.BackgroundColor3 = color or Theme.C.blue
	toastCount += 1
	pill.LayoutOrder = toastCount
	pill.Parent = holder
	Theme.Corner(pill, 27)
	Theme.Stroke(pill)
	Theme.Shade(pill)
	Theme.Text(pill, text, {
		Size = UDim2.new(1, -30, 1, -14),
		Position = UDim2.fromOffset(15, 7),
	})
	Effects.PopIn(pill, 0.35)
	Theme.Play(sound or "notify", 0.4)
	task.delay(2.6, function()
		tween(Effects.ScaleOf(pill), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.22)
		pill:Destroy()
	end)
end

-- ─────────────────────── RAIGS I CONFETI ───────────────────────

-- Raigs de llum que giren darrere d'una carta. Torna el marc per poder-lo esborrar.
function Effects.Sunburst(parent: GuiObject, color: Color3, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Sunburst"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = 1
	holder.Parent = parent
	for i = 0, 11 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, size * 0.09, 1, 0)
		ray.Rotation = i * 15
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.ZIndex = 1
		ray.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = ray
	end
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		holder.Rotation += dt * 25
	end)
	return holder
end

local CONFETTI = { Theme.C.pink, Theme.C.yellow, Theme.C.cyan, Theme.C.green, Theme.C.purple, Theme.C.orange }

function Effects.Confetti(parent: GuiObject, count: number?)
	for _ = 1, count or 40 do
		local bit = Instance.new("Frame")
		bit.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromScale(0.5, 0.45)
		bit.BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)]
		bit.BorderSizePixel = 0
		bit.Rotation = math.random(0, 360)
		bit.ZIndex = 60
		bit.Parent = parent
		local angle = math.random() * math.pi * 2
		local dist = math.random(160, 420)
		local target = UDim2.new(0.5, math.cos(angle) * dist, 0.45, math.sin(angle) * dist * 0.7 + 120)
		tween(bit, 1.2, { Position = target, Rotation = bit.Rotation + math.random(-360, 360) }, Enum.EasingStyle.Quart)
		task.delay(0.8, function()
			tween(bit, 0.4, { BackgroundTransparency = 1 })
		end)
		task.delay(1.3, function()
			bit:Destroy()
		end)
	end
end

return Effects
