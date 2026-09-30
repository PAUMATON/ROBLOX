--!strict

-- BoneBuilder — fa els models de les peces d'os amb parts bàsiques (el pla B
-- del CLAUDE.md, mentre no hi hagi malles de Cube 3D).
--
-- Tot surt de Config/Bones: la forma de cada esquelet és a SkeletonDef
-- (escala, morro, costelles, cua). Aquí només hi ha geometria, cap número
-- de balanceig.
--
-- Estil: formes arrodonides (el·lipsoides), ossos llargs amb els dos caps
-- dobles de l'os "de dibuix", vèrtebres amb apòfisis, conques fosques i
-- dents. Res de caixes: un fòssil ha de semblar un os des de lluny.
--
-- Conveni: +Z és el davant (cap), -Z el darrere (cua), +Y amunt. El pivot de
-- cada peça és a l'origen, i Layout() diu on va cada peça en muntar-les.

local Bones = require(script.Parent.Parent.Config.Bones)

type SkeletonDef = Bones.SkeletonDef

local BoneBuilder = {}

local BONE = Color3.fromRGB(237, 227, 204) -- os #EDE3CC
local BONE_DARK = Color3.fromRGB(214, 200, 170) -- juntes i caps
local SOCKET = Color3.fromRGB(52, 46, 40)
local TOOTH = Color3.fromRGB(252, 246, 228)

local V = Vector3.new
local UP = Vector3.yAxis

-- ────────────────────────── PRIMITIVES ──────────────────────────

