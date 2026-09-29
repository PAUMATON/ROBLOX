--[[ ═══════════════════════════════════════════════════════════════════════
     MUSEU DE FÒSSILS · constructor del món · biblioteca comuna
     S'afegeix al principi de cada mòdul (tools/world/run.py ho fa sol).

     Escala (CLAUDE.md): el jugador fa 5 studs. Terra a Y = 0.
     Eixos: X = est, Z = sud. La "cara" de tot edifici és la -Z local
     (LookVector), com els personatges de Roblox.
     ═══════════════════════════════════════════════════════════════════════ ]]
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local C = Color3.fromRGB
local M = Enum.Material
local V3 = Vector3.new
local CF = CFrame.new
local rad = math.rad
local UP = V3(0, 1, 0)

-- ─────────────────────── PALETA (CLAUDE.md + tons de la mateixa família) ───────────────────────
local COL = {
	sand = C(217, 199, 160), -- #D9C7A0
	earth = C(139, 111, 71), -- #8B6F47
	rock = C(110, 106, 99), -- #6E6A63
	bone = C(237, 227, 204), -- #EDE3CC
	brass = C(192, 138, 62), -- #C08A3E
	green = C(47, 74, 60), -- #2F4A3C
	uiBg = C(47, 42, 36), -- #2F2A24
	-- derivats
	cream = C(245, 238, 222),
	boneDark = C(214, 202, 176),
	greenMid = C(74, 110, 88),
	greenLight = C(120, 150, 118),
	brick = C(170, 90, 56),
	terracotta = C(188, 104, 70),
	slate = C(72, 76, 84),
	wood = C(146, 102, 64),
	woodDark = C(96, 66, 44),
	glass = C(118, 150, 162),
	asphalt = C(64, 66, 70),
	pave = C(206, 199, 184),
	paveDark = C(182, 174, 158),
	iron = C(40, 44, 42),
	leaf = C(98, 138, 72),
	leafDark = C(70, 110, 60),
	water = C(90, 160, 176),
}
-- arrebossats de les cases (tots càlids, cap de "caramel")
local PLASTERS = {
	C(242, 234, 214), C(237, 227, 204), C(226, 208, 170), C(232, 198, 160),
	C(214, 168, 136), C(190, 202, 172), C(224, 190, 172), C(236, 216, 180),
}
local SHUTTERS = { COL.green, COL.greenMid, COL.wood, C(92, 120, 128), COL.brick }
local ROOFS = { COL.terracotta, C(170, 88, 60), COL.slate, C(88, 84, 80) }
local FLOWERS = { C(214, 60, 70), C(236, 120, 150), C(242, 196, 70), C(250, 246, 236), C(150, 100, 190), C(236, 130, 60) }

-- ─────────────────────── CARPETES ───────────────────────
local function folder(name, parent)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local WORLD = folder("World", Workspace)
local ZONES = folder("Zones", Workspace)
local MUSEUMS = folder("Museums", Workspace)

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

