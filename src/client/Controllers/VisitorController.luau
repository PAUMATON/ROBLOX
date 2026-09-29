--!strict

-- VisitorController — dibuixa els visitants dels museus, NOMÉS en aquest
-- ordinador (no es replica res): el servidor (VisitorService) diu qui entra,
-- quines vitrines mirarà i quan, i aquí se'l fa caminar amb el mateix camí
-- (Util/VisitorPath) a partir de l'hora del servidor.
--   · només es dibuixen els museus que tens a prop (RENDER_DISTANCE);
--   · camina amb l'animació de caminar de Roblox i s'atura a mirar;
--   · quan deixa propina, li surt "+X $" al damunt (i "WOW!" si és grossa).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local VisitorPath = require(Shared:WaitForChild("Util"):WaitForChild("VisitorPath"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))

local C = Theme.C
local player = Players.LocalPlayer

local VisitorController = {}

local RENDER_DISTANCE = 240
local WALK_ANIM = "rbxassetid://507777826" -- caminar R15 (Roblox)
local IDLE_ANIM = "rbxassetid://507766388" -- quiet R15 (Roblox)

type Shown = {
	data: any,
	plan: VisitorPath.Plan,
	frame: CFrame,
	model: Model?,
	root: BasePart?,
	lift: number,
	walk: AnimationTrack?,
	idle: AnimationTrack?,
	walking: boolean?,
}

local visits: { [number]: Shown } = {}
local folder: Folder
local lastOwnerToast = 0

local function makeModel(v: Shown)
	local rigs = ReplicatedStorage:FindFirstChild("VisitorRigs")
	local template = rigs and rigs:FindFirstChild(tostring(v.data.look))
	if not template then
		return
	end
	local model = (template :: Model):Clone()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		model:Destroy()
		return
	end
	root.Anchored = true
	-- sense física ni estats (si no, el Humanoid es creu que cau i es tomba)
	hum.EvaluateStateMachine = false
	hum.PlatformStand = false
	v.lift = hum.HipHeight + root.Size.Y / 2
	model.Parent = folder
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local walk = Instance.new("Animation")
	walk.AnimationId = WALK_ANIM
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIM
	pcall(function()
		v.walk = animator:LoadAnimation(walk)
		v.idle = animator:LoadAnimation(idle)
	end)
	v.model = model
	v.root = root
	v.walking = nil
end

local function dropModel(v: Shown)
	if v.model then
		v.model:Destroy()
	end
	v.model, v.root, v.walk, v.idle = nil, nil, nil, nil
end

local function add(data: any)
	if type(data) ~= "table" or typeof(data.plot) ~= "Instance" or not data.plot:IsA("Model") then
		return
	end
	local frame = VisitorPath.Frame(data.plot)
	if not frame or visits[data.id] then
		return
	end
	visits[data.id] = {
		data = data,
		plan = VisitorPath.Plan(data.slots, data.looks, data.sides),
		frame = frame,
		lift = 3,
	}
end

local function remove(id: number)
	local v = visits[id]
	if v then
		dropModel(v)
		visits[id] = nil
	end
end

-- Sobre el cap del visitant: el símbol de diners i, a sota, "+X" (el que ha
-- donat). Puja una mica i s'esvaeix.
local function tipPop(v: Shown?, amount: number, wow: boolean)
	if not v or not v.model then
		return
	end
	local head = v.model:FindFirstChild("Head") :: BasePart?
	local anchor = head or v.root
	if not anchor then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(if wow then 220 else 160, if wow then 130 else 100)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Adornee = anchor
	bb.Parent = folder
	local icon = Theme.Icon(bb, "$", {
		Size = UDim2.fromScale(1, 0.55),
	})
	local label = Theme.Text(bb, (if wow then "WOW! +" else "+") .. Theme.Short(amount), {
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.55),
		TextColor3 = if wow then C.gold else C.yellow,
		StrokeThickness = 3,
	})
	local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad)
	TweenService:Create(bb, info, { StudsOffset = Vector3.new(0, 5.5, 0) }):Play()
	local fade = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(icon, fade, { TextTransparency = 1 }):Play()
	task.delay(2.3, function()
		bb:Destroy()
	end)
	local dist = (workspace.CurrentCamera.CFrame.Position - anchor.Position).Magnitude
	if dist < 60 then
		Theme.Play(if wow then "reward" else "pop", if wow then 0.6 else 0.35, 1.3)
	end
end

local function onUpdate(msg: any)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "spawn" then
		add(msg.visit)
	elseif msg.type == "snapshot" then
		for _, data in msg.visits or {} do
			add(data)
		end
	elseif msg.type == "remove" then
		remove(msg.id)
	elseif msg.type == "tip" then
		local amount = tonumber(msg.amount) or 0
		tipPop(visits[msg.id], amount, msg.wow == true)
		-- a l'amo, un avís (sense omplir la pantalla)
		if msg.owner == player.UserId then
			local now = os.clock()
			if msg.wow or now - lastOwnerToast > 25 then
				lastOwnerToast = now
				Effects.Toast((if msg.wow then "🤩 WOW! A visitor tipped you " else "👀 A visitor tipped you ") .. `+{Theme.Short(amount)} $`, C.gold, if msg.wow then "reward" else "pop")
			end
		end
	end
end

function VisitorController.Start()
	folder = Instance.new("Folder")
	folder.Name = "LocalVisitors"
	folder.Parent = workspace

	Remotes.VisitorUpdate.OnClientEvent:Connect(onUpdate)

	-- quins es dibuixen (els museus propers), un cop per segon
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local now = workspace:GetServerTimeNow()
		local camPos = workspace.CurrentCamera.CFrame.Position
		acc += dt
		local recheck = acc > 1
		if recheck then
			acc = 0
		end
		for id, v in visits do
			local elapsed = now - v.data.t0
			if elapsed > v.plan.duration + 0.5 then
				remove(id)
				continue
			end
			if recheck then
				local near = (v.frame.Position - camPos).Magnitude < RENDER_DISTANCE
				if near and not v.model then
					makeModel(v)
				elseif not near and v.model then
					dropModel(v)
				end
			end
			local root = v.root
			if root then
				if elapsed < 0 then
					root.CFrame = CFrame.new(0, -500, 0)
				else
					local pos, dir, walking = VisitorPath.At(v.plan, elapsed)
					local world = v.frame * CFrame.new(pos.X, VisitorPath.FLOOR + v.lift, pos.Z)
					local wdir = v.frame:VectorToWorldSpace(Vector3.new(dir.X, 0, dir.Z))
					root.CFrame = CFrame.lookAt(world.Position, world.Position + wdir)
					if walking ~= v.walking then
						v.walking = walking
						if walking then
							if v.idle then
								v.idle:Stop(0.2)
							end
							if v.walk then
								v.walk:Play(0.2)
								v.walk:AdjustSpeed(0.8)
							end
						else
							if v.walk then
								v.walk:Stop(0.2)
							end
							if v.idle then
								v.idle:Play(0.2)
							end
						end
					end
				end
			end
		end
	end)
end

return VisitorController