local function part(model: Model, name: string, size: Vector3, cf: CFrame, shape: Enum.PartType?, color: Color3?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color or BONE
	p.Material = Enum.Material.Limestone -- os mat, sense les taques del marbre
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- el·lipsoide (bloc amb malla d'esfera): cranis, morros, pelvis, urpes
local function ellip(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3?): BasePart
	local p = part(model, name, size, cf, nil, color)
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	return p
end

local function ball(model: Model, name: string, d: number, pos: Vector3, color: Color3?)
	part(model, name, V(d, d, d), CFrame.new(pos), Enum.PartType.Ball, color)
end

-- CFrame a `a` amb la Z local mirant cap a `b` (per a el·lipsoides allargats)
local function along(a: Vector3, b: Vector3): CFrame
	if (b - a).Magnitude < 1e-3 then
		return CFrame.new(a)
	end
	local dir = (b - a).Unit
	local upv = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else UP
	return CFrame.lookAt(a, b, upv)
end

-- una direcció perpendicular a `dir`, tan horitzontal com es pugui
local function sideOf(dir: Vector3): Vector3
	local s = dir:Cross(UP)
	if s.Magnitude < 0.1 then
		s = dir:Cross(Vector3.xAxis)
	end
	return s.Unit
end

-- Diàfisi entre dos punts (cilindre, eix a la X local)
local function shaft(model: Model, a: Vector3, b: Vector3, thick: number, color: Color3?)
	local d = (b - a).Magnitude
	if d < 0.02 then
		return
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	part(model, "Shaft", V(d, thick, thick), cf, Enum.PartType.Cylinder, color)
end

-- Os llarg "de dibuix": diàfisi i dos caps dobles a cada punta
local function longBone(model: Model, a: Vector3, b: Vector3, thick: number)
	shaft(model, a, b, thick)
	local side = sideOf((b - a).Unit)
	for _, e in { a, b } do
		for _, sg in { -1, 1 } do
			ball(model, "Epiphysis", thick * 1.3, e + side * sg * thick * 0.42, BONE_DARK)
		end
	end
end

-- Os corbat entre punts (costelles, forquilles): prim, s'aprima cap a la punta
local function curve(model: Model, pts: { Vector3 }, thick: number, taper: number?)
	local n = #pts - 1
	for i = 1, n do
		local t = (i - 1) / math.max(1, n)
		shaft(model, pts[i], pts[i + 1], thick * (1 - (taper or 0.4) * t))
	end
	for i = 2, n do
		local t = (i - 1) / math.max(1, n)
		ball(model, "Bend", thick * (1 - (taper or 0.4) * t), pts[i])
	end
end

-- Vèrtebra: disc (cos vertebral) en la direcció de la columna, apòfisi
-- espinosa cap amunt i dues transverses als costats.
local function vertebra(model: Model, pos: Vector3, dir: Vector3, r: number, spike: number?)
	local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
	part(model, "Centrum", V(r * 0.62, r, r), cf, Enum.PartType.Cylinder)
	local side = sideOf(dir)
	local up = dir:Cross(side).Unit
	if up.Y < 0 then
		up = -up
	end
	local h = r * (spike or 1.1)
	ellip(model, "SpinousProcess", V(r * 0.22, h, r * 0.5), CFrame.fromMatrix(pos + up * (r * 0.35 + h / 2), side, up))
	for _, sg in { -1, 1 } do
		ellip(model, "Transverse", V(r * 0.75, r * 0.2, r * 0.32), CFrame.fromMatrix(pos + side * sg * r * 0.55 + up * r * 0.1, side, up))
	end
end

-- Columna de vèrtebres al llarg d'uns punts (radi que va de r0 a r1)
local function column(model: Model, pts: { Vector3 }, r0: number, r1: number, spike: number?)
	for i, p in pts do
		local t = (i - 1) / math.max(1, #pts - 1)
		local dir = if i < #pts then (pts[i + 1] - p) else (p - pts[i - 1])
		if dir.Magnitude < 1e-3 then
			dir = Vector3.zAxis
		end
		vertebra(model, p, dir.Unit, r0 + (r1 - r0) * t, spike)
	end
	-- disc intervertebral: una diàfisi prima que les uneix
	for i = 1, #pts - 1 do
		local t = (i - 1) / math.max(1, #pts - 1)
		shaft(model, pts[i], pts[i + 1], (r0 + (r1 - r0) * t) * 0.45, BONE_DARK)
	end
end

-- Dent: el·lipsoide prim i punxegut que penja (o puja) des de `root`
local function tooth(model: Model, root: Vector3, len: number, w: number, down: boolean, back: number?)
	local tip = root + V(0, if down then -len else len, -(back or 0))
	ellip(model, "Tooth", V(w, w * 0.9, len * 2), along(root, tip), TOOTH)
end

-- Urpa: corbada cap avall i endavant
local function claw(model: Model, root: Vector3, len: number, w: number)
	local tip = root + V(0, -len * 0.45, len)
	ellip(model, "Claw", V(w, w, len * 1.5), along(root, tip), BONE_DARK)
end

-- ─────────────────────────── MAMÍFER ───────────────────────────

local mammal: { [string]: (Model, SkeletonDef) -> () } = {}

function mammal.Skull(m, sk)
	local s = sk.s
	-- morro (rostre): curt al gat, llarg a la rata i al gos
	local L = (0.2 + (sk.snout or 0.6) * 0.55) * s
	local z0 = 0.34 * s -- on comença el morro
	-- volta del crani, cresta i occipital
	ellip(m, "Cranium", V(0.78 * s, 0.66 * s, 0.9 * s), CFrame.new(0, 0.03 * s, -0.06 * s))
	ellip(m, "Crest", V(0.09 * s, 0.18 * s, 0.72 * s), CFrame.new(0, 0.33 * s, -0.12 * s))
	ellip(m, "Occiput", V(0.6 * s, 0.48 * s, 0.2 * s), CFrame.new(0, 0, -0.5 * s))
	-- morro que s'estreny i el forat del nas (UN, a la punta)
	ellip(m, "Snout", V(0.46 * s, 0.34 * s, L * 1.08), CFrame.new(0, -0.07 * s, z0 + L / 2) * CFrame.Angles(math.rad(3), 0, 0))
	ellip(m, "SnoutTip", V(0.3 * s, 0.27 * s, 0.26 * s), CFrame.new(0, -0.09 * s, z0 + L))
	ellip(m, "NasalOpening", V(0.18 * s, 0.14 * s, 0.05 * s), CFrame.new(0, -0.05 * s, z0 + L + 0.12 * s), SOCKET)
	ellip(m, "NasalBridge", V(0.2 * s, 0.08 * s, L * 0.9), CFrame.new(0, 0.08 * s, z0 + L * 0.45))
	for _, sgn in { -1, 1 } do
		-- conca de l'ull, gran i mirant endavant i enfora, amb la cella d'os
		local eye = V(sgn * 0.27 * s, 0.1 * s, 0.28 * s)
		ellip(m, "EyeSocket", V(0.3 * s, 0.3 * s, 0.1 * s), CFrame.lookAt(eye, eye + V(sgn * 0.75, 0.05, 1)), SOCKET)
		ellip(m, "Brow", V(0.24 * s, 0.1 * s, 0.2 * s), CFrame.new(sgn * 0.24 * s, 0.21 * s, 0.24 * s) * CFrame.Angles(0, 0, math.rad(sgn * -14)))
		-- arc zigomàtic: la galta que s'obre cap enfora
		curve(m, { V(sgn * 0.24 * s, -0.08 * s, 0.34 * s), V(sgn * 0.4 * s, -0.1 * s, 0.1 * s), V(sgn * 0.32 * s, -0.06 * s, -0.2 * s) }, 0.1 * s, 0.2)
		-- dents de dalt, del davant cap enrere (la segona és l'ullal)
		local n = 5
		for i = 0, n - 1 do
			local t = i / (n - 1)
			local z = z0 + L * (0.95 - t * 0.95)
			local x = sgn * (0.08 + 0.1 * t) * s
			local long = if i == 1 then 0.16 else 0.08
			tooth(m, V(x, -0.2 * s, z), long * s, 0.06 * s, true)
		end
		-- ullals de sabre: dos trams que baixen i es corben enrere
		if sk.fangs then
			local f = sk.fangs
			local root = V(sgn * 0.12 * s, -0.2 * s, z0 + L * 0.72)
			local mid = root + V(0, -0.45 * f * s, 0.04 * s)
			local tip = mid + V(0, -0.4 * f * s, -0.12 * s)
			ellip(m, "Fang", V(0.13 * s, 0.1 * s, (mid - root).Magnitude * 1.15), along(root, mid), TOOTH)
			ellip(m, "FangTip", V(0.09 * s, 0.07 * s, (tip - mid).Magnitude * 1.3), along(mid, tip), TOOTH)
		end
	end
	if not Bones.HasPiece(sk, "Jaw") then
		mammal.Jaw(m, sk)
	end
end

-- Mandíbula: part del crani, o peça pròpia ("Jaw")
function mammal.Jaw(m, sk)
	local s = sk.s
	local L = (0.2 + (sk.snout or 0.6) * 0.55) * s
	-- mandíbula una mica oberta, amb les branques que pugen i les dents de baix
	local hinge = CFrame.new(0, -0.24 * s, -0.08 * s) * CFrame.Angles(math.rad(-9), 0, 0)
	local jl = L + 0.42 * s
	ellip(m, "Jaw", V(0.36 * s, 0.12 * s, jl), hinge * CFrame.new(0, -0.04 * s, jl / 2))
	for _, sgn in { -1, 1 } do
		ellip(m, "JawRamus", V(0.08 * s, 0.34 * s, 0.22 * s), hinge * CFrame.new(sgn * 0.17 * s, 0.1 * s, 0.02 * s))
		for i = 0, 3 do
			local t = i / 3
			local root = (hinge * CFrame.new(sgn * (0.07 + 0.08 * t) * s, 0.03 * s, jl * (0.93 - t * 0.7))).Position
			tooth(m, root, (if i == 0 then 0.12 else 0.07) * s, 0.05 * s, false)
		end
	end
end

-- Costelles i estèrnum: part de la columna, o peça pròpia ("Ribs") si
-- l'esquelet en té (Bones.EXTRA_PIECES)
function mammal.Ribs(m, sk)
	local s, n = sk.s, sk.ribs or 6
	local len = 2.6 * s
	-- Costelles: arc des de la columna cap avall i enfora, més llargues al mig
	for i = 1, n do
		local t = (i - 1) / math.max(1, n - 1)
		local z = -len * 0.3 + (len * 0.6) * t
		local r = (0.5 + 0.18 * math.sin(t * math.pi)) * s
		for _, sgn in { -1, 1 } do
			local rp = {}
			for k = 0, 5 do
				local a = math.rad(100 * k / 5)
				table.insert(rp, V(sgn * (0.08 * s + r * math.sin(a)), -r * 1.1 * (1 - math.cos(a)), z + k * 0.02 * s))
			end
			curve(m, rp, 0.075 * s, 0.5)
		end
	end
	-- estèrnum
	ellip(m, "Sternum", V(0.12 * s, 0.1 * s, len * 0.55), CFrame.new(0, -0.58 * 1.1 * s - 0.1 * s, 0))
end

function mammal.Spine(m, sk)
	local s = sk.s
	local len = 2.6 * s
	local pts = {}
	for i = 0, 10 do
		local t = i / 10
		table.insert(pts, V(0, math.sin(t * math.pi) * 0.12 * s, -len / 2 + len * t))
	end
	column(m, pts, 0.2 * s, 0.17 * s, 1.2)
	if not Bones.HasPiece(sk, "Ribs") then
		mammal.Ribs(m, sk)
	end
end

-- una mà/peu de 4 dits amb artells i urpes
local function paw(m: Model, s: number, at: Vector3)
	for d = 0, 3 do
		local spread = (d - 1.5) * 0.07 * s
		local knuckle = at + V(spread, -0.04 * s, 0.14 * s)
		shaft(m, at, knuckle, 0.05 * s)
		ball(m, "Knuckle", 0.065 * s, knuckle, BONE_DARK)
		local tipPos = knuckle + V(spread * 0.3, -0.02 * s, 0.1 * s)
		shaft(m, knuckle, tipPos, 0.04 * s)
		claw(m, tipPos, 0.09 * s, 0.045 * s)
	end
end

function mammal.ForeLimbs(m, sk)
	local s = sk.s
	for _, sgn in { -1, 1 } do
		local shoulder = V(sgn * 0.34 * s, 0, 0)
		local elbow = V(sgn * 0.42 * s, -0.72 * s, 0.14 * s)
		local wrist = V(sgn * 0.4 * s, -1.38 * s, -0.02 * s)
		local palm = V(sgn * 0.4 * s, -1.52 * s, 0.08 * s)
		-- omòplat: làmina inclinada enrere amb la cresta (l'espina)
		local sc = CFrame.new(shoulder + V(0, 0.28 * s, -0.12 * s)) * CFrame.Angles(math.rad(-28), 0, math.rad(sgn * 8))
		ellip(m, "Scapula", V(0.07 * s, 0.5 * s, 0.3 * s), sc)
		ellip(m, "ScapulaSpine", V(0.1 * s, 0.42 * s, 0.05 * s), sc * CFrame.new(sgn * 0.03 * s, 0, 0.02 * s))
		ball(m, "HumerusHead", 0.2 * s, shoulder, BONE_DARK)
		longBone(m, shoulder, elbow, 0.12 * s)
		-- avantbraç: cúbit i radi, dos ossos
		local side = V(0, 0, 1)
		longBone(m, elbow + side * 0.03 * s, wrist + side * 0.03 * s, 0.09 * s)
		shaft(m, elbow - side * 0.04 * s, wrist - side * 0.04 * s, 0.05 * s)
		ball(m, "Wrist", 0.12 * s, wrist, BONE_DARK)
		shaft(m, wrist, palm, 0.09 * s)
		paw(m, s, palm)
	end
end

-- Pelvis: part de les potes del darrere, o peça pròpia ("Pelvis")
function mammal.Pelvis(m, sk)
	local s = sk.s
	-- pelvis: sacre (vèrtebres soldades), dues ales (ili) i l'anell de sota
	column(m, { V(0, 0.14 * s, 0.26 * s), V(0, 0.15 * s, 0.02 * s), V(0, 0.14 * s, -0.22 * s) }, 0.15 * s, 0.13 * s, 0.7)
	for _, sgn in { -1, 1 } do
		local socket = V(sgn * 0.3 * s, -0.05 * s, -0.06 * s)
		ellip(m, "Ilium", V(0.09 * s, 0.2 * s, 0.56 * s), CFrame.new(sgn * 0.21 * s, 0.1 * s, 0.14 * s) * CFrame.Angles(math.rad(-18), math.rad(sgn * -12), 0))
		-- l'anell (isqui i pubis) amb el forat al mig
		curve(m, { socket, V(sgn * 0.24 * s, -0.16 * s, -0.3 * s), V(sgn * 0.1 * s, -0.22 * s, -0.16 * s), V(0, -0.2 * s, 0.04 * s), V(sgn * 0.14 * s, -0.14 * s, 0.1 * s), socket }, 0.07 * s, 0)
		ball(m, "Socket", 0.17 * s, socket, BONE_DARK)
	end
end

function mammal.HindLimbs(m, sk)
	local s = sk.s
	if not Bones.HasPiece(sk, "Pelvis") then
		mammal.Pelvis(m, sk)
	end
	for _, sgn in { -1, 1 } do
		local hip = V(sgn * 0.34 * s, -0.05 * s, -0.06 * s)
		local knee = V(sgn * 0.4 * s, -0.72 * s, 0.24 * s)
		local ankle = V(sgn * 0.39 * s, -1.36 * s, -0.12 * s)
		local foot = V(sgn * 0.39 * s, -1.56 * s, 0.06 * s)
		longBone(m, hip, knee, 0.13 * s)
		ball(m, "Kneecap", 0.12 * s, knee + V(0, 0.02 * s, 0.07 * s), BONE_DARK)
		-- tíbia i peroné
		longBone(m, knee + V(0, 0, 0.02 * s), ankle + V(0, 0, 0.02 * s), 0.1 * s)
		shaft(m, knee + V(sgn * 0.05 * s, 0, -0.03 * s), ankle + V(sgn * 0.05 * s, 0, -0.03 * s), 0.045 * s)
		ellip(m, "Heel", V(0.09 * s, 0.1 * s, 0.22 * s), CFrame.new(ankle + V(0, -0.04 * s, -0.09 * s)))
		shaft(m, ankle, foot, 0.09 * s)
		paw(m, s, foot)
	end
end

function mammal.Tail(m, sk)
	local s = sk.s
	local segs = sk.tailSegs or 12
	local len = (sk.tailLen or 1.6) * s
	local pts = {}
	for i = 0, segs do
		local t = i / segs
		table.insert(pts, V(0, -math.sin(t * 1.5) * 0.5 * s, -len * t))
	end
	column(m, pts, 0.17 * s, 0.06 * s, 0.7)
end

-- ──────────────────────────── OCELL ────────────────────────────

local bird: { [string]: (Model, SkeletonDef) -> () } = {}

function bird.Skull(m, sk)
	local s = sk.s
	local b = sk.beak or 1 -- el dodo té un bec enorme i ganxut
	ellip(m, "Cranium", V(0.64 * s, 0.6 * s, 0.7 * s), CFrame.new(0, 0, 0))
	ellip(m, "Occiput", V(0.44 * s, 0.4 * s, 0.2 * s), CFrame.new(0, -0.02 * s, -0.34 * s))
	-- bec: una corba de trossos que s'aprimen; si b > 1, la punta fa ganxo avall
	local len = (0.55 + 0.35 * b) * s
	local n = 5
	local prev: Vector3? = nil
	local bulb = math.max(0, b - 1) -- el dodo té la punta del bec grossa i bombada
	for i = 0, n do
		local t = i / n
		local hook = bulb * (t ^ 3) * 0.2 * s
		local p = V(0, -0.02 * s - hook, 0.24 * s + t * len)
		local w = (0.34 - 0.12 * t) * s * b ^ 0.6
		local h = (0.3 - 0.1 * t + bulb * 0.24 * math.max(0, t - 0.4)) * s * (0.7 + 0.3 * b)
		if prev then
			-- trossos molt encavalcats: es veu un sol bec llis
			ellip(m, "Beak", V(w, h, (p - prev).Magnitude * 3.2), along(prev, p))
		end
		prev = p
	end
	local tip = prev :: Vector3
	-- la punta: un ganxo que baixa (petit als ocells normals, gros al dodo)
	local hs = (0.5 + 0.5 * b) * s
	ellip(m, "BeakHook", V(0.12 * hs, 0.2 * hs, 0.16 * hs), CFrame.new(tip + V(0, -0.07 * hs, 0.02 * hs)) * CFrame.Angles(math.rad(40), 0, 0))
	-- mandíbula de baix: just a sota del bec, tocant-lo
	local lowY = -0.02 * s - 0.12 * s * (0.75 + 0.25 * b)
	ellip(m, "BeakLower", V(0.2 * s * math.sqrt(b), 0.1 * s, len * 0.82), CFrame.new(0, lowY, 0.24 * s + len * 0.4) * CFrame.Angles(math.rad(3), 0, 0))
	ellip(m, "Nostril", V(0.07 * s, 0.05 * s, 0.18 * s * b), CFrame.new(0, 0.08 * s, 0.4 * s + len * 0.2), SOCKET)
	-- les conques enormes són el que fa reconeixible un crani d'ocell
	for _, sgn in { -1, 1 } do
		local eye = V(sgn * 0.26 * s, 0.05 * s, 0.14 * s)
		ellip(m, "EyeSocket", V(0.36 * s, 0.36 * s, 0.08 * s), CFrame.lookAt(eye, eye + V(sgn, 0, 0.35)), SOCKET)
		ellip(m, "EyeRing", V(0.44 * s, 0.44 * s, 0.05 * s), CFrame.lookAt(eye - V(sgn * 0.02 * s, 0, 0), eye + V(sgn, 0, 0.35)))
	end
	ball(m, "Atlas", 0.16 * s, V(0, -0.12 * s, -0.4 * s))
end

-- Coll en S: part de la columna, o peça pròpia ("Neck")
function bird.Neck(m, sk)
	local s = sk.s
	local neck = {}
	for i = 0, 6 do
		local t = i / 6
		table.insert(neck, V(0, 0.5 * s - math.sin(t * math.pi) * 0.28 * s, 0.75 * s - t * 0.75 * s))
	end
	column(m, neck, 0.13 * s, 0.15 * s, 0.6)
end

function bird.Spine(m, sk)
	local s = sk.s
	if not Bones.HasPiece(sk, "Neck") then
		bird.Neck(m, sk)
	end
	local trunk = {}
	for i = 0, 5 do
		table.insert(trunk, V(0, 0.05 * s, -i * 0.16 * s))
	end
	column(m, trunk, 0.16 * s, 0.15 * s, 0.9)
	if not Bones.HasPiece(sk, "Ribs") then
		bird.Ribs(m, sk)
	end
end

-- Estèrnum, quilla, forquilla i costelles: part de la columna, o peça pròpia ("Ribs")
function bird.Ribs(m, sk)
	local s = sk.s
	-- estèrnum amb la quilla (el que fa volar un ocell)
	ellip(m, "Sternum", V(0.52 * s, 0.1 * s, 0.9 * s), CFrame.new(0, -0.5 * s, -0.32 * s))
	ellip(m, "Keel", V(0.08 * s, 0.46 * s, 0.86 * s), CFrame.new(0, -0.7 * s, -0.3 * s))
	local round = if sk.stocky then 1.45 else 1 -- el dodo és rodanxó
	for _, sgn in { -1, 1 } do
		-- forquilla
		curve(m, { V(sgn * 0.3 * s, 0.02 * s, 0.06 * s), V(sgn * 0.14 * s, -0.24 * s, 0.02 * s), V(0, -0.4 * s, -0.05 * s) }, 0.055 * s, 0.2)
		for i = 1, 4 do
			local z = -0.05 * s - i * 0.17 * s
			local rp = {}
			for k = 0, 4 do
				local a = math.rad(95 * k / 4)
				table.insert(rp, V(sgn * 0.42 * round * s * math.sin(a), -0.55 * round * s * (1 - math.cos(a)), z))
			end
			curve(m, rp, 0.05 * s, 0.4)
		end
	end
end

function bird.ForeLimbs(m, sk)
	-- el dodo no vola: ales petitones
	local s = if sk.stocky then sk.s * 0.55 else sk.s
	local PRINT = Color3.fromRGB(226, 214, 190)
	for _, sgn in { -1, 1 } do
		-- ala mig oberta: húmer enrere, avantbraç endavant, mà enfora
		local shoulder = V(sgn * 0.22 * s, 0, 0)
		local elbow = V(sgn * 0.8 * s, 0.12 * s, -0.32 * s)
		local wrist = V(sgn * 1.38 * s, 0.16 * s, 0.02 * s)
		local tip = V(sgn * 2 * s, 0.1 * s, -0.12 * s)
		ellip(m, "Coracoid", V(0.14 * s, 0.1 * s, 0.4 * s), CFrame.new(shoulder + V(sgn * -0.04 * s, -0.16 * s, 0.1 * s)))
		ball(m, "Shoulder", 0.14 * s, shoulder, BONE_DARK)
		longBone(m, shoulder, elbow, 0.1 * s)
		-- cúbit (gruixut) i radi (prim)
		local side = (wrist - elbow).Unit:Cross(Vector3.yAxis).Unit
		longBone(m, elbow + side * 0.05 * s, wrist + side * 0.05 * s, 0.075 * s)
		shaft(m, elbow - side * 0.06 * s, wrist - side * 0.06 * s, 0.045 * s)
		ball(m, "Wrist", 0.12 * s, wrist, BONE_DARK)
		-- mà: carpometacarp (dos ossos) i el dit
		local hand = wrist:Lerp(tip, 0.5)
		shaft(m, wrist, hand, 0.08 * s)
		shaft(m, wrist + side * 0.05 * s, hand + side * 0.05 * s, 0.04 * s)
		curve(m, { hand, hand:Lerp(tip, 0.5) + V(0, 0.02 * s, 0), tip }, 0.05 * s, 0.5)
		-- l'empremta de les plomes a la roca: de la mà i de l'avantbraç cap enrere
		for i = 0, 6 do
			local t = i / 6
			local from = elbow:Lerp(tip, 0.25 + t * 0.75)
			local lenF = (0.55 + 0.35 * t) * s
			local to = from + V(sgn * 0.12 * t * s, -0.03 * s, -lenF)
			ellip(m, "FeatherPrint", V(0.22 * s, 0.03 * s, lenF), CFrame.lookAt((from + to) / 2, to), PRINT)
		end
	end
end

-- Sinsacre i ili: part de les potes, o peça pròpia ("Pelvis")
function bird.Pelvis(m, sk)
	local s = sk.s
	ellip(m, "Synsacrum", V(0.2 * s, 0.14 * s, 0.72 * s), CFrame.new(0, 0.14 * s, 0))
	for _, sgn in { -1, 1 } do
		ellip(m, "Ilium", V(0.18 * s, 0.1 * s, 0.7 * s), CFrame.new(sgn * 0.16 * s, 0.08 * s, -0.02 * s) * CFrame.Angles(0, 0, math.rad(sgn * -20)))
	end
end

function bird.HindLimbs(m, sk)
	local s = sk.s
	if not Bones.HasPiece(sk, "Pelvis") then
		bird.Pelvis(m, sk)
	end
	for _, sgn in { -1, 1 } do
		local hip = V(sgn * 0.18 * s, 0, -0.05 * s)
		local knee = V(sgn * 0.26 * s, -0.5 * s, 0.16 * s)
		local heel = V(sgn * 0.24 * s, -0.95 * s, -0.14 * s)
		-- El tars llarg és el que fa que una pota d'ocell es reconegui
		local foot = V(sgn * 0.24 * s, -1.62 * s, 0.02 * s)
		longBone(m, hip, knee, 0.085 * s)
		longBone(m, knee, heel, 0.075 * s)
		longBone(m, heel, foot, 0.06 * s)
		for t = -1, 1 do
			local toe = foot + V(t * 0.14 * s, -0.04 * s, 0.26 * s)
			curve(m, { foot, foot:Lerp(toe, 0.5) + V(0, 0.02 * s, 0), toe }, 0.04 * s, 0.2)
			claw(m, toe, 0.08 * s, 0.04 * s)
		end
		local back = foot + V(0, -0.04 * s, -0.18 * s)
		shaft(m, foot, back, 0.035 * s)
		claw(m, back, 0.06 * s, 0.035 * s)
	end
end

function bird.Tail(m, sk)
	local s = sk.s
	-- sinsacre curt, vèrtebres caudals que es fan petites i el pigòstil (la
	-- "rabadilla" d'on surten les plomes), que és el que es fossilitza
	local pts = {}
	for i = 0, 5 do
		local t = i / 5
		table.insert(pts, V(0, math.sin(t * 1.4) * 0.12 * s, -i * 0.13 * s))
	end
	column(m, pts, 0.15 * s, 0.09 * s, 0.9)
	local py = V(0, 0.2 * s, -0.8 * s)
	ellip(m, "Pygostyle", V(0.12 * s, 0.34 * s, 0.26 * s), CFrame.new(py) * CFrame.Angles(math.rad(-35), 0, 0))
	ellip(m, "PygostyleTip", V(0.08 * s, 0.2 * s, 0.14 * s), CFrame.new(py + V(0, 0.2 * s, -0.08 * s)) * CFrame.Angles(math.rad(-50), 0, 0), BONE_DARK)
	-- l'empremta de les plomes a la roca: fines, en ventall, molt clares
	for i = -3, 3 do
		local a = math.rad(i * 12)
		local from = py + V(0, -0.05 * s, -0.08 * s)
		local to = from + V(math.sin(a) * 0.9 * s, -0.08 * s, -math.cos(a) * 0.9 * s)
		ellip(m, "FeatherPrint", V(0.12 * s, 0.03 * s, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(226, 214, 190))
	end
end

-- ─────────────────────────── TERÒPODE (T-Rex) ───────────────────────────

local theropod: { [string]: (Model, SkeletonDef) -> () } = {}

function theropod.Skull(m, sk)
	local s = sk.s
	-- crani gros i alt, morro llarg i mandíbula potent
	ellip(m, "Cranium", V(1.5 * s, 1.75 * s, 2.6 * s), CFrame.new(0, 0.1 * s, -0.4 * s))
	ellip(m, "Snout", V(1.15 * s, 1.25 * s, 2.8 * s), CFrame.new(0, -0.1 * s, 1.5 * s) * CFrame.Angles(math.rad(6), 0, 0))
	ellip(m, "NoseTip", V(0.9 * s, 0.9 * s, 0.8 * s), CFrame.new(0, -0.3 * s, 2.75 * s))
	local split = Bones.HasPiece(sk, "Jaw")
	if not split then
		theropod.Jaw(m, sk)
	end
	ellip(m, "Occiput", V(1.3 * s, 1.1 * s, 0.6 * s), CFrame.new(0, 0.2 * s, -1.6 * s))
	for _, sgn in { -1, 1 } do
		-- conca de l'ull, cella amb banyeta i les finestres del crani
		ellip(m, "EyeSocket", V(0.3 * s, 0.55 * s, 0.5 * s), CFrame.new(sgn * 0.66 * s, 0.4 * s, -0.2 * s), SOCKET)
		ellip(m, "Brow", V(0.3 * s, 0.22 * s, 0.7 * s), CFrame.new(sgn * 0.6 * s, 0.76 * s, -0.2 * s))
		ellip(m, "BrowHorn", V(0.18 * s, 0.34 * s, 0.24 * s), CFrame.new(sgn * 0.58 * s, 0.95 * s, -0.05 * s) * CFrame.Angles(math.rad(-20), 0, 0))
		ellip(m, "Fenestra", V(0.3 * s, 0.7 * s, 1.05 * s), CFrame.new(sgn * 0.6 * s, 0 * s, 0.9 * s), SOCKET)
		ellip(m, "Temporal", V(0.3 * s, 0.6 * s, 0.6 * s), CFrame.new(sgn * 0.68 * s, 0.1 * s, -1.1 * s), SOCKET)
		ellip(m, "Nostril", V(0.2 * s, 0.24 * s, 0.34 * s), CFrame.new(sgn * 0.3 * s, -0.05 * s, 2.7 * s), SOCKET)
		-- dents grosses de dalt i de baix
		for i = 0, 7 do
			local z = -0.35 * s + i * 0.44 * s
			tooth(m, V(sgn * 0.44 * s, -0.62 * s, z), (0.32 + 0.1 * math.sin(i * 1.3)) * s, 0.16 * s, true, 0.06 * s)
		end
	end
end

-- Mandíbula i dents de baix: part del crani, o peça pròpia ("Jaw")
function theropod.Jaw(m, sk)
	local s = sk.s
	ellip(m, "Jaw", V(1.25 * s, 0.6 * s, 3.8 * s), CFrame.new(0, -0.95 * s, 0.8 * s) * CFrame.Angles(math.rad(-8), 0, 0))
	for _, sgn in { -1, 1 } do
		for i = 1, 6 do
			local z = -0.35 * s + i * 0.44 * s
			tooth(m, V(sgn * 0.4 * s, -0.78 * s, z + 0.2 * s), 0.22 * s, 0.13 * s, false)
		end
	end
end

function theropod.Spine(m, sk)
	local s = sk.s
	-- coll en S que puja cap al cap, esquena i maluc
	local pts = {}
	for i = 0, 12 do
		local t = i / 12
		local z = -2.2 + t * 6
		local y = if z > 2 then (z - 2) * 0.7 else math.sin(t * math.pi) * 0.25
		table.insert(pts, V(0, y * s, z * s))
	end
	column(m, pts, 0.62 * s, 0.5 * s, 1.3)
	if not Bones.HasPiece(sk, "Ribs") then
		theropod.Ribs(m, sk)
	end
end

-- Costelles i gastràlia: part de la columna, o peça pròpia ("Ribs")
function theropod.Ribs(m, sk)
	local s = sk.s
	local r = 1.3 * s
	for i = 1, 8 do
		local t = (i - 1) / 7
		local z = (-1.4 + (i - 1) * 0.5) * s
		local rr = r * (0.85 + 0.25 * math.sin(t * math.pi))
		for _, sgn in { -1, 1 } do
			local rp = {}
			for k = 0, 5 do
				local a = math.rad(100 * k / 5)
				table.insert(rp, V(sgn * (0.2 * s + rr * math.sin(a)), -rr * 1.3 * (1 - math.cos(a)), z + k * 0.04 * s))
			end
			curve(m, rp, 0.18 * s, 0.5)
		end
	end
	-- costelles del ventre (gastràlia)
	for i = 0, 5 do
		local z = (-1.2 + i * 0.5) * s
		curve(m, { V(-1 * s, -2.9 * s, z), V(0, -3.15 * s, z + 0.1 * s), V(1 * s, -2.9 * s, z) }, 0.1 * s, 0)
	end
end

function theropod.ForeLimbs(m, sk)
	local s = sk.s
	-- els famosos bracets
	for _, sgn in { -1, 1 } do
		local shoulder = V(sgn * 0.6 * s, 0, 0)
		local elbow = V(sgn * 0.8 * s, -0.6 * s, 0.35 * s)
		local hand = V(sgn * 0.7 * s, -0.9 * s, 0.8 * s)
		ellip(m, "Scapula", V(0.16 * s, 1.1 * s, 0.4 * s), CFrame.new(shoulder + V(0, 0.4 * s, -0.2 * s)) * CFrame.Angles(math.rad(25), 0, 0))
		longBone(m, shoulder, elbow, 0.18 * s)
		longBone(m, elbow, hand, 0.15 * s)
		for c = -1, 1, 2 do
			local f = hand + V(c * 0.08 * s, -0.12 * s, 0.14 * s)
			shaft(m, hand, f, 0.07 * s)
			claw(m, f, 0.24 * s, 0.1 * s)
		end
	end
end

-- Pelvis: part de les potes, o peça pròpia ("Pelvis")
function theropod.Pelvis(m, sk)
	local s = sk.s
	-- pelvis: ili gran a banda i banda, pubis cap endavant amb "bota"
	for _, sgn in { -1, 1 } do
		ellip(m, "Ilium", V(0.3 * s, 1.2 * s, 2.6 * s), CFrame.new(sgn * 0.62 * s, 0.55 * s, 0))
		ellip(m, "Pubis", V(0.26 * s, 1.5 * s, 0.34 * s), CFrame.new(sgn * 0.36 * s, -0.5 * s, 0.6 * s) * CFrame.Angles(math.rad(-25), 0, 0))
		ellip(m, "Ischium", V(0.22 * s, 1.1 * s, 0.3 * s), CFrame.new(sgn * 0.34 * s, -0.3 * s, -0.8 * s) * CFrame.Angles(math.rad(35), 0, 0))
	end
	ellip(m, "PubicBoot", V(0.9 * s, 0.4 * s, 0.9 * s), CFrame.new(0, -1.2 * s, 0.95 * s))
end

function theropod.HindLimbs(m, sk)
	local s = sk.s
	if not Bones.HasPiece(sk, "Pelvis") then
		theropod.Pelvis(m, sk)
	end
	for _, sgn in { -1, 1 } do
		local hip = V(sgn * 0.85 * s, 0, 0)
		local knee = V(sgn * 1.05 * s, -2.4 * s, 0.9 * s)
		local ankle = V(sgn * 0.95 * s, -4.6 * s, -0.5 * s)
		local foot = V(sgn * 0.95 * s, -5.3 * s, 0.5 * s)
		longBone(m, hip, knee, 0.55 * s)
		longBone(m, knee, ankle, 0.45 * s)
		longBone(m, ankle, foot, 0.3 * s)
		for t = -1, 1 do
			local toe = foot + V(t * 0.32 * s, -0.08 * s, 0.7 * s)
			shaft(m, foot, toe, 0.15 * s)
			claw(m, toe, 0.36 * s, 0.16 * s)
		end
	end
end

function theropod.Tail(m, sk)
	local s = sk.s
	local segs = 14
	local pts = {}
	for i = 0, segs do
		local t = i / segs
		table.insert(pts, V(0, (math.sin(t * 2.2) * 0.4 - t * 0.6) * s, -7 * t * s))
	end
	column(m, pts, 0.62 * s, 0.18 * s, 1)
	-- chevrons (ossets de sota la cua)
	for i = 1, segs - 3 do
		local t = i / segs
		local p = pts[i + 1]
		ellip(m, "Chevron", V(0.12 * s, (0.6 - 0.4 * t) * s, 0.14 * s), CFrame.new(p + V(0, -(0.5 - 0.3 * t) * s, 0)) * CFrame.Angles(math.rad(25), 0, 0))
	end
end

local BUILDERS = { mammal = mammal, bird = bird, theropod = theropod }

-- ────────────────────────── API PUBLICA ──────────────────────────

-- On va cada peça respecte del centre de l'esquelet muntat.
function BoneBuilder.Layout(def: SkeletonDef): { [string]: Vector3 }
	local s = def.s
	if def.kind == "theropod" then
		return {
			Spine = V(0, 0, 0),
			HindLimbs = V(0, -0.3 * s, -1.6 * s),
			ForeLimbs = V(0, -0.9 * s, 2.4 * s),
			Skull = V(0, 2.6 * s, 5.6 * s),
			Tail = V(0, 0.2 * s, -2.4 * s),
		}
	end
	if def.kind == "bird" then
		return {
			Spine = V(0, 0, 0),
			Skull = V(0, 0.62 * s, 0.86 * s),
			ForeLimbs = V(0, 0.1 * s, -0.15 * s),
			HindLimbs = V(0, -0.5 * s, -0.5 * s),
			Tail = V(0, -0.05 * s, -0.95 * s),
		}
	end
	local len = 2.6 * s
	return {
		Spine = V(0, 0, 0),
		Skull = V(0, 0.26 * s, len / 2 + 0.55 * s),
		ForeLimbs = V(0, -0.04 * s, len / 2 - 0.4 * s),
		HindLimbs = V(0, -0.04 * s, -len / 2 + 0.5 * s),
		Tail = V(0, 0.12 * s, -len / 2),
	}
end

-- Les peces de més es construeixen amb les mateixes coordenades que la
-- peça de base de la qual surten: van al mateix lloc.
local EXTRA_AT = { Ribs = "Spine", Neck = "Spine", Pelvis = "HindLimbs", Jaw = "Skull" }
BoneBuilder.EXTRA_AT = EXTRA_AT

-- ─────────────────────────── ESTAT ───────────────────────────
-- Com es veu cada estat (Bones > ESTAT): del més brut al més net. `tint` és
-- el color cap on s'estira l'os i quant; `wobble`, quants graus es torcen
-- les parts (un os esclafat no està ben posat); `shine`, la reflectància.
local DIRT = Color3.fromRGB(139, 111, 71) -- terra #8B6F47
local RUST = Color3.fromRGB(168, 120, 78)
local SAND = Color3.fromRGB(217, 199, 160) -- sorra #D9C7A0
local IVORY = Color3.fromRGB(255, 252, 240)
local LOOKS: { { tint: Color3?, amount: number, wobble: number, shine: number, sparkle: boolean? } } = {
	{ tint = DIRT, amount = 0.6, wobble = 9, shine = 0 }, -- Crushed
	{ tint = RUST, amount = 0.4, wobble = 4, shine = 0 }, -- Cracked
	{ tint = SAND, amount = 0.25, wobble = 0, shine = 0 }, -- Dusty
	{ tint = nil, amount = 0, wobble = 0, shine = 0 }, -- Clean
	{ tint = IVORY, amount = 0.4, wobble = 0, shine = 0.06 }, -- Polished
	{ tint = IVORY, amount = 0.65, wobble = 0, shine = 0.11 }, -- Mint
	{ tint = IVORY, amount = 0.85, wobble = 0, shine = 0.16, sparkle = true }, -- Pristine
}

-- Aplica l'estat a un model ja fet. Determinista (sempre torç igual la
-- mateixa peça): al museu i a la UI es veu idèntic.
function BoneBuilder.Weather(model: Model, grade: number)
	local look = LOOKS[grade]
	if not look then
		return
	end
	local rng = Random.new(#model.Name * 97 + grade)
	local biggest: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Color ~= SOCKET then
				if look.tint then
					d.Color = d.Color:Lerp(look.tint, look.amount)
				end
				d.Reflectance = look.shine
				if look.shine > 0 then
					d.Material = Enum.Material.SmoothPlastic
				end
			end
			if look.wobble > 0 then
				local w = math.rad(look.wobble)
				d.CFrame *= CFrame.Angles(rng:NextNumber(-w, w), rng:NextNumber(-w, w), rng:NextNumber(-w, w))
			end
			if not biggest or d.Size.Magnitude > biggest.Size.Magnitude then
				biggest = d
			end
		end
	end
	if look.sparkle and biggest then
		local sparks = Instance.new("Sparkles")
		sparks.SparkleColor = Color3.fromRGB(255, 200, 250)
		sparks.Parent = biggest
	end
	model:SetAttribute("Grade", grade)
end

-- Una peça sola, amb els atributs que la identifiquen. Amb `grade`, amb
-- l'aspecte del seu estat.
function BoneBuilder.Piece(skeletonId: string, pieceId: string, grade: number?): Model
	local def = Bones.ById[skeletonId]
	assert(def, `[BoneBuilder] esquelet desconegut {skeletonId}`)
	local build = BUILDERS[def.kind][pieceId]
	assert(build, `[BoneBuilder] peça desconeguda {pieceId}`)

	local key = Bones.PieceKey(skeletonId, pieceId)
	local model = Instance.new("Model")
	model.Name = key
	build(model, def)
	model.WorldPivot = CFrame.identity
	model:SetAttribute("Piece", key)
	model:SetAttribute("Rarity", Bones.PieceInfo[key].rarity)
	if grade then
		BoneBuilder.Weather(model, grade)
	end
	return model
end

-- L'esquelet sencer, amb totes les peces al seu lloc i el pivot al centre.
-- Accepta l'id ("Rat") o l'esquelet muntat amb estats ("Rat#34425"): llavors
-- cada peça es veu del seu estat.
function BoneBuilder.Assembled(item: string): Model
	local skeletonId = Bones.BaseOf(item)
	local def = Bones.ById[skeletonId]
	assert(def, `[BoneBuilder] esquelet desconegut {skeletonId}`)
	local grades = if string.find(item, "#", 1, true) then Bones.GradesOf(item) else nil
	local layout = BoneBuilder.Layout(def)
	local model = Instance.new("Model")
	model.Name = skeletonId
	for i, piece in Bones.PiecesOf(skeletonId) do
		local m = BoneBuilder.Piece(skeletonId, piece.id, grades and grades[i])
		m:PivotTo(CFrame.new(layout[piece.id] or layout[EXTRA_AT[piece.id] or ""] or Vector3.zero))
		m.Parent = model
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("Skeleton", skeletonId)
	return model
end

return BoneBuilder
