--!strict

-- EventController — el munt daurat (esdeveniment de DigService): quan un munt
-- porta l'atribut Golden (fins quan, en temps del servidor), aquí se'l fa
-- brillar: contorn daurat, espurnes i un rètol amb el temps que queda.
-- Només visual: qui el cava i què dona ho decideix el servidor.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))

local C = Theme.C
local player = Players.LocalPlayer

local EventController = {}

local shown: { [BasePart]: { Instance } } = {}

local function clear(spot: BasePart)
	for _, obj in shown[spot] or {} do
		obj:Destroy()
	end
	shown[spot] = nil
end

local function show(spot: BasePart, untilTime: number)
	clear(spot)
	local objs: { Instance } = {}
	local hl = Instance.new("Highlight")
	hl.FillColor = C.gold
	hl.FillTransparency = 0.35
	hl.OutlineColor = C.yellow
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = spot
	hl.Parent = spot
	table.insert(objs, hl)

	local att = Instance.new("Attachment")
	att.Parent = spot
	table.insert(objs, att)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(C.yellow, C.gold)
	sparks.LightEmission = 1
	sparks.Rate = 18
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Parent = att

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 70)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 250
	bb.Adornee = spot
	bb.Parent = player:WaitForChild("PlayerGui")
	table.insert(objs, bb)
	Theme.Text(bb, "⭐ GOLDEN ⭐", { Size = UDim2.fromScale(1, 0.6), TextColor3 = C.yellow, StrokeThickness = 3 })
	local timer = Theme.Text(bb, "", {
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.6),
		TextColor3 = C.cream,
		StrokeThickness = 2,
	})
	shown[spot] = objs

	-- compte enrere fins que s'acaba o algú el cava
	task.spawn(function()
		while shown[spot] == objs do
			local left = untilTime - workspace:GetServerTimeNow()
			if left <= 0 then
				clear(spot)
				return
			end
			timer.Text = `x3 LUCK · {math.ceil(left)}s`
			task.wait(0.5)
		end
	end)
end

local function watch(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local function refresh()
		local untilTime = spot:GetAttribute("Golden")
		if type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow() then
			show(spot, untilTime)
		else
			clear(spot)
		end
	end
	spot:GetAttributeChangedSignal("Golden"):Connect(refresh)
	refresh()
end

function EventController.Start()
	for _, spot in CollectionService:GetTagged("DigSpot") do
		watch(spot)
	end
	CollectionService:GetInstanceAddedSignal("DigSpot"):Connect(watch)
end

return EventController