-- ─────────────────────── PECES ───────────────────────
-- P: peça ancorada. deco = true → sense col·lisió ni ombra (detalls petits)
local function P(size, cf, color, mat, parent, deco, cls)
	local p = Instance.new(cls or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	if deco then
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end
local function Wd(size, cf, color, mat, parent, deco)
	return P(size, cf, color, mat, parent, deco, "WedgePart")
end
-- cilindre amb l'eix a la X local de cf
local function Cyl(len, dia, cf, color, mat, parent, deco)
	local p = P(V3(len, dia, dia), cf, color, mat, parent, deco)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local UPRIGHT = CFrame.Angles(0, 0, rad(90))
-- cilindre vertical centrat a pos
local function VCyl(h, dia, pos, color, mat, parent, deco)
	return Cyl(h, dia, CF(pos) * UPRIGHT, color, mat, parent, deco)
end
local function Ball(dia, pos, color, mat, parent, deco)
	local p = P(V3(dia, dia, dia), CF(pos), color, mat, parent, deco)
	p.Shape = Enum.PartType.Ball
	return p
end
-- panell pla que mira cap a n (la cara Front del panell queda cap a n)
local function panel(size, pos, n, color, mat, parent, deco)
	return P(size, CFrame.lookAt(pos, pos + n), color, mat, parent, deco)
end
-- barra entre dos punts (secció quadrada th)
local function beam(a, b, th, color, mat, parent, deco)
	local L = (b - a).Magnitude
	return P(V3(th, th, L), CFrame.lookAt((a + b) / 2, b), color, mat, parent, deco)
end

-- text sobre una peça (SurfaceGui a la cara Front)
local function Label(part, text, color, font, face, ppu)
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppu or 50
	g.LightInfluence = 0.4
	g.MaxDistance = 300
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Font = font or Enum.Font.FredokaOne
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = t
	t.Parent = g
	g.Parent = part
	return t
end

-- ─────────────────────── GEOMETRIA DE LES CUNYES (es mesura, no se suposa) ───────────────────────
local function probeHeight(cls, x, z)
	local p = Instance.new(cls)
	p.Anchored = true
	p.Size = V3(4, 4, 4)
	p.CFrame = CF(0, 30000, 0)
	p.Parent = Workspace
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { p }
	local r = Workspace:Raycast(V3(x, 30010, z), V3(0, -20, 0), rp)
	p:Destroy()
	return r and (r.Position.Y - 30000) or -9
end
-- WedgePart: volem la vora alta a +Z local
local WEDGE_FIX = CFrame.identity
if probeHeight("WedgePart", 0, 1.5) < probeHeight("WedgePart", 0, -1.5) then
	WEDGE_FIX = CFrame.Angles(0, math.pi, 0)
end
-- CornerWedgePart: a quina cantonada (local) hi ha l'àpex
local CW_SX, CW_SZ, bestH = 1, -1, -99
for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
	local h = probeHeight("CornerWedgePart", q[1] * 1.5, q[2] * 1.5)
	if h > bestH then
		CW_SX, CW_SZ, bestH = q[1], q[2], h
	end
end
-- rotació que porta l'àpex cap a la direcció (dx, dz)
local function cwRot(dx, dz)
	for k = 0, 3 do
		local r = CFrame.Angles(0, k * math.pi / 2, 0)
		if (r:VectorToWorldSpace(V3(CW_SX, 0, CW_SZ)) - V3(dx, 0, dz)).Magnitude < 0.1 then
			return r
		end
	end
	return CFrame.identity
end
-- cunya de cantonada: cf = centre de la peça; l'àpex mira cap a (dx, dz)
local function Corner(cf, sx, h, sz, dx, dz, color, mat, parent)
	local r = cwRot(dx, dz)
	local size = V3(sx, h, sz)
	if math.abs(r.LookVector.X) > 0.5 then
		size = V3(sz, h, sx) -- girat 90°: s'intercanvien X i Z
	end
	return P(size, cf * r, color, mat, parent, false, "CornerWedgePart")
end
-- piràmide quadrada (cf = centre de la base)
local function Pyramid(cf, base, h, color, mat, parent, colors)
	local q = 0
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			q += 1
			local col = colors and colors[(q - 1) % #colors + 1] or color
			Corner(cf * CF(sx * base / 4, h / 2, sz * base / 4), base / 2, h, base / 2, -sx, -sz, col, mat, parent)
		end
	end
end

-- ─────────────────────── TEULADES ───────────────────────
-- Teulada a quatre aigües massissa. cf = centre de la planta a l'alçada de
-- la base de la teulada; L sobre X, Wz sobre Z. Retorna l'alçada.
local function hipRoof(cf, L, Wz, pitch, over, color, mat, trim, parent)
	if L < Wz then
		cf = cf * CFrame.Angles(0, math.pi / 2, 0)
		L, Wz = Wz, L
	end
	local Lx, Wx = L + 2 * over, Wz + 2 * over
	local h = (Wx / 2) * math.tan(pitch)
	local mid = Lx - Wx
	if mid > 0.05 then
		Wd(V3(mid, h, Wx / 2), cf * CF(0, h / 2, -Wx / 4) * WEDGE_FIX, color, mat, parent)
		Wd(V3(mid, h, Wx / 2), cf * CF(0, h / 2, Wx / 4) * CFrame.Angles(0, math.pi, 0) * WEDGE_FIX, color, mat, parent)
	end
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			Corner(cf * CF(sx * (math.max(mid, 0) / 2 + Wx / 4), h / 2, sz * Wx / 4), Wx / 2, h, Wx / 2, -sx, -sz, color, mat, parent)
		end
	end
	if trim then
		for s = -1, 1, 2 do
			P(V3(Lx + 0.2, 0.9, 0.8), cf * CF(0, -0.25, s * (Wx / 2 - 0.3)), trim, M.SmoothPlastic, parent, true)
			P(V3(0.8, 0.9, Wx + 0.2), cf * CF(s * (Lx / 2 - 0.3), -0.25, 0), trim, M.SmoothPlastic, parent, true)
		end
	end
	return h
end

-- Teulada a dues aigües amb volum de golfa del color de la façana, lloses
-- amb ràfec, carener i vores (barge boards). cf: X = carener, Sp = amplada.
local function gableRoof(cf, L, Sp, pitch, eave, gov, roofC, roofMat, gableC, gableMat, trim, parent)
	local t = 1.2
	local h = (Sp / 2) * math.tan(pitch)
	Wd(V3(L, h, Sp / 2), cf * CF(0, h / 2, -Sp / 4) * WEDGE_FIX, gableC, gableMat, parent)
	Wd(V3(L, h, Sp / 2), cf * CF(0, h / 2, Sp / 4) * CFrame.Angles(0, math.pi, 0) * WEDGE_FIX, gableC, gableMat, parent)
	local cp, sp = math.cos(pitch), math.sin(pitch)
	local e = t * 0.9
	local len = (Sp / 2 + eave) / cp + e
	local sc = ((Sp / 2 + eave) / cp - e) / 2
	for side = -1, 1, 2 do
		local y = h - sc * sp + (t / 2) * cp
		local z = side * (sc * cp + (t / 2) * sp)
		local rot = CFrame.Angles(side * pitch, 0, 0)
		P(V3(L + 2 * gov, t, len), cf * CF(0, y, z) * rot, roofC, roofMat, parent)
		if trim then
			for gx = -1, 1, 2 do
				P(V3(0.7, t + 0.5, len), cf * CF(gx * (L / 2 + gov - 0.2), y - 0.2, z) * rot, trim, M.SmoothPlastic, parent, true)
			end
		end
	end
	-- el carener passa 0,05 per fora de les vores: si acabés al mateix pla
	-- (+0,3 → L/2+gov+0,15, com la cara de fora de la vora) les dues cares
	-- es barallarien i farien pampallugues
	P(V3(L + 2 * gov + 0.4, t, t * 1.8), cf * CF(0, h + t / cp - 0.1, 0), roofC:Lerp(C(0, 0, 0), 0.15), roofMat, parent)
	return h
end

-- ─────────────────────── FORMES EXTRA ───────────────────────
-- el·lipsoide (esfera deformada): capçades d'arbre, cúpules, arbustos
local function Ellipsoid(size, cf, color, mat, parent, deco)
	local p = P(size, cf, color, mat, parent, deco)
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	return p
end
-- anella d'arc (dovelles) en el pla XY local de cf; cf al centre de la línia d'imposta
local function ArchRing(cf, radius, band, depth, color, mat, parent, segs)
	segs = segs or 7
	for k = 0, segs - 1 do
		local a0 = math.pi * k / segs
		local a1 = math.pi * (k + 1) / segs
		local am = (a0 + a1) / 2
		local len = 2 * (radius + band / 2) * math.sin((a1 - a0) / 2) + 0.15
		local c = cf * CF(math.cos(am) * (radius + band / 2), math.sin(am) * (radius + band / 2), 0) * CFrame.Angles(0, 0, am + math.pi / 2)
		P(V3(len, band, depth), c, color, mat, parent, true)
	end
end
-- finestra amb arc de mig punt sobre una paret (cara cap a n)
local function ArchWindow(pos, n, w, h, frame, glass, parent)
	local base = CFrame.lookAt(pos, pos + n)
	P(V3(w + 1, h + 0.6, 0.3), base * CF(0, -0.3, -0.12), frame, M.SmoothPlastic, parent, true)
	local g = P(V3(w, h, 0.25), base * CF(0, 0, -0.25), glass, M.SmoothPlastic, parent, true)
	g.Reflectance = 0.25
	local top = base * CF(0, h / 2, -0.25) * CFrame.Angles(0, rad(90), 0)
	Cyl(0.25, w, top, glass, M.SmoothPlastic, parent, true).Reflectance = 0.25
	ArchRing(base * CF(0, h / 2, -0.2), w / 2, 0.8, 0.35, frame, M.SmoothPlastic, parent, 7)
	P(V3(0.25, h + w / 2 - 0.3, 0.2), base * CF(0, w / 4, -0.4), frame, M.SmoothPlastic, parent, true)
end

-- ─────────────────────── PLÀNOL DEL MÓN (compartit per tots els mòduls) ───────────────────────
-- Els museus estan repartits per la ciutat; la plaça major és de vianants
-- amb porxos, i un passeig la uneix amb el Gran Museu al nord.
local LAYOUT = {
	LAND = { x0 = -340, x1 = 166, z0 = -270, z1 = 270 },
	PROM = { x0 = 166, x1 = 186 }, -- passeig marítim
	BEACH_FLAT_X1 = 236,
	-- carrers: {x0, z0, x1, z1, amplada}
	ROADS = {
		{ -340, -190, 166, -190, 24 }, -- RA (nord)
		{ -340, -110, 166, -110, 24 }, -- RB
		{ -190, -44, 166, -44, 24 }, -- R1
		{ -340, 66, 166, 66, 24 }, -- R2
		{ -340, 160, 166, 160, 24 }, -- R3
		{ -190, -270, -190, 270, 24 }, -- R6 (costat de l'obra)
		{ -60, -202, -60, 270, 24 }, -- R4
		{ 100, -202, 100, 270, 24 }, -- R5
	},
	-- plaça major de vianants: els trams de carrer que hi entren són plaça
	PLAZA = { x0 = -72, x1 = 112, z0 = -56, z1 = 78 },
	PLAZA_CORE = { x0 = -48, x1 = 88, z0 = -32, z1 = 54 },
	-- passeig de vianants de la plaça al Gran Museu
	PASSEIG = { x0 = 5, x1 = 35, z0 = -202, z1 = -56 },
	-- Zona 1 · 60x60, amb l'entrada al sud (al camí de vianants) i cases al
	-- voltant (també a l'est, entre la tanca i el carrer: EAST_LOTS).
	OBRA = { x0 = -298, x1 = -238, z0 = -68, z1 = -8 },
	EAST_LOTS = { x0 = -236, x1 = -202, z0 = -40, z1 = -6 }, -- dues cases mirant al carrer R6
	-- Dig & Co., l'única botiga de la plaça: al racó nord-est, mirant la font
	-- (on hi havia l'escenari; a l'oest tapava el Museu 5)
	SHOP = { x = 70, z = -24, dx = -0.81, dz = 0.58 },
	-- camins de vianants {x0, z0, x1, z1, amplada}
	PATHS = { { -330, -2, -202, -2, 7 } },
	-- museus: {nom, estil, x, z, cara (dx, dz), amplada, fondària}
	MUSEUMS = {
		-- tots iguals (disseny modern); només canvia on són i cap on miren
		{ "MUSEU 1", "modern", 20, -238, 0, 1, 70, 52 },
		{ "MUSEU 2", "modern", -125, -150, 0, 1, 70, 52 },
		{ "MUSEU 3", "modern", -266, -150, 0, 1, 70, 52 },
		{ "MUSEU 4", "modern", -266, 113, 0, -1, 70, 52 },
		{ "MUSEU 5", "modern", -104, 11, 1, 0, 70, 52 },
		{ "MUSEU 6", "modern", 20, 210, 0, -1, 70, 52 },
		{ "MUSEU 7", "modern", 140, 113, 1, 0, 70, 52 },
		{ "MUSEU 8", "modern", -125, 113, 0, -1, 70, 52 },
	},
	-- illes de cases {x0, x1, z0, z1, cares amb carrer}; les cares que donen
	-- a la plaça porten porxos (vegeu 03_houses)
	BLOCKS = {
		{ -330, -202, -262, -202, "S" },
		{ -178, 166, -262, -202, "S" },
		{ -330, -202, -178, -122, "NS" },
		{ -178, -72, -178, -122, "NSEW" },
		{ -48, 5, -178, -122, "NSEW" },
		{ 35, 88, -178, -122, "NSEW" },
		{ 112, 166, -178, -122, "NSWE" },
		{ -178, -72, -98, -56, "S" },
		{ -48, 5, -98, -56, "SE" },
		{ 35, 88, -98, -56, "SW" },
		{ 112, 166, -98, -56, "SE" },
		{ -178, -72, -32, 54, "NSEW" },
		{ 112, 166, -32, 54, "EW" },
		{ -330, -202, 4, 54, "NSE" },
		{ -330, -202, -98, -40, "NE" }, -- cases al nord i a l'est de l'obra
		{ -178, -72, 78, 148, "NSEW" },
		{ -48, 88, 78, 148, "NSEW" },
		{ 112, 166, 78, 148, "EW" },
		{ -178, -72, 172, 262, "NSEW" },
		{ -48, 88, 172, 262, "NSEW" },
		{ 112, 166, 172, 262, "EW" },
		{ -330, -202, 78, 148, "NSE" },
		{ -330, -202, 172, 262, "NE" },
	},
}
-- rectangle ocupat per cada museu (per no posar-hi cases)
LAYOUT.MUSEUM_RECTS = {}
for _, mu in ipairs(LAYOUT.MUSEUMS) do
	local w, d = mu[7], mu[8]
	if mu[5] ~= 0 then
		w, d = d, w
	end
	table.insert(LAYOUT.MUSEUM_RECTS, { mu[3] - w / 2 - 3, mu[3] + w / 2 + 3, mu[4] - d / 2 - 3, mu[4] + d / 2 + 3 })
end
local function inRects(x, z, rects, pad)
	pad = pad or 0
	for _, r in ipairs(rects) do
		if x > r[1] - pad and x < r[2] + pad and z > r[3] - pad and z < r[4] + pad then
			return true
		end
	end
	return false
end

-- ─────────────────────── MOBILIARI URBÀ MODERN (compartit) ───────────────────────
-- Les cases són tradicionals; el carrer, la plaça, la platja i l'obra porten
-- aquest mobiliari: formigó, acer fosc, fusta clara i llum de LED.
local MOD = {
	white = C(242, 240, 234),
	conc = C(186, 184, 178),
	concD = C(150, 148, 142),
	char = C(58, 60, 64),
	steel = C(34, 36, 40),
	wood = C(170, 118, 76),
	glass = C(86, 112, 124),
	rail = C(196, 222, 228),
	led = C(255, 238, 206),
}

-- banc: bloc de formigó amb seient i respatller de fusta
local function modernBench(p, facing, parent)
	local m = Instance.new("Model")
	m.Name = "Bench"
	local O = CFrame.lookAt(p, p + facing)
	P(V3(6.4, 1.5, 2.2), O * CF(0, 0.75, 0), MOD.conc, M.Concrete, m)
	P(V3(6.4, 0.3, 2.3), O * CF(0, 1.65, 0), MOD.wood, M.WoodPlanks, m)
	P(V3(6.4, 1.8, 0.3), O * CF(0, 2.6, 1.05), MOD.wood, M.WoodPlanks, m)
	m.Parent = parent
	return m
end

-- fanal: pal quadrat prim i capçal pla de LED que surt cap a `dir`
local function modernLamp(p, dir, parent, height, light)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	local h = height or 13
	P(V3(1.2, 0.4, 1.2), CF(p + UP * 0.2), MOD.concD, M.Concrete, m)
	P(V3(0.5, h, 0.5), CF(p + UP * (h / 2)), MOD.steel, M.Metal, m)
	local cf = CFrame.lookAt(p + UP * h + dir * 2, p + UP * h + dir * 5)
	P(V3(1.1, 0.35, 4.2), cf, MOD.steel, M.Metal, m, true)
	local g = P(V3(0.8, 0.1, 3.6), cf * CF(0, -0.2, 0), C(255, 240, 214), M.Neon, m, true)
	if light then
		local pl = Instance.new("SpotLight")
		pl.Face = Enum.NormalId.Bottom
		pl.Range = 24
		pl.Angle = 100
		pl.Brightness = 1.2
		pl.Color = C(255, 230, 196)
		pl.Parent = g
	end
	m.Parent = parent
	return m
end

-- pilona d'acer amb anell de llum
local function modernBollard(p, parent)
	VCyl(2.4, 0.9, p + UP * 1.2, MOD.steel, M.Metal, parent)
	VCyl(0.14, 0.95, p + UP * 2.1, MOD.led, M.Neon, parent, true)
end

-- barana de vidre entre `a` i `b` (a terra), amb passamà d'acer
local function glassRail(a, b, h, parent)
	local L = (b - a).Magnitude
	local n = math.max(1, math.floor(L / 4))
	for k = 0, n - 1 do
		local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
		local mid = (p0 + p1) / 2
		local g = P(V3(0.15, h, (p1 - p0).Magnitude - 0.25), CFrame.lookAt(mid + UP * (h / 2), p1 + UP * (h / 2)), MOD.rail, M.Glass, parent, true)
		g.Transparency = 0.55
		P(V3(0.3, h + 0.2, 0.3), CF(p0 + UP * ((h + 0.2) / 2)), MOD.steel, M.Metal, parent, true)
	end
	P(V3(0.3, h + 0.2, 0.3), CF(b + UP * ((h + 0.2) / 2)), MOD.steel, M.Metal, parent, true)
	P(V3(0.35, 0.25, L), CFrame.lookAt((a + b) / 2 + UP * (h + 0.2), b + UP * (h + 0.2)), C(170, 172, 174), M.Metal, parent, true)
end

-- para-sol modern: pal d'acer i tela quadrada plana
local function squareParasol(p, color, parent, size)
	local s = size or 8
	VCyl(7.6, 0.25, p + UP * 3.8, MOD.steel, M.Metal, parent, true)
	local t = P(V3(s, 0.25, s), CF(p + UP * 7.7), color, M.Fabric, parent, true)
	t.CastShadow = true
	return t
end

-- gandula moderna blanca
local function lounger(cf, parent)
	P(V3(2.2, 0.35, 5.6), cf * CF(0, 1.1, 0.4), MOD.white, M.SmoothPlastic, parent)
	P(V3(2.2, 0.35, 2.2), cf * CF(0, 1.9, -2.6) * CFrame.Angles(rad(35), 0, 0), MOD.white, M.SmoothPlastic, parent)
	for _, z in ipairs({ -1.6, 2.6 }) do
		P(V3(2, 0.9, 0.3), cf * CF(0, 0.45, z), MOD.steel, M.Metal, parent, true)
	end
end

-- ─────────────────────── MODELS DE LA TOOLBOX ───────────────────────
-- Models gratuïts del Creator Store, triats a mà (palmeres, arbustos, roques...).
-- Es carreguen un cop per mòdul i se'n treu TOT el que no és geometria:
-- scripts (poden portar virus), sons, partícules, prompts i clics. Queden
-- ancorats i sense col·lisió (decoració), si no es diu el contrari.
local ASSETS = {
	palmChunky = 5142894263, -- palmera de tronc corbat, fulles verd viu
	palmCoco = 12429665880, -- palmera prima amb cocos
	pine = 12549617200, -- pi low poly (estil simulador)
	bushRound = 5003870763, -- arbust rodó
	bushLeafy = 7191673673, -- arbust de fulles
	rocks = 10467970896, -- paquet de roques low poly
	wheelbarrow = 2542985710, -- carretó rovellat
	lifeguard = 10969289501, -- torre de socorrista
	umbrellaSet = 9017391415, -- tres para-sols amb gandules
	umbrellaChairs = 3874861332, -- para-sol de colors amb dues cadires
	sandCastle = 18852029806, -- castell de sorra
	trexSkull = 132118623717048, -- crani de T-Rex (portava scripts: fora)
}
local assetCache = {}
local STRIP = { "LuaSourceContainer", "Sound", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Camera", "ProximityPrompt", "ClickDetector", "Humanoid", "Tool", "BillboardGui" }
local function assetTemplate(id)
	if assetCache[id] ~= nil then
		return assetCache[id]
	end
	local ok, objs = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if not ok or #objs == 0 then
		warn("no s'ha pogut carregar el model " .. tostring(id))
		assetCache[id] = false
		return false
	end
	local m = Instance.new("Model")
	m.Name = "Asset"
	for _, o in ipairs(objs) do
		o.Parent = m
	end
	for _, d in ipairs(m:GetDescendants()) do
		for _, cls in ipairs(STRIP) do
			if d:IsA(cls) then
				d:Destroy()
				break
			end
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	m:PivotTo(CFrame.identity)
	assetCache[id] = m
	return m
end
-- Posa un model: la base del model (centre de sota) queda a `cf`, girat com
-- `cf`, i fa `h` d'alt. opts.collide = true perquè no el travessin.
local function Asset(key, cf, h, parent, opts)
	local tpl = assetTemplate(ASSETS[key] or key)
	if not tpl then
		return nil
	end
	local m = tpl:Clone()
	m.Name = type(key) == "string" and key or "Asset"
	local _, size = m:GetBoundingBox()
	if h and size.Y > 0 then
		m:ScaleTo(m:GetScale() * (h / size.Y))
	end
	m:PivotTo(CFrame.identity)
	local bcf, bsize = m:GetBoundingBox()
	local bottom = bcf.Position - V3(0, bsize.Y / 2, 0)
	m:PivotTo(cf * CF(-bottom))
	if opts and opts.collide then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = true
			end
		end
	end
	m.Parent = parent
	return m
end

-- Una roca sola del paquet de roques (el paquet porta caixes de col·lisió
-- visibles: se n'agafa només la malla). `size` = la mida més gran.
local ROCK_NAMES = { "Rock", "rockb", "shaperock", "1", "0" }
local function Rock(cf, size, parent, which, color)
	local tpl = assetTemplate(ASSETS.rocks)
	if not tpl then
		return nil
	end
	local src = tpl:FindFirstChild(ROCK_NAMES[(which - 1) % #ROCK_NAMES + 1], true)
	if not src or not src:IsA("MeshPart") then
		return nil
	end
	local r = src:Clone()
	r:ClearAllChildren()
	r.Size = r.Size * (size / math.max(r.Size.X, r.Size.Y, r.Size.Z))
	r.CFrame = cf * CF(0, r.Size.Y * 0.3, 0)
	r.Color = color or COL.rock
	r.Material = M.Slate
	r.Anchored = true
	r.CanCollide = true
	r.Parent = parent
	return r
end

-- ─────────────────────── LLOC D'EXCAVACIÓ (DigSpot) ───────────────────────
-- Una llosa de terra de 8x8 amb forats DE VERITAT (CSG): un clot rodó gran
-- amb un esglaó a mitja alçada i dos forats petits als cantons (les
-- "rodones"). Al fons del clot hi ha el munt per cavar, amb un os que treu
-- el nas. El munt és la part DigSpot (el servidor l'encongeix quan es buida).
-- Les peces "Fill" (l'os, les pedretes) són filles del munt i el servidor les
-- amaga mentre és buit. El model té el munt com a PrimaryPart: el client hi
-- arriba clicant qualsevol peça del forat.
-- `g` = centre de la llosa a l'altura del terra. Ha de ser múltiple de 4 en X
-- i Z: sota la llosa es buida el terreny, i la graella del terreny és de 4.
local PIT_STYLES = {
	earth = {
		slab = C(132, 100, 62),
		floor = C(84, 62, 40),
		mound = C(176, 136, 88),
		mat = M.Ground,
		pebble = C(150, 146, 138),
	},
	sand = {
		slab = C(222, 202, 156),
		floor = C(176, 150, 106),
		mound = C(210, 186, 138),
		mat = M.Sand,
		pebble = C(240, 206, 196), -- petxines
	},
	-- Egipte: sorra daurada del desert, més càlida que la de la platja
	desert = {
		slab = C(226, 190, 128),
		floor = C(184, 142, 86),
		mound = C(214, 172, 108),
		mat = M.Sand,
		pebble = C(196, 168, 120),
	},
}
local TOY = { C(240, 80, 80), C(70, 160, 230), C(250, 200, 60), C(90, 200, 120) }
local PIT_TILE, PIT_R, PIT_LEDGE, PIT_DEPTH = 8, 2.7, 3.4, 2.4
local CRATER_R, CRATER_H = 12, 1.5 -- esfera del cràter de la platja i quant surt
-- alçada del terra del forat a `d` del centre (a la platja, el casquet)
local function pitGround(style, d)
	if style == "earth" then
		return 0
	end
	return math.max(0, math.sqrt(math.max(CRATER_R * CRATER_R - d * d, 0)) - (CRATER_R - CRATER_H))
end
local function vcut(pos, radius, top, bottom)
	local c = Instance.new("Part")
	c.Shape = Enum.PartType.Cylinder
	c.Anchored = true
	c.Size = V3(top - bottom, radius * 2, radius * 2)
	c.CFrame = CF(pos.X, (top + bottom) / 2, pos.Z) * UPRIGHT
	c.Parent = Workspace
	return c
end
local function digPit(g, zone, name, style, r, parent)
	local S = PIT_STYLES[style]
	local m = Instance.new("Model")
	m.Name = "DigPit_" .. name
	m.Parent = parent -- el CSG vol les peces dins del joc
	local T = PIT_TILE
	-- sota la llosa, el terreny avall (si no, trauria el cap pel fons del
	-- forat): la capa de -4..0 buida i la de -8..-4 gairebé buida (la
	-- superfície del terreny queda a ~-5, per sota de la llosa)
	do
		local terrain = Workspace.Terrain
		local region = Region3.new(V3(g.X - T / 2, -8, g.Z - T / 2), V3(g.X + T / 2, 4, g.Z + T / 2)):ExpandToGrid(4)
		local mats, occ = terrain:ReadVoxels(region, 4)
		for x = 1, mats.Size.X do
			for z = 1, mats.Size.Z do
				occ[x][1][z] = math.min(occ[x][1][z], 0.2)
				for y = 2, mats.Size.Y do
					occ[x][y][z] = 0
					mats[x][y][z] = M.Air
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occ)
	end
	-- la llosa i els forats
	-- a l'obra, lloses quadrades en quadrícula; a la platja, un cràter: una
	-- esfera gran enterrada de la qual només surt el casquet (vora suau)
	local slab
	if style ~= "earth" then
		slab = Ball(CRATER_R * 2, g + UP * (CRATER_H - CRATER_R), S.slab, S.mat, m)
	else
		slab = P(V3(T, 3.2, T), CF(g - UP * 1.6), S.slab, S.mat, m)
	end
	local turn = r:NextInteger(0, 1) * math.pi / 2
	local cuts = {
		vcut(g, PIT_LEDGE, g.Y + 1, g.Y - 0.9),
		vcut(g, PIT_R, g.Y + 1, g.Y - PIT_DEPTH),
	}
	local small = {}
	for q = 0, 1 do
		local a = turn + math.pi / 4 + q * math.pi
		local c = g + V3(math.cos(a), 0, math.sin(a)) * 3.55
		table.insert(small, c)
		table.insert(cuts, vcut(c, 0.95, g.Y + 1, g.Y - 1.3))
	end
	local ok, union = pcall(function()
		return slab:SubtractAsync(cuts)
	end)
	for _, c in ipairs(cuts) do
		c:Destroy()
	end
	if ok and union then
		union.Name = "PitSlab"
		union.UsePartColor = true
		union.Color = S.slab
		union.Material = S.mat
		union.Anchored = true
		union.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
		union.RenderFidelity = Enum.RenderFidelity.Precise
		union.Parent = m
		slab:Destroy()
	else
		warn("CSG ha fallat a " .. name .. ": " .. tostring(union))
		slab.Parent = m
	end
	-- fons més fosc (terra humida) al clot gran i als petits
	Cyl(0.1, PIT_R * 2 - 0.1, CF(g - UP * (PIT_DEPTH - 0.05)) * UPRIGHT, S.floor, S.mat, m, true)
	for _, c in ipairs(small) do
		Cyl(0.1, 1.8, CF(c - UP * 1.25) * UPRIGHT, S.floor, S.mat, m, true)
	end
	-- el munt del fons: aquí es cava (DigSpot)
	local mr = r:NextNumber(1.75, 1.95)
	local mound = P(V3(mr * 2, mr * 1.4, mr * 2), CF(g - UP * (PIT_DEPTH - mr * 0.42)) * CFrame.Angles(0, r:NextNumber(0, 6), 0), S.mound, S.mat, m)
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = mound
	mound.Name = name
	tag(mound, "DigSpot")
	mound:SetAttribute("Zone", zone) -- ha de coincidir amb Config/Zones.luau
	m.PrimaryPart = mound
	-- el que hi ha damunt del munt (s'amaga quan el munt és buit)
	local function fill(part)
		part:SetAttribute("Fill", true)
		part.Parent = mound
		return part
	end
	local top = mound.Position + UP * (mr * 0.6)
	if r:NextNumber() < 0.85 then
		local a = top + V3(r:NextNumber(-0.3, 0.3), -0.2, r:NextNumber(-0.3, 0.3))
		local b = a + V3(r:NextNumber(-1, 1), 0.8, r:NextNumber(-1, 1))
		fill(beam(a, b, 0.4, COL.bone, M.Marble, m, true))
		fill(Ball(0.7, b, COL.bone, M.Marble, m, true))
	end
	for _ = 1, 3 do
		local a = r:NextNumber(0, math.pi * 2)
		fill(Ball(r:NextNumber(0.35, 0.55), mound.Position + V3(math.cos(a) * mr * 0.6, mr * 0.28, math.sin(a) * mr * 0.6), S.pebble, M.Slate, m, true))
	end
	-- estris als dos cantons sense forat
	local corner = {}
	for q = 0, 1 do
		local a = turn + math.pi * 3 / 4 + q * math.pi
		corner[q + 1] = g + V3(math.cos(a), 0, math.sin(a)) * 4.6
	end
	-- paleta clavada a l'esglaó
	local ta = turn + r:NextNumber(0, math.pi * 2)
	local tcf = CF(g + V3(math.cos(ta), 0, math.sin(ta)) * 3.05 + UP * -0.2) * CFrame.Angles(rad(20), -ta, 0)
	P(V3(0.16, 1.2, 0.16), tcf * CF(0, 0.55, 0), COL.woodDark, M.Wood, m, true)
	Wd(V3(0.08, 0.8, 0.6), tcf * CF(0, -0.35, 0) * CFrame.Angles(math.pi, 0, 0), C(190, 196, 204), M.Metal, m, true)
	local cornerUp = UP * pitGround(style, 3.7)
	if style == "earth" then
		-- galleda de goma negra plena de terra, a un cantó
		local bp = g:Lerp(corner[1], 0.82)
		VCyl(1.2, 1.3, bp + UP * 0.6, C(40, 40, 42), M.SmoothPlastic, m, true)
		VCyl(0.1, 1.1, bp + UP * 1.17, S.floor, S.mat, m, true)
		-- raspall a l'altre
		local brcf = CF(g:Lerp(corner[2], 0.8) + UP * 0.12) * CFrame.Angles(0, ta, rad(90))
		P(V3(0.14, 1, 0.14), brcf, C(200, 60, 50), M.SmoothPlastic, m, true)
		P(V3(0.4, 0.4, 0.3), brcf * CF(0, -0.6, 0), C(236, 220, 170), M.Fabric, m, true)
	elseif style == "desert" then
		-- àmfora de fang mig enterrada, a un cantó
		local ap = g:Lerp(corner[1], 0.8) + cornerUp
		local acf = CF(ap + UP * 0.7) * CFrame.Angles(rad(12), ta, 0)
		Ellipsoid(V3(1.3, 1.6, 1.3), acf, C(178, 96, 58), M.SmoothPlastic, m).CanCollide = false
		VCyl(0.5, 0.55, (acf * CF(0, 0.95, 0)).Position, C(160, 84, 50), M.SmoothPlastic, m, true)
		P(V3(0.9, 0.12, 1.5), acf * CF(0, 0.2, 0), C(62, 118, 150), M.SmoothPlastic, m, true) -- franja pintada
		-- pinzell d'arqueòleg a l'altre
		local brcf = CF(g:Lerp(corner[2], 0.8) + cornerUp + UP * 0.12) * CFrame.Angles(0, ta, rad(90))
		P(V3(0.14, 1, 0.14), brcf, COL.woodDark, M.Wood, m, true)
		P(V3(0.4, 0.4, 0.3), brcf * CF(0, -0.6, 0), C(236, 220, 170), M.Fabric, m, true)
	else
		-- galleda i pala de joguina, de colors
		local col = TOY[r:NextInteger(1, #TOY)]
		local bp = g:Lerp(corner[1], 0.8) + cornerUp
		VCyl(1.1, 1.1, bp + UP * 0.55, col, M.SmoothPlastic, m, true)
		VCyl(0.12, 1.15, bp + UP * 1.12, col:Lerp(C(255, 255, 255), 0.3), M.SmoothPlastic, m, true)
		local scf = CF(g:Lerp(corner[2], 0.8) + cornerUp + UP * 0.9) * CFrame.Angles(rad(20), ta, rad(-25))
		P(V3(0.16, 1.6, 0.16), scf, TOY[r:NextInteger(1, #TOY)], M.SmoothPlastic, m, true)
		P(V3(0.8, 0.7, 0.1), scf * CF(0, -1, 0), TOY[r:NextInteger(1, #TOY)], M.SmoothPlastic, m, true)
		-- una estrella de mar a la vora
		local sp = g + V3(math.cos(ta + 1), 0, math.sin(ta + 1)) * 4.9 + UP * (pitGround(style, 4.9) + 0.12)
		for k = 0, 4 do
			P(V3(0.3, 0.15, 0.9), CF(sp) * CFrame.Angles(0, k * math.pi * 2 / 5, 0) * CF(0, 0, 0.4), C(236, 120, 80), M.SmoothPlastic, m, true)
		end
	end
	m.Parent = parent
	return m, mound
end

-- ─────────────────────── CAMP D'EXCAVACIÓ IRREGULAR (obra) ───────────────────────
-- Una sola llosa de terra gran (x0,z0 i mida múltiples de 4) amb `count`
-- clots de mides i fondàries diferents, repartits a l'atzar sense tocar-se.
-- Cada clot té el seu munt (DigSpot) al fons, i n'hi ha que tenen un
-- esglaó o un forat petit enganxat: cap és igual. Retorna els centres.
local function digField(x0, z0, sx, sz, count, zone, prefix, r, parent)
	local S = PIT_STYLES.earth
	local gy = 0.02
	local field = Instance.new("Model")
	field.Name = "DigField"
	field.Parent = parent
	-- terreny avall sota tota la llosa
	do
		local terrain = Workspace.Terrain
		local region = Region3.new(V3(x0, -8, z0), V3(x0 + sx, 4, z0 + sz)):ExpandToGrid(4)
		local mats, occ = terrain:ReadVoxels(region, 4)
		for x = 1, mats.Size.X do
			for z = 1, mats.Size.Z do
				occ[x][1][z] = math.min(occ[x][1][z], 0.2)
				for y = 2, mats.Size.Y do
					occ[x][y][z] = 0
					mats[x][y][z] = M.Air
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occ)
	end
	-- on van els clots: grans, mitjans i petits, sense tocar-se. Si no hi
	-- caben tots, es torna a provar amb clots una mica més petits.
	local pits = {}
	local scale = 1
	for _ = 1, 8 do
		pits = {}
		local tries = 0
		while #pits < count and tries < 3000 do
			tries += 1
			local n = #pits
			local rad0 = scale * (if n < 3 then r:NextNumber(3, 3.5) elseif n < 9 then r:NextNumber(2.2, 2.8) else r:NextNumber(1.6, 2.1))
			-- els grossos poden tenir un esglaó: ocupen més
			local ledge = rad0 > 2.7 and r:NextNumber() < 0.7
			local outer = if ledge then rad0 * 1.1 + 0.6 else rad0 * 1.15
			local x = r:NextNumber(x0 + outer + 1, x0 + sx - outer - 1)
			local z = r:NextNumber(z0 + outer + 1, z0 + sz - outer - 1)
			local ok = true
			for _, q in ipairs(pits) do
				if (V3(x, 0, z) - V3(q.x, 0, q.z)).Magnitude < outer + q.outer + 0.9 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(pits, { x = x, z = z, r = rad0, ledge = ledge, outer = outer })
			end
		end
		if #pits >= count then
			break
		end
		scale *= 0.93
	end
	local slab = P(V3(sx, 3.4, sz), CF(x0 + sx / 2, gy - 1.7, z0 + sz / 2), S.slab, S.mat, field)
	local cuts = {}
	for _, q in ipairs(pits) do
		local g = V3(q.x, gy, q.z)
		q.core = q.r
		q.depth = math.clamp(q.r * 0.75 + r:NextNumber(-0.3, 0.3), 1.3, 2.8)
		-- forma: el clot principal una mica ovalat (dos cilindres encavalcats)
		local a = r:NextNumber(0, math.pi * 2)
		local off = V3(math.cos(a), 0, math.sin(a)) * q.r * 0.25
		table.insert(cuts, vcut(g + off, q.r * 0.85, gy + 1, gy - q.depth))
		table.insert(cuts, vcut(g - off, q.r * 0.8, gy + 1, gy - q.depth + 0.3))
		if q.ledge then
			-- esglaó a mitja alçada: un anell sencer al voltant del clot ovalat
			table.insert(cuts, vcut(g, q.outer, gy + 1, gy - q.depth * 0.4))
		end
		if r:NextNumber() < 0.5 then
			-- forat petit enganxat
			local b = r:NextNumber(0, math.pi * 2)
			local c = g + V3(math.cos(b), 0, math.sin(b)) * (q.outer + 0.3)
			if c.X > x0 + 1.5 and c.X < x0 + sx - 1.5 and c.Z > z0 + 1.5 and c.Z < z0 + sz - 1.5 then
				table.insert(cuts, vcut(c, r:NextNumber(0.8, 1.2), gy + 1, gy - r:NextNumber(0.8, 1.3)))
			end
		end
	end
	local ok, union = pcall(function()
		return slab:SubtractAsync(cuts)
	end)
	for _, c in ipairs(cuts) do
		c:Destroy()
	end
	if ok and union then
		union.Name = "FieldSlab"
		union.UsePartColor = true
		union.Color = S.slab
		union.Material = S.mat
		union.Anchored = true
		union.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
		union.RenderFidelity = Enum.RenderFidelity.Precise
		union.Parent = field
		slab:Destroy()
	else
		warn("CSG del camp ha fallat: " .. tostring(union))
	end
	-- a cada clot: fons fosc, el munt (DigSpot) i, de vegades, una eina
	for i, q in ipairs(pits) do
		local g = V3(q.x, gy, q.z)
		local m = Instance.new("Model")
		m.Name = "DigPit_" .. prefix .. i
		Cyl(0.1, q.core * 1.3, CF(g - UP * (q.depth - 0.05)) * UPRIGHT, S.floor, S.mat, m, true)
		local mr = math.clamp(q.core * 0.62, 1.3, 2.3)
		local mound = P(V3(mr * 2, mr * 1.4, mr * 2), CF(g - UP * (q.depth - mr * 0.42)) * CFrame.Angles(0, r:NextNumber(0, 6), 0), S.mound, S.mat, m)
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Parent = mound
		mound.Name = prefix .. i
		tag(mound, "DigSpot")
		mound:SetAttribute("Zone", zone)
		m.PrimaryPart = mound
		local function fill(part)
			part:SetAttribute("Fill", true)
			part.Parent = mound
		end
		local top = mound.Position + UP * (mr * 0.6)
		if r:NextNumber() < 0.85 then
			local a = top + V3(r:NextNumber(-0.3, 0.3), -0.2, r:NextNumber(-0.3, 0.3))
			local b = a + V3(r:NextNumber(-1, 1), 0.8, r:NextNumber(-1, 1)) * (mr / 2)
			fill(beam(a, b, 0.4, COL.bone, M.Marble, m, true))
			fill(Ball(0.7, b, COL.bone, M.Marble, m, true))
		end
		for _ = 1, 2 do
			local a = r:NextNumber(0, math.pi * 2)
			fill(Ball(r:NextNumber(0.35, 0.55), mound.Position + V3(math.cos(a) * mr * 0.6, mr * 0.28, math.sin(a) * mr * 0.6), S.pebble, M.Slate, m, true))
		end
		local roll = r:NextNumber()
		local a = r:NextNumber(0, math.pi * 2)
		local edge = g + V3(math.cos(a), 0, math.sin(a)) * (q.outer + 0.8)
		if roll < 0.35 then
			VCyl(1.2, 1.3, edge + UP * 0.6, C(40, 40, 42), M.SmoothPlastic, m, true)
			VCyl(0.1, 1.1, edge + UP * 1.17, S.floor, S.mat, m, true)
		elseif roll < 0.6 then
			local tcf = CF(edge + UP * 0.7) * CFrame.Angles(rad(20), -a, 0)
			P(V3(0.16, 1.2, 0.16), tcf * CF(0, 0.55, 0), COL.woodDark, M.Wood, m, true)
			Wd(V3(0.08, 0.8, 0.6), tcf * CF(0, -0.35, 0) * CFrame.Angles(math.pi, 0, 0), C(190, 196, 204), M.Metal, m, true)
		end
		m.Parent = field
	end
	return pits
end
