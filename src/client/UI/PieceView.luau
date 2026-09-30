--!strict

-- PieceView — la peça d'os de veritat (o l'esquelet muntat) en 3D dins de la
-- UI, amb el mateix BoneBuilder que fa servir el museu. Així el que surt a
-- la targeta, a la motxilla o al museu és exactament la peça que tens.
--
--   PieceView.New(parent, item, { spin = true, size = UDim2, ... })
--     item = clau de peça ("Dodo_Skull") o id d'esquelet ("Dodo")
--
-- La càmera s'ajusta sola a la mida de la peça. Els que giren, ho fan tots
-- des d'un sol RenderStepped (no un per visor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bones = require(Shared:WaitForChild("Config"):WaitForChild("Bones"))
local BoneBuilder = require(Shared:WaitForChild("Util"):WaitForChild("BoneBuilder"))

local PieceView = {}

export type Options = {
	spin: boolean?, -- gira a poc a poc
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	angle: number?, -- gir inicial (graus)
}

type Spinner = { vp: ViewportFrame, model: Model, pivot: CFrame, angle: number }
local spinners: { Spinner } = {}
local spinConn: RBXScriptConnection? = nil

local function ensureSpin()
	if spinConn then
		return
	end
	spinConn = RunService.RenderStepped:Connect(function(dt: number)
		for i = #spinners, 1, -1 do
			local s = spinners[i]
			if not s.vp.Parent then
				table.remove(spinners, i)
			else
				s.angle += dt * 0.9
				s.model:PivotTo(CFrame.Angles(0, s.angle, 0) * s.pivot)
			end
		end
	end)
end

local function build(item: string): Model?
	local ok, model = pcall(function()
		-- amb estat ("Rat_Skull#4", "Rat#34425") es veu brut o net; la base
		-- sola (l'índex) es veu com una peça Clean
		local info = Bones.PieceInfo[item]
		local graded = string.find(item, "#", 1, true) ~= nil
		if info then
			return BoneBuilder.Piece(info.skeleton, info.piece, if graded then Bones.GradeOf(item) else nil)
		elseif Bones.ById[item] then
			return BoneBuilder.Assembled(item)
		end
		return nil
	end)
	return if ok then model else nil
end

function PieceView.New(parent: Instance, item: string, opts: Options?): ViewportFrame
	local o = opts or {}
	local vp = Instance.new("ViewportFrame")
	vp.Name = "PieceView"
	vp.BackgroundTransparency = 1
	vp.Size = o.size or UDim2.fromScale(1, 1)
	vp.Position = o.position or UDim2.new()
	vp.AnchorPoint = o.anchor or Vector2.zero
	vp.ZIndex = o.zIndex or 1
	vp.Ambient = Color3.fromRGB(170, 160, 150)
	vp.LightColor = Color3.fromRGB(255, 246, 228)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.8)
	vp.Parent = parent

	local model = build(item)
	if not model then
		return vp
	end
	-- centrat a l'origen
	local cf, size = model:GetBoundingBox()
	local pivot = CFrame.new(-cf.Position) * model:GetPivot()
	model:PivotTo(pivot)
	model.Parent = vp

	-- càmera de tres quarts, una mica per sobre, que hi càpiga tota la peça
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.08
	local dir = Vector3.new(1, 0.55, 1.15).Unit
	camera.CFrame = CFrame.lookAt(dir * dist, Vector3.zero)
	camera.Parent = vp
	vp.CurrentCamera = camera

	local start = math.rad(o.angle or 0)
	model:PivotTo(CFrame.Angles(0, start, 0) * pivot)
	if o.spin then
		table.insert(spinners, { vp = vp, model = model, pivot = pivot, angle = start })
		ensureSpin()
	end
	return vp
end

return PieceView
