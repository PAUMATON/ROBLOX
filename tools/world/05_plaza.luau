-- ═══════════════════════════ 05 · PLAÇA MAJOR ═══════════════════════════
-- Plaça de vianants moderna envoltada de pòrtics: font amb un esquelet de
-- T-Rex, terrasses, jardins, garlandes de colors i fanals d'halo.
-- L'única botiga és Dig & Co. (09_toolshop), al racó nord-est.
-- La porta "TO THE MUSEUMS" (ToMuseum) obre el passeig cap als museus.
local F = folder("Plaza", WORLD)
local Q = LAYOUT.PLAZA
local FX, FZ = 20, 11 -- centre de la font
local TOP = 0.65
local BONE_M = M.Marble
local rng = Random.new(66)

-- ── esquelet de T-Rex (mira cap a -Z local) ──
-- Postura de rugit: cua enlaire, cos inclinat, boca oberta. Vèrtebres amb
-- apòfisis, costelles corbes, gastràlia, pelvis amb "bota", potes amb els
-- caps dels ossos i urpes, i un crani arrodonit amb dents i finestres.
local function trex(O, s, parent)
	local m = Instance.new("Model")
	m.Name = "TRexSkeleton"
	local BONE = COL.bone
	local BONE_D = C(214, 200, 170)
	local HOLE = C(52, 46, 40)
	local TOOTH = C(252, 248, 238)
	local function W(x, y, z)
		return (O * CF(x * s, y * s, z * s)).Position
	end
	local function el(size, cf, col, deco)
		return Ellipsoid(size * s, cf, col or BONE, M.Marble, m, deco)
	end
	local function lcf(x, y, z)
		return O * CF(x * s, y * s, z * s)
	end
	-- ─ columna: una corba suau de la punta de la cua fins al cap ─
	local ctrl = {
		V3(0, 5.5, 23), V3(0, 8.5, 17.5), V3(0, 10.8, 12), V3(0, 12.3, 6.5), V3(0, 13, 1.5),
		V3(0, 13, -3.5), V3(0, 12.4, -8), V3(0, 12.6, -11), V3(0, 14.2, -13.2), V3(0, 15.6, -14.6),
	}
	local function catmull(p0, p1, p2, p3, t)
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end
	local pts = {}
	for i = 1, #ctrl - 1 do
		local p0, p1, p2, p3 = ctrl[math.max(i - 1, 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(i + 2, #ctrl)]
		for k = 0, 3 do
			table.insert(pts, catmull(p0, p1, p2, p3, k / 4))
		end
	end
	table.insert(pts, ctrl[#ctrl])
	local n = #pts
	for i, p in ipairs(pts) do
		local t = (i - 1) / (n - 1) -- 0 = punta de la cua, 1 = cap
		-- gruix: prim a la cua, gros al maluc i a l'esquena, mitjà al coll
		local r = if t < 0.45 then 0.25 + 0.75 * (t / 0.45) else (if t < 0.8 then 1 else 1 - (t - 0.8) * 1.2)
		local nxt = pts[math.min(i + 1, n)]
		local prv = pts[math.max(i - 1, 1)]
		local dir = (nxt - prv).Unit
		local wp = W(p.X, p.Y, p.Z)
		local look = CFrame.lookAt(wp, wp + O:VectorToWorldSpace(dir))
		-- cos vertebral, apòfisi espinosa i transverses
		el(V3(r * 1.1, r * 1.1, r * 0.8), look, BONE)
		local spike = if t > 0.35 and t < 0.85 then 0.95 else 0.6
		el(V3(r * 0.3, r * spike * 1.6, r * 0.7), look * CF(0, r * (0.5 + spike * 0.6) * s, 0), BONE)
		if t < 0.85 then
			for sx = -1, 1, 2 do
				el(V3(r * 0.9, r * 0.25, r * 0.4), look * CF(sx * r * 0.65 * s, r * 0.15 * s, 0), BONE_D, true)
			end
		end
		if i > 1 then
			beam(W(prv.X, prv.Y, prv.Z), wp, r * 0.55 * s, BONE_D, M.Marble, m, true)
		end
		-- chevrons sota la cua
		if t > 0.08 and t < 0.42 then
			el(V3(r * 0.25, r * 1.4, r * 0.35), look * CF(0, -r * 1.1 * s, 0) * CFrame.Angles(rad(-25), 0, 0), BONE, true)
		end
	end
	-- ─ costelles corbes i gastràlia ─
	for k = 0, 8 do
		local z = -9.5 + k * 1.15
		local y = 12.4 - math.abs(z + 4) * 0.05
		local len = 1 - math.abs(k - 4) / 9
		for sx = -1, 1, 2 do
			local prev = W(sx * 0.4, y, z)
			for q = 1, 5 do
				local a = q / 5 * math.pi * 0.62
				local nxt = W(sx * (0.4 + math.sin(a) * 3 * len + 0.2), y - (1 - math.cos(a)) * 5.6 * len, z + q * 0.12)
				beam(prev, nxt, (0.34 - q * 0.03) * s, BONE, M.Marble, m, true)
				prev = nxt
			end
		end
	end
	for k = 0, 5 do
		local z = -7.5 + k * 1.3
		local a, b, c = W(-1.7, 7.4, z), W(0, 6.9, z + 0.2), W(1.7, 7.4, z)
		beam(a, b, 0.18 * s, BONE_D, M.Marble, m, true)
		beam(b, c, 0.18 * s, BONE_D, M.Marble, m, true)
	end
	-- ─ pelvis: ili a banda i banda, pubis cap endavant amb bota, isqui enrere ─
	for sx = -1, 1, 2 do
		el(V3(0.4, 2.4, 5), lcf(sx * 1.1, 12.2, 1.5), BONE)
		el(V3(0.35, 3.8, 0.7), lcf(sx * 0.7, 9.6, -0.2) * CFrame.Angles(rad(-28), 0, 0), BONE)
		el(V3(0.3, 3, 0.55), lcf(sx * 0.7, 10.2, 3.4) * CFrame.Angles(rad(35), 0, 0), BONE)
	end
	el(V3(1.8, 0.8, 2.2), lcf(0, 7.9, -1.5), BONE)
	-- ─ potes: fèmur, tíbia i metatarsos amb els caps dels ossos, dits i urpes ─
	local function longBone(a, b, th)
		beam(a, b, th * s, BONE, M.Marble, m)
		local side = (b - a).Unit:Cross(Vector3.yAxis)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.xAxis
		for _, e in ipairs({ a, b }) do
			for sg = -1, 1, 2 do
				Ball(th * 1.3 * s, e + side * sg * th * 0.42 * s, BONE_D, M.Marble, m, true)
			end
		end
	end
	for sx = -1, 1, 2 do
		local hip, knee, ankle, foot = W(sx * 1.9, 11.6, 1.2), W(sx * 2.2, 7, -1.8), W(sx * 2.1, 2.8, 1.2), W(sx * 2.1, 0.8, -0.6)
		longBone(hip, knee, 0.8)
		longBone(knee, ankle, 0.62)
		longBone(ankle, foot, 0.42)
		for t = -1, 1 do
			local toe = W(sx * 2.1 + t * 0.9, 0.45, -2.8 + math.abs(t) * 0.5)
			beam(foot, toe, 0.38 * s, BONE, M.Marble, m)
			local tip = toe + O:VectorToWorldSpace(V3(0, -0.25, -1)) * s
			Ellipsoid(V3(0.36, 0.36, 1.1) * s, CFrame.lookAt(toe, tip) * CF(0, 0, -0.35 * s), BONE_D, M.Marble, m, true)
		end
		beam(foot, W(sx * 2.1, 0.5, 0.6), 0.25 * s, BONE, M.Marble, m, true)
	end
	-- ─ bracets amb dues urpes ─
	for sx = -1, 1, 2 do
		el(V3(0.3, 2.4, 0.8), lcf(sx * 1.3, 11.8, -9.2) * CFrame.Angles(rad(30), 0, 0), BONE)
		local sh, elb, wr = W(sx * 1.35, 10.7, -9.4), W(sx * 1.9, 9.1, -10.2), W(sx * 1.6, 8.5, -11.3)
		longBone(sh, elb, 0.35)
		longBone(elb, wr, 0.28)
		for c = -1, 1, 2 do
			local tip = W(sx * 1.6 + c * 0.2, 7.9, -11.9)
			beam(wr, tip, 0.14 * s, BONE_D, M.Marble, m, true)
		end
	end
	-- ─ crani: gros, arrodonit, amb la boca oberta rugint ─
	local head = lcf(0, 16.2, -16.6) * CFrame.Angles(rad(-8), 0, 0)
	el(V3(2.9, 3.3, 4.4), head, BONE)
	el(V3(2.2, 2.5, 4.6), head * CF(0, -0.15 * s, -3.2 * s) * CFrame.Angles(rad(6), 0, 0), BONE)
	el(V3(1.8, 1.8, 1.5), head * CF(0, -0.4 * s, -5.3 * s), BONE)
	el(V3(2.5, 2, 1.2), head * CF(0, 0.2 * s, 2 * s), BONE)
	for sx = -1, 1, 2 do
		el(V3(0.6, 1.1, 1), head * CF(sx * 1.25 * s, 0.75 * s, -0.4 * s), HOLE, true)
		el(V3(0.6, 0.45, 1.4), head * CF(sx * 1.15 * s, 1.5 * s, -0.4 * s), BONE)
		el(V3(0.35, 0.7, 0.45), head * CF(sx * 1.05 * s, 1.9 * s, -0.2 * s) * CFrame.Angles(rad(-20), 0, 0), BONE)
		el(V3(0.55, 1.2, 1.9), head * CF(sx * 1.05 * s, -0.1 * s, -2.6 * s), HOLE, true)
		el(V3(0.55, 1, 1), head * CF(sx * 1.3 * s, 0.1 * s, 1.1 * s), HOLE, true)
		el(V3(0.35, 0.4, 0.5), head * CF(sx * 0.5 * s, 0 * s, -5.8 * s), HOLE, true)
		-- dents de dalt
		for k = 0, 8 do
			local z = -0.6 - k * 0.6
			local tp = head * CF(sx * 0.8 * s, -1.25 * s, z * s)
			Ellipsoid(V3(0.24, 0.24, 1.1 - math.abs(k - 3) * 0.06) * s, tp * CFrame.Angles(rad(90), 0, 0) * CF(0, 0, 0.3 * s), TOOTH, M.Marble, m, true)
		end
	end
	-- mandíbula oberta (gira des de la part de darrere del crani)
	local jaw = head * CF(0, -1.5 * s, 0.8 * s) * CFrame.Angles(rad(-28), 0, 0)
	el(V3(2.3, 1, 6.6), jaw * CF(0, 0, -3 * s), BONE)
	for sx = -1, 1, 2 do
		for k = 0, 7 do
			local tp = jaw * CF(sx * 0.75 * s, 0.35 * s, (-1.2 - k * 0.62) * s)
			Ellipsoid(V3(0.22, 0.22, 0.9) * s, tp * CFrame.Angles(rad(-90), 0, 0) * CF(0, 0, 0.25 * s), TOOTH, M.Marble, m, true)
		end
	end
	m.Parent = parent
	return m
end

-- ── paleta moderna de la plaça ──
local WHITE = C(242, 240, 234)
local CONC = C(186, 184, 178)
local CONC_D = C(150, 148, 142)
local CHAR = C(58, 60, 64)
local FRAME = C(34, 36, 40)
local WOODC = C(170, 118, 76)
local GLASSC = C(86, 112, 124)
local LED = C(255, 238, 206)

-- ── font amb el T-Rex: vas baix de formigó fosc i sòcol de pedra ──
do
	local m = Instance.new("Model")
	m.Name = "TRexFountain"
	local c = V3(FX, TOP, FZ)
	VCyl(1.6, 46, c + UP * 0.8, CHAR, M.Concrete, m)
	-- vora de formigó: un anell (no un disc, que taparia l'aigua)
	for k = 0, 35 do
		local ang = (k + 0.5) / 36 * math.pi * 2
		local q = c + V3(math.cos(ang) * 23.1, 1.9, math.sin(ang) * 23.1)
		P(V3(1.6, 0.6, 2 * math.pi * 23.9 / 36 + 0.1), CFrame.lookAt(q, V3(c.X, q.Y, c.Z)) * CFrame.Angles(0, math.pi / 2, 0), CONC, M.Concrete, m)
	end
	local w = VCyl(0.14, 44, c + UP * 1.62, C(40, 150, 215), M.SmoothPlastic, m)
	w.Transparency = 0.15
	w.Reflectance = 0.3
	w.CanCollide = false
	-- anell de llum just sota la vora
	VCyl(0.12, 46.4, c + UP * 1.55, LED, M.Neon, m, true)
	-- sòcol de pedra fosca, net, on s'enfila el T-Rex
	P(V3(14, 5.5, 9), CF(c + UP * 4.25), C(74, 76, 80), M.Slate, m)
	P(V3(14.6, 0.35, 9.6), CF(c + UP * 7.1), CONC, M.Concrete, m)
	-- brolladors verticals en anell
	for k = 0, 11 do
		local a = k * math.pi / 6
		local p = c + V3(math.cos(a) * 17, 0, math.sin(a) * 17)
		local j = VCyl(4.5, 0.7, p + UP * 4, C(210, 240, 255), M.SmoothPlastic, m, true)
		j.Transparency = 0.35
		VCyl(0.4, 1.4, p + UP * 1.8, CONC_D, M.Metal, m, true)
		-- esquitxos a dalt del brollador
		local att = Instance.new("Attachment")
		att.Position = V3(2.3, 0, 0) -- (el cilindre té l'eix a la X)
		att.Parent = j
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(C(230, 246, 255), C(160, 214, 245))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(0.6, 0.9)
		pe.Speed = NumberRange.new(4, 6)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.Acceleration = V3(0, -28, 0)
		pe.Rate = 14
		pe.LightEmission = 0.3
		pe.EmissionDirection = Enum.NormalId.Right
		pe.Parent = att
	end
	-- so de l'aigua: només se sent de prop (ProSoundEffects, llicència de Roblox)
	local water = Instance.new("Sound")
	water.Name = "FountainWater"
	water.SoundId = "rbxassetid://9120552550"
	water.Looped = true
	water.Playing = true
	water.Volume = 0.35
	water.RollOffMode = Enum.RollOffMode.InverseTapered
	water.RollOffMinDistance = 14
	water.RollOffMaxDistance = 55
	water.Parent = w
	local plaque = P(V3(12, 1.8, 0.3), CFrame.lookAt(c + V3(0, 1.2, 23.6), c + V3(0, 1.2, 30)), CHAR, M.Metal, m, true)
	Label(plaque, "T-REX · 66 MILLION YEARS AGO", WHITE, Enum.Font.GothamBold)
	trex(CFrame.lookAt(c + UP * 6.8, c + UP * 6.8 + V3(-1, 0, 0.3)), 1.25, m)
	m.Parent = F
end

-- ── porta dels museus (ToMuseum): dos pilons d'acer i una biga amb llum ──
do
	local m = Instance.new("Model")
	m.Name = "MuseumGate"
	local gx, gz = 20, Q.z0 + 6
	for s = -1, 1, 2 do
		local p = V3(gx + s * 12.5, TOP, gz)
		P(V3(3, 20, 3), CF(p + UP * 10), CHAR, M.Concrete, m)
		-- franja de llum a la cara interior
		P(V3(0.2, 16, 0.8), CF(p + UP * 9 - V3(s * 1.55, 0, 0)), LED, M.Neon, m, true)
	end
	P(V3(28, 2.6, 3.4), CF(gx, TOP + 21.3, gz), CHAR, M.Concrete, m)
	local sign = P(V3(22, 2, 0.2), CFrame.lookAt(V3(gx, TOP + 21.3, gz + 1.75), V3(gx, TOP + 21.3, gz + 10)), CHAR, M.SmoothPlastic, m, true)
	Label(sign, "TO THE MUSEUMS", WHITE, Enum.Font.GothamBlack)
	P(V3(24, 0.2, 1), CF(gx, TOP + 19.9, gz + 1.2), LED, M.Neon, m, true)
	local pad = P(V3(12, 0.5, 8), CF(gx, TOP + 0.25, gz), COL.brass, M.Metal, m)
	pad.Name = "MuseumDoor"
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "GoMuseum"
	pr.ActionText = "Go to your museum"
	pr.ObjectText = "Museum"
	pr.HoldDuration = 0.3
	pr.MaxActivationDistance = 12
	pr.Parent = pad
	tag(pad, "ToMuseum")
	m.Parent = F
end

-- ── punt d'aparició: al sud de la font, mirant cap a la porta dels museus ──
do
	local p = V3(FX, TOP + 0.5, Q.z1 - 18)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "CitySpawn"
	sp.Anchored = true
	sp.Size = V3(10, 1, 10)
	sp.CFrame = CFrame.lookAt(p, V3(FX, TOP + 0.5, FZ))
	sp.Color = WHITE
	sp.Material = M.Concrete
	sp.Duration = 0
	sp.Neutral = true
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = F
	local d = sp:FindFirstChildOfClass("Decal")
	if d then
		d:Destroy()
	end
	-- anell de colors damunt la llosa (on apareixes)
	local ring = { C(240, 60, 70), C(255, 150, 40), C(255, 214, 60), C(70, 200, 110), C(50, 170, 240), C(170, 90, 240) }
	for k = 0, 17 do
		local a = (k + 0.5) / 18 * math.pi * 2
		local q = p + V3(math.cos(a) * 4.1, 0.53, math.sin(a) * 4.1)
		P(V3(0.7, 0.06, 1.35), CFrame.lookAt(q, p + UP * 0.53), ring[k % #ring + 1], M.SmoothPlastic, F, true)
	end
end

-- ── jardineria de la plaça: gespa, bardissa retallada, arbres rodons i flors ──
local LAWN_TOP = TOP + 0.35
local HEDGE = C(62, 124, 58)
local LEAF = C(96, 160, 72)
local FLOWER_RINGS = {
	{ C(255, 110, 160), C(255, 214, 70), C(170, 110, 240) },
	{ C(255, 150, 60), C(250, 246, 236), C(240, 70, 90) },
	{ C(120, 200, 255), C(255, 214, 70), C(255, 110, 160) },
}
-- arbre de copa rodona retallada (com els del poble, però de jardí)
local function roundTree(p, h, parent)
	VCyl(h * 0.45, 0.7, p + UP * (h * 0.225), C(120, 88, 60), M.Wood, parent)
	local col = LEAF:Lerp(HEDGE, rng:NextNumber(0, 0.5))
	Ellipsoid(V3(h * 0.5, h * 0.46, h * 0.5), CF(p + UP * (h * 0.66)), col, M.Grass, parent)
	Ellipsoid(V3(h * 0.34, h * 0.3, h * 0.34), CF(p + UP * (h * 0.86) + V3(0.3, 0, -0.2)), col:Lerp(C(255, 255, 255), 0.08), M.Grass, parent)
end
-- bardissa retallada entre dos punts (a terra de la gespa)
local function hedge(a, b, parent)
	local L = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	P(V3(1.5, 1.3, L), cf * CF(0, 0.65, 0), HEDGE, M.Grass, parent)
	Cyl(L, 1.5, cf * CF(0, 1.3, 0) * CFrame.Angles(0, math.pi / 2, 0), HEDGE, M.Grass, parent)
end
-- parterre rodó de flors per anells de colors, amb vorada de pedra
local function flowerBed(p, r, parent, palette)
	local cols = palette or FLOWER_RINGS[rng:NextInteger(1, #FLOWER_RINGS)]
	VCyl(0.5, r * 2 + 1, p + UP * 0.25, CONC, M.Concrete, parent)
	VCyl(0.5, r * 2, p + UP * 0.3, C(84, 64, 44), M.Ground, parent, true)
	for k, col in ipairs(cols) do
		local rr = r * (1 - (k - 1) * 0.3)
		VCyl(0.3 + k * 0.12, rr * 2 - 0.4, p + UP * (0.55 + k * 0.06), col, M.Grass, parent, true)
	end
	-- flors soltes a la vora exterior
	for k = 0, math.floor(r * 3) do
		local a = k / math.floor(r * 3 + 1) * math.pi * 2
		Ball(0.6, p + V3(math.cos(a) * (r - 0.4), 1.05, math.sin(a) * (r - 0.4)), cols[1]:Lerp(C(255, 255, 255), 0.25), M.SmoothPlastic, parent, true)
	end
end
-- gespa baixa amb vorada de formigó, bardissa a les vores (amb portes al mig
-- de cada costat) i un arbre rodó a cada cantó
local function lawn(x0, x1, z0, z1, parent)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	P(V3(x1 - x0, 0.3, z1 - z0), CF(cx, TOP + 0.15, cz), CONC, M.Concrete, parent)
	P(V3(x1 - x0 - 1.2, 0.1, z1 - z0 - 1.2), CF(cx, TOP + 0.3, cz), C(112, 172, 82), M.Grass, parent)
	local y = LAWN_TOP
	local gap = 5
	local i0, i1, j0, j1 = x0 + 1.6, x1 - 1.6, z0 + 1.6, z1 - 1.6
	for _, e in ipairs({
		{ V3(i0, y, j0), V3(cx - gap, y, j0) }, { V3(cx + gap, y, j0), V3(i1, y, j0) },
		{ V3(i0, y, j1), V3(cx - gap, y, j1) }, { V3(cx + gap, y, j1), V3(i1, y, j1) },
		{ V3(i0, y, j0), V3(i0, y, cz - gap) }, { V3(i0, y, cz + gap), V3(i0, y, j1) },
		{ V3(i1, y, j0), V3(i1, y, cz - gap) }, { V3(i1, y, cz + gap), V3(i1, y, j1) },
	}) do
		hedge(e[1], e[2], parent)
	end
	for _, q in ipairs({ { i0 + 3, j0 + 3 }, { i1 - 3, j0 + 3 }, { i0 + 3, j1 - 3 }, { i1 - 3, j1 - 3 } }) do
		roundTree(V3(q[1], y, q[2]), rng:NextNumber(11, 13), parent)
	end
	-- camí de grava en creu fins al centre
	P(V3(x1 - x0 - 3.2, 0.06, 3), CF(cx, TOP + 0.37, cz), C(222, 206, 172), M.Slate, parent, true)
	P(V3(3, 0.06, z1 - z0 - 3.2), CF(cx, TOP + 0.37, cz), C(222, 206, 172), M.Slate, parent, true)
end
-- dinosaure de bardissa (braquiosaure), amb flors per sobre
local function topiary(p, facing, parent)
	local m = Instance.new("Model")
	m.Name = "DinoTopiary"
	local O = CFrame.lookAt(p, p + facing)
	local function blob(size, x, y, z, rot)
		local cf = O * CF(x, y, z)
		if rot then
			cf = cf * rot
		end
		return Ellipsoid(size, cf, HEDGE:Lerp(LEAF, 0.35), M.Grass, m)
	end
	blob(V3(6, 5, 9), 0, 5.4, 0)
	for _, q in ipairs({ { 1.9, -2.6 }, { -1.9, -2.6 }, { 1.9, 2.8 }, { -1.9, 2.8 } }) do
		blob(V3(1.9, 5, 1.9), q[1], 2.4, q[2])
	end
	-- coll llarg que puja cap endavant i el cap
	local prev = V3(0, 6.5, -3.5)
	for k = 1, 6 do
		local pt = V3(0, 6.5 + k * 1.55, -3.5 - k * 0.75)
		blob(V3(2.2 - k * 0.12, 2.4, 2.2 - k * 0.12), pt.X, pt.Y, pt.Z)
		prev = pt
	end
	blob(V3(1.9, 1.6, 3), prev.X, prev.Y + 0.9, prev.Z - 1.2)
	for sx = -1, 1, 2 do
		Ball(0.45, (O * CF(sx * 0.8, prev.Y + 1.3, prev.Z - 1.6)).Position, C(40, 36, 34), M.SmoothPlastic, m, true)
	end
	-- cua que baixa
	for k = 1, 6 do
		blob(V3(2.2 - k * 0.28, 1.8 - k * 0.18, 2.4), 0, 5.2 - k * 0.55, 4 + k * 1.6)
	end
	-- flors damunt de l'esquena
	for k = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local fp = O * CF(math.cos(a) * 2.2, 7.4 + rng:NextNumber(-0.4, 0.4), math.sin(a) * 3.6)
		Ball(0.55, fp.Position, FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, m, true)
	end
	m.Parent = parent
	return m
end

-- ── mobiliari ──
-- banc i fanals: els de la lib (mobiliari modern comú a tot el món)
local function bench(p, facing, parent)
	return modernBench(p, facing, parent or F)
end
-- fanal d'halo: pal prim i un anell de llum a dalt
local function haloLamp(p)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	P(V3(1.4, 0.4, 1.4), CF(p + UP * 0.2), CONC_D, M.Concrete, m)
	P(V3(0.55, 14, 0.55), CF(p + UP * 7), FRAME, M.Metal, m)
	local ring = VCyl(0.35, 4.2, p + UP * 14.2, FRAME, M.Metal, m, true)
	ring.CastShadow = false
	local glow = VCyl(0.15, 3.8, p + UP * 13.95, LED, M.Neon, m, true)
	local pl = Instance.new("PointLight")
	pl.Range = 24
	pl.Brightness = 1
	pl.Color = C(255, 232, 196)
	pl.Parent = glow
	m.Parent = F
end
-- plàtan en escocell
local function planeTree(p, h)
	local m = Instance.new("Model")
	m.Name = "PlaneTree"
	P(V3(4.4, 0.25, 4.4), CF(p + UP * 0.08), CHAR, M.Metal, m, true)
	VCyl(h * 0.55, 1.5, p + UP * (h * 0.275), C(150, 140, 118), M.Wood, m)
	local col = COL.leaf:Lerp(COL.leafDark, rng:NextNumber(0.2, 0.7))
	Ellipsoid(V3(h * 0.8, h * 0.5, h * 0.8), CF(p + UP * (h * 0.72)), col, M.SmoothPlastic, m)
	Ellipsoid(V3(h * 0.55, h * 0.4, h * 0.55), CF(p + UP * (h * 0.9) + V3(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))), col:Lerp(C(255, 255, 255), 0.07), M.SmoothPlastic, m)
	Ellipsoid(V3(h * 0.5, h * 0.36, h * 0.5), CF(p + UP * (h * 0.66) + V3(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))), col:Lerp(C(0, 0, 0), 0.08), M.SmoothPlastic, m)
	m.Parent = F
end

-- anella de bancs i quatre fanals al voltant de la font
for k = 0, 3 do
	local a = k * math.pi / 2 + math.pi / 4
	local p = V3(FX + math.cos(a) * 31, TOP, FZ + math.sin(a) * 31)
	bench(p, (V3(FX, TOP, FZ) - p).Unit)
end
for k = 0, 3 do
	local a = k * math.pi / 2 + math.pi / 4
	haloLamp(V3(FX + math.cos(a) * 38, TOP, FZ + math.sin(a) * 38))
end
-- plàtans davant dels pòrtics
for _, x in ipairs({ -44, -18, 58, 84 }) do
	planeTree(V3(x, TOP, Q.z0 + 12), 16)
	planeTree(V3(x, TOP, Q.z1 - 12), 16)
end
for _, z in ipairs({ -30, 50 }) do
	planeTree(V3(Q.x1 - 12, TOP, z), 16)
end

-- ── terrasses (quadrant sud-est): taula rodona i para-sol quadrat ──
local function cafeTable(p, canopy)
	local m = Instance.new("Model")
	m.Name = "CafeTable"
	VCyl(2.9, 0.35, p + UP * 1.45, FRAME, M.Metal, m)
	VCyl(0.25, 3.4, p + UP * 3.05, WHITE, M.SmoothPlastic, m)
	for k = 0, 3 do
		local a2 = k * math.pi / 2 + 0.4
		local cp = p + V3(math.cos(a2) * 2.8, 0, math.sin(a2) * 2.8)
		local O = CFrame.lookAt(cp, p)
		P(V3(1.8, 0.3, 1.8), O * CF(0, 1.8, 0), WOODC, M.WoodPlanks, m)
		P(V3(1.8, 1.6, 0.25), O * CF(0, 2.7, 0.8), FRAME, M.Metal, m, true)
		for _, lq in ipairs({ { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 }, { -0.7, -0.7 } }) do
			P(V3(0.15, 1.7, 0.15), O * CF(lq[1], 0.85, lq[2]), FRAME, M.Metal, m, true)
		end
	end
	VCyl(7.6, 0.25, p + UP * 3.8, FRAME, M.Metal, m, true)
	P(V3(7.6, 0.25, 7.6), CF(p + UP * 7.7), canopy, M.Fabric, m, true).CastShadow = true
	m.Parent = F
end
local canopies = { WHITE, C(222, 214, 200) }
do
	local m = Instance.new("Model")
	m.Name = "CafeLawn"
	lawn(48, 104, 30, 70, m)
	P(V3(28, 0.5, 26), CF(75, TOP + 0.25, 51), WOODC, M.WoodPlanks, m)
	for k = 0, 12 do
		P(V3(0.2, 0.52, 26), CF(62 + k * 2.2, TOP + 0.26, 51), C(150, 104, 66), M.WoodPlanks, m, true)
	end
	-- garlanda de bombetes sobre la terrassa
	for _, row in ipairs({ 42, 60 }) do
		for k = 0, 12 do
			local b = Ball(0.4, V3(62 + k * 2.2, TOP + 8.6 - math.sin(k / 12 * math.pi) * 0.8, row), C(255, 226, 160), M.Neon, m, true)
			if k % 6 == 3 then
				local pl = Instance.new("PointLight")
				pl.Range = 12
				pl.Brightness = 0.6
				pl.Color = C(255, 220, 160)
				pl.Parent = b
			end
		end
	end
	m.Parent = F
end
local nc = 0
for _, x in ipairs({ 68, 82 }) do
	for _, z in ipairs({ 44, 58 }) do
		nc += 1
		cafeTable(V3(x, TOP + 0.5, z), canopies[nc % 2 + 1])
	end
end
-- ── jardí (quadrant sud-oest): el triceratops de bronze sobre un parterre de flors ──
do
	local m = Instance.new("Model")
	m.Name = "Garden"
	local g = V3(-36, TOP, 50)
	lawn(-64, -8, 30, 70, m)
	flowerBed(g + UP * 0.35, 9, m, FLOWER_RINGS[1])
	-- triceratops de bronze sobre un sòcol, mirant la font
	local tc = CFrame.lookAt(g + UP * 0.35, g + UP * 0.35 + V3(1, 0, -1))
	P(V3(6, 2.4, 9), tc * CF(0, 1.2, 0), CHAR, M.Concrete, m)
	P(V3(6.4, 0.25, 9.4), tc * CF(0, 2.45, 0), C(96, 98, 102), M.Concrete, m)
	local plaque = P(V3(4, 0.8, 0.1), tc * CF(0, 1.3, -4.55), CHAR, M.Metal, m, true)
	Label(plaque, "TRICERATOPS", COL.brass, Enum.Font.GothamBlack)
	local BR = C(122, 90, 56)
	local BRL = C(170, 128, 76)
	local y0 = 2.55
	-- cos i panxa
	Ellipsoid(V3(3.8, 3.2, 6), tc * CF(0, y0 + 3.1, 0.6), BR, M.Metal, m)
	Ellipsoid(V3(3.4, 2.2, 4.6), tc * CF(0, y0 + 2.4, 0.9), BRL, M.Metal, m)
	-- potes gruixudes amb peus
	for _, q in ipairs({ { 1.3, -1.4 }, { -1.3, -1.4 }, { 1.4, 2.4 }, { -1.4, 2.4 } }) do
		local lp = tc * CF(q[1], y0, q[2])
		Cyl(2.4, 1.1, lp * CF(0, 1.2, 0) * UPRIGHT, BR, M.Metal, m)
		Ellipsoid(V3(1.4, 0.6, 1.6), lp * CF(0, 0.3, -0.2), BR, M.Metal, m)
	end
	-- cua
	Ellipsoid(V3(1.3, 1.2, 4), tc * CF(0, y0 + 2.6, 4.6) * CFrame.Angles(rad(-18), 0, 0), BR, M.Metal, m)
	-- cap, bec i la gran golla amb punxes
	local head = tc * CF(0, y0 + 3, -3.2)
	Ellipsoid(V3(2.4, 2.2, 2.8), head, BR, M.Metal, m)
	Ellipsoid(V3(1.3, 1.3, 1.8), head * CF(0, -0.4, -1.6) * CFrame.Angles(rad(-20), 0, 0), BRL, M.Metal, m)
	local frill = head * CF(0, 1.3, 1.1) * CFrame.Angles(rad(-30), 0, 0)
	Ellipsoid(V3(4.6, 3.6, 0.5), frill, BR, M.Metal, m)
	for k = 0, 6 do
		local a = rad(-90 + k * 30)
		local sp = frill * CF(math.sin(a) * 2.2, math.cos(a) * 1.7, 0)
		Ellipsoid(V3(0.45, 0.8, 0.35), sp * CFrame.Angles(0, 0, -a), BRL, M.Metal, m)
	end
	-- les tres banyes: dues de grosses sobre els ulls i una al nas
	for s = -1, 1, 2 do
		local hb = head * CF(s * 0.6, 0.8, -0.8)
		Ellipsoid(V3(0.35, 0.35, 2.6), hb * CFrame.Angles(rad(28), rad(s * -8), 0) * CF(0, 0, -1.1), COL.bone, M.Marble, m)
		Ellipsoid(V3(0.35, 0.45, 0.35), head * CF(s * 0.75, 0.35, -0.7), C(30, 26, 22), M.SmoothPlastic, m, true)
	end
	Ellipsoid(V3(0.3, 0.9, 0.3), head * CF(0, 0.3, -2.1) * CFrame.Angles(rad(-15), 0, 0), COL.bone, M.Marble, m)
	bench(g + V3(-14, 0.35, 0), V3(1, 0, 0), m)
	bench(g + V3(14, 0.35, 0), V3(-1, 0, 0), m)
	m.Parent = F
end

-- ═════════ MÉS VIDA A LA PLAÇA ═════════
-- jardineres llargues d'acer amb flors (on abans hi havia els carretons)
local function steelPlanter(p, yaw)
	local m = Instance.new("Model")
	m.Name = "SteelPlanter"
	local cf = CF(p) * CFrame.Angles(0, yaw, 0)
	P(V3(8, 1.8, 2.8), cf * CF(0, 0.9, 0), CHAR, M.Metal, m)
	P(V3(7.4, 0.2, 2.2), cf * CF(0, 1.75, 0), C(84, 66, 46), M.Ground, m, true)
	local r3 = Random.new(math.floor(p.X * 3 + p.Z))
	for k = 0, 7 do
		local bp = (cf * CF(-3 + k * 0.85, 2.2, r3:NextNumber(-0.6, 0.6))).Position
		if k % 3 == 0 then
			Ellipsoid(V3(1.4, 1.6, 1.4), CF(bp), COL.leafDark, M.Grass, m)
		else
			Ball(0.9, bp + UP * 0.2, FLOWERS[r3:NextInteger(1, #FLOWERS)], M.SmoothPlastic, m, true)
		end
	end
	m.Parent = F
end

-- rètol del joc a la vora sud: lletres grosses sobre un sòcol baix
do
	local m = Instance.new("Model")
	m.Name = "TitleSign"
	local p = V3(FX, TOP, Q.z1 - 6)
	P(V3(28, 1, 3.4), CF(p + UP * 0.5), CONC, M.Concrete, m)
	local s = P(V3(26, 3.6, 0.8), CF(p + UP * 2.8), CHAR, M.SmoothPlastic, m)
	local front = P(V3(25, 3, 0.2), CFrame.lookAt(p + UP * 2.8 - V3(0, 0, 0.5), p + UP * 2.8 - V3(0, 0, 5)), CHAR, M.SmoothPlastic, m, true)
	Label(front, "FOSSIL MUSEUM", C(255, 206, 110), Enum.Font.GothamBlack)
	local back = P(V3(25, 3, 0.2), CFrame.lookAt(p + UP * 2.8 + V3(0, 0, 0.5), p + UP * 2.8 + V3(0, 0, 5)), CHAR, M.SmoothPlastic, m, true)
	Label(back, "FOSSIL MUSEUM", C(255, 206, 110), Enum.Font.GothamBlack)
	P(V3(26, 0.12, 0.3), CF(p + UP * 1.05 - V3(0, 0, 1.4)), LED, M.Neon, m, true)
	s.CastShadow = true
	m.Parent = F
end

-- ═════════ COLOR I VIDA (sense botigues: l'única és Dig & Co.) ═════════
-- anell de color continu al voltant de la font
do
	local m = Instance.new("Model")
	m.Name = "FountainRing"
	Cyl(0.1, 60, CF(FX, TOP + 0.1, FZ) * UPRIGHT, COL.terracotta, M.Slate, m, true)
	Cyl(0.1, 55, CF(FX, TOP + 0.13, FZ) * UPRIGHT, C(238, 228, 206), M.Slate, m, true)
	Cyl(0.1, 51, CF(FX, TOP + 0.16, FZ) * UPRIGHT, C(96, 170, 160), M.Slate, m, true)
	Cyl(0.1, 49.5, CF(FX, TOP + 0.19, FZ) * UPRIGHT, C(238, 228, 206), M.Slate, m, true)
	m.Parent = F
end

-- garlandes de banderetes de colors entre els quatre fanals d'halo
do
	local m = Instance.new("Model")
	m.Name = "Bunting"
	local FLAGS = { C(240, 60, 70), C(255, 150, 40), C(255, 214, 60), C(70, 200, 110), C(50, 170, 240), C(170, 90, 240), C(255, 90, 180) }
	local tops = {}
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		table.insert(tops, V3(FX + math.cos(a) * 38, TOP + 13.6, FZ + math.sin(a) * 38))
	end
	local nf = 0
	for k = 1, 4 do
		local a, b = tops[k], tops[k % 4 + 1]
		local segs = 10
		local prev = a
		for q = 1, segs do
			local t = q / segs
			local p = a:Lerp(b, t) - UP * (math.sin(t * math.pi) * 3.2)
			beam(prev, p, 0.08, C(250, 250, 250), M.Fabric, m, true)
			prev = p
		end
		local L = (b - a).Magnitude
		local count = math.floor(L / 1.7)
		for q = 1, count - 1 do
			local t = q / count
			local p = a:Lerp(b, t) - UP * (math.sin(t * math.pi) * 3.2)
			nf += 1
			local dir = (b - a).Unit
			local cf = CFrame.lookAt(p, p + dir:Cross(UP)) * CF(0, -0.55, 0)
			Wd(V3(0.05, 1, 0.9), cf * CFrame.Angles(0, math.pi / 2, math.pi) * WEDGE_FIX, FLAGS[nf % #FLAGS + 1], M.Fabric, m, true)
		end
	end
	m.Parent = F
end

-- jardí del nord-oest: un braquiosaure de bardissa sobre un parterre de flors
do
	local m = Instance.new("Model")
	m.Name = "TopiaryGarden"
	lawn(-64, -8, -46, -8, m)
	local c = V3(-36, LAWN_TOP, -27)
	flowerBed(c, 10.5, m, FLOWER_RINGS[3])
	topiary(c + UP * 0.8, (V3(FX, 0, FZ) - V3(c.X, 0, c.Z)).Unit, m)
	bench(V3(-36, LAWN_TOP, -12.5), V3(0, 0, -1), m)
	bench(V3(-52, LAWN_TOP, -27), V3(1, 0, 0), m)
	m.Parent = F
end

print("Plaça Major: T-Rex nou, font, porta, garlandes, terrasses i jardins amb bardissa, flors i un braquiosaure")
