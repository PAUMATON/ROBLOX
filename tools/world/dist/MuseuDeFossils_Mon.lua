--[[ ═══════════════════════════════════════════════════════════════════════
     MUSEU DE FÒSSILS · constructor del món (plugin)
     Pestanya PLUGINS → botó "Construir el món".

     Esborra el món anterior (Workspace.World, Zones, Museums i el terreny)
     i el torna a fer: plaça amb el T-Rex, 8 museus, cases, platja, Zona 1
     (obra), parcs i carrers. NO toca els scripts del joc.
     Es pot desfer amb Ctrl+Z. Recorda desar (Ctrl+S) quan t'agradi.

     Generat per tools/world/make_plugin.py — no l'editis a mà, edita els
     mòduls de tools/world/ i torna'l a generar.
     ═══════════════════════════════════════════════════════════════════════ ]]

local function BuildWorld()
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

	local STEPS = {}
STEPS[#STEPS + 1] = { "01_ground", function()
-- ═══════════════════════════ 01 · NETEJA, TERRENY I LLUM ═══════════════════════════
local Lighting = game:GetService("Lighting")
local Terrain = Workspace.Terrain

-- Neteja: el món anterior (i la prova de Chamonix) fora
for _, name in ipairs({ "Chamonix", "World", "Zones", "Museums", "Baseplate" }) do
	local x = Workspace:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end
for _, x in ipairs(Workspace:GetChildren()) do
	if x:IsA("SpawnLocation") then
		x:Destroy()
	end
end
WORLD = folder("World", Workspace)
ZONES = folder("Zones", Workspace)
MUSEUMS = folder("Museums", Workspace)
Terrain:Clear()

-- ── Terra: gespa a tot el continent ──
-- (el terreny de Roblox queda 2 studs per sobre del bloc: per això els blocs acaben a -2)
local L = LAYOUT.LAND
for x = L.x0, LAYOUT.PROM.x1 - 1, 256 do
	for z = L.z0, L.z1 - 1, 256 do
		local sx = math.min(256, LAYOUT.PROM.x1 - x)
		local sz = math.min(256, L.z1 - z)
		Terrain:FillBlock(CF(x + sx / 2, -10, z + sz / 2), V3(sx, 16, sz), M.LeafyGrass)
	end
end
-- ── Mar: aigua fins a l'horitzó ──
local SEA_X1 = 1100
for x = LAYOUT.PROM.x1, SEA_X1 - 1, 256 do
	for z = L.z0 - 400, L.z1 + 399, 256 do
		local sx = math.min(256, SEA_X1 - x)
		Terrain:FillBlock(CF(x + sx / 2, -11, z + 128), V3(sx, 14, 256), M.Water)
		Terrain:FillBlock(CF(x + sx / 2, -24, z + 128), V3(sx, 12, 256), M.Sand)
	end
end
-- ── Platja: sorra plana i després una rampa suau que entra al mar ──
local zs, ze = L.z0 - 40, L.z1 + 40
local flat = LAYOUT.BEACH_FLAT_X1
Terrain:FillBlock(CF((LAYOUT.PROM.x1 + flat) / 2, -10.3, (zs + ze) / 2), V3(flat - LAYOUT.PROM.x1, 16, ze - zs), M.Sand)
local run, drop = 130, 11
local ang = math.atan(drop / run)
Terrain:FillBlock(
	CF(flat + run / 2, -drop / 2 - 10.3, (zs + ze) / 2) * CFrame.Angles(0, 0, -ang),
	V3(run / math.cos(ang) + 6, 16, ze - zs),
	M.Sand
)
-- extrems de la platja: roques
for _, zz in ipairs({ L.z0 - 30, L.z1 + 30 }) do
	for k = 0, 5 do
		Terrain:FillBall(V3(LAYOUT.PROM.x1 + 20 + k * 22, -2 + (5 - k) * 1.2, zz + (k % 2) * 12 - 6), 14 - k, M.Rock)
	end
end

-- ── Sota els paviments, res de gespa (l'herba del terreny travessa les peces) ──
-- (ReplaceMaterial canvia el material sense tocar l'alçada del terra)
local function paint(x0, x1, z0, z1, mat)
	if x1 > x0 and z1 > z0 then
		local region = Region3.new(V3(x0, -8, z0), V3(x1, 8, z1)):ExpandToGrid(4)
		Terrain:ReplaceMaterial(region, 4, M.LeafyGrass, mat)
	end
end
for _, r in ipairs(LAYOUT.ROADS) do
	local hw = r[5] / 2 + 1
	paint(math.min(r[1], r[3]) - hw, math.max(r[1], r[3]) + hw, math.min(r[2], r[4]) - hw, math.max(r[2], r[4]) + hw, M.Pavement)
end
for _, R in ipairs({ LAYOUT.PLAZA, LAYOUT.PASSEIG }) do
	paint(R.x0 - 2, R.x1 + 2, R.z0 - 2, R.z1 + 2, M.Pavement)
end
paint(LAYOUT.PROM.x0 - 2, LAYOUT.PROM.x1, L.z0, L.z1, M.Pavement)
for _, r in ipairs(LAYOUT.MUSEUM_RECTS) do
	paint(r[1], r[2], r[3], r[4], M.Pavement)
end
local O = LAYOUT.OBRA
paint(O.x0 - 4, O.x1 + 4, O.z0 - 4, O.z1 + 4, M.Ground)

-- herba del terreny: sense brins alts (es veien malament i travessaven les peces)
pcall(function()
	Terrain.Decoration = false
end)

-- ── Colors del terreny (paleta del CLAUDE.md) ──
Terrain:SetMaterialColor(M.Grass, C(118, 158, 84))
Terrain:SetMaterialColor(M.LeafyGrass, C(124, 164, 88))
Terrain:SetMaterialColor(M.Sand, COL.sand)
Terrain:SetMaterialColor(M.Rock, COL.rock)
Terrain:SetMaterialColor(M.Pavement, COL.paveDark)
Terrain:SetMaterialColor(M.Ground, COL.earth)
Terrain.WaterColor = C(64, 150, 170)
Terrain.WaterTransparency = 0.45
Terrain.WaterReflectance = 0.5
Terrain.WaterWaveSize = 0.18
Terrain.WaterWaveSpeed = 9

-- ── Llum (default.project.json: Future, ClockTime 14, Brightness 2) ──
for _, x in ipairs(Lighting:GetChildren()) do
	if x.Name == "ChamonixColor" or x:IsA("BloomEffect") or x:IsA("DepthOfFieldEffect") or x:IsA("SunRaysEffect") then
		x:Destroy()
	end
end
local cl = Terrain:FindFirstChildOfClass("Clouds")
if cl then
	cl:Destroy()
end
-- tarda assolellada i càlida: ombres llargues però suaus, colors vius
Lighting.ClockTime = 15.2
Lighting.Brightness = 2.3
Lighting.ExposureCompensation = -0.12
Lighting.GeographicLatitude = 32
Lighting.Ambient = C(110, 100, 96)
Lighting.OutdoorAmbient = C(150, 140, 132)
Lighting.ColorShift_Top = C(255, 236, 206)
Lighting.ColorShift_Bottom = C(170, 190, 220)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ShadowSoftness = 0.35
Lighting.FogEnd = 100000
Lighting.GlobalShadows = true
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Name = "FossilAtmosphere"
atm.Density = 0.28
atm.Offset = 0.2
atm.Haze = 1.2
atm.Glare = 0.35
atm.Color = C(214, 222, 236)
atm.Decay = C(120, 150, 196)
atm.Parent = Lighting
local cc = Lighting:FindFirstChild("FossilColor") or Instance.new("ColorCorrectionEffect")
cc.Name = "FossilColor"
cc.Saturation = 0.18
cc.Contrast = 0.08
cc.Brightness = 0.02
cc.TintColor = C(255, 248, 236)
cc.Parent = Lighting
local bloom = Lighting:FindFirstChild("FossilBloom") or Instance.new("BloomEffect")
bloom.Name = "FossilBloom"
bloom.Intensity = 0.35
bloom.Size = 28
bloom.Threshold = 2
bloom.Parent = Lighting
local rays = Lighting:FindFirstChild("FossilSunRays") or Instance.new("SunRaysEffect")
rays.Name = "FossilSunRays"
rays.Intensity = 0.06
rays.Spread = 0.6
rays.Parent = Lighting
-- núvols esponjosos
local clouds = Instance.new("Clouds")
clouds.Cover = 0.52
clouds.Density = 0.6
clouds.Color = C(255, 252, 246)
clouds.Parent = Terrain
print("Terreny, platja i llum fets")

end }
STEPS[#STEPS + 1] = { "02_streets", function()
-- ═══════════════════════════ 02 · CARRERS, PLAÇA MAJOR I PASSEIGS ═══════════════════════════
local F = folder("Streets", WORLD)
local ROAD_TOP, WALK_TOP = 0.3, 0.65
local WALK_W = 4
local PZ = LAYOUT.PLAZA
local STONE_A = C(214, 204, 186) -- llosa clara
local STONE_B = C(196, 184, 162) -- llosa fosca
local STONE_C = C(170, 156, 132) -- sanefes

local roads = {}
for _, r in ipairs(LAYOUT.ROADS) do
	local horiz = r[2] == r[4]
	table.insert(roads, {
		horiz = horiz,
		c = horiz and r[2] or r[1],
		a0 = horiz and math.min(r[1], r[3]) or math.min(r[2], r[4]),
		a1 = horiz and math.max(r[1], r[3]) or math.max(r[2], r[4]),
		w = r[5],
	})
end
local function pt(rd, a, off, y)
	if rd.horiz then
		return V3(a, y, rd.c + off)
	end
	return V3(rd.c + off, y, a)
end
local function strip(rd, a0, a1, off, width, top, th, color, mat, parent, deco)
	if a1 - a0 < 0.05 then
		return
	end
	local size = rd.horiz and V3(a1 - a0, th, width) or V3(width, th, a1 - a0)
	return P(size, CF(pt(rd, (a0 + a1) / 2, off, top - th / 2)), color, mat, parent, deco)
end
-- trams que queden dins la plaça de vianants (no es dibuixen com a carrer)
local function plazaCut(rd)
	if rd.horiz then
		if rd.c > PZ.z0 and rd.c < PZ.z1 then
			return { PZ.x0, PZ.x1 }
		end
	elseif rd.c > PZ.x0 and rd.c < PZ.x1 then
		return { PZ.z0, PZ.z1 }
	end
end
for _, rd in ipairs(roads) do
	rd.cuts = {}
	for _, o in ipairs(roads) do
		if o ~= rd and o.horiz ~= rd.horiz then
			if o.c >= rd.a0 - o.w / 2 and o.c <= rd.a1 + o.w / 2 and rd.c >= o.a0 - rd.w / 2 and rd.c <= o.a1 + rd.w / 2 then
				table.insert(rd.cuts, { o.c - o.w / 2, o.c + o.w / 2, cross = true })
			end
		end
	end
	local pc = plazaCut(rd)
	if pc then
		table.insert(rd.cuts, { pc[1], pc[2] })
	end
	table.sort(rd.cuts, function(p, q)
		return p[1] < q[1]
	end)
end
local function freeIntervals(rd, list)
	local out, cur = {}, rd.a0
	for _, cut in ipairs(list) do
		if cut[1] > cur then
			table.insert(out, { cur, cut[1] })
		end
		cur = math.max(cur, cut[2])
	end
	if cur < rd.a1 then
		table.insert(out, { cur, rd.a1 })
	end
	return out
end

local corners = {}
for i, rd in ipairs(roads) do
	local m = Instance.new("Model")
	m.Name = "Road" .. i
	local roadW = rd.w - 2 * WALK_W
	local pc = plazaCut(rd)
	local roadIv = freeIntervals(rd, pc and { { pc[1], pc[2] } } or {})
	for _, iv in ipairs(roadIv) do
		strip(rd, iv[1], iv[2], 0, roadW, ROAD_TOP + (rd.horiz and 0 or 0.01), 1, COL.asphalt, M.SmoothPlastic, m)
	end
	for _, iv in ipairs(freeIntervals(rd, rd.cuts)) do
		for s = -1, 1, 2 do
			strip(rd, iv[1], iv[2], s * (rd.w / 2 - WALK_W / 2), WALK_W, WALK_TOP, 1.3, COL.pave, M.SmoothPlastic, m)
			-- vorada 0,05 més curta a cada punta: si acaba on acaba la vorera, les
			-- dues cares del final queden al mateix pla i fan pampallugues
			strip(rd, iv[1] + 0.05, iv[2] - 0.05, s * (roadW / 2 + 0.3), 0.6, WALK_TOP + 0.02, 1.3, COL.cream, M.SmoothPlastic, m, true)
		end
		local a = iv[1] + 4
		while a + 5 < iv[2] - 4 do
			strip(rd, a, a + 5, 0, 0.6, ROAD_TOP + 0.04, 0.1, COL.bone, M.SmoothPlastic, m, true)
			a += 11
		end
	end
	for _, cut in ipairs(rd.cuts) do
		if cut.cross then
			local cx = (cut[1] + cut[2]) / 2
			local hw = (cut[2] - cut[1]) / 2 - WALK_W / 2
			for sa = -1, 1, 2 do
				for so = -1, 1, 2 do
					local p = pt(rd, cx + sa * hw, so * (rd.w / 2 - WALK_W / 2), WALK_TOP - 0.65)
					local key = math.floor(p.X) .. "," .. math.floor(p.Z)
					if not corners[key] and not (p.X > PZ.x0 and p.X < PZ.x1 and p.Z > PZ.z0 and p.Z < PZ.z1) then
						corners[key] = true
						P(V3(WALK_W, 1.3, WALK_W), CF(p), COL.pave, M.SmoothPlastic, m)
					end
				end
			end
		end
	end
	m.Parent = F
end

local function zebra(x, z, horizRoad, width)
	local m = Instance.new("Model")
	m.Name = "Crosswalk"
	for k = -3, 3 do
		if horizRoad then
			P(V3(1.6, 0.1, width - 8), CF(x + k * 2.8, ROAD_TOP + 0.05, z), COL.bone, M.SmoothPlastic, m, true)
		else
			P(V3(width - 8, 0.1, 1.6), CF(x, ROAD_TOP + 0.05, z + k * 2.8), COL.bone, M.SmoothPlastic, m, true)
		end
	end
	m.Parent = F
end
zebra(20, -190, true, 24)
zebra(20, -110, true, 24)

-- pilones d'acer amb anell de llum on els carrers entren a la plaça
local function bollards(rd, a)
	local roadW = rd.w - 2 * WALK_W
	for k = -2, 2 do
		modernBollard(pt(rd, a, k * (roadW / 5), WALK_TOP), F)
	end
end
for _, rd in ipairs(roads) do
	local pc = plazaCut(rd)
	if pc then
		if pc[1] > rd.a0 then
			bollards(rd, pc[1] + 1.5)
		end
		if pc[2] < rd.a1 then
			bollards(rd, pc[2] - 1.5)
		end
	end
end

-- ── camins de vianants ──
for _, pth in ipairs(LAYOUT.PATHS or {}) do
	local x0, z0, x1, z1, w = pth[1], pth[2], pth[3], pth[4], pth[5]
	local horiz = z0 == z1
	local len = horiz and math.abs(x1 - x0) or math.abs(z1 - z0)
	local c = V3((x0 + x1) / 2, WALK_TOP - 0.65, (z0 + z1) / 2)
	P(horiz and V3(len, 1.3, w) or V3(w, 1.3, len), CF(c), STONE_A, M.SmoothPlastic, F)
	for s = -1, 1, 2 do
		local e = horiz and V3(0, 0.02, s * (w / 2 - 0.3)) or V3(s * (w / 2 - 0.3), 0.02, 0)
		P(horiz and V3(len, 1.3, 0.6) or V3(0.6, 1.3, len), CF(c + e), STONE_C, M.SmoothPlastic, F, true)
	end
end

-- ── Plaça Major: llosa de dos tons, sanefa i estrella al voltant de la font ──
do
	local m = Instance.new("Model")
	m.Name = "PlazaPaving"
	local cx, cz = (PZ.x0 + PZ.x1) / 2, (PZ.z0 + PZ.z1) / 2
	local fx, fz = 20, 11 -- centre de la font
	local w, d = PZ.x1 - PZ.x0, PZ.z1 - PZ.z0
	P(V3(w, 1.3, d), CF(cx, WALK_TOP - 0.65, cz), STONE_A, M.SmoothPlastic, m)
	-- quadrícula de llosa (franges fosques cada 8)
	for x = PZ.x0 + 8, PZ.x1 - 8, 8 do
		P(V3(0.5, 0.06, d - 12), CF(x, WALK_TOP + 0.02, cz), STONE_B, M.SmoothPlastic, m, true)
	end
	for z = PZ.z0 + 8, PZ.z1 - 8, 8 do
		P(V3(w - 12, 0.06, 0.5), CF(cx, WALK_TOP + 0.02, z), STONE_B, M.SmoothPlastic, m, true)
	end
	-- sanefa perimetral davant dels porxos
	for _, e in ipairs({ { cx, PZ.z0 + 5, w - 8, 1.4 }, { cx, PZ.z1 - 5, w - 8, 1.4 }, { PZ.x0 + 5, cz, 1.4, d - 8 }, { PZ.x1 - 5, cz, 1.4, d - 8 } }) do
		P(V3(e[3], 0.08, e[4]), CF(e[1], WALK_TOP + 0.03, e[2]), STONE_C, M.SmoothPlastic, m, true)
	end
	-- estrella de vuit puntes i anells al voltant de la font
	for k = 0, 7 do
		local a = k * math.pi / 4
		local dir = V3(math.cos(a), 0, math.sin(a))
		local p = V3(fx, WALK_TOP + 0.05, fz) + dir * 34
		P(V3(2.2, 0.08, 22), CFrame.lookAt(p, p + dir), k % 2 == 0 and STONE_C or STONE_B, M.SmoothPlastic, m, true)
	end
	for k, dia in ipairs({ 66, 63, 52, 50 }) do
		Cyl(0.06 + k * 0.01, dia, CF(fx, WALK_TOP + 0.03 + k * 0.01, fz) * UPRIGHT, k % 2 == 1 and STONE_C or STONE_A, M.SmoothPlastic, m, true)
	end
	m.Parent = F
end

-- ── Passeig dels Museus: de la plaça al Gran Museu, amb jardí central ──
do
	local m = Instance.new("Model")
	m.Name = "Passeig"
	local S = LAYOUT.PASSEIG
	local cx = (S.x0 + S.x1) / 2
	-- trams entre carrers (els carrers RA i RB el travessen)
	for _, seg in ipairs({ { -178, -122 }, { -98, -56 }, { -202, -202 } }) do
		local z0, z1 = seg[1], seg[2]
		if z1 > z0 then
			for s = -1, 1, 2 do
				P(V3(11, 1.3, z1 - z0), CF(cx + s * 9.5, WALK_TOP - 0.65, (z0 + z1) / 2), STONE_A, M.SmoothPlastic, m)
				P(V3(0.5, 0.06, z1 - z0), CF(cx + s * 12, WALK_TOP + 0.02, (z0 + z1) / 2), STONE_B, M.SmoothPlastic, m, true)
			end
			-- vorada del jardí central
			for s = -1, 1, 2 do
				P(V3(0.8, 1.1, z1 - z0), CF(cx + s * 3.6, 0.55, (z0 + z1) / 2), COL.boneDark, M.SmoothPlastic, m)
			end
		end
	end
	m.Parent = F
end

-- ── Passeig marítim ──
do
	local m = Instance.new("Model")
	m.Name = "Promenade"
	local x0, x1 = LAYOUT.PROM.x0, LAYOUT.PROM.x1
	local z0, z1 = LAYOUT.LAND.z0, LAYOUT.LAND.z1
	P(V3(x1 - x0, 1.3, z1 - z0), CF((x0 + x1) / 2, WALK_TOP - 0.65, (z0 + z1) / 2), COL.pave, M.SmoothPlastic, m)
	for z = z0 + 4, z1 - 4, 8 do
		P(V3(x1 - x0 - 2, 0.1, 3.4), CF((x0 + x1) / 2, WALK_TOP + 0.03, z) * CFrame.Angles(0, rad(12), 0), COL.cream, M.SmoothPlastic, m, true)
	end
	m.Parent = F
end
print("Carrers, Plaça Major, passeig dels museus i passeig marítim fets")

end }
STEPS[#STEPS + 1] = { "03_houses", function()
-- ═══════════════════════════ 03 · CASES ═══════════════════════════
-- Quatre tipus: "town" (casa de poble), "cottage" (caseta de camp),
-- "villa" (vila amb torre) i "beach" (casa de platja amb terrat).
-- Cada casa té el seu Random amb llavor fixa: surt igual cada vegada.
-- (Les cases es queden tradicionals a propòsit: és el que més agrada.
--  El que és modern és el mobiliari de carrer, la plaça, la platja i l'obra.)
local F = folder("Houses", WORLD)
local FH = 8 -- alçada d'una planta (jugador = 5)
local STONE = C(186, 178, 162)

-- ── cares d'un volum: centre (a terra), normal, tangent, llargada ──
local function face(cf, w, d, which)
	if which == "F" then
		return (cf * CF(0, 0, -d / 2)).Position, cf.LookVector, cf.RightVector, w
	elseif which == "B" then
		return (cf * CF(0, 0, d / 2)).Position, -cf.LookVector, -cf.RightVector, w
	elseif which == "L" then
		return (cf * CF(-w / 2, 0, 0)).Position, -cf.RightVector, cf.LookVector, d
	end
	return (cf * CF(w / 2, 0, 0)).Position, cf.RightVector, -cf.LookVector, d
end
local function slots(len, spacing)
	local k = math.max(1, math.floor((len - 3) / spacing))
	local t = {}
	for i = 1, k do
		t[i] = (i - (k + 1) / 2) * (len / k)
	end
	return t
end

-- ── finestra: marc, vidre, creu, ampit; persianes i jardinera opcionals ──
local function window(m, pos, n, tg, o)
	local w, h = o.w or 3.4, o.h or 4.6
	local frame = o.frame or COL.cream
	panel(V3(w + 0.8, h + 0.8, 0.3), pos + n * 0.15, n, frame, M.SmoothPlastic, m, true)
	local g = panel(V3(w, h, 0.2), pos + n * 0.28, n, COL.glass, M.SmoothPlastic, m, true)
	g.Reflectance = 0.25
	panel(V3(0.3, h, 0.15), pos + n * 0.4, n, frame, M.SmoothPlastic, m, true)
	panel(V3(w, 0.3, 0.15), pos + n * 0.4 + UP * (h * 0.12), n, frame, M.SmoothPlastic, m, true)
	panel(V3(w + 1.4, 0.45, 1.0), pos + n * 0.5 - UP * (h / 2 + 0.55), n, STONE, M.SmoothPlastic, m, true)
	if o.shut then
		for s = -1, 1, 2 do
			local sp = panel(V3(w * 0.55, h + 0.5, 0.25), pos + tg * (s * (w / 2 + 0.4 + w * 0.275)) + n * 0.2, n, o.shut, M.WoodPlanks, m, true)
			sp.CastShadow = true
		end
	end
	if o.flowers then
		local bp = pos + n * 0.9 - UP * (h / 2 + 0.2)
		panel(V3(w + 0.8, 0.9, 1.1), bp, n, o.box or COL.woodDark, M.WoodPlanks, m, true)
		for k = -1, 1 do
			Ball(1.25, bp + UP * 0.75 + tg * (k * w * 0.32), FLOWERS[o.rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, m, true)
		end
	end
end

-- finestra rodona (golfes)
local function roundWindow(m, pos, n, dia)
	local c = CFrame.lookAt(pos + n * 0.2, pos + n) * CFrame.Angles(0, rad(90), 0)
	Cyl(0.3, dia + 0.8, c, COL.cream, M.SmoothPlastic, m, true)
	local g = Cyl(0.35, dia, CFrame.lookAt(pos + n * 0.3, pos + n) * CFrame.Angles(0, rad(90), 0), COL.glass, M.SmoothPlastic, m, true)
	g.Reflectance = 0.25
end

-- ── porta amb marc de pedra, finestró, pom de llautó, esglaó i llumeta ──
local function door(m, pos, n, tg, color, rng)
	panel(V3(6, 8.8, 0.4), pos + UP * 4.4 + n * 0.2, n, STONE, M.SmoothPlastic, m, true)
	panel(V3(4.4, 7, 0.3), pos + UP * 3.5 + n * 0.4, n, color, M.WoodPlanks, m, true)
	local tr = panel(V3(4.4, 1.1, 0.2), pos + UP * 7.75 + n * 0.35, n, COL.glass, M.SmoothPlastic, m, true)
	tr.Reflectance = 0.25
	Ball(0.55, pos + UP * 3.4 + n * 0.65 + tg * 1.5, COL.brass, M.Metal, m, true)
	P(V3(6.6, 0.6, 2.4), CFrame.lookAt(pos + n * 1.2 + UP * 0.3, pos + n * 2 + UP * 0.3), STONE, M.SmoothPlastic, m)
	local lamp = panel(V3(0.9, 1.3, 0.9), pos + UP * 6.2 + n * 0.8 + tg * 3.8, n, C(255, 236, 196), M.Neon, m, true)
	panel(V3(1.2, 0.3, 1.2), pos + UP * 7.0 + n * 0.8 + tg * 3.8, n, COL.iron, M.Metal, m, true)
	if rng:NextNumber() < 0.5 then
		local pl = Instance.new("PointLight")
		pl.Range = 12
		pl.Brightness = 0.8
		pl.Color = C(255, 220, 170)
		pl.Parent = lamp
	end
end

-- balcó de ferro davant d'una finestra de pis
local function balcony(m, pos, n, tg, width)
	P(V3(width, 0.5, 2.8), CFrame.lookAt(pos + n * 1.4 - UP * 0.25, pos + n * 3 - UP * 0.25), STONE, M.SmoothPlastic, m)
	local top = pos + n * 2.7 + UP * 3.1
	panel(V3(width, 0.3, 0.3), top, n, COL.iron, M.Metal, m, true)
	panel(V3(width, 0.2, 0.2), pos + n * 2.7 + UP * 0.6, n, COL.iron, M.Metal, m, true)
	local nb = math.floor(width / 1.1)
	for k = 0, nb do
		local p = pos + n * 2.7 + tg * (-width / 2 + k * width / nb) + UP * 1.85
		P(V3(0.18, 2.6, 0.18), CF(p), COL.iron, M.Metal, m, true)
	end
	for s = -1, 1, 2 do
		local a = pos + tg * (s * width / 2) + UP * 3.1 + n * 0.2
		beam(a, a + n * 2.5, 0.25, COL.iron, M.Metal, m, true)
	end
end

local function chimney(m, cf, x, z, baseY, h)
	P(V3(2.6, h, 2.6), cf * CF(x, baseY + h / 2, z), COL.brick, M.Brick, m)
	P(V3(3.2, 0.6, 3.2), cf * CF(x, baseY + h + 0.3, z), STONE, M.SmoothPlastic, m)
	for s = -1, 1, 2 do
		VCyl(1.0, 0.7, (cf * CF(x + s * 0.6, baseY + h + 1.1, z)).Position, C(170, 100, 70), M.SmoothPlastic, m, true)
	end
end

-- ── rètol de botiga amb tendal de ratlles ──
local function shopFront(m, pos, n, tg, width, name, rng, noAwning)
	panel(V3(width, 6.4, 0.3), pos + UP * 3.6 + n * 0.3, n, COL.green, M.SmoothPlastic, m, true)
	local g = panel(V3(width - 1.4, 5.2, 0.2), pos + UP * 3.5 + n * 0.45, n, COL.glass, M.SmoothPlastic, m, true)
	g.Reflectance = 0.25
	local sign = panel(V3(width - 1, 1.8, 0.4), pos + UP * 7.6 + n * 0.5, n, COL.green, M.SmoothPlastic, m, true)
	Label(sign, name, COL.brass, Enum.Font.FredokaOne)
	panel(V3(width - 0.6, 0.25, 0.3), pos + UP * 8.6 + n * 0.55, n, COL.brass, M.Metal, m, true)
	if noAwning then
		return
	end
	-- tendal
	local stripes = 6
	local sw = (width - 1) / stripes
	for k = 1, stripes do
		local ap = pos + tg * ((k - (stripes + 1) / 2) * sw) + UP * 9.6 + n * 2.1
		local a = P(V3(sw + 0.02, 0.25, 4.2), CFrame.lookAt(ap, ap + n) * CFrame.Angles(rad(-22), 0, 0), k % 2 == 0 and COL.cream or COL.green, M.SmoothPlastic, m, true)
		a.CastShadow = true
	end
	panel(V3(width - 1, 0.8, 0.25), pos + UP * 8.45 + n * 4.05, n, COL.green, M.SmoothPlastic, m, true)
end

-- ═══════════════════════════ TIPUS DE CASA ═══════════════════════════
local function houseTown(cf, w, d, floors, rng, opt)
	local m = Instance.new("Model")
	m.Name = opt.shop and ("Shop_" .. opt.shop) or "TownHouse"
	local wall = PLASTERS[rng:NextInteger(1, #PLASTERS)]
	local shut = SHUTTERS[rng:NextInteger(1, #SHUTTERS)]
	local roofC = ROOFS[rng:NextInteger(1, #ROOFS)]
	local Hw = floors * FH + 1
	local A = opt.arcade or 0 -- fondària dels porxos (els pisos volen per sobre)
	-- sòcol: 0,25 per fora de la paret. Amb +0,4 les seves cares quedaven al
	-- mateix pla que les de fora de les pilastres de cantonada (w/2 - 0,4 + 0,6)
	-- i feien pampallugues a totes les cantonades
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, M.SmoothPlastic, m)
	if A > 0 then
		local hU = Hw - (FH + 1)
		P(V3(w, hU, A), cf * CF(0, FH + 1 + hU / 2, -d / 2 - A / 2), wall, M.SmoothPlastic, m)
		local nb = math.max(2, math.floor(w / 6.5 + 0.5))
		local bw = w / nb
		local zf = -d / 2 - A + 0.9
		for k = 0, nb do
			local x = math.clamp(-w / 2 + k * bw, -w / 2 + 0.9, w / 2 - 0.9)
			P(V3(1.7, FH + 1, 1.7), cf * CF(x, (FH + 1) / 2, zf), COL.cream, M.SmoothPlastic, m)
			P(V3(2.3, 0.6, 2.3), cf * CF(x, 0.3, zf), STONE, M.SmoothPlastic, m, true)
			P(V3(2.3, 0.6, 2.3), cf * CF(x, FH + 0.6, zf), STONE, M.SmoothPlastic, m, true)
		end
		for k = 0, nb - 1 do
			local xa = -w / 2 + k * bw
			local run = math.min(2.6, bw / 2 - 1)
			for sgn = -1, 1, 2 do
				local xx = sgn < 0 and (xa + 0.85 + run / 2) or (xa + bw - 0.85 - run / 2)
				local rot = CFrame.Angles(0, sgn < 0 and -math.pi / 2 or math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi)
				Wd(V3(1.2, 2.2, run), cf * CF(xx, FH + 1 - 1.1, zf) * rot * WEDGE_FIX, COL.cream, M.SmoothPlastic, m, true)
			end
		end
		P(V3(w, 0.1, A), cf * CF(0, 0.66, -d / 2 - A / 2), C(206, 190, 164), M.SmoothPlastic, m, true)
		for s2 = -1, 1, 2 do
			P(V3(1.3, Hw - FH - 1, 1.3), cf * CF(s2 * (w / 2 - 0.45), FH + 1 + (Hw - FH - 1) / 2, -d / 2 - A + 0.45), COL.cream, M.SmoothPlastic, m, true)
		end
		-- fanalets penjats dins els porxos
		for k = 0, nb - 1 do
			local lp = cf * CF(-w / 2 + (k + 0.5) * bw, FH - 0.8, -d / 2 - A / 2)
			P(V3(0.8, 1.2, 0.8), lp, C(255, 236, 196), M.Neon, m, true)
			P(V3(0.12, 1.4, 0.12), lp * CF(0, 1.2, 0), COL.iron, M.Metal, m, true)
		end
	end
	for f = 1, floors - 1 do
		P(V3(w + 0.3, 0.5, d + A + 0.3), cf * CF(0, 1 + f * FH, -A / 2), COL.cream, M.SmoothPlastic, m)
	end
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(1.3, Hw, 1.3), cf * CF(q[1] * (w / 2 - 0.45), Hw / 2, q[2] * (d / 2 - 0.45)), COL.cream, M.SmoothPlastic, m, true)
	end
	P(V3(w + 1.3, 1.0, d + A + 1.3), cf * CF(0, Hw - 0.2, -A / 2), COL.cream, M.SmoothPlastic, m)
	hipRoof(cf * CF(0, Hw + 0.3, -A / 2), w, d + A, rad(rng:NextNumber(27, 33)), 1.4, roofC, roofC == COL.slate and M.Slate or M.SmoothPlastic, COL.cream, m)
	chimney(m, cf, w * 0.25 * (rng:NextNumber() < 0.5 and -1 or 1), d * 0.18, Hw, 5 + math.min(w, d) * 0.28)
	-- façanes
	for _, which in ipairs({ "F", "L", "R", "B" }) do
		if not (opt.blind and opt.blind[which]) then
			local c, n, tg, len = face(cf, w, d, which)
			local sl = slots(len, 7)
			local doorAt = which == "F" and (#sl >= 3 and math.ceil(#sl / 2) or 1) or -1
			for i, o in ipairs(sl) do
				local base = c + tg * o
				-- planta baixa
				if which == "F" and opt.shop then
					if i == 1 then
						shopFront(m, c, n, tg, math.min(len - 3, 16), opt.shop, rng, A > 0)
					end
				elseif i == doorAt then
					door(m, base + UP * 1.2, n, tg, shut, rng)
				else
					window(m, base + UP * (1 + FH * 0.5 + 0.3), n, tg, { shut = which ~= "B" and shut or nil })
				end
				-- pisos
				local fsh = (which == "F" and A > 0) and n * A or Vector3.zero
				for f = 1, floors - 1 do
					local wp = base + fsh + UP * (1 + f * FH + FH * 0.5 + 0.3)
					local balc = which == "F" and f == 1 and opt.balcony and i == doorAt
					window(m, wp, n, tg, {
						shut = which ~= "B" and shut or nil,
						flowers = which == "F" and not balc and f == 1,
						rng = rng,
						h = balc and 6.2 or 4.6,
					})
					if balc then
						balcony(m, base + fsh + UP * (1 + f * FH + 0.5), n, tg, 8)
					end
				end
			end
		end
	end
	m.Parent = F
	return m
end

local function houseCottage(cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "Cottage"
	local brick = rng:NextNumber() < 0.55
	local wall = brick and COL.brick or PLASTERS[rng:NextInteger(1, #PLASTERS)]
	local shut = SHUTTERS[rng:NextInteger(1, #SHUTTERS)]
	local roofC = rng:NextNumber() < 0.5 and COL.slate or COL.terracotta
	local Hw = FH + 1.5
	-- sòcol: veure houseTown (no al pla de les pilastres)
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, brick and M.Brick or M.SmoothPlastic, m)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		-- 0,1 més altes que la paret: el cap queda dins de la teulada i no al
		-- mateix pla que el de la paret (pampallugues)
		P(V3(1.2, Hw + 0.1, 1.2), cf * CF(q[1] * (w / 2 - 0.4), (Hw + 0.1) / 2, q[2] * (d / 2 - 0.4)), COL.cream, M.SmoothPlastic, m, true)
	end
	local pitch = rad(rng:NextNumber(38, 44))
	local gableC = brick and COL.cream or wall
	local h = gableRoof(cf * CF(0, Hw, 0), w, d, pitch, 1.8, 1.4, roofC, roofC == COL.slate and M.Slate or M.SmoothPlastic, gableC, M.SmoothPlastic, COL.cream, m)
	chimney(m, cf, -w * 0.3, d * 0.1, Hw, h + 3)
	-- lucana (dormer) a la vessant del davant
	do
		local zf = -d / 2 + 2.2
		local yb = Hw + (d / 2 - 2.2) * 0 + 2.2 * math.tan(pitch)
		local dcf = cf * CF(0, 0, zf + 2.5)
		P(V3(5.2, 5, 5), dcf * CF(0, yb + 1.5, 0), gableC, M.SmoothPlastic, m)
		gableRoof(dcf * CF(0, yb + 4, 0) * CFrame.Angles(0, math.pi / 2, 0), 5, 5.2, rad(45), 0.8, 0.6, roofC, roofC == COL.slate and M.Slate or M.SmoothPlastic, gableC, M.SmoothPlastic, COL.cream, m)
		local c, n, tg = face(dcf, 5.2, 5, "F")
		window(m, c + UP * (yb + 1.6), n, tg, { w = 2.6, h = 3.0 })
	end
	-- façana: porta al mig i finestres amb jardinera
	local c, n, tg, len = face(cf, w, d, "F")
	door(m, c + UP * 1.2, n, tg, shut, rng)
	for s = -1, 1, 2 do
		window(m, c + tg * (s * len * 0.3) + UP * 5.6, n, tg, { shut = shut, flowers = true, rng = rng })
	end
	-- porxo sobre la porta
	local pc = c + n * 2.6
	for s = -1, 1, 2 do
		P(V3(0.7, 8.2, 0.7), CF(pc + tg * (s * 3.2) + UP * 4.1), COL.cream, M.WoodPlanks, m)
	end
	P(V3(8.2, 0.5, 3.6), CFrame.lookAt(pc + UP * 8.5, pc + UP * 8.5 + n) * CFrame.Angles(rad(-14), 0, 0), roofC, M.SmoothPlastic, m)
	-- finestres rodones a les golfes i finestres laterals
	for _, which in ipairs({ "L", "R" }) do
		local c2, n2, tg2 = face(cf, w, d, which)
		roundWindow(m, c2 + UP * (Hw + h * 0.35), n2, 2.4)
		window(m, c2 + UP * 5.6, n2, tg2, { shut = shut })
	end
	local c3, n3, tg3 = face(cf, w, d, "B")
	window(m, c3 + UP * 5.6, n3, tg3, {})
	m.Parent = F
	return m
end

local function houseVilla(cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "Villa"
	local wall = PLASTERS[rng:NextInteger(1, #PLASTERS)]
	local shut = SHUTTERS[rng:NextInteger(1, #SHUTTERS)]
	local roofC = ROOFS[rng:NextInteger(1, #ROOFS)]
	local rmat = roofC == COL.slate and M.Slate or M.SmoothPlastic
	local Hw = 2 * FH + 1
	-- sòcol: veure houseTown (no al pla de les pilastres)
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, M.SmoothPlastic, m)
	P(V3(w + 0.3, 0.5, d + 0.3), cf * CF(0, 1 + FH, 0), COL.cream, M.SmoothPlastic, m)
	P(V3(w + 1.3, 1.0, d + 1.3), cf * CF(0, Hw - 0.2, 0), COL.cream, M.SmoothPlastic, m)
	hipRoof(cf * CF(0, Hw + 0.3, 0), w, d, rad(28), 1.5, roofC, rmat, COL.cream, m)
	-- torre a la cantonada del davant
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local tw = 8
	local tcf = cf * CF(side * (w / 2 - tw / 2 + 1), 0, -d / 2 + tw / 2 - 1)
	local Ht = Hw + FH
	P(V3(tw, Ht, tw), tcf * CF(0, Ht / 2, 0), wall, M.SmoothPlastic, m)
	P(V3(tw + 1, 0.9, tw + 1), tcf * CF(0, Ht - 0.2, 0), COL.cream, M.SmoothPlastic, m)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(1.1, Ht, 1.1), tcf * CF(q[1] * (tw / 2 - 0.35), Ht / 2, q[2] * (tw / 2 - 0.35)), COL.cream, M.SmoothPlastic, m, true)
	end
	Pyramid(tcf * CF(0, Ht + 0.3, 0), tw + 2, 8, roofC, rmat, m)
	VCyl(2.2, 0.3, (tcf * CF(0, Ht + 9.3, 0)).Position, COL.brass, M.Metal, m, true)
	Ball(0.9, (tcf * CF(0, Ht + 10.6, 0)).Position, COL.brass, M.Metal, m, true)
	for _, which in ipairs({ "F", "L", "R" }) do
		local c, n, tg = face(tcf, tw, tw, which)
		window(m, c + UP * (Hw + FH * 0.5), n, tg, { shut = shut, w = 3.0, h = 4.4 })
	end
	-- Una finestra de la casa (amb l'ampit d'1 de fondària i els finestrons,
	-- fins a 4 de costat) no pot tocar la torre. La torre surt 1 per davant i
	-- 1 pel costat: l'ampit hi quedava enterrat amb la cara al mateix pla que
	-- la de la torre, i feia pampallugues.
	local function hitsTower(base, n, tg)
		for _, a in ipairs({ -4.1, 0, 4.1 }) do
			for _, b in ipairs({ 0.05, 1.1 }) do
				local l = tcf:PointToObjectSpace(base + tg * a + n * b)
				if math.abs(l.X) < tw / 2 + 0.05 and math.abs(l.Z) < tw / 2 + 0.05 then
					return true
				end
			end
		end
		return false
	end
	-- façanes principals
	for _, which in ipairs({ "F", "L", "R", "B" }) do
		local c, n, tg, len = face(cf, w, d, which)
		local sl = slots(len, 7.5)
		local doorAt = which == "F" and math.ceil(#sl / 2) or -1
		for i, o in ipairs(sl) do
			local base = c + tg * o
			local inTower = hitsTower(base, n, tg)
			if not inTower then
				if i == doorAt then
					door(m, base + UP * 1.2, n, tg, shut, rng)
					-- porxo amb dues columnes i balcó a sobre
					for s = -1, 1, 2 do
						VCyl(FH, 1.2, base + n * 3.2 + tg * (s * 3.6) + UP * (1 + FH / 2), COL.cream, M.SmoothPlastic, m)
					end
					P(V3(9, 0.8, 4.2), CFrame.lookAt(base + n * 2.1 + UP * (FH + 1.3), base + n * 3 + UP * (FH + 1.3)), COL.cream, M.SmoothPlastic, m)
					-- +1,75 i no +1,7: el terra del balcó queda 0,05 per sobre
					-- de la llosa del porxo (al mateix pla feia pampallugues)
					balcony(m, base + n * 1.3 + UP * (FH + 1.75), n, tg, 8.6)
				else
					window(m, base + UP * (1 + FH * 0.5), n, tg, { shut = which ~= "B" and shut or nil, h = 5.4 })
				end
				window(m, base + UP * (1 + FH * 1.5 + 0.3), n, tg, { shut = which ~= "B" and shut or nil, flowers = which == "F", rng = rng })
			end
		end
	end
	m.Parent = F
	return m
end

local function houseBeach(cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "BeachHouse"
	local wall = rng:NextNumber() < 0.6 and COL.cream or PLASTERS[rng:NextInteger(1, 4)]
	local shut = rng:NextNumber() < 0.5 and C(84, 124, 136) or COL.green
	local Hw = 2 * FH + 1
	-- sòcol: veure houseTown (no al pla de les pilastres)
	P(V3(w + 0.5, 1.4, d + 0.5), cf * CF(0, 0.7, 0), STONE, M.SmoothPlastic, m)
	P(V3(w, Hw, d), cf * CF(0, Hw / 2, 0), wall, M.SmoothPlastic, m)
	P(V3(w + 0.3, 0.5, d + 0.3), cf * CF(0, 1 + FH, 0), COL.bone, M.SmoothPlastic, m)
	-- terrat amb ampit
	for _, e in ipairs({ { 0, -d / 2 + 0.4, w, 0.8 }, { 0, d / 2 - 0.4, w, 0.8 }, { -w / 2 + 0.4, 0, 0.8, d }, { w / 2 - 0.4, 0, 0.8, d } }) do
		P(V3(e[3] + 0.4, 2.6, e[4] + 0.4), cf * CF(e[1], Hw + 1.3, e[2]), wall, M.SmoothPlastic, m)
		P(V3(e[3] + 0.9, 0.4, e[4] + 0.9), cf * CF(e[1], Hw + 2.8, e[2]), COL.bone, M.SmoothPlastic, m, true)
	end
	P(V3(w - 1.6, 0.3, d - 1.6), cf * CF(0, Hw + 0.15, 0), C(196, 150, 110), M.WoodPlanks, m)
	-- pèrgola de fusta i para-sol
	local px = w * 0.22
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(0.6, 6, 0.6), cf * CF(px + q[1] * 3.2, Hw + 3, q[2] * (d / 2 - 2.5)), COL.wood, M.WoodPlanks, m)
	end
	for k = -3, 3 do
		P(V3(7.2, 0.4, 0.5), cf * CF(px, Hw + 6.2, k * (d - 5) / 7), COL.wood, M.WoodPlanks, m, true)
	end
	local ux, uz = -w * 0.2, -d * 0.1
	VCyl(5.5, 0.3, (cf * CF(ux, Hw + 2.75, uz)).Position, COL.bone, M.SmoothPlastic, m, true)
	Pyramid(cf * CF(ux, Hw + 5, uz) * CFrame.Angles(0, rad(45), 0), 7, 1.8, COL.green, M.SmoothPlastic, m, { COL.green, COL.cream, COL.green, COL.cream })
	for s = -1, 1, 2 do
		P(V3(2, 0.5, 5), cf * CF(ux + s * 2.6, Hw + 0.8, uz + 3.8), COL.cream, M.SmoothPlastic, m)
	end
	-- façanes: finestrals grans a baix, finestres amb porticons a dalt
	for _, which in ipairs({ "F", "L", "R", "B" }) do
		local c, n, tg, len = face(cf, w, d, which)
		local sl = slots(len, 7.5)
		local doorAt = which == "F" and math.ceil(#sl / 2) or -1
		for i, o in ipairs(sl) do
			local base = c + tg * o
			if i == doorAt then
				door(m, base + UP * 1.2, n, tg, shut, rng)
			else
				window(m, base + UP * (1 + FH * 0.5), n, tg, { w = 4.2, h = 5.4, frame = COL.bone })
			end
			window(m, base + UP * (1 + FH * 1.5 + 0.3), n, tg, { shut = shut, frame = COL.bone, flowers = which == "F", rng = rng, box = COL.bone })
		end
	end
	-- porxo de fusta al davant
	local c, n, tg, len = face(cf, w, d, "F")
	P(V3(len, 0.6, 5), CFrame.lookAt(c + n * 2.5 + UP * 0.9, c + n * 4 + UP * 0.9), C(196, 150, 110), M.WoodPlanks, m)
	for k = -1, 1, 2 do
		P(V3(0.5, 3, 0.5), CF(c + n * 4.8 + tg * (k * (len / 2 - 0.4)) + UP * 2.4), COL.bone, M.SmoothPlastic, m, true)
	end
	panel(V3(len, 0.4, 0.4), c + n * 4.8 + UP * 3.8, n, COL.bone, M.SmoothPlastic, m, true)
	m.Parent = F
	return m
end

-- ── jardinet del davant: tanca de fusta, camí i flors ──
local function frontGarden(cf, lotW, depth, rng)
	local m = Instance.new("Model")
	m.Name = "Garden"
	local c, n, tg = face(cf, lotW, 0, "F")
	local gate = 3
	for s = -1, 1, 2 do
		local a0, a1 = gate, lotW / 2 - 0.4
		local mid = c + tg * (s * (a0 + a1) / 2)
		for _, y in ipairs({ 1.2, 2.6 }) do
			P(V3(a1 - a0, 0.3, 0.25), CFrame.lookAt(mid + UP * y, mid + UP * y + n), COL.cream, M.WoodPlanks, m, true)
		end
		local k = a0
		while k <= a1 do
			P(V3(0.5, 3.4, 0.3), CFrame.lookAt(c + tg * (s * k) + UP * 1.7, c + tg * (s * k) + UP * 1.7 + n), COL.cream, M.WoodPlanks, m, true)
			k += 1.3
		end
		-- parterre de flors
		for q = 1, 3 do
			local fp = c + tg * (s * rng:NextNumber(4.5, lotW / 2 - 2)) - n * rng:NextNumber(1.5, depth - 1.5)
			Ball(rng:NextNumber(1.8, 2.6), fp + UP * 0.7, COL.leafDark, M.SmoothPlastic, m, true)
			Ball(0.9, fp + UP * 1.7, FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, m, true)
		end
	end
	P(V3(2.8, 0.25, depth), CFrame.lookAt(c - n * (depth / 2) + UP * 0.12, c - n * depth + UP * 0.12), STONE, M.SmoothPlastic, m, true)
	m.Parent = F
end

-- ═══════════════════════════ REPARTIMENT PER ILLES ═══════════════════════════
local SHOP_NAMES = { "DINO DINER", "FOSSIL TRADE", "MAMMOTH CAFÉ", "ICE AGE GELATO", "JURASSIC BOOKS", "AMMONITE BAKERY", "SOUVENIRS", "TOOLS & BRUSHES" }
local shopIdx = 0
local count = 0
local SIDE = {
	N = function(b)
		return b[1], b[2], b[3], V3(0, 0, -1)
	end,
	S = function(b)
		return b[1], b[2], b[4], V3(0, 0, 1)
	end,
	W = function(b)
		return b[3], b[4], b[1], V3(-1, 0, 0)
	end,
	E = function(b)
		return b[3], b[4], b[2], V3(1, 0, 0)
	end,
}
local LOT_D = 24
local PZ = LAYOUT.PLAZA
local OB = LAYOUT.OBRA
local function facesPlaza(sideCh, fixed, a0, a1)
	if sideCh == "E" then
		return math.abs(fixed - PZ.x0) < 1 and a1 > PZ.z0 and a0 < PZ.z1
	elseif sideCh == "W" then
		return math.abs(fixed - PZ.x1) < 1 and a1 > PZ.z0 and a0 < PZ.z1
	elseif sideCh == "S" then
		return math.abs(fixed - PZ.z0) < 1 and a1 > PZ.x0 and a0 < PZ.x1
	elseif sideCh == "N" then
		return math.abs(fixed - PZ.z1) < 1 and a1 > PZ.x0 and a0 < PZ.x1
	end
	return false
end
for bi, b in ipairs(LAYOUT.BLOCKS) do
	local sides = b[5]
	local nearPlaza = b[2] > PZ.x0 - 30 and b[1] < PZ.x1 + 30 and b[4] > PZ.z0 - 30 and b[3] < PZ.z1 + 30
	local beachBlock = b[2] >= 160
	for sideCh in sides:gmatch(".") do
		local a0, a1, fixed, nrm = SIDE[sideCh](b)
		local horiz = sideCh == "N" or sideCh == "S"
		if not horiz and (sides:find("N") or sides:find("S")) then
			if sides:find("N") then
				a0 += LOT_D
			end
			if sides:find("S") then
				a1 -= LOT_D
			end
		end
		local len = a1 - a0
		local plazaSide = facesPlaza(sideCh, fixed, a0, a1)
		if len >= 18 then
			local nLots = math.max(1, math.floor(len / (plazaSide and 22 or 25)))
			local lotW = len / nLots
			for li = 1, nLots do
				local ac = a0 + (li - 0.5) * lotW
				local front = horiz and V3(ac, 0, fixed) or V3(fixed, 0, ac)
				local seed = math.floor(ac * 7 + fixed * 13 + bi * 101)
				local rng = Random.new(seed)
				local kind
				if plazaSide then
					kind = "shop"
				elseif beachBlock and sideCh == "E" then
					kind = "beach"
				elseif nearPlaza then
					kind = "town"
				else
					local r = rng:NextNumber()
					kind = r < 0.36 and "cottage" or (r < 0.6 and "villa" or "town")
				end
				local terraced = kind == "shop" or (kind == "town" and nearPlaza)
				local w = terraced and (lotW - 0.6) or math.min(lotW - rng:NextNumber(4, 7), 22)
				local d = kind == "cottage" and rng:NextNumber(14, 16) or rng:NextNumber(15, 18)
				local arcade = kind == "shop" and 5 or 0
				local setback = kind == "shop" and 0.5 or (terraced and 1.5 or (kind == "beach" and 7 or rng:NextNumber(5.5, 7)))
				local center = front - nrm * (setback + arcade + d / 2)
				-- cap casa sobre un museu ni dins l'obra
				local blocked = inRects(center.X, center.Z, LAYOUT.MUSEUM_RECTS, 9)
					or (center.X > OB.x0 - 12 and center.X < OB.x1 + 20 and center.Z > OB.z0 - 12 and center.Z < OB.z1 + 12)
				if not blocked then
					local cf = CFrame.lookAt(center, center + nrm)
					local blind = terraced and { L = li > 1, R = li < nLots } or nil
					if kind == "shop" then
						shopIdx += 1
						houseTown(cf, w, d, 3, rng, { shop = SHOP_NAMES[(shopIdx - 1) % #SHOP_NAMES + 1], balcony = true, blind = blind, arcade = arcade })
					elseif kind == "town" then
						houseTown(cf, w, d, rng:NextInteger(2, 3), rng, { balcony = rng:NextNumber() < 0.6, blind = blind })
					elseif kind == "cottage" then
						houseCottage(cf, w, d, rng)
					elseif kind == "villa" then
						houseVilla(cf, math.max(w, 18), d, rng)
					else
						houseBeach(cf, w, d, rng)
					end
					if not terraced then
						local gcf = CFrame.lookAt(front - nrm * 0.2, front - nrm * 0.2 + nrm)
						frontGarden(gcf, lotW - 1, setback - 0.6, rng)
					end
					count += 1
				end
			end
		end
	end
end
-- dues cases a l'est de l'obra, entre la tanca i el carrer (on hi havia el pati d'obra)
do
	local E = LAYOUT.EAST_LOTS
	local nrm = V3(1, 0, 0)
	local lotW = (E.z1 - E.z0) / 2
	for li = 1, 2 do
		local rng = Random.new(4242 + li)
		local front = V3(E.x1, 0, E.z0 + (li - 0.5) * lotW)
		local w = lotW - rng:NextNumber(2.5, 3.5)
		local d = rng:NextNumber(14, 15.5)
		local setback = rng:NextNumber(5.5, 6.5)
		local center = front - nrm * (setback + d / 2)
		local cf = CFrame.lookAt(center, center + nrm)
		if li == 1 then
			houseCottage(cf, w, d, rng)
		else
			houseTown(cf, w, d, 2, rng, { balcony = true })
		end
		frontGarden(CFrame.lookAt(front - nrm * 0.2, front - nrm * 0.2 + nrm), lotW - 1, setback - 0.6, rng)
		count += 1
	end
end
print(("Cases: %d (botigues %d)"):format(count, shopIdx))

end }
STEPS[#STEPS + 1] = { "04_museums", function()
-- ═══════════════════════════ 04 · MUSEUS (8, tots iguals) ═══════════════════════════
-- Un sol disseny modern repetit a les 8 parcel·les (70 x 52): gran vestíbul de
-- vidre entre dos volums de pedra amb aletes, marquesina volada amb el nom del
-- propietari, banderoles i, a dins, una galeria lluminosa amb 10 vitrines de
-- vidre (sòcol blanc, llum de raresa a la base i focus des del sostre).
-- Contracte amb el joc (src/server/Services/MuseumService.luau), NO es pot trencar:
--   · Model a Workspace.Museums, nom "Plot<i>", etiqueta "MuseumPlot"
--   · "Slot1".."Slot10" (sòcols, girats 90° perquè l'exhibició es vegi de perfil)
--   · "Glow1".."Glow10" (llum de la base, el servidor hi posa el color de raresa)
--   · "Plaque1".."Plaque10" (plaques amb TextLabel)
--   · "OwnerSign" amb un TextLabel ("FREE MUSEUM" / "<NOM>'S MUSEUM")
--   · "Entry" (on apareix el jugador) i un coixí amb ProximityPrompt i etiqueta "ToCity"
-- Marc local: origen al centre de la parcel·la, la façana mira a -Z.
local FLOOR = 1.2
local IH = 22 -- alçada interior
local TOP = FLOOR + IH
local STONE = C(236, 230, 216) -- pedra clara
local STONE2 = C(214, 206, 190)
local DARK = C(40, 42, 46) -- perfileria
local CHAR = C(52, 54, 58)
local GLASSC = C(176, 210, 220)
local OAK = C(196, 158, 116)
local FLOORC = C(238, 234, 226)
local WALLC = C(246, 243, 236)
local LED = C(255, 244, 222)
local EXHIBITS = { "T-REX", "TRICERATOPS", "MAMMOTH", "AMMONITES", "PTERODACTYL", "DIPLODOCUS", "STEGOSAURUS", "MEGALODON" }

-- carcassa: x ∈ [-32, 32], z ∈ [-14, 26]; interior x ∈ [-30.8, 30.8], z ∈ [-12.8, 24.8]
local SX, Z0, Z1 = 32, -14, 26
local IX, IZ0, IZ1 = 30.8, -12.8, 24.8
local HALLX = 12 -- mig ample del vestíbul de vidre
local ZCAN = -22 -- vora de la marquesina

-- vitrines: {x, z}. Sis als costats (mirant al passadís) i quatre al centre.
local CASES = {
	{ -24, -2 }, { -24, 9 }, { -24, 20 },
	{ -9, 3.5 }, { -9, 15 },
	{ 9, 3.5 }, { 9, 15 },
	{ 24, -2 }, { 24, 9 }, { 24, 20 },
}

local function Bx(m, O, x, y, z, sx, sy, sz, color, mat, deco)
	return P(V3(sx, sy, sz), O * CF(x, y, z), color, mat or M.SmoothPlastic, m, deco)
end
local function glass(m, O, x, y, z, sx, sy, sz, tr)
	local g = Bx(m, O, x, y, z, sx, sy, sz, GLASSC, M.Glass)
	g.Transparency = tr or 0.6
	g.Reflectance = 0.12
	return g
end
local function text(m, O, x, y, z, w, h, str, fg, bg, font, facing)
	local p = Bx(m, O, x, y, z, w, h, 0.2, bg or STONE, M.SmoothPlastic, true)
	if facing then
		p.CFrame = p.CFrame * CFrame.Angles(0, math.pi, 0)
	end
	local t = Label(p, str, fg, font or Enum.Font.GothamBlack)
	return p, t
end
local function ammonite(m, pos, n, size, col)
	local base = CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, rad(90), 0)
	for k, f in ipairs({ 1, 0.74, 0.5, 0.28 }) do
		Cyl(0.25 + k * 0.08, size * f, base * CF(k * 0.08, 0, 0), k % 2 == 1 and (col or COL.brass) or STONE, M.Metal, m, true)
	end
	local right = CFrame.lookAt(pos, pos + n).RightVector
	for k = 0, 9 do
		local a = k * 0.62
		local r = size * (0.46 - k * 0.035)
		Ball(size * 0.09, pos + n * 0.55 + (right * math.cos(a) + UP * math.sin(a)) * r, col or COL.brass, M.Metal, m, true)
	end
end

-- pterodàctil penjat (esquelet), centrat a cf, mirant cap a -Z
local function pterosaur(m, cf, s)
	local B = COL.bone
	local function bb(a, b, th)
		beam((cf * CF(a.X * s, a.Y * s, a.Z * s)).Position, (cf * CF(b.X * s, b.Y * s, b.Z * s)).Position, th * s, B, M.Marble, m, true)
	end
	Ellipsoid(V3(1.3 * s, 1 * s, 3.4 * s), cf, B, M.Marble, m, true)
	bb(V3(0, 0.2, -1.6), V3(0, 1, -3.6), 0.35)
	Ellipsoid(V3(0.8 * s, 0.9 * s, 2.2 * s), cf * CF(0, 1.2 * s, -4.6 * s) * CFrame.Angles(rad(-12), 0, 0), B, M.Marble, m, true)
	bb(V3(0, 1.3, -5.6), V3(0, 1.1, -8.2), 0.3)
	bb(V3(0, 1.6, -4), V3(0, 2.6, -2.6), 0.25)
	Ball(0.35 * s, (cf * CF(0.35 * s, 1.4 * s, -4.9 * s)).Position, COL.uiBg, M.SmoothPlastic, m, true)
	bb(V3(0, 0, 1.6), V3(0, -0.3, 3.4), 0.2)
	for sx = -1, 1, 2 do
		local sh = V3(sx * 0.6, 0.3, -0.8)
		local el = V3(sx * 3.2, 0.8, -1.2)
		local wr = V3(sx * 5.4, 0.6, -0.6)
		local tip = V3(sx * 11.5, 0.2, 1.4)
		bb(sh, el, 0.3)
		bb(el, wr, 0.26)
		bb(wr, tip, 0.2)
		bb(wr, V3(sx * 6.4, 0.9, -1.4), 0.12)
		bb(V3(sx * 0.4, -0.4, 1), V3(sx * 1.6, -1.6, 1.8), 0.2)
		local a = (cf * CF(sh.X * s, sh.Y * s, sh.Z * s)).Position
		local b = (cf * CF(tip.X * s, tip.Y * s, tip.Z * s)).Position
		local c = (cf * CF(sx * 1.2 * s, 0.1 * s, 1.6 * s)).Position
		local mid = (a + b + c) / 3
		local mem = P(V3((b - a).Magnitude, 0.08, 2.6 * s), CFrame.lookAt(mid, mid + (b - a).Unit:Cross(UP)) * CFrame.Angles(0, rad(90), 0), C(236, 222, 196), M.SmoothPlastic, m, true)
		mem.Transparency = 0.55
	end
	for sx = -1, 1, 2 do
		P(V3(0.06, 9, 0.06), cf * CF(sx * 3 * s, 4.6, -0.8 * s), DARK, M.Metal, m, true)
	end
end

-- ── una vitrina: sòcol amb llum de raresa, caixa de vidre, focus i placa ──
local function showcase(m, O, k, x, z)
	local face = -math.sign(x) -- cap a on hi ha el passadís
	-- sòcol fosc a terra i franja de llum (el servidor la pinta del color de raresa)
	Bx(m, O, x, FLOOR + 0.2, z, 8.8, 0.4, 8.8, CHAR, M.SmoothPlastic)
	local glow = Bx(m, O, x, FLOOR + 0.5, z, 8.4, 0.2, 8.4, C(120, 124, 132), M.Neon, true)
	glow.Name = "Glow" .. k
	-- sòcol blanc: és el "Slot", girat 90° perquè l'exhibició es vegi de perfil
	local slot = P(V3(8, 2.2, 8), O * CF(x, FLOOR + 1.7, z) * CFrame.Angles(0, rad(90), 0), C(250, 248, 244), M.SmoothPlastic, m)
	slot.Name = "Slot" .. k
	local ytop = FLOOR + 2.8
	Bx(m, O, x, ytop + 0.03, z, 8.1, 0.06, 8.1, C(232, 228, 220), M.SmoothPlastic, true)
	-- caixa de vidre (parets, tapa) amb perfil fosc
	local GH = 6.6
	for _, e in ipairs({ { 0, 4.1, 8.2, 0.15 }, { 0, -4.1, 8.2, 0.15 }, { 4.1, 0, 0.15, 8.2 }, { -4.1, 0, 0.15, 8.2 } }) do
		local g = Bx(m, O, x + e[1], ytop + GH / 2, z + e[2], e[3], GH, e[4], GLASSC, M.Glass)
		g.Transparency = 0.78
		g.Reflectance = 0.1
	end
	local lid = Bx(m, O, x, ytop + GH + 0.08, z, 8.35, 0.16, 8.35, GLASSC, M.Glass, true)
	lid.Transparency = 0.7
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		Bx(m, O, x + q[1] * 4.1, ytop + GH / 2, z + q[2] * 4.1, 0.22, GH, 0.22, DARK, M.Metal, true)
	end
	-- perfil de la tapa: 0,28 d'alt perquè la seva cara de sota quedi 0,04
	-- per sota de la del vidre (amb 0,22 hi quedava a 0,01 i feien pampallugues)
	for _, e in ipairs({ { 0, 4.1, 8.4, 0.22 }, { 0, -4.1, 8.4, 0.22 }, { 4.1, 0, 0.22, 8.4 }, { -4.1, 0, 0.22, 8.4 } }) do
		Bx(m, O, x + e[1], ytop + GH + 0.1, z + e[2], e[3], 0.28, e[4], DARK, M.Metal, true)
	end
	-- focus penjat del sostre
	Bx(m, O, x, TOP - 0.5, z, 1.2, 0.8, 1.2, DARK, M.Metal, true)
	local lens = Bx(m, O, x, TOP - 0.95, z, 0.9, 0.1, 0.9, LED, M.Neon, true)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 42
	spot.Range = 26
	spot.Brightness = 2.2
	spot.Color = C(255, 240, 216)
	spot.Parent = lens
	-- placa inclinada davant la vitrina, mirant al passadís
	local pp = (O * CF(x + face * 5.1, FLOOR + 1.6, z)).Position
	local look = CFrame.lookAt(pp, pp + O.RightVector * face) * CFrame.Angles(rad(-28), 0, 0)
	local plaque = P(V3(3.6, 1.4, 0.2), look, CHAR, M.SmoothPlastic, m, true)
	plaque.Name = "Plaque" .. k
	Label(plaque, "EMPTY CASE", COL.bone, Enum.Font.GothamBold)
	P(V3(0.2, 1.4, 0.2), CF(pp - UP * 0.8), DARK, M.Metal, m, true)
end

local function buildMuseum(O, index)
	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	local n = O.LookVector

	-- ── sòcol de tota la parcel·la i escales al davant ──
	Bx(m, O, 0, FLOOR / 2, 0, 70, FLOOR, 52, STONE2, M.Limestone)
	for k = 1, 2 do
		local h = FLOOR - k * 0.4
		Bx(m, O, 0, h / 2, -26 - (k - 0.5) * 1.3, 40 + k * 1.2, h, 1.3, STONE2, M.Limestone)
	end
	-- paviment de l'esplanada amb una franja fosca cap a la porta
	Bx(m, O, 0, FLOOR + 0.02, -20, 8, 0.05, 12, CHAR, M.SmoothPlastic, true)

	-- ── carcassa: dos volums de pedra amb aletes verticals ──
	for s = -1, 1, 2 do
		local cx = s * (HALLX + (SX - HALLX) / 2)
		local w = SX - HALLX
		Bx(m, O, cx, FLOOR + IH / 2, Z0 + 0.6, w, IH, 1.2, STONE, M.Limestone)
		for k = 0, math.floor(w / 2.5) do
			local fxp = s * HALLX + s * (1 + k * 2.5)
			if math.abs(fxp) < SX - 0.5 then
				Bx(m, O, fxp, FLOOR + IH / 2, Z0 - 0.3, 0.45, IH, 0.8, STONE2, M.Limestone, true)
			end
		end
		-- banderola penjada
		local bn = Bx(m, O, cx, FLOOR + 11, Z0 - 0.9, 6, 13, 0.15, s < 0 and C(120, 70, 200) or C(214, 150, 40), M.Fabric, true)
		Label(bn, s < 0 and "🦖" or "🦴", C(255, 255, 255), Enum.Font.GothamBlack, Enum.NormalId.Front, 20)
		local bt = Bx(m, O, cx, FLOOR + 5.6, Z0 - 1, 6, 1.6, 0.15, s < 0 and C(120, 70, 200) or C(214, 150, 40), M.Fabric, true)
		Label(bt, s < 0 and "DINOSAURS" or "FOSSILS", C(255, 255, 255), Enum.Font.GothamBlack)
		Bx(m, O, cx, FLOOR + 17.8, Z0 - 0.95, 6.6, 0.3, 0.3, DARK, M.Metal, true)
		-- parets laterals i del fons
		Bx(m, O, s * (SX - 0.6), FLOOR + IH / 2, (Z0 + Z1) / 2, 1.2, IH, Z1 - Z0, STONE, M.Limestone)
	end
	Bx(m, O, 0, FLOOR + IH / 2, Z1 - 0.6, 2 * SX, IH, 1.2, STONE, M.Limestone)

	-- ── vestíbul de vidre amb muntants i portes obertes ──
	for s = -1, 1, 2 do
		glass(m, O, s * (4 + (HALLX - 4) / 2), FLOOR + IH / 2, Z0 + 0.3, HALLX - 4, IH, 0.3, 0.55)
	end
	glass(m, O, 0, FLOOR + 12 + (IH - 12) / 2, Z0 + 0.3, 8, IH - 12, 0.3, 0.55)
	for x = -HALLX, HALLX, 4 do
		if math.abs(x) < 4 then
			-- dins la porta: el muntant només va del travesser cap amunt
			Bx(m, O, x, FLOOR + 12 + (IH - 12) / 2, Z0 + 0.1, 0.35, IH - 12, 0.5, DARK, M.Metal)
		else
			Bx(m, O, x, FLOOR + IH / 2, Z0 + 0.1, 0.35, IH, 0.5, DARK, M.Metal)
		end
	end
	for _, y in ipairs({ FLOOR + 12.2, FLOOR + 17.5 }) do
		Bx(m, O, 0, y, Z0 + 0.1, 2 * HALLX, 0.35, 0.5, DARK, M.Metal)
	end
	for s = -1, 1, 2 do
		local hinge = O * CF(s * 4, FLOOR + 5.9, Z0 + 0.4)
		local door = P(V3(3.8, 11.6, 0.2), hinge * CFrame.Angles(0, rad(-s * 80), 0) * CF(-s * 1.9, 0, 0), GLASSC, M.Glass, m, true)
		door.Transparency = 0.5
	end

	-- ── coberta amb claraboies ──
	local ry = TOP + 0.6
	Bx(m, O, 0, ry, (Z0 + Z1) / 2, 2 * SX + 1, 1.2, Z1 - Z0 + 1, STONE, M.Limestone)
	for _, x in ipairs({ -16.5, 16.5 }) do
		local sk = glass(m, O, x, ry + 0.7, 6, 5, 0.3, 26, 0.35)
		sk.CanCollide = true
		Bx(m, O, x, ry + 0.9, 6, 5.4, 0.3, 26.4, DARK, M.Metal, true).Transparency = 0.7
	end
	-- ampit amb coronament fosc
	for _, e in ipairs({ { 0, Z0, 2 * SX + 1, 0.8 }, { 0, Z1, 2 * SX + 1, 0.8 }, { -SX, (Z0 + Z1) / 2, 0.8, Z1 - Z0 }, { SX, (Z0 + Z1) / 2, 0.8, Z1 - Z0 } }) do
		Bx(m, O, e[1], ry + 1.3, e[2], e[3], 1.4, e[4], STONE, M.Limestone)
		Bx(m, O, e[1], ry + 2.05, e[2], e[3] + 0.1, 0.15, e[4] + 0.1, DARK, M.Metal, true)
	end
	-- logotip al capdamunt del vestíbul
	text(m, O, 0, FLOOR + 20, Z0 - 0.3, 20, 2.2, "FOSSIL MUSEUM", COL.brass, CHAR)

	-- ── marquesina volada, sotacoberta de fusta i llums ──
	local cy = FLOOR + 13.5
	Bx(m, O, 0, cy, (ZCAN + Z0) / 2, 34, 1.1, Z0 - ZCAN, WALLC, M.SmoothPlastic)
	Bx(m, O, 0, cy - 0.6, (ZCAN + Z0) / 2, 33.4, 0.1, Z0 - ZCAN - 0.4, OAK, M.WoodPlanks, true)
	for _, x in ipairs({ -12, -4, 4, 12 }) do
		local d = Bx(m, O, x, cy - 0.68, ZCAN + 3, 1.2, 0.08, 1.2, LED, M.Neon, true)
		if x == -4 or x == 4 then
			local pl = Instance.new("PointLight")
			pl.Range = 16
			pl.Brightness = 0.9
			pl.Color = C(255, 230, 196)
			pl.Parent = d
		end
	end
	for s = -1, 1, 2 do
		VCyl(cy - FLOOR, 0.6, (O * CF(s * 15.5, FLOOR + (cy - FLOOR) / 2, ZCAN + 1)).Position, DARK, M.Metal, m)
	end
	-- rètol del propietari a la vora de la marquesina: lletres daurades sobre fosc
	local sign = Bx(m, O, 0, cy, ZCAN - 0.08, 32, 1.6, 0.2, CHAR, M.SmoothPlastic)
	sign.Name = "OwnerSign"
	local g = Instance.new("SurfaceGui")
	g.Name = "SignGui"
	g.Face = Enum.NormalId.Front
	g.LightInfluence = 0
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "FREE MUSEUM"
	lbl.TextColor3 = C(255, 206, 110)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = g

	-- ── esplanada: jardineres, estany amb ammonita i pilones ──
	for s = -1, 1, 2 do
		local px = s * 25
		Bx(m, O, px, FLOOR + 0.9, -20, 12, 1.8, 7, STONE2, M.Limestone)
		Bx(m, O, px, FLOOR + 1.85, -20, 11.2, 0.1, 6.2, C(84, 66, 46), M.Ground, true)
		VCyl(4, 0.6, (O * CF(px, FLOOR + 3.8, -20)).Position, COL.woodDark, M.Wood, m)
		Ellipsoid(V3(6, 4.6, 6), O * CF(px, FLOOR + 7.4, -20), COL.leaf, M.SmoothPlastic, m)
		for q = -1, 1, 2 do
			Ellipsoid(V3(2.4, 1.6, 2.4), O * CF(px + q * 3.6, FLOOR + 2.5, -20), COL.leafDark, M.Grass, m, true)
		end
	end
	Bx(m, O, 16, FLOOR + 0.3, -24.2, 8, 0.6, 3.2, STONE2, M.Limestone)
	local water = Bx(m, O, 16, FLOOR + 0.62, -24.2, 7.4, 0.1, 2.6, C(70, 150, 170), M.Glass, true)
	water.Transparency = 0.15
	ammonite(m, (O * CF(16, FLOOR + 2.4, -24.2)).Position, n, 2.6)
	for _, x in ipairs({ -6, 6 }) do
		local bp = (O * CF(x, FLOOR, -25)).Position
		VCyl(2, 0.8, bp + UP * 1, DARK, M.Metal, m)
		VCyl(0.14, 0.85, bp + UP * 1.7, LED, M.Neon, m, true)
	end

	-- ══════════════ INTERIOR ══════════════
	-- terra de pedra polida, passadís central fosc amb filet de llautó
	Bx(m, O, 0, FLOOR + 0.02, (IZ0 + IZ1) / 2, 2 * IX, 0.04, IZ1 - IZ0, FLOORC, M.Marble, true)
	Bx(m, O, 0, FLOOR + 0.05, (IZ0 + IZ1) / 2, 7, 0.05, IZ1 - IZ0 - 2, CHAR, M.SmoothPlastic, true)
	for s = -1, 1, 2 do
		Bx(m, O, s * 3.6, FLOOR + 0.06, (IZ0 + IZ1) / 2, 0.2, 0.05, IZ1 - IZ0 - 2, COL.brass, M.Metal, true)
	end
	-- parets: sòcol de roure i filet de llautó
	for s = -1, 1, 2 do
		Bx(m, O, s * (IX - 0.1), FLOOR + 2, (IZ0 + IZ1) / 2, 0.2, 4, IZ1 - IZ0, OAK, M.WoodPlanks, true)
		Bx(m, O, s * (IX - 0.15), FLOOR + 4.1, (IZ0 + IZ1) / 2, 0.2, 0.15, IZ1 - IZ0, COL.brass, M.Metal, true)
		Bx(m, O, s * (IX - 0.05), FLOOR + IH / 2 + 2, (IZ0 + IZ1) / 2, 0.1, IH - 4, IZ1 - IZ0, WALLC, M.SmoothPlastic, true)
	end
	Bx(m, O, 0, FLOOR + 2, IZ1 - 0.1, 2 * IX, 4, 0.2, OAK, M.WoodPlanks, true)
	Bx(m, O, 0, FLOOR + 4.1, IZ1 - 0.15, 2 * IX, 0.15, 0.2, COL.brass, M.Metal, true)
	-- sostre blanc i tires de LED
	Bx(m, O, 0, TOP - 0.05, (IZ0 + IZ1) / 2, 2 * IX, 0.1, IZ1 - IZ0, WALLC, M.SmoothPlastic, true)
	for _, x in ipairs({ -9, 9 }) do
		Bx(m, O, x, TOP - 0.15, (IZ0 + IZ1) / 2, 0.5, 0.1, IZ1 - IZ0 - 4, LED, M.Neon, true)
	end

	-- vitrines
	for k, c in ipairs(CASES) do
		showcase(m, O, k, c[1], c[2])
	end

	-- mur del fons: gran panell amb l'ammonita i el nom
	Bx(m, O, 0, FLOOR + 12, IZ1 - 0.3, 24, 12, 0.2, C(38, 70, 60), M.SmoothPlastic, true)
	ammonite(m, (O * CF(0, FLOOR + 14.2, IZ1 - 0.45)).Position, n, 6.4)
	text(m, O, 0, FLOOR + 8.2, IZ1 - 0.45, 20, 1.8, "FOSSIL MUSEUM", COL.brass, C(38, 70, 60), Enum.Font.GothamBlack)
	-- quadres de dinosaures a les parets de sobre les vitrines laterals
	for s = -1, 1, 2 do
		for i, z in ipairs({ -2, 9, 20 }) do
			local c = (O * CF(s * (IX - 0.25), FLOOR + 13, z)).Position
			local nn = -O.RightVector * s
			P(V3(7.4, 5.4, 0.2), CFrame.lookAt(c, c + nn), OAK, M.WoodPlanks, m, true)
			local art = P(V3(6.6, 4.6, 0.2), CFrame.lookAt(c + nn * 0.12, c + nn * 2), C(38, 70, 60), M.SmoothPlastic, m, true)
			Label(art, ({ "🦖", "🦕", "🦴", "🐚", "🦣", "🦅" })[(i + (s > 0 and 3 or 0) + index) % 6 + 1], C(255, 255, 255), Enum.Font.GothamBlack)
		end
	end

	-- vestíbul: taulell d'informació i botiga de records
	Bx(m, O, -22, FLOOR + 1.6, -9, 10, 3.2, 3, WALLC, M.SmoothPlastic)
	Bx(m, O, -22, FLOOR + 3.3, -9, 10.4, 0.25, 3.4, OAK, M.WoodPlanks)
	text(m, O, -22, FLOOR + 2, -10.55, 4, 1, "INFO", COL.brass, CHAR)
	Bx(m, O, 22, FLOOR + 3.5, -11.9, 12, 7, 1.6, OAK, M.WoodPlanks)
	for k = 0, 2 do
		for q = -2, 2 do
			Ball(0.9, (O * CF(22 + q * 2.2, FLOOR + 1.6 + k * 2.4, -10.9)).Position, ({ COL.bone, COL.brass, C(120, 70, 200), C(56, 148, 255) })[(k + q) % 4 + 1], M.SmoothPlastic, m, true)
		end
	end
	text(m, O, 22, FLOOR + 7.6, -11.05, 8, 1.1, "GIFT SHOP", COL.brass, CHAR)

	-- pterodàctil penjat sobre el passadís
	pterosaur(m, O * CF(0, TOP - 5.5, 9) * CFrame.Angles(rad(-4), rad(18), rad(6)), 1.1)

	-- ── arribada i sortida (joc) ──
	local entry = Bx(m, O, 0, FLOOR + 0.15, -10, 6, 0.3, 3, COL.brass, M.Metal)
	entry.Name = "Entry"
	entry.CastShadow = false
	local back = Bx(m, O, 8, FLOOR + 0.25, -11.2, 4, 0.5, 2.6, C(38, 70, 60), M.SmoothPlastic)
	back.Name = "BackPad"
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "GoCity"
	pr.ActionText = "Back to town"
	pr.ObjectText = "Exit"
	pr.HoldDuration = 0.3
	pr.MaxActivationDistance = 10
	pr.Parent = back
	tag(back, "ToCity")
	local ep = (O * CF(8, FLOOR + 14, Z0 + 0.7)).Position
	local es = P(V3(4.4, 1.2, 0.2), CFrame.lookAt(ep, ep - n), C(40, 150, 90), M.SmoothPlastic, m, true)
	Label(es, "EXIT", COL.bone, Enum.Font.GothamBlack)

	tag(m, "MuseumPlot")
	m.Parent = MUSEUMS
	return m
end

for i, mu in ipairs(LAYOUT.MUSEUMS) do
	local c = V3(mu[3], 0, mu[4])
	local O = CFrame.lookAt(c, c + V3(mu[5], 0, mu[6]))
	local ok, err = pcall(buildMuseum, O, i)
	if not ok then
		warn("Museu " .. i .. ": " .. tostring(err))
	end
end
print("Museus: " .. #LAYOUT.MUSEUMS .. " (70x52, 10 vitrines de vidre)")

end }
STEPS[#STEPS + 1] = { "05_plaza", function()
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

end }
STEPS[#STEPS + 1] = { "06_beach", function()
-- ═══════════════════════════ 06 · PLATJA ═══════════════════════════
-- Platja moderna: passeig amb barana de vidre, cabanes blanques, palmeres,
-- para-sols de colors, beach club, moll, far, torre de socorrista, castells,
-- roques i forats a la sorra per excavar (DigSpot).
-- Palmeres, para-sols, socorrista, castells i roques són models de la
-- Toolbox (lib: Asset, sense scripts).
local F = folder("Beach", WORLD)
local PX0, PX1 = LAYOUT.PROM.x0, LAYOUT.PROM.x1
local Z0, Z1 = LAYOUT.LAND.z0 + 8, LAYOUT.LAND.z1 - 8
local SAND_Y = -0.3
local WET = C(190, 170, 132)
local rng = Random.new(2026)

-- palmera: model de la Toolbox (dos tipus alternats), girada a l'atzar
local palmN = 0
local function palm(p, h, lean)
	palmN += 1
	Asset(palmN % 3 == 0 and "palmCoco" or "palmChunky", CF(p) * CFrame.Angles(0, lean, 0), h, F)
end

-- ── passeig: barana de vidre, palmeres, fanals de LED, bancs i escales ──
do
	local m = Instance.new("Model")
	m.Name = "PromenadeRail"
	local x = PX1 - 0.6
	local z = Z0
	while z < Z1 do
		local z2 = math.min(z + 48, Z1)
		-- sòcol de formigó i barana de vidre (deixem 8 studs d'escala cada 56)
		P(V3(0.9, 0.9, z2 - z), CF(x, 1.1, (z + z2) / 2), MOD.conc, M.Concrete, m)
		glassRail(V3(x, 1.55, z), V3(x, 1.55, z2), 2.8, m)
		-- escala de formigó cap a la sorra
		local sz = z2 + 4
		for st = 0, 2 do
			P(V3(1.4, 0.35, 7), CF(PX1 + 0.7 + st * 1.4, 0.5 - st * 0.35, sz), MOD.conc, M.Concrete, m)
		end
		z = z2 + 8
	end
	m.Parent = F
	for zz = Z0 + 10, Z1 - 10, 26 do
		palm(V3(PX0 + 4, 0.65, zz), rng:NextNumber(18, 24), rng:NextNumber(0, math.pi * 2))
	end
	for zz = Z0 + 23, Z1 - 10, 26 do
		modernLamp(V3(PX0 + 4, 0.65, zz), V3(1, 0, 0), F, 12, rng:NextNumber() < 0.5)
		-- banc mirant al mar
		modernBench(V3(PX1 - 4, 0.65, zz), V3(1, 0, 0), F)
	end
end

-- ── cabanes de platja: ratlles verticals de color, teulada a dues aigües ──
local HUT_COLS = { C(64, 170, 190), C(240, 150, 70), C(236, 96, 96), C(96, 180, 120), C(250, 200, 70), C(120, 130, 220) }
for i = 0, 8 do
	local m = Instance.new("Model")
	m.Name = "BeachCabana"
	local z = Z0 + 18 + i * 13
	local O = CFrame.lookAt(V3(PX1 + 12, SAND_Y, z), V3(PX1 + 30, SAND_Y, z))
	local col = HUT_COLS[i % #HUT_COLS + 1]
	P(V3(8.4, 0.5, 7.4), O * CF(0, 0.25, 0), C(150, 146, 140), M.WoodPlanks, m)
	P(V3(7.4, 7, 6.2), O * CF(0, 4, 0.3), MOD.white, M.SmoothPlastic, m)
	-- ratlles de color a la paret de darrere i als costats
	for k = 0, 6 do
		if k % 2 == 1 then
			P(V3(7.4 / 7, 7, 0.1), O * CF(-3.7 + (k + 0.5) * 7.4 / 7, 4, 3.45), col, M.SmoothPlastic, m, true)
		end
	end
	for k = 0, 5 do
		if k % 2 == 1 then
			for sx = -1, 1, 2 do
				P(V3(0.1, 7, 6.2 / 6), O * CF(sx * 3.75, 4, -2.8 + (k + 0.5) * 6.2 / 6), col, M.SmoothPlastic, m, true)
			end
		end
	end
	gableRoof(O * CF(0, 7.5, 0.3) * CFrame.Angles(0, math.pi / 2, 0), 6.2, 7.4, rad(32), 0.5, 0.3, col:Lerp(C(0, 0, 0), 0.25), M.SmoothPlastic, MOD.white, M.SmoothPlastic, MOD.white, m)
	-- porta de color i llistons de fusta
	panel(V3(3, 5.6, 0.25), (O * CF(0, 3.3, -2.85)).Position, O.LookVector, col, M.SmoothPlastic, m, true)
	for k = -1, 1, 2 do
		panel(V3(1.6, 5.6, 0.25), (O * CF(k * 2.6, 3.3, -2.85)).Position, O.LookVector, MOD.wood, M.WoodPlanks, m, true)
	end
	P(V3(3, 0.2, 2.4), O * CF(-5.4, 0.25, -1), col, M.Fabric, m, true)
	m.Parent = F
end

-- ── para-sols de colors amb cadires (Toolbox) i tovalloles ──
local TOWELS = { C(214, 80, 80), C(80, 140, 190), C(236, 196, 80), C(120, 180, 120), C(236, 150, 170) }
local umbrellas = {}
for row = 0, 1 do
	for i = 0, 8 do
		local z = 10 + i * 26 + row * 13
		local x = PX1 + 22 + row * 20 + rng:NextNumber(-2, 2)
		-- (a la segona fila hi ha el plesiosaure entre z 40 i 92)
		if z < Z1 - 8 and not (row == 1 and z > 36 and z < 96) then
			local m = Instance.new("Model")
			m.Name = "Parasol"
			local p = V3(x, SAND_Y, z)
			table.insert(umbrellas, p)
			local yaw = rng:NextNumber(-0.5, 0.5) + math.pi / 2
			Asset("umbrellaChairs", CF(p) * CFrame.Angles(0, yaw, 0), 8, m)
			-- tovallola estesa al costat, amb franges
			local tcf = CF(p + V3(0, 0.12, 4.2)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
			local tc = TOWELS[rng:NextInteger(1, #TOWELS)]
			P(V3(2.8, 0.1, 5.2), tcf, tc, M.Fabric, m, true)
			for q = -1, 1, 2 do
				-- franja: més estreta que la tovallola i 0,03 més alta (no al mateix pla)
				P(V3(2.74, 0.14, 0.5), tcf * CF(0, 0.02, q * 1.6), tc:Lerp(C(255, 255, 255), 0.6), M.Fabric, m, true)
			end
			m.Parent = F
		end
	end
end

-- ── torre de socorrista moderna i xarxa de vòlei ──
do
	local p = V3(PX1 + 34, SAND_Y, -40)
	Asset("lifeguard", CF(p) * CFrame.Angles(0, rad(-90), 0), 14, F, { collide = true })
	local vm = Instance.new("Model")
	vm.Name = "Volleyball"
	local c = V3(PX1 + 32, SAND_Y, 150)
	for s = -1, 1, 2 do
		VCyl(8, 0.4, c + V3(s * 12, 4, 0), COL.cream, M.SmoothPlastic, vm)
	end
	local net = P(V3(24, 3, 0.1), CF(c + UP * 6.2), COL.cream, M.Fabric, vm, true)
	net.Transparency = 0.5
	Ball(1.4, c + V3(-4, 0.7, 6), C(236, 196, 80), M.SmoothPlastic, vm)
	vm.Parent = F
end

-- ── moll: coberta de fusta gris, barana de vidre i fanals de LED ──
do
	local m = Instance.new("Model")
	m.Name = "Pier"
	local z, x0, x1 = -120, PX1 + 20, 360
	local deck = 1.6
	local DECK = C(150, 140, 128)
	P(V3(x1 - x0, 0.8, 12), CF((x0 + x1) / 2, deck, z), DECK, M.WoodPlanks, m)
	for x = x0 + 5, x1, 10 do
		for sgn = -1, 1, 2 do
			VCyl(16, 1.2, V3(x, deck - 8, z + sgn * 5.4), MOD.concD, M.Concrete, m)
		end
	end
	for sgn = -1, 1, 2 do
		glassRail(V3(x0, deck + 0.4, z + sgn * 5.8), V3(x1 - 5, deck + 0.4, z + sgn * 5.8), 2.8, m)
	end
	for x = x0 + 20, x1 - 10, 40 do
		modernLamp(V3(x, deck + 0.4, z - 5.2), V3(0, 0, 1), m, 10, false)
	end
	-- plataforma final
	P(V3(26, 0.8, 26), CF(x1 + 8, deck, z), DECK, M.WoodPlanks, m)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		VCyl(16, 1.4, V3(x1 + 8 + q[1] * 12, deck - 8, z + q[2] * 12), MOD.concD, M.Concrete, m)
	end
	for _, e in ipairs({ { V3(x1 + 21, 0, z - 13), V3(x1 + 21, 0, z + 13) }, { V3(x1 - 5, 0, z + 13), V3(x1 + 21, 0, z + 13) }, { V3(x1 - 5, 0, z - 13), V3(x1 + 21, 0, z - 13) } }) do
		glassRail(e[1] + UP * (deck + 0.4), e[2] + UP * (deck + 0.4), 2.8, m)
	end
	-- prismàtics turístics
	local tp = V3(x1 + 16, deck + 0.4, z)
	VCyl(3.4, 0.5, tp + UP * 1.7, MOD.steel, M.Metal, m)
	P(V3(1.6, 1, 1.4), CFrame.lookAt(tp + UP * 3.9, tp + UP * 3.9 + V3(1, 0, 0)), C(60, 150, 190), M.SmoothPlastic, m)
	-- veler amarrat
	local b = CFrame.lookAt(V3(x1 - 20, -1.2, z + 14), V3(x1 + 10, -1.2, z + 14))
	P(V3(5, 2.4, 16), b, COL.cream, M.SmoothPlastic, m)
	Wd(V3(5, 2.4, 5), b * CF(0, 0, -10.5) * CFrame.Angles(0, math.pi, 0) * WEDGE_FIX, COL.cream, M.SmoothPlastic, m)
	P(V3(5.2, 0.5, 21), b * CF(0, 1.3, -2.4), C(64, 170, 190), M.SmoothPlastic, m, true)
	P(V3(0.5, 20, 0.5), b * CF(0, 11, -2), C(200, 200, 204), M.Metal, m)
	Wd(V3(0.15, 16, 9), b * CF(0, 11, 2.6) * WEDGE_FIX, COL.cream, M.Fabric, m)
	m.Parent = F
end

-- ── far modern sobre l'escullera: torre blanca de formigó ──
do
	local m = Instance.new("Model")
	m.Name = "Lighthouse"
	local z = 212
	for k = 0, 9 do
		local x = PX1 + 60 + k * 14
		for q = -1, 1 do
			local r = P(V3(rng:NextNumber(7, 11), rng:NextNumber(5, 8), rng:NextNumber(7, 11)), CF(x + rng:NextNumber(-3, 3), -1.5 + rng:NextNumber(0, 2), z + q * 6) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), COL.rock, M.Slate, m)
			r.CastShadow = true
		end
	end
	-- passarel·la de formigó amb barana de vidre fins al far
	P(V3(126, 0.8, 7), CF(PX1 + 123, 2.4, z), MOD.conc, M.Concrete, m)
	glassRail(V3(PX1 + 60, 2.8, z + 3.3), V3(PX1 + 184, 2.8, z + 3.3), 2.4, m)
	local base = V3(PX1 + 192, 0, z)
	VCyl(6, 24, base + UP * 1, COL.rock, M.Slate, m)
	VCyl(1, 25, base + UP * 4.5, MOD.conc, M.Concrete, m)
	-- fust: cilindres blancs que s'estrenyen, amb una franja vermella a dalt
	for k = 0, 5 do
		local h = 7
		VCyl(h, 11 - k * 0.8, base + UP * (5 + h / 2 + k * h), k == 5 and C(226, 70, 60) or MOD.white, M.SmoothPlastic, m)
	end
	local top = base + UP * 47
	VCyl(0.8, 12, top + UP * 0.4, MOD.steel, M.Metal, m)
	local lensGlass = VCyl(4.6, 6.4, top + UP * 3.1, MOD.rail, M.Glass, m)
	lensGlass.Transparency = 0.5
	local lens = VCyl(3, 3.4, top + UP * 3.1, C(255, 244, 200), M.Neon, m)
	local pl = Instance.new("PointLight")
	pl.Range = 60
	pl.Brightness = 2
	pl.Color = C(255, 236, 190)
	pl.Parent = lens
	VCyl(0.8, 8, top + UP * 5.8, MOD.steel, M.Metal, m)
	VCyl(1.6, 0.4, top + UP * 7, MOD.steel, M.Metal, m, true)
	-- caseta del far: caixa blanca de teulada plana
	P(V3(12, 8, 10), CF(base + V3(-15, 8, 0)), MOD.white, M.SmoothPlastic, m)
	P(V3(13, 0.6, 11), CF(base + V3(-15, 12.3, 0)), MOD.char, M.SmoothPlastic, m)
	local w = P(V3(0.2, 3.4, 6), CF(base + V3(-8.95, 8.6, 0)), MOD.glass, M.SmoothPlastic, m, true)
	w.Reflectance = 0.3
	m.Parent = F
end

-- ── barques blanques a la sorra, amb una franja de color ──
for _, bp in ipairs({ { PX1 + 52, -70, 20 }, { PX1 + 48, 110, -30 }, { PX1 + 58, 12, 60 } }) do
	local m = Instance.new("Model")
	m.Name = "Boat"
	local O = CF(bp[1], SAND_Y + 0.8, bp[2]) * CFrame.Angles(0, rad(bp[3]), rad(8))
	local col = HUT_COLS[rng:NextInteger(1, #HUT_COLS)]
	P(V3(4.4, 1.6, 10), O, MOD.white, M.SmoothPlastic, m)
	Wd(V3(4.4, 1.6, 3), O * CF(0, 0, -6.5) * CFrame.Angles(0, math.pi, 0) * WEDGE_FIX, MOD.white, M.SmoothPlastic, m)
	P(V3(4.5, 0.4, 10.1), O * CF(0, -0.2, 0), col, M.SmoothPlastic, m, true)
	-- el terra acaba 0,1 abans de la popa (a 5,0 quedava al pla de la cara del buc)
	P(V3(3.6, 0.3, 9.3), O * CF(0, 0.7, 0.25), C(150, 140, 128), M.WoodPlanks, m, true)
	-- bancs una mica més estrets que el terra (3,6): si no, els costats
	-- quedaven al mateix pla i feien pampallugues
	for k = -1, 1 do
		P(V3(3.5, 0.4, 0.8), O * CF(0, 0.9, k * 3), MOD.white, M.SmoothPlastic, m, true)
	end
	m.Parent = F
end

-- ═════════ MÉS VIDA A LA PLATJA ═════════
-- llocs ocupats (els munts per excavar no s'hi posaran a sobre)
local busy = {}
local function occupy(x, z, r)
	table.insert(busy, { x, z, r })
end
local WOOD = C(156, 146, 132) -- fusta gris (composite)
local WOOD_D = C(120, 112, 102)

-- ── passarel·les de fusta des de les escales fins a l'aigua ──
for _, bw in ipairs({ { -98, 52 }, { -42, 26 }, { 14, 52 }, { 70, 52 }, { 126, 30 }, { 182, 36 }, { 238, 46 } }) do
	local z, len = bw[1], bw[2]
	local m = Instance.new("Model")
	m.Name = "Boardwalk"
	local x0 = PX1 + 2
	P(V3(len, 0.3, 4.4), CF(x0 + len / 2, SAND_Y + 0.2, z), WOOD, M.WoodPlanks, m)
	for k = 0, math.floor(len / 3) do
		P(V3(0.25, 0.32, 4.6), CF(x0 + 1 + k * 3, SAND_Y + 0.22, z), WOOD_D, M.WoodPlanks, m, true)
	end
	m.Parent = F
	for x = x0, x0 + len, 6 do
		occupy(x, z, 4)
	end
end

-- ── beach club: caixa blanca, gran voladís pla, barra i terrassa ──
do
	local m = Instance.new("Model")
	m.Name = "BeachBar"
	local c = V3(PX1 + 28, SAND_Y, -12)
	local O = CFrame.lookAt(c, c + V3(1, 0, 0))
	P(V3(22, 1, 14), O * CF(0, 0.5, 0), WOOD, M.WoodPlanks, m)
	-- volum de la barra
	P(V3(10, 7, 5), O * CF(-4, 4.5, 3.6), MOD.white, M.SmoothPlastic, m)
	P(V3(10.4, 0.6, 2.2), O * CF(-4, 4.2, 0.2), MOD.wood, M.WoodPlanks, m)
	P(V3(10, 3.2, 1.8), O * CF(-4, 2.5, 0.4), MOD.white, M.SmoothPlastic, m)
	for k = 0, 3 do
		local sp = O * CF(-8 + k * 2.6, 0, -1.6)
		VCyl(2.4, 0.3, (sp * CF(0, 2.2, 0)).Position, MOD.steel, M.Metal, m, true)
		VCyl(0.4, 1.4, (sp * CF(0, 3.5, 0)).Position, C(64, 170, 190), M.SmoothPlastic, m)
	end
	-- teulada plana volada sobre pilars d'acer i franja de LED
	P(V3(16, 0.7, 11), O * CF(-2, 8.4, 1.4), MOD.white, M.SmoothPlastic, m)
	P(V3(15.6, 0.12, 0.3), O * CF(-2, 8, -4.1), MOD.led, M.Neon, m, true)
	for q = -1, 1, 2 do
		P(V3(0.5, 7.6, 0.5), O * CF(-2 + q * 7.4, 4.3, -3.6), MOD.steel, M.Metal, m)
	end
	local sg = P(V3(8, 1.4, 0.3), O * CF(-4, 7.2, 1.1), MOD.char, M.SmoothPlastic, m, true)
	Label(sg, "BEACH BAR", MOD.white, Enum.Font.GothamBlack)
	-- taules amb para-sol quadrat a la terrassa
	for _, q in ipairs({ { 5, -3 }, { 5, 3.5 } }) do
		local tp = (O * CF(q[1], 1, q[2])).Position
		VCyl(2.6, 0.3, tp + UP * 1.3, MOD.steel, M.Metal, m, true)
		VCyl(0.3, 3, tp + UP * 2.7, MOD.white, M.SmoothPlastic, m)
		squareParasol(tp, C(236, 226, 206), m, 6.4)
		for k = 0, 2 do
			local a = k * 2.1
			VCyl(1.8, 1.2, tp + UP * 0.9 + V3(math.cos(a) * 2.4, 0, math.sin(a) * 2.4), MOD.wood, M.WoodPlanks, m, true)
		end
	end
	-- taulers de surf de colors
	for k = 0, 3 do
		local sb = O * CF(9.4, 3.6, -5 + k * 1.2) * CFrame.Angles(rad(8), 0, rad(-12))
		Ellipsoid(V3(0.3, 7, 1.6), sb, ({ C(236, 110, 90), C(80, 170, 200), C(240, 200, 80), C(120, 190, 130) })[k + 1], M.SmoothPlastic, m)
	end
	m.Parent = F
	occupy(c.X, c.Z, 14)
end

-- ── grups de palmeres sobre la sorra ──
for _, g in ipairs({ { PX1 + 46, -30 }, { PX1 + 44, 250 }, { PX1 + 20, -104 } }) do
	for k = 0, 2 do
		local a = k * 2.2 + g[2]
		palm(V3(g[1] + math.cos(a) * 3, SAND_Y, g[2] + math.sin(a) * 3), rng:NextNumber(16, 22), a)
	end
	occupy(g[1], g[2], 7)
end

-- ── matolls de duna al peu del passeig ──
for z = Z0 + 6, Z1 - 6, 9 do
	if rng:NextNumber() < 0.7 then
		local p = V3(PX1 + 2 + rng:NextNumber(0, 2), SAND_Y, z + rng:NextNumber(-2, 2))
		Ellipsoid(V3(rng:NextNumber(2.6, 4), rng:NextNumber(1.6, 2.4), rng:NextNumber(2.6, 4)), CF(p + UP * 0.6), C(150, 160, 90):Lerp(C(110, 140, 80), rng:NextNumber()), M.SmoothPlastic, F, true)
	end
end

-- ── dutxes al peu de les escales ──
for _, z in ipairs({ -98, 14, 126 }) do
	local m = Instance.new("Model")
	m.Name = "Shower"
	local p = V3(PX1 + 5, SAND_Y, z + 4)
	P(V3(3, 0.3, 3), CF(p + UP * 0.2), MOD.conc, M.Concrete, m)
	VCyl(8, 0.4, p + UP * 4, C(200, 200, 204), M.Metal, m)
	P(V3(1.4, 0.3, 0.3), CF(p + UP * 7.9 + V3(0.6, 0, 0)), C(200, 200, 204), M.Metal, m, true)
	VCyl(0.3, 0.9, p + UP * 7.6 + V3(1.2, 0, 0), C(200, 200, 204), M.Metal, m, true)
	m.Parent = F
	occupy(p.X, p.Z, 3)
end

-- ── caiacs al costat del moll ──
for k = 0, 2 do
	local cf = CF(PX1 + 38 + k * 3, SAND_Y + 0.5, -108 + k * 2) * CFrame.Angles(0, rad(78), 0)
	Ellipsoid(V3(1.9, 0.9, 9), cf, ({ C(236, 150, 50), C(220, 70, 70), C(60, 150, 190) })[k + 1], M.SmoothPlastic, F)
	Ellipsoid(V3(1.2, 0.3, 2.2), cf * CF(0, 0.4, 0), C(40, 40, 44), M.SmoothPlastic, F, true)
end
occupy(PX1 + 41, -106, 7)

-- ── castells de sorra ──
local function sandcastle(p)
	local m = Instance.new("Model")
	m.Name = "SandCastle"
	Asset("sandCastle", CF(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 3.6, m)
	VCyl(1.1, 1.1, p + V3(3.6, 0.55, 1.6), C(80, 150, 220), M.SmoothPlastic, m, true)
	P(V3(0.2, 2.2, 0.2), CF(p + V3(3.4, 1, -2)) * CFrame.Angles(0, 0, rad(20)), C(240, 200, 60), M.SmoothPlastic, m, true)
	m.Parent = F
	occupy(p.X, p.Z, 5)
end
sandcastle(V3(PX1 + 36, SAND_Y, 96))
sandcastle(V3(PX1 + 18, SAND_Y, 200))
sandcastle(V3(PX1 + 40, SAND_Y, -150))
sandcastle(V3(PX1 + 30, SAND_Y, 40))

-- ── joguines i tovalloles a prop dels para-sols ──
for i, u in ipairs(umbrellas) do
	if i % 3 == 0 then
		Ball(1.4, u + V3(4.5, 0.7, -3), ({ C(240, 80, 80), C(80, 160, 230), C(250, 210, 70) })[i % 3 + 1], M.SmoothPlastic, F)
	end
	occupy(u.X, u.Z, 7)
end

-- ── pòrtics d'entrada d'acer al passeig (on hi arriben els carrers) ──
for _, z in ipairs({ -44, 66 }) do
	local m = Instance.new("Model")
	m.Name = "BeachGate"
	local x = PX1 - 3
	for sgn = -1, 1, 2 do
		P(V3(1, 11.6, 1), CF(x, 6.4, z + sgn * 6.6), MOD.steel, M.Metal, m)
	end
	P(V3(1, 1, 14.2), CF(x, 12.7, z), MOD.steel, M.Metal, m)
	local sg = P(V3(0.4, 2.2, 12), CF(x, 10.8, z), MOD.white, M.SmoothPlastic, m)
	Label(sg, "FOSSIL BEACH", C(38, 110, 120), Enum.Font.GothamBlack, Enum.NormalId.Left)
	Label(sg, "FOSSIL BEACH", C(38, 110, 120), Enum.Font.GothamBlack, Enum.NormalId.Right)
	P(V3(0.3, 0.12, 12), CF(x, 9.55, z), MOD.led, M.Neon, m, true)
	-- aquí es desbloqueja la platja (ShopService hi posa el botó)
	local unlock = P(V3(4, 0.2, 10), CF(x, 0.8, z), COL.brass, M.SmoothPlastic, m, true)
	unlock.Name = "BeachUnlock"
	unlock.Transparency = 1
	unlock.CanQuery = false
	unlock:SetAttribute("Zone", "beach")
	tag(unlock, "ZoneUnlock")
	m.Parent = F
end

-- ── al mar: boies, plataforma amb tobogan i velers ──
for z = Z0 + 20, Z1 - 30, 14 do
	if math.abs(z + 120) > 14 and math.abs(z - 212) > 14 then
		Ball(1.4, V3(PX1 + 112, -1.7, z), (math.floor(z / 14) % 2 == 0) and C(230, 60, 60) or C(250, 250, 250), M.SmoothPlastic, F, true)
	end
end
do
	local m = Instance.new("Model")
	m.Name = "SwimPlatform"
	local c = V3(PX1 + 120, -1.4, 40)
	P(V3(12, 1, 12), CF(c), C(236, 234, 228), M.SmoothPlastic, m)
	for q = -1, 1, 2 do
		for r = -1, 1, 2 do
			VCyl(1.4, 1.6, c + V3(q * 5, -0.8, r * 5), C(60, 110, 150), M.SmoothPlastic, m, true)
		end
	end
	-- escala i tobogan
	for s = -1, 1, 2 do
		P(V3(0.3, 7, 0.3), CF(c + V3(3.6, 4, s * 1.2)), C(200, 200, 204), M.Metal, m, true)
	end
	for k = 0, 4 do
		P(V3(0.25, 0.25, 2.6), CF(c + V3(3.6, 1.4 + k * 1.3, 0)), C(200, 200, 204), M.Metal, m, true)
	end
	P(V3(2.6, 0.4, 2.6), CF(c + V3(3.6, 7.6, 0)), C(80, 160, 220), M.SmoothPlastic, m)
	local sl = P(V3(2.4, 0.4, 11), CFrame.lookAt(c + V3(3.6, 7.6, 0), c + V3(3.6, 0.2, 10)) * CF(0, 0, -5.4), C(240, 190, 60), M.SmoothPlastic, m)
	sl.CFrame = sl.CFrame
	m.Parent = F
end
local function sailboat(p, yaw, sailC)
	local m = Instance.new("Model")
	m.Name = "Sailboat"
	local cf = CF(p) * CFrame.Angles(0, yaw, 0)
	Ellipsoid(V3(4.4, 2.6, 13), cf, C(246, 244, 238), M.SmoothPlastic, m)
	P(V3(4.2, 0.4, 9), cf * CF(0, 0.9, 0.8), C(196, 150, 110), M.WoodPlanks, m, true)
	P(V3(0.4, 16, 0.4), cf * CF(0, 8.6, -0.6), C(200, 200, 204), M.Metal, m)
	Wd(V3(0.15, 13, 6.4), cf * CF(0, 8.8, 2.8) * WEDGE_FIX, sailC, M.Fabric, m)
	Wd(V3(0.15, 9, 3.6), cf * CF(0, 6.4, -2.6) * CFrame.Angles(0, math.pi, 0) * WEDGE_FIX, C(246, 244, 238), M.Fabric, m)
	m.Parent = F
end
sailboat(V3(PX1 + 190, -1.6, -40), rad(20), C(246, 244, 238))
sailboat(V3(PX1 + 250, -1.6, 130), rad(-35), C(230, 90, 80))
sailboat(V3(PX1 + 320, -1.6, 20), rad(60), C(80, 160, 210))

-- ── cartells de zona d'excavació ──
for _, z in ipairs({ -60, 150 }) do
	local p = V3(PX1 + 8, SAND_Y, z)
	P(V3(0.4, 5, 0.4), CF(p + UP * 2.5), MOD.steel, M.Metal, F, true)
	local sg = P(V3(0.3, 2.4, 5), CF(p + UP * 5.4), MOD.char, M.SmoothPlastic, F, true)
	Label(sg, "DIG HERE ⛏", C(255, 206, 110), Enum.Font.GothamBlack, Enum.NormalId.Right)
	occupy(p.X, p.Z, 3)
end

-- ── punt d'arribada del botó "La Platja" de la UI (TravelService) ──
-- al passeig, davant de l'escala de z = 6, mirant al mar
do
	local tp = P(V3(4, 0.2, 4), CF(179, 0.75, 6) * CFrame.Angles(0, math.rad(-90), 0), COL.brass, M.SmoothPlastic, F, true)
	tp.Name = "TravelPoint"
	tp.Transparency = 1
	tp.CanQuery = false
	tp:SetAttribute("Destination", "beach")
	tag(tp, "TravelPoint")
end

-- ── roques a la vora de l'aigua i més grups de palmeres ──
for k, rp in ipairs({ { PX1 + 60, -200, 7 }, { PX1 + 64, -78, 5 }, { PX1 + 62, 186, 6 }, { PX1 + 56, 240, 8 }, { PX1 + 12, 252, 5 }, { PX1 + 66, 20, 4 } }) do
	for q = 0, 2 do
		local a = q * 2.1 + k
		Rock(CF(rp[1] + math.cos(a) * rp[3] * 0.5, SAND_Y, rp[2] + math.sin(a) * rp[3] * 0.5) * CFrame.Angles(0, a, 0), rp[3] * (1 - q * 0.25), F, k + q)
	end
	occupy(rp[1], rp[2], rp[3] + 2)
end
for _, g in ipairs({ { PX1 + 14, 172 }, { PX1 + 50, -186 }, { PX1 + 10, -150 } }) do
	for k = 0, 1 do
		local a = k * 2.6 + g[2]
		palm(V3(g[1] + math.cos(a) * 3, SAND_Y, g[2] + math.sin(a) * 3), rng:NextNumber(16, 22), a)
	end
	occupy(g[1], g[2], 6)
end

-- ── el gran plesiosaure: un esquelet enorme mig enterrat a la sorra ──
do
	local m = Instance.new("Model")
	m.Name = "Plesiosaur"
	local base = CF(PX1 + 44, SAND_Y, 66) -- l'esquena va al llarg de Z
	local BONE = COL.bone
	-- vora de sorra remoguda
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		Ellipsoid(V3(4, 0.9, 3), base * CF(math.cos(a) * 9, 0, math.sin(a) * 24) * CFrame.Angles(0, -a, 0), C(226, 208, 164), M.Sand, m, true)
	end
	P(V3(15, 0.1, 44), base * CF(0, 0.05, 0), C(200, 178, 132), M.Sand, m, true)
	-- columna: del coll llarg a la cua, amb vèrtebres
	local spine = {}
	for i = 0, 26 do
		local t = i / 26
		local z = -21 + t * 42
		local y = if t < 0.35 then 1.2 + math.sin(t / 0.35 * math.pi * 0.5) * 2.6 else 3.8 - (t - 0.35) * 5
		local x = math.sin(t * math.pi * 1.4) * 1.6
		table.insert(spine, (base * CF(x, math.max(y, 0.5), z)).Position)
	end
	for i, pnt in ipairs(spine) do
		local sz = if i > 9 and i < 20 then 1.3 else 0.9
		Ellipsoid(V3(sz * 1.2, sz, sz * 1.1), CF(pnt), BONE, M.Marble, m)
		if i > 1 then
			beam(spine[i - 1], pnt, 0.5, BONE, M.Marble, m, true)
		end
		-- apòfisis cap amunt
		if i > 8 and i < 22 then
			P(V3(0.25, 1.2, 0.6), CF(pnt + UP * 0.8), BONE, M.Marble, m, true)
		end
	end
	-- costelles en arc que surten de la sorra
	for i = 10, 19 do
		local pnt = spine[i]
		for sx = -1, 1, 2 do
			local prev = pnt
			for q = 1, 4 do
				local a = q / 4 * math.pi * 0.55
				local nxt = pnt + V3(sx * math.sin(a) * 4.2, -math.cos(a) * 0 - q * 0.9 + 0.4, 0)
				beam(prev, nxt, 0.36, BONE, M.Marble, m, true)
				prev = nxt
			end
		end
	end
	-- crani al cap del coll i quatre aletes
	local head = spine[1]
	Ellipsoid(V3(1.8, 1.3, 3), CF(head + V3(0, 0.4, -1.6)), BONE, M.Marble, m)
	Ellipsoid(V3(0.4, 0.5, 0.6), CF(head + V3(0.6, 0.7, -1.4)), COL.uiBg, M.SmoothPlastic, m, true)
	Ellipsoid(V3(0.4, 0.5, 0.6), CF(head + V3(-0.6, 0.7, -1.4)), COL.uiBg, M.SmoothPlastic, m, true)
	for _, f in ipairs({ { 12, -1 }, { 12, 1 }, { 18, -1 }, { 18, 1 } }) do
		local root = spine[f[1]]
		local tip = root + V3(f[2] * 6, -2.4, 2)
		beam(root, tip, 0.5, BONE, M.Marble, m, true)
		for k = -1, 1 do
			beam(tip, tip + V3(f[2] * 1.6, -0.3, 1.2 + k * 0.8), 0.25, BONE, M.Marble, m, true)
		end
	end
	-- cordill i cartell
	for _, q in ipairs({ { -10, -26 }, { 10, -26 }, { 10, 26 }, { -10, 26 } }) do
		P(V3(0.35, 2.4, 0.35), base * CF(q[1], 1.2, q[2]), COL.wood, M.Wood, m, true)
	end
	for _, e in ipairs({ { -10, -26, 10, -26 }, { 10, -26, 10, 26 }, { 10, 26, -10, 26 }, { -10, 26, -10, -26 } }) do
		beam((base * CF(e[1], 2, e[2])).Position, (base * CF(e[3], 2, e[4])).Position, 0.08, C(230, 60, 50), M.Fabric, m, true)
	end
	local sg = P(V3(0.3, 2.2, 7), base * CF(-10.4, 2.8, -12), MOD.char, M.SmoothPlastic, m, true)
	Label(sg, "PLESIOSAUR · 80 MILLION YEARS", C(255, 206, 110), Enum.Font.GothamBlack, Enum.NormalId.Left)
	P(V3(0.3, 2.8, 0.3), base * CF(-10.4, 1.4, -12), COL.wood, M.Wood, m, true)
	m.Parent = F
	occupy(PX1 + 44, 66, 28)
end
occupy(PX1 + 34, -40, 16) -- la torre de socorrista (és grossa)
for _, bp in ipairs({ { PX1 + 52, -70 }, { PX1 + 48, 110 }, { PX1 + 58, 12 } }) do
	occupy(bp[1], bp[2], 7) -- les barques
end

-- ── la vora de l'aigua: flotadors, gavines a la barana del moll, petxines i estrelles ──
local FLOATS = { C(255, 90, 150), C(255, 200, 50), C(70, 190, 240), C(120, 220, 120) }
for k, fz in ipairs({ -30, 30, 110, 190 }) do
	local c = V3(PX1 + 58 + (k % 2) * 6, -1.55, fz)
	for q = 0, 9 do
		local a = q / 10 * math.pi * 2
		local seg = Cyl(1.3, 0.9, CF(c + V3(math.cos(a) * 1.3, 0, math.sin(a) * 1.3)) * CFrame.Angles(0, -a, 0), q % 2 == 0 and FLOATS[k] or MOD.white, M.SmoothPlastic, F, true)
		seg.CFrame = seg.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	end
end
for k = 0, 5 do
	-- gavines damunt dels pilons del moll
	local gp = V3(PX1 + 45 + k * 22, 5.5, -120 + (k % 2 == 0 and 5.8 or -5.8))
	Ellipsoid(V3(0.8, 0.8, 1.6), CF(gp), MOD.white, M.SmoothPlastic, F, true)
	Ball(0.55, gp + V3(0, 0.45, -0.7), MOD.white, M.SmoothPlastic, F, true)
	P(V3(0.12, 0.12, 0.35), CF(gp + V3(0, 0.4, -1.1)), C(250, 190, 40), M.SmoothPlastic, F, true)
	Ellipsoid(V3(1.9, 0.12, 0.7), CF(gp + V3(0, 0.25, 0.1)), C(150, 156, 164), M.SmoothPlastic, F, true)
end
local SHELLS = { C(240, 206, 196), C(250, 236, 220), C(236, 170, 150), C(226, 196, 150) }
for _ = 1, 70 do
	local sp = V3(rng:NextNumber(PX1 + 4, PX1 + 70), SAND_Y + 0.08, rng:NextNumber(Z0, Z1))
	if rng:NextNumber() < 0.15 then
		for q = 0, 4 do
			P(V3(0.26, 0.14, 0.8), CF(sp) * CFrame.Angles(0, q * math.pi * 2 / 5, 0) * CF(0, 0, 0.35), C(236, 120, 80), M.SmoothPlastic, F, true)
		end
	else
		Ellipsoid(V3(0.6, 0.25, 0.5), CF(sp) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), SHELLS[rng:NextInteger(1, #SHELLS)], M.SmoothPlastic, F, true)
	end
end
-- línies del camp de vòlei
do
	local c = V3(PX1 + 32, SAND_Y + 0.06, 150)
	for _, e in ipairs({ { 0, -8, 26, 0.3 }, { 0, 8, 26, 0.3 }, { -13, 0, 0.3, 16 }, { 13, 0, 0.3, 16 } }) do
		P(V3(e[3], 0.05, e[4]), CF(c + V3(e[1], 0, e[2])), C(40, 120, 200), M.Fabric, F, true)
	end
end

-- ── munts de sorra per excavar (DigSpot) ──
local digs = 0
local tries = 0
local placed = {}
while digs < 26 and tries < 600 do
	tries += 1
	-- múltiples de 4: la llosa del forat va alineada amb la graella del terreny
	local x = math.floor(rng:NextNumber(PX1 + 10, PX1 + 46) / 4 + 0.5) * 4
	local z = math.floor(rng:NextNumber(Z0 + 10, Z1 - 10) / 4 + 0.5) * 4
	local ok = true
	for _, u in ipairs(umbrellas) do
		if (V3(x, 0, z) - V3(u.X, 0, u.Z)).Magnitude < 10 then
			ok = false
		end
	end
	if z < Z0 + 140 and x < PX1 + 20 then
		ok = false -- casetes de bany
	end
	if math.abs(z + 120) < 12 or math.abs(z - 212) < 12 or (math.abs(z + 40) < 10 and x > PX1 + 26) or math.abs(z - 150) < 16 then
		ok = false -- moll, far, socorrista, vòlei
	end
	for _, q in ipairs(placed) do
		if (q - V3(x, 0, z)).Magnitude < 12 then
			ok = false
		end
	end
	for _, b in ipairs(busy) do
		if (V3(x, 0, z) - V3(b[1], 0, b[2])).Magnitude < b[3] + 4 then
			ok = false
		end
	end
	if ok then
		digs += 1
		table.insert(placed, V3(x, 0, z))
		digPit(V3(x, SAND_Y, z), "beach", "BeachDig" .. digs, "sand", rng, F)
	end
end
print(("Platja: palmeres, para-sols, socorrista, castells, roques, beach club, moll, far i %d forats per excavar"):format(digs))

end }
STEPS[#STEPS + 1] = { "07_obra", function()
-- ═══════════════════════════ 07 · ZONA 1: L'OBRA (60x60) ═══════════════════════════
-- Escales del CLAUDE.md (no se'n surt res): solar 60x60 · tanca 4 alt ·
-- excavadora 12-14 alt · oficina de contenidors · grua 22 alt · edifici 24x18.
-- L'entrada és al sud, al camí de vianants; al voltant hi ha cases i, a
-- l'est, entre la tanca i el carrer, dues cases més (03_houses).
-- Hi han trobat fòssils: 16 forats d'excavació mig cavats (DigSpot al munt
-- del mig de cada forat), carpes d'arqueòleg i la gran troballa al nord.
local OB = LAYOUT.OBRA
local ox, oz = (OB.x0 + OB.x1) / 2, (OB.z0 + OB.z1) / 2
local HALF = (OB.x1 - OB.x0) / 2 -- 30
local zone = Instance.new("Model")
zone.Name = "Construction"
local rng = Random.new(1)
local YELLOW = C(230, 186, 40)
local YELLOW_D = C(186, 146, 26)
local ORANGE = C(255, 107, 0)
local CONCRETE = C(184, 180, 168)
local BLACK = C(30, 30, 30)
local STEEL = C(120, 122, 125)
local BRAND = C(38, 150, 160) -- franja turquesa de la promotora
local DIRT = C(128, 98, 62)
local GROUND = 0.02 -- el terra és el terreny (Ground), per poder-hi fer clots

local function O(x, y, z)
	return CF(ox + x, y, oz + z)
end
local function W(x, y, z)
	return V3(ox + x, y, oz + z)
end

-- ── terra del solar: el terreny mateix (01_ground el pinta de Ground) ──
-- rodades de l'excavadora des de la porta
for s = -1, 1, 2 do
	for k = 0, 7 do
		P(V3(2, 0.05, 0.5), O(16 + s * 3.2, GROUND + 0.05, 28 - k * 1.1), C(96, 74, 48), M.Ground, zone, true)
	end
end

-- ── tanca: panells blancs amb franja de color ──
local function hoarding(a, b)
	local L = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b) * CF(0, 2, -L / 2)
	P(V3(0.4, 4, L), cf, MOD.white, M.SmoothPlastic, zone)
	P(V3(0.46, 0.7, L), cf * CF(0, 1.1, 0), BRAND, M.SmoothPlastic, zone, true)
	P(V3(0.46, 0.3, L), cf * CF(0, 0.5, 0), YELLOW, M.SmoothPlastic, zone, true)
	local n = math.max(1, math.floor(L / 6))
	for k = 0, n do
		local p = a:Lerp(b, k / n)
		-- 0,56 de gruix: 0,05 més que les franges (0,46), perquè les cares no
		-- quedin al mateix pla (amb 0,5 hi quedaven a 0,02 i feien pampallugues)
		P(V3(0.56, 4.3, 0.56), CF(p + UP * 2.15), MOD.steel, M.Metal, zone)
		P(V3(1.2, 0.5, 1.2), CF(p + UP * 0.25), MOD.concD, M.Concrete, zone, true)
	end
	-- rètol imprès a la cara de fora, als trams llargs
	if L > 40 then
		local mid = a:Lerp(b, 0.5)
		local out = (V3(mid.X, 0, mid.Z) - V3(ox, 0, oz)).Unit
		local banner = P(V3(26, 2.2, 0.1), CFrame.lookAt(mid + UP * 2.4 + out * 0.3, mid + UP * 2.4 + out * 2), MOD.char, M.SmoothPlastic, zone, true)
		Label(banner, "FOSSILS FOUND HERE · DIG SITE", MOD.white, Enum.Font.GothamBlack)
	end
end
local c = V3(ox, 0, oz)
hoarding(c + V3(-HALF, 0, -HALF), c + V3(HALF, 0, -HALF))
hoarding(c + V3(-HALF, 0, -HALF), c + V3(-HALF, 0, HALF))
hoarding(c + V3(HALF, 0, -HALF), c + V3(HALF, 0, HALF))
hoarding(c + V3(-HALF, 0, HALF), c + V3(-8, 0, HALF))
hoarding(c + V3(8, 0, HALF), c + V3(HALF, 0, HALF))

-- ── porta al sud, amb rètol mirant al camí ──
for s = -1, 1, 2 do
	P(V3(1.2, 9, 1.2), O(s * 8.6, 4.5, HALF), YELLOW, M.SmoothPlastic, zone)
	for k = 0, 4 do
		P(V3(1.26, 0.9, 1.26), O(s * 8.6, 1 + k * 1.8, HALF), BLACK, M.SmoothPlastic, zone, true)
	end
	-- banderoles de colors a dalt dels pilars
	P(V3(0.15, 2.6, 0.15), O(s * 8.6, 10.3, HALF), MOD.steel, M.Metal, zone, true)
	P(V3(0.08, 1.2, 1.8), O(s * 8.6, 11, HALF + 0.9), s < 0 and ORANGE or BRAND, M.Fabric, zone, true)
end
local sign = P(V3(16, 3, 0.4), O(0, 8, HALF + 0.4), MOD.char, M.SmoothPlastic, zone)
Label(sign, "ZONE 1 · FOSSIL DIG SITE", MOD.white, Enum.Font.GothamBlack, Enum.NormalId.Back)
sign.Name = "ZoneSign"
P(V3(16, 0.35, 0.45), O(0, 6.4, HALF + 0.4), YELLOW, M.SmoothPlastic, zone, true)
local warnSign = P(V3(3, 3, 0.3), O(12, 2.6, HALF + 0.35), C(250, 210, 40), M.SmoothPlastic, zone, true)
Label(warnSign, "⚠", BLACK, Enum.Font.FredokaOne, Enum.NormalId.Back)

-- ── edifici en construcció (24x18, racó nord-est) ──
do
	local m = Instance.new("Model")
	m.Name = "BuildingUnderConstruction"
	local bx, bz = 16, -19
	local BW, D, FLH, floors = 24, 18, 7, 3
	for f = 0, floors do
		local y = f * FLH
		if f > 0 then
			P(V3(BW, 0.8, D), O(bx, y, bz), CONCRETE, M.Concrete, m)
		end
		if f < floors then
			for ix = 0, 3 do
				for iz = 0, 2 do
					P(V3(1.4, FLH, 1.4), O(bx - BW / 2 + 0.8 + ix * (BW - 1.6) / 3, y + FLH / 2, bz - D / 2 + 0.8 + iz * (D - 1.6) / 2), CONCRETE, M.Concrete, m)
				end
			end
		end
	end
	P(V3(BW + 1, 1, D + 1), O(bx, 0.3, bz), C(150, 146, 136), M.Concrete, m)
	-- mur cortina de vidre a mig muntar (cara nord i oest), per fora de les columnes
	local function curtain(a0, a1, off, y0, h, alongZ)
		local span = a1 - a0
		local n = math.max(1, math.floor(span / 4))
		for k = 0, n - 1 do
			local mid = a0 + (k + 0.5) * span / n
			local size = if alongZ then V3(0.3, h, span / n - 0.3) else V3(span / n - 0.3, h, 0.3)
			local pos = if alongZ then O(bx + off, y0 + h / 2, bz + mid) else O(bx + mid, y0 + h / 2, bz + off)
			local g = P(size, pos, MOD.glass, M.SmoothPlastic, m)
			g.Reflectance = 0.35
		end
	end
	curtain(-BW / 2 + 1.6, BW / 2 - 1.6, -D / 2 - 0.3, 0.8, FLH - 1.6, false)
	curtain(-BW / 2 + 1.6, 2, -D / 2 - 0.3, FLH + 0.4, FLH - 1.6, false)
	curtain(-D / 2 + 1.6, D / 2 - 1.6, -BW / 2 - 0.3, 0.8, FLH - 1.6, true)
	-- ferros d'espera a dalt de tot
	for ix = 0, 3 do
		for iz = 0, 2 do
			for q = -1, 1, 2 do
				P(V3(0.18, 2.4, 0.18), O(bx - BW / 2 + 0.8 + ix * (BW - 1.6) / 3 + q * 0.35, floors * FLH + 1.6, bz - D / 2 + 0.8 + iz * (D - 1.6) / 2), C(120, 70, 40), M.SmoothPlastic, m, true)
			end
		end
	end
	-- bastida metàl·lica a la cara sud
	local sz = bz + D / 2 + 1.8
	for ix = 0, 6 do
		local x = bx - BW / 2 + ix * BW / 6
		for _, dz in ipairs({ 0, 2.2 }) do
			P(V3(0.3, floors * FLH + 3, 0.3), O(x, (floors * FLH + 3) / 2, sz + dz), STEEL, M.Metal, m, true)
		end
	end
	for f = 1, floors do
		P(V3(BW, 0.35, 2.6), O(bx, f * FLH - 0.6, sz + 1.1), C(150, 152, 154), M.DiamondPlate, m)
		P(V3(BW, 0.25, 0.25), O(bx, f * FLH + 0.6, sz + 2.2), STEEL, M.Metal, m, true)
		P(V3(BW, 0.25, 0.25), O(bx, f * FLH + 1.6, sz + 2.2), STEEL, M.Metal, m, true)
	end
	local net = P(V3(10, floors * FLH, 0.1), O(bx + 6, floors * FLH / 2 + 0.5, sz + 2.4), C(60, 140, 80), M.Fabric, m, true)
	net.Transparency = 0.35
	-- pancarta a la bastida
	local ban = P(V3(9, 3, 0.1), O(bx - 6, 12, sz + 2.45), MOD.white, M.Fabric, m, true)
	Label(ban, "NEW FOSSIL WING · COMING SOON", BRAND, Enum.Font.GothamBlack, Enum.NormalId.Back)
	m.Parent = zone
end

-- ── grua torre de 22 d'alt (la ploma passa per sobre de l'edifici) ──
do
	local m = Instance.new("Model")
	m.Name = "TowerCrane"
	local gx, gz = 2, -25
	local H = 22
	P(V3(5, 1.6, 5), O(gx, 0.8, gz), CONCRETE, M.Concrete, m)
	local S2 = 1.1
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		P(V3(0.35, H, 0.35), O(gx + q[1] * S2, H / 2 + 1.6, gz + q[2] * S2), YELLOW, M.Metal, m)
	end
	local panel_h = 2.4
	for k = 0, math.floor((H - 1) / panel_h) - 1 do
		local y0 = 1.6 + k * panel_h
		for _, f in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local a, b
			if f[1] ~= 0 then
				a = V3(ox + gx + f[1] * S2, y0, oz + gz - S2)
				b = V3(ox + gx + f[1] * S2, y0 + panel_h, oz + gz + S2)
				if k % 2 == 1 then
					a, b = V3(a.X, a.Y, b.Z), V3(b.X, b.Y, a.Z)
				end
			else
				a = V3(ox + gx - S2, y0, oz + gz + f[2] * S2)
				b = V3(ox + gx + S2, y0 + panel_h, oz + gz + f[2] * S2)
				if k % 2 == 1 then
					a, b = V3(b.X, a.Y, a.Z), V3(a.X, b.Y, b.Z)
				end
			end
			beam(a, b, 0.22, YELLOW, M.Metal, m, true)
		end
	end
	local top = H + 1.6
	P(V3(3, 1, 3), O(gx, top + 0.5, gz), YELLOW_D, M.Metal, m)
	P(V3(2.2, 2, 2.4), O(gx - 1.8, top + 1.6, gz), COL.bone, M.SmoothPlastic, m)
	P(V3(2.25, 0.9, 2.45), O(gx - 1.8, top + 2, gz), COL.glass, M.SmoothPlastic, m, true)
	-- ploma (cap a +X, sobre l'edifici) i contraploma
	local jibY = top + 2.4
	local L1, L2 = 24, 9
	for _, zz in ipairs({ -0.7, 0.7 }) do
		P(V3(L1, 0.3, 0.3), O(gx + L1 / 2, jibY, gz + zz), YELLOW, M.Metal, m)
	end
	P(V3(L1, 0.3, 0.3), O(gx + L1 / 2, jibY + 1.4, gz), YELLOW, M.Metal, m)
	for k = 0, 11 do
		local x = gx + k * 2
		for _, zz in ipairs({ -0.7, 0.7 }) do
			beam(V3(ox + x, jibY, oz + gz + zz), V3(ox + x + 1, jibY + 1.4, oz + gz), 0.18, YELLOW, M.Metal, m, true)
		end
	end
	P(V3(L2, 0.4, 2), O(gx - L2 / 2, jibY, gz), YELLOW, M.Metal, m)
	P(V3(2.4, 2.2, 2.2), O(gx - L2 + 1.2, jibY + 1.3, gz), CONCRETE, M.Concrete, m)
	P(V3(0.5, 4, 0.5), O(gx, jibY + 2.4, gz), YELLOW, M.Metal, m)
	beam(V3(ox + gx, jibY + 4.4, oz + gz), V3(ox + gx + L1 * 0.7, jibY + 1.4, oz + gz), 0.15, STEEL, M.Metal, m, true)
	beam(V3(ox + gx, jibY + 4.4, oz + gz), V3(ox + gx - L2, jibY + 0.4, oz + gz), 0.15, STEEL, M.Metal, m, true)
	-- carro, cable i un feix de bigues penjat sobre l'edifici
	local tx = gx + 17
	P(V3(1.6, 0.6, 1.8), O(tx, jibY - 0.4, gz), YELLOW_D, M.Metal, m)
	P(V3(0.12, 5, 0.12), O(tx, jibY - 3.1, gz), BLACK, M.Metal, m, true)
	P(V3(0.8, 0.8, 0.8), O(tx, jibY - 5.8, gz), ORANGE, M.SmoothPlastic, m)
	for k = -1, 1 do
		P(V3(0.8, 0.8, 7), O(tx + k * 0.9, jibY - 7.4, gz), C(90, 96, 104), M.Metal, m)
	end
	-- llum vermell d'avís a dalt de tot
	Ball(0.6, W(gx, jibY + 4.8, gz), C(255, 60, 50), M.Neon, m, true)
	m.Parent = zone
end

-- ── excavadora (13 d'alt amb el braç aixecat), racó sud-est ──
local function excavator(cf)
	local m = Instance.new("Model")
	m.Name = "Excavator"
	for s = -1, 1, 2 do
		P(V3(2.2, 2, 11), cf * CF(s * 3.2, 1, 0), C(40, 40, 42), M.SmoothPlastic, m)
		for k = -2, 2 do
			Cyl(2.3, 1.7, cf * CF(s * 3.2, 1, k * 2.2), C(70, 70, 72), M.Metal, m, true)
		end
	end
	P(V3(5, 1, 5), cf * CF(0, 2.5, 0), BLACK, M.Metal, m)
	local body = cf * CF(0, 3, 0.6)
	P(V3(7.4, 3.2, 8), body * CF(0, 1.6, 1.2), YELLOW, M.SmoothPlastic, m)
	P(V3(7.6, 2, 2.2), body * CF(0, 1.2, 5.4), YELLOW_D, M.SmoothPlastic, m)
	P(V3(3.4, 4.2, 3.6), body * CF(-1.8, 5.2, -1.4), YELLOW, M.SmoothPlastic, m)
	P(V3(3.45, 2.4, 3.65), body * CF(-1.8, 5.7, -1.4), COL.glass, M.SmoothPlastic, m, true)
	P(V3(0.5, 2.4, 0.5), body * CF(2.4, 4.4, 3.2), BLACK, M.Metal, m, true)
	local pivot = body * CF(1.2, 3.4, -2.6)
	local boom = pivot * CFrame.Angles(rad(52), 0, 0)
	P(V3(1.2, 1.6, 9), boom * CF(0, 0, -4.5), YELLOW, M.SmoothPlastic, m)
	local elbow = boom * CF(0, 0, -9)
	local stick = elbow * CFrame.Angles(rad(-128), 0, 0)
	P(V3(1, 1.2, 6.5), stick * CF(0, 0, -3.25), YELLOW, M.SmoothPlastic, m)
	local wrist = stick * CF(0, 0, -6.5)
	local bucket = P(V3(2.6, 2, 2.2), wrist * CFrame.Angles(rad(30), 0, 0) * CF(0, 0, -1), C(90, 90, 92), M.Metal, m)
	for k = -1, 1 do
		P(V3(0.4, 0.3, 0.8), bucket.CFrame * CF(k * 0.9, -1.1, -0.8), C(60, 60, 60), M.Metal, m, true)
	end
	beam(pivot.Position + UP * -1.5, (boom * CF(0, -0.6, -4)).Position, 0.45, C(200, 200, 205), M.Metal, m, true)
	m.Parent = zone
	return m
end
excavator(O(24, GROUND, 22) * CFrame.Angles(0, rad(-10), 0))

-- ── oficina d'obra: dos mòduls-contenidor apilats, amb escala i barana ──
do
	local m = Instance.new("Model")
	m.Name = "SiteOffice"
	local cf = O(-24, GROUND, -23) * CFrame.Angles(0, math.pi, 0)
	for lvl = 0, 1 do
		local y = 1.6 + lvl * 3.2
		P(V3(8, 3, 4), cf * CF(0, y, lvl * 0.6), lvl == 0 and MOD.white or BRAND, M.SmoothPlastic, m)
		P(V3(8.2, 0.25, 4.2), cf * CF(0, y + 1.62, lvl * 0.6), MOD.steel, M.Metal, m, true)
		local w = P(V3(3.4, 1.2, 0.2), cf * CF(-1.6, y + 0.3, lvl * 0.6 - 2.1), MOD.glass, M.SmoothPlastic, m, true)
		w.Reflectance = 0.3
		P(V3(1.2, 2.3, 0.2), cf * CF(2.6, y - 0.3, lvl * 0.6 - 2.1), MOD.steel, M.Metal, m, true)
	end
	for k = 0, 5 do
		P(V3(1.4, 0.2, 0.7), cf * CF(4.6, 0.4 + k * 0.55, -2.6 + k * 0.55), MOD.steel, M.Metal, m, true)
	end
	P(V3(8, 0.2, 1.2), cf * CF(0, 3.25, -2.75), MOD.steel, M.Metal, m, true)
	glassRail((cf * CF(-4, 3.35, -3.35)).Position, (cf * CF(4, 3.35, -3.35)).Position, 1.8, m)
	local s = P(V3(4, 0.8, 0.2), cf * CF(-1, 5.9, -1.55), MOD.char, M.SmoothPlastic, m, true)
	Label(s, "SITE OFFICE", MOD.white, Enum.Font.GothamBlack)
	m.Parent = zone
end

-- ── la gran troballa: un sauròpode mig desenterrat i un crani de T-Rex ──
do
	local m = Instance.new("Model")
	m.Name = "BigFossil"
	local base = O(-10, GROUND, -17)
	-- clot poc fondo amb vora de terra
	P(V3(21, 0.14, 7), base * CF(1.5, 0.08, 0), C(98, 74, 48), M.Ground, m, true)
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		Ellipsoid(V3(3.4, 1, 2.6), base * CF(1.5 + math.cos(a) * 11.4, 0.25, math.sin(a) * 4.2) * CFrame.Angles(0, -a, 0), DIRT, M.Ground, m, true)
	end
	local prev
	for i = 0, 9 do
		local s = (i >= 3 and i <= 6) and 1.3 or 1
		local p = (base * CF(-8 + i * 1.8, 0.45, math.sin(i * 0.5) * 0.8)).Position
		Ellipsoid(V3(1.3 * s, 0.8 * s, 1.3 * s), CF(p), COL.bone, M.Marble, m)
		if prev then
			beam(prev, p, 0.55, COL.bone, M.Marble, m, true)
		end
		if i >= 3 and i <= 6 then
			for sgn = -1, 1, 2 do
				local q = p + V3(0.3, -0.1, sgn * 1.2)
				beam(p, q, 0.4, COL.bone, M.Marble, m, true)
				beam(q, q + V3(0.2, -0.1, sgn * 1.2), 0.35, COL.bone, M.Marble, m, true)
			end
		end
		prev = p
	end
	-- el crani de T-Rex, mig enterrat a l'altre cap
	Asset("trexSkull", base * CF(12, -0.4, 0) * CFrame.Angles(0, rad(-80), rad(-8)), 3.6, m)
	-- piquets i cordill
	for _, q in ipairs({ { -11, -4 }, { 14, -4 }, { 14, 4 }, { -11, 4 } }) do
		P(V3(0.3, 1.6, 0.3), base * CF(q[1], 0.8, q[2]), COL.wood, M.Wood, m, true)
	end
	for _, e in ipairs({ { -11, -4, 14, -4 }, { 14, -4, 14, 4 }, { 14, 4, -11, 4 }, { -11, 4, -11, -4 } }) do
		beam((base * CF(e[1], 1.3, e[2])).Position, (base * CF(e[3], 1.3, e[4])).Position, 0.07, C(230, 60, 50), M.Fabric, m, true)
	end
	local sg = P(V3(5, 1.6, 0.3), base * CF(4, 2.6, 4.4), MOD.char, M.SmoothPlastic, m, true)
	Label(sg, "BIG DISCOVERY!", C(255, 206, 110), Enum.Font.GothamBlack, Enum.NormalId.Back)
	P(V3(0.3, 2.6, 0.3), base * CF(4, 1.3, 4.4), COL.wood, M.Wood, m, true)
	-- focus que il·lumina la troballa
	local tf = base * CF(-12, 0, 5)
	P(V3(2.4, 1, 2.4), tf * CF(0, 0.5, 0), YELLOW, M.SmoothPlastic, m)
	P(V3(0.4, 10, 0.4), tf * CF(0, 5.5, 0), STEEL, M.Metal, m)
	for s = -1, 1, 2 do
		P(V3(1.4, 1.2, 0.6), tf * CF(s * 0.9, 10.6, -0.4), C(255, 250, 220), M.Neon, m, true)
	end
	m.Parent = zone
end


-- ── ELS 16 CLOTS PER EXCAVAR (DigSpot) ──
-- Una zona excavada de 32x32 (alineada amb la graella del terreny) amb clots
-- de mides, formes i fondàries diferents, repartits a l'atzar.
local dig = Instance.new("Model")
dig.Name = "FossilDig"
dig.Parent = zone
local FX0, FZ0 = -296, -48 -- cantó nord-oest (món)
local pits = digField(FX0, FZ0, 32, 32, 16, "construction", "ObraDig", rng, dig)
-- vora de fusta al voltant (tapa la junta amb el terreny)
for _, e in ipairs({ { FX0 + 16, FZ0 - 0.3, 33, 0.6 }, { FX0 + 16, FZ0 + 32.3, 33, 0.6 }, { FX0 - 0.3, FZ0 + 16, 0.6, 32 }, { FX0 + 32.3, FZ0 + 16, 0.6, 32 } }) do
	P(V3(e[3], 0.5, e[4]), CF(e[1], GROUND + 0.2, e[2]), COL.wood, M.WoodPlanks, dig)
end
-- piquets i cordill només pel perímetre
for k = 0, 8 do
	for _, c in ipairs({ V3(FX0 + k * 4, GROUND, FZ0), V3(FX0 + k * 4, GROUND, FZ0 + 32), V3(FX0, GROUND, FZ0 + k * 4), V3(FX0 + 32, GROUND, FZ0 + k * 4) }) do
		P(V3(0.3, 1.8, 0.3), CF(c + UP * 0.9), COL.wood, M.Wood, dig, true)
	end
end
for _, e in ipairs({ { FX0 + 16, FZ0, 32, 0.07 }, { FX0 + 16, FZ0 + 32, 32, 0.07 }, { FX0, FZ0 + 16, 0.07, 32 }, { FX0 + 32, FZ0 + 16, 0.07, 32 } }) do
	P(V3(e[3], 0.07, e[4]), CF(e[1], GROUND + 1.5, e[2]), C(230, 60, 50), M.Fabric, dig, true)
end
-- una carpa blanca sobre el clot més gros
for i = 1, 1 do
	local q = pits[i]
	if q then
		local tc = CF(q.x, GROUND, q.z)
		-- potes fora del clot (i del seu esglaó)
		local half = math.max(4.3, q.outer + 0.8)
		for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			P(V3(0.3, 7, 0.3), tc * CF(c[1] * half, 3.5, c[2] * half), MOD.steel, M.Metal, dig, true)
		end
		P(V3(half * 2 + 0.6, 0.3, half * 2 + 0.6), tc * CF(0, 7.1, 0), MOD.white, M.Fabric, dig, true).CastShadow = true
		for s2 = -1, 1, 2 do
			P(V3(half * 2 + 0.8, 0.8, 0.15), tc * CF(0, 6.6, s2 * (half + 0.35)), BRAND, M.Fabric, dig, true)
		end
	end
end
-- carretons i piles de terra entre els forats
Asset("wheelbarrow", O(8, GROUND, 14) * CFrame.Angles(0, rad(40), 0), 2.6, dig)
Asset("wheelbarrow", O(10.5, GROUND, 25) * CFrame.Angles(0, rad(-120), 0), 2.6, dig)
-- garbells i galledes a la vora de la quadrícula
for k, sp in ipairs({ { 7.5, -4 }, { 7.5, 4 }, { -14, 25.5 }, { -22, 25.5 } }) do
	local scf = O(sp[1], GROUND, sp[2]) * CFrame.Angles(0, k * 1.1, 0)
	P(V3(2.2, 0.2, 1.6), scf * CF(0, 1.2, 0) * CFrame.Angles(0, 0, rad(10)), COL.wood, M.WoodPlanks, dig, true)
	local mesh = P(V3(1.9, 0.05, 1.3), scf * CF(0, 1.32, 0) * CFrame.Angles(0, 0, rad(10)), C(90, 90, 92), M.DiamondPlate, dig, true)
	mesh.Transparency = 0.2
	for q = -1, 1, 2 do
		P(V3(0.15, 1.2, 0.15), scf * CF(q * 0.9, 0.6, 0), COL.wood, M.Wood, dig, true)
	end
	Ellipsoid(V3(1.8, 0.5, 1.4), scf * CF(0.2, 0.2, 0), DIRT, M.Ground, dig, true)
	VCyl(1.2, 1.3, (scf * CF(1.8, 0.6, 0.6)).Position, k % 2 == 0 and C(40, 40, 42) or ORANGE, M.SmoothPlastic, dig, true)
end
for _, h in ipairs({ { -27, -14, 6 }, { 26, -2, 6 }, { 12, 6, 4 } }) do
	local hp = O(h[1], GROUND, h[2])
	Ellipsoid(V3(h[3], h[3] * 0.45, h[3] * 0.8), hp, DIRT, M.Ground, dig)
	Ellipsoid(V3(h[3] * 0.6, h[3] * 0.4, h[3] * 0.5), hp * CF(h[3] * 0.2, h[3] * 0.2, 0), C(146, 112, 70), M.Ground, dig, true)
end
-- taula de treball amb ossos per netejar i una caixa de troballes
do
	local tb = O(11, GROUND, -1.5) * CFrame.Angles(0, rad(15), 0)
	P(V3(5, 0.3, 2.4), tb * CF(0, 2.6, 0), COL.wood, M.WoodPlanks, dig)
	for _, q in ipairs({ { 2.2, 1 }, { -2.2, 1 }, { 2.2, -1 }, { -2.2, -1 } }) do
		P(V3(0.25, 2.5, 0.25), tb * CF(q[1], 1.25, q[2]), MOD.steel, M.Metal, dig, true)
	end
	for k = -1, 1 do
		local bp = (tb * CF(k * 1.4, 2.95, 0)).Position
		beam(bp - V3(0.6, 0, 0.2), bp + V3(0.6, 0, 0.2), 0.3, COL.bone, M.Marble, dig, true)
		Ball(0.45, bp - V3(0.6, 0, 0.2), COL.bone, M.Marble, dig, true)
		Ball(0.45, bp + V3(0.6, 0, 0.2), COL.bone, M.Marble, dig, true)
	end
	P(V3(1.6, 1, 1.2), tb * CF(0, 0.5, 2.2), C(40, 110, 170), M.SmoothPlastic, dig, true)
	local lbl = P(V3(1.2, 0.5, 0.05), tb * CF(0, 0.6, 2.82), MOD.white, M.SmoothPlastic, dig, true)
	Label(lbl, "FINDS", MOD.char, Enum.Font.GothamBlack, Enum.NormalId.Back)
end

-- ── material d'obra dins la tanca: tubs, lavabo, cons, roques ──
do
	local m = Instance.new("Model")
	m.Name = "SiteMaterials"
	for k = 0, 2 do
		for q = 0, 2 - k do
			Cyl(8, 1.6, O(24, GROUND + 0.8 + k * 1.4, -3 + q * 1.7 + k * 0.85), CONCRETE, M.Concrete, m)
		end
	end
	for k = 0, 3 do
		local p = (O(-2 - k * 2.6, GROUND, 28)).Position
		Pyramid(CF(p), 1.2, 2, ORANGE, M.SmoothPlastic, m)
		P(V3(1.4, 0.2, 1.4), CF(p + UP * 0.1), BLACK, M.SmoothPlastic, m, true)
	end
	P(V3(3, 6, 3), O(27, GROUND + 3, 10), C(40, 120, 180), M.SmoothPlastic, m)
	P(V3(3.2, 0.4, 3.2), O(27, GROUND + 6.2, 10), C(230, 230, 230), M.SmoothPlastic, m)
	-- roques trobades, apilades a la vora de la tanca
	for k, rp in ipairs({ { -27.5, 27.5, 2.6 }, { -25.5, 28, 1.6 }, { 27.5, 3, 2.4 }, { 27.8, 5.2, 1.4 }, { -28, -18, 2 } }) do
		Rock(O(rp[1], GROUND, rp[2]) * CFrame.Angles(0, k * 1.3, 0), rp[3], m, k, C(150, 140, 126))
	end
	m.Parent = zone
end

-- accés de grava fins al camí
P(V3(18, 0.5, 8), O(0, 0.1, HALF + 4), C(170, 158, 136), M.Slate, zone)
-- punt d'arribada del botó "Dig Site" de la UI (TravelService): al camí, mirant la porta
do
	local tp = P(V3(4, 0.2, 4), O(0, 0.45, HALF + 6), COL.brass, M.SmoothPlastic, zone, true)
	tp.Name = "TravelPoint"
	tp.Transparency = 1
	tp.CanQuery = false
	tp:SetAttribute("Destination", "construction")
	tag(tp, "TravelPoint")
end
zone.Parent = ZONES

print("Zona 1 (obra 60x60): 16 forats mig excavats, carpes, gran troballa, grua, edifici i excavadora")

end }
STEPS[#STEPS + 1] = { "08_props", function()
-- ═══════════════════════════ 08 · VIDA DE CARRER ═══════════════════════════
-- Arbres i fanals a les voreres, jardí del Passeig dels Museus, patis de
-- les illes, bosc a les vores i turons verds a l'horitzó. Sense cotxes.
local F = folder("Props", WORLD)
local TREES = folder("Trees", F)
local LAMPS = folder("Lamps", F)
local rng = Random.new(7)
local WALK_TOP = 0.65
local PZ = LAYOUT.PLAZA

-- ── cap arbre dins d'un edifici ──
-- Els arbres de vorera són a 2 de la façana i la capçada en fa 4-5 de radi:
-- es ficaven dins de les cases. Abans de plantar-ne un, es mira si la seva
-- capçada toca alguna peça d'un edifici (ja fets: 03-05 van abans); si la
-- toca, es fa més petit, i si ni així hi cap, no es planta.
local fitParams = OverlapParams.new()
fitParams.FilterType = Enum.RaycastFilterType.Include
do
	local list = {}
	for _, f in ipairs({ WORLD:FindFirstChild("Houses"), WORLD:FindFirstChild("Plaza"), WORLD:FindFirstChild("ToolShop"), MUSEUMS, ZONES }) do
		if f then
			table.insert(list, f)
		end
	end
	fitParams.FilterDescendantsInstances = list
end
local MIN_TREE = 9
-- caixa que ocupa la capçada: `reach` de radi (en fracció de h), de y0 a y1
local function clearFor(p, h, reach, y0, y1)
	local size = V3(2 * reach * h + 0.4, (y1 - y0) * h, 2 * reach * h + 0.4)
	return #Workspace:GetPartBoundsInBox(CF(p + UP * ((y0 + y1) / 2 * h)), size, fitParams) == 0
end
-- torna l'alçada que hi cap (<= h) i si cal la capçada recollida, o nil
local function fitRound(p, h)
	while h >= MIN_TREE do
		if clearFor(p, h, 0.39, 0.42, 1.06) then
			return h, false
		end
		-- capçada recollida (les boles de sobre gairebé centrades)
		if clearFor(p, h, 0.33, 0.42, 1.06) then
			return h, true
		end
		h -= 1
	end
	return nil
end

-- ── arbres (capçades ovalades de diversos verds, no boles perfectes) ──
local function roundTree(p, h, parent)
	local fh, tight = fitRound(p, h)
	-- (els números a l'atzar es treuen igualment: així la resta del món
	-- surt igual tant si l'arbre hi cap com si no)
	local r1, r2, r3, r4, r5 = rng:NextNumber(0.1, 0.8), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)
	if not fh then
		return nil
	end
	h = fh
	local s2, s3 = if tight then 0.03 else 0.08, if tight then 0.05 else 0.16
	local m = Instance.new("Model")
	m.Name = "Tree"
	VCyl(h * 0.5, 1.1 + h * 0.03, p + UP * (h * 0.25), C(112, 90, 66), M.Wood, m)
	beam(p + UP * (h * 0.42), p + UP * (h * 0.58) + V3(h * 0.12, 0, h * 0.05), 0.6, C(112, 90, 66), M.Wood, m, true)
	local col = COL.leaf:Lerp(COL.leafDark, r1)
	Ellipsoid(V3(h * 0.62, h * 0.46, h * 0.62), CF(p + UP * (h * 0.68)), col, M.SmoothPlastic, m)
	Ellipsoid(V3(h * 0.46, h * 0.38, h * 0.46), CF(p + UP * (h * 0.86) + V3(r2, 0, r3) * h * s2), col:Lerp(C(255, 255, 255), 0.07), M.SmoothPlastic, m)
	Ellipsoid(V3(h * 0.42, h * 0.32, h * 0.42), CF(p + UP * (h * 0.6) + V3(r4, 0, r5) * h * s3), col:Lerp(C(0, 0, 0), 0.1), M.SmoothPlastic, m)
	m.Parent = parent or TREES
	return m
end
local function conifer(p, h, parent)
	-- base de 0,5h girada: arriba a 0,36h del tronc
	while h >= MIN_TREE * 1.5 and not clearFor(p, h, 0.36, 0.1, 0.9) do
		h -= 1.5
	end
	local rots = { rng:NextNumber(), rng:NextNumber(0, 1.5), rng:NextNumber(0, 1.5), rng:NextNumber(0, 1.5) }
	if not clearFor(p, h, 0.36, 0.1, 0.9) then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Pine"
	VCyl(h * 0.25, 1.3, p + UP * (h * 0.125), C(100, 80, 60), M.Wood, m)
	local col = C(52, 92, 62):Lerp(C(72, 112, 72), rots[1])
	for k = 0, 2 do
		Pyramid(CF(p + UP * (h * 0.14 + k * h * 0.24)) * CFrame.Angles(0, rots[k + 2], 0), h * 0.5 * (1 - k * 0.25), h * 0.38, col, M.SmoothPlastic, m)
	end
	m.Parent = parent or TREES
	return m
end
local function cypress(p, h, parent)
	local m = Instance.new("Model")
	m.Name = "Cypress"
	VCyl(2.4, 0.9, p + UP * 1.2, COL.woodDark, M.Wood, m)
	Ellipsoid(V3(4.4, h, 4.4), CF(p + UP * (1.6 + h / 2)), C(58, 96, 60), M.SmoothPlastic, m)
	m.Parent = parent or TREES
end

-- ── fanal de carrer modern (lib: modernLamp) ──
local function streetLamp(p, arm)
	local m = modernLamp(p, arm, LAMPS, 14, rng:NextNumber() < 0.4)
	m.Name = "StreetLamp"
	return m
end

-- ── al llarg dels carrers (no dins la plaça ni davant dels museus) ──
local roads = {}
for _, r in ipairs(LAYOUT.ROADS) do
	local horiz = r[2] == r[4]
	table.insert(roads, { horiz = horiz, c = horiz and r[2] or r[1], a0 = horiz and math.min(r[1], r[3]) or math.min(r[2], r[4]), a1 = horiz and math.max(r[1], r[3]) or math.max(r[2], r[4]), w = r[5] })
end
local function nearCross(rd, a)
	for _, o in ipairs(roads) do
		if o ~= rd and o.horiz ~= rd.horiz and math.abs(o.c - a) < o.w / 2 + 10 and rd.c >= o.a0 - 12 and rd.c <= o.a1 + 12 then
			return true
		end
	end
	if rd.horiz and math.abs(a - 20) < 18 then
		return true -- pas del passeig
	end
	return false
end
local function pt(rd, a, off, y)
	if rd.horiz then
		return V3(a, y, rd.c + off)
	end
	return V3(rd.c + off, y, a)
end
local function blocked(p, pad)
	return (p.X > PZ.x0 - 4 and p.X < PZ.x1 + 4 and p.Z > PZ.z0 - 4 and p.Z < PZ.z1 + 4) or inRects(p.X, p.Z, LAYOUT.MUSEUM_RECTS, pad or 26) or p.X > LAYOUT.PROM.x0 - 4
end
local nLamps, nTrees = 0, 0
for _, rd in ipairs(roads) do
	local roadW = rd.w - 8
	local k = 0
	local a = rd.a0 + 18
	while a < rd.a1 - 10 do
		if not nearCross(rd, a) then
			k += 1
			local s = (k % 2 == 0) and 1 or -1
			if k % 2 == 0 then
				local p = pt(rd, a, s * (roadW / 2 + 0.9), WALK_TOP)
				if not blocked(p, 4) then
					streetLamp(p, (pt(rd, a, 0, 0) - pt(rd, a, s, 0)).Unit)
					nLamps += 1
				end
			end
			-- a 2,5 de la façana (i no a 2): més lloc per a la capçada, i
			-- l'escocell (2,8) encara no trepitja la calçada
			local tp = pt(rd, a + 9, -s * (rd.w / 2 - 2.5), WALK_TOP)
			if not blocked(tp) then
				if roundTree(tp, rng:NextNumber(12, 15)) then
					P(V3(2.8, 0.2, 2.8), CF(tp + UP * 0.05), C(96, 76, 54), M.SmoothPlastic, TREES, true)
					nTrees += 1
				end
			end
		end
		a += 17
	end
end

-- ── jardí central del Passeig dels Museus ──
do
	local S = LAYOUT.PASSEIG
	local cx = (S.x0 + S.x1) / 2
	for _, seg in ipairs({ { -178, -122 }, { -98, -56 } }) do
		local z0, z1 = seg[1], seg[2]
		P(V3(6.4, 0.8, z1 - z0 - 1), CF(cx, 0.4, (z0 + z1) / 2), C(78, 116, 62), M.SmoothPlastic, F)
		local z = z0 + 5
		local k = 0
		while z < z1 - 3 do
			k += 1
			local p = V3(cx, 0.8, z)
			if k % 3 == 0 then
				-- fanal doble: dos capçals de LED, un cap a cada vorera
				modernLamp(p, V3(1, 0, 0), LAMPS, 12, true).Name = "PasseigLamp"
				modernLamp(p, V3(-1, 0, 0), LAMPS, 12, false).Name = "PasseigLamp"
			elseif k % 3 == 1 then
				cypress(p, rng:NextNumber(12, 16))
			else
				for q = -2, 2 do
					Ball(1.2, p + V3(rng:NextNumber(-2, 2), 0.7, q * 1.1), FLOWERS[rng:NextInteger(1, #FLOWERS)], M.SmoothPlastic, F, true)
				end
				Ellipsoid(V3(4, 2.4, 4), CF(p + UP * 0.9), COL.leafDark, M.SmoothPlastic, F)
			end
			z += 7
		end
		-- bancs a les vores, mirant al jardí
		for bz = z0 + 10, z1 - 8, 18 do
			for s = -1, 1, 2 do
				local bp = V3(cx + s * 7.5, WALK_TOP, bz)
				modernBench(bp, V3(-s, 0, 0), F)
			end
		end
		-- plàtans a les dues vores del passeig
		for tz = z0 + 6, z1 - 4, 14 do
			for s = -1, 1, 2 do
				roundTree(V3(cx + s * 13.4, WALK_TOP, tz), rng:NextNumber(14, 17))
			end
		end
	end
end

-- ── patis interiors de les illes (sense tocar museus ni obra) ──
local OB = LAYOUT.OBRA
for _, b in ipairs(LAYOUT.BLOCKS) do
	local x0, x1, z0, z1 = b[1] + 26, b[2] - 26, b[3] + 26, b[4] - 26
	if x1 - x0 > 6 and z1 - z0 > 6 then
		local n = math.min(6, math.floor((x1 - x0) * (z1 - z0) / 300) + 1)
		for _ = 1, n do
			local p = V3(rng:NextNumber(x0, x1), 0, rng:NextNumber(z0, z1))
			local inObra = p.X > OB.x0 - 6 and p.X < OB.x1 + 6 and p.Z > OB.z0 - 6 and p.Z < OB.z1 + 6
			if not inRects(p.X, p.Z, LAYOUT.MUSEUM_RECTS, 6) and not inObra then
				if rng:NextNumber() < 0.3 then
					conifer(p, rng:NextNumber(16, 22))
				else
					roundTree(p, rng:NextNumber(12, 17))
				end
			end
		end
	end
end

-- ── bosc a les vores (tanca el món) i turons verds a l'horitzó ──
local L = LAYOUT.LAND
for z = L.z0 + 4, L.z1 - 4, 11 do
	conifer(V3(L.x0 + 5 + rng:NextNumber(-2, 2), 0, z), rng:NextNumber(20, 30))
end
for x = L.x0 + 14, LAYOUT.PROM.x0 - 10, 11 do
	for _, zz in ipairs({ L.z0 + 4, L.z1 - 4 }) do
		local p = V3(x, 0, zz + rng:NextNumber(-2, 2))
		if not inRects(p.X, p.Z, LAYOUT.MUSEUM_RECTS, 2) then
			if rng:NextNumber() < 0.6 then
				conifer(p, rng:NextNumber(20, 30))
			else
				roundTree(p, rng:NextNumber(14, 19))
			end
		end
	end
end
local T = Workspace.Terrain
T:FillBlock(CF(-470, -10, 0), V3(260, 16, 1060), M.LeafyGrass)
T:FillBlock(CF(-80, -10, -400), V3(520, 16, 260), M.LeafyGrass)
T:FillBlock(CF(-80, -10, 400), V3(520, 16, 260), M.LeafyGrass)
local hills = {}
for z = -520, 520, 70 do
	table.insert(hills, V3(-540 + rng:NextNumber(-30, 30), -50, z))
end
for x = -470, 140, 70 do
	table.insert(hills, V3(x, -50, -470 + rng:NextNumber(-30, 30)))
	table.insert(hills, V3(x, -50, 470 + rng:NextNumber(-30, 30)))
end
for _, h in ipairs(hills) do
	T:FillBall(h, rng:NextNumber(95, 140), M.LeafyGrass)
end
-- refresca la malla del terreny dels turons (evita forats de visualització)
for _, r in ipairs({ { -720, -400, -560, 560 }, { -600, 200, -640, -300 }, { -600, 200, 300, 640 } }) do
	for z = r[3], r[4] - 1, 400 do
		local region = Region3.new(V3(r[1], -64, z), V3(r[2], 160, math.min(z + 400, r[4]))):ExpandToGrid(4)
		local mats, occ = T:ReadVoxels(region, 4)
		T:WriteVoxels(region, 4, mats, occ)
	end
end
print(("Carrer: %d fanals, %d arbres de vorera; passeig, patis, bosc i turons fets (sense cotxes)"):format(nLamps, nTrees))

end }
STEPS[#STEPS + 1] = { "09_toolshop", function()
-- ═══════════════════════════ 09 · DIG & CO. (botiga d'eines, a la plaça) ═══════════════════════════
-- L'única botiga de la plaça: eines d'arqueòleg estil Fisch. Les eines estan
-- exposades soltes davant la botiga, en semicercle, cadascuna al seu sòcol.
-- El joc (ShopService) hi posa el model i el botó; aquí només hi ha el mapa:
--   · parts "ToolStand" amb atribut ToolId (ha de coincidir amb Config/Tools)
--   · part "ShopkeeperSpot" (on es posa en Rex, darrere el taulell)
--   · TravelPoint "shop" (botó "Tool Shop" de la UI)
local F = folder("ToolShop", WORLD)
local TOP = 0.65
local SC = LAYOUT.SHOP -- centre de l'edifici i cap on mira
local O = CFrame.lookAt(V3(SC.x, TOP, SC.z), V3(SC.x + SC.dx, TOP, SC.z + SC.dz))
local function L(x, y, z)
	return O * CF(x, y, z)
end
local W, D, H = 24, 14, 11 -- amplada (façana), fondària i alçada
local FRONT = -D / 2 -- la façana és a la -Z local
local WOODW = C(150, 104, 68) -- revestiment de fusta
local WOODL = C(196, 150, 104)
local DARKM = MOD.steel
local ORANGE = C(240, 130, 50)
local CREAM = C(250, 240, 218)
local TOOL_IDS = { "rusty_shovel", "steel_trowel", "field_pickaxe", "pro_brush", "golden_shovel", "sonic_drill" }
local TOOL_NAMES = { "RUSTY TROWEL", "STEEL TROWEL", "PRO TROWEL", "RUBY TROWEL", "GOLDEN TROWEL", "DIAMOND TROWEL" }
local TOOL_COLS = { C(150, 96, 60), C(190, 196, 204), C(60, 140, 230), C(230, 50, 80), C(255, 200, 50), C(120, 230, 255) }
local rng = Random.new(909)

local m = Instance.new("Model")
m.Name = "DigAndCo"

-- ── terra: plataforma de fusta davant la botiga, amb un graó ──
P(V3(W + 4, 0.5, D + 2), L(0, 0.25, 1), MOD.concD, M.Concrete, m)
P(V3(W + 2, 0.3, 5), L(0, 0.55, FRONT - 2.4), WOODL, M.WoodPlanks, m)
-- juntes entre taulons: 0,03 per sobre de la plataforma i una mica més
-- curtes, perquè cap cara quedi al mateix pla que les de la plataforma
for k = -5, 5 do
	P(V3(0.15, 0.36, 4.9), L(k * 2.2, 0.56, FRONT - 2.4), C(170, 124, 84), M.WoodPlanks, m, true)
end

-- ── l'edifici: sòcol fosc, parets de fusta, davant obert amb aparadors ──
P(V3(W, 0.4, D), L(0, 0.7, 0), C(120, 90, 62), M.WoodPlanks, m)
P(V3(W, H, 1), L(0, H / 2 + 0.5, D / 2 - 0.5), WOODW, M.WoodPlanks, m)
for s = -1, 1, 2 do
	P(V3(1, H, D), L(s * (W / 2 - 0.5), H / 2 + 0.5, 0), WOODW, M.WoodPlanks, m)
	-- llistons verticals a les parets laterals
	for k = -2, 2 do
		P(V3(0.2, H - 1, 0.4), L(s * (W / 2 + 0.02), H / 2 + 0.5, k * 2.6), C(120, 80, 50), M.WoodPlanks, m, true)
	end
end
P(V3(W + 0.4, 1, D + 0.4), L(0, 1, 0), DARKM, M.Metal, m, true)
-- façana: pilars d'acer, aparadors a banda i banda, obertura amb taulell al mig
-- 0,9 de gruix centrats on hi hauria el de 0,8: sobresurten 0,05 de la
-- paret i del terra (a tocar, les cares de fusta i d'acer feien pampallugues)
for _, x in ipairs({ -W / 2 + 0.4, -4.6, 4.6, W / 2 - 0.4 }) do
	P(V3(0.9, H, 0.9), L(x, H / 2 + 0.5, FRONT + 0.4), DARKM, M.Metal, m)
end
for s = -1, 1, 2 do
	local cx = s * 8.3
	-- ampit de fusta i vidre de l'aparador
	P(V3(6.6, 2, 0.6), L(cx, 1.5, FRONT + 0.5), WOODL, M.WoodPlanks, m)
	local g = P(V3(6.6, 5.4, 0.2), L(cx, 5.2, FRONT + 0.4), MOD.rail, M.Glass, m)
	g.Transparency = 0.6
	P(V3(6.6, 0.3, 0.7), L(cx, 8, FRONT + 0.4), DARKM, M.Metal, m, true)
	-- dins l'aparador: un crani i eines penjades
	P(V3(6, 0.3, 2), L(cx, 2.6, FRONT + 1.6), WOODL, M.WoodPlanks, m, true)
	for k = -1, 1 do
		local tc = L(cx + k * 1.8, 5.2, FRONT + 2.2)
		P(V3(0.2, 2.6, 0.2), tc, COL.woodDark, M.Wood, m, true)
		P(V3(0.9, 1, 0.1), tc * CF(0, -1.5, 0), TOOL_COLS[(k + s + 3) % #TOOL_COLS + 1], M.Metal, m, true)
	end
end
-- dintell sobre l'obertura
P(V3(W, 2.8, 1), L(0, H - 0.9, FRONT + 0.5), WOODW, M.WoodPlanks, m)

-- ── tendal a ratlles taronja i crema, inclinat, amb serrell ──
do
	local n = 12
	local aw = W + 1
	for k = 0, n - 1 do
		local x = -aw / 2 + (k + 0.5) * aw / n
		local col = k % 2 == 0 and ORANGE or CREAM
		P(V3(aw / n, 0.2, 5), L(x, 8.6, FRONT - 2.3) * CFrame.Angles(rad(-18), 0, 0), col, M.Fabric, m, true).CastShadow = true
		-- serrell (triangles penjant)
		Wd(V3(aw / n - 0.1, 0.8, 0.12), L(x, 7.4, FRONT - 4.75) * CFrame.Angles(math.pi, 0, 0) * WEDGE_FIX, col, M.Fabric, m, true)
	end
	-- bombetes al llarg del tendal
	for k = 0, 11 do
		local b = Ball(0.4, (L(-aw / 2 + 1 + k * (aw - 2) / 11, 7.2, FRONT - 4.9)).Position, C(255, 230, 170), M.Neon, m, true)
		if k % 4 == 1 then
			local pl = Instance.new("PointLight")
			pl.Range = 12
			pl.Brightness = 0.7
			pl.Color = C(255, 220, 170)
			pl.Parent = b
		end
	end
end

-- ── teulada volada i rètol 3D a sobre ──
P(V3(W + 3, 0.8, D + 2), L(0, H + 0.9, 0.4), MOD.char, M.SmoothPlastic, m)
P(V3(W + 3.2, 0.25, 0.3), L(0, H + 0.4, FRONT - 0.7), MOD.led, M.Neon, m, true)
do
	-- caixa del rètol
	local sign = P(V3(17, 3.4, 0.8), L(0, H + 3.4, FRONT + 1), MOD.char, M.SmoothPlastic, m)
	Label(sign, "DIG & CO.", C(255, 206, 110), Enum.Font.FredokaOne, Enum.NormalId.Front, 60)
	P(V3(17.8, 4.2, 0.6), L(0, H + 3.4, FRONT + 1.3), ORANGE, M.SmoothPlastic, m, true)
	-- el subtítol, al dintell, per sobre del tendal
	local sub = P(V3(14, 1.1, 0.2), L(0, H - 0.6, FRONT - 0.1), ORANGE, M.SmoothPlastic, m, true)
	Label(sub, "ARCHAEOLOGY TOOLS", MOD.white, Enum.Font.GothamBlack)
	-- pala i pic gegants creuats darrere el rètol (es veuen de lluny)
	local c0 = L(0, H + 6.5, FRONT + 2.2)
	for s = -1, 1, 2 do
		local rot = c0 * CFrame.Angles(0, 0, rad(s * 38))
		P(V3(0.8, 11, 0.8), rot, WOODL, M.WoodPlanks, m)
		if s < 0 then
			-- pala
			P(V3(3, 3.4, 0.4), rot * CF(0, 6.8, 0), C(200, 206, 214), M.Metal, m)
			Wd(V3(3, 1.2, 0.4), rot * CF(0, 9.1, 0) * CFrame.Angles(0, 0, 0) * WEDGE_FIX, C(200, 206, 214), M.Metal, m)
		else
			-- pic
			P(V3(5.4, 0.8, 0.9), rot * CF(0, 5.4, 0), C(110, 116, 126), M.Metal, m)
			for q = -1, 1, 2 do
				Wd(V3(0.9, 0.8, 1.4), rot * CF(q * 3.2, 5.4, 0) * CFrame.Angles(0, q * math.pi / 2, 0) * WEDGE_FIX, C(110, 116, 126), M.Metal, m)
			end
		end
	end
	-- caixes i un barril al terrat
	P(V3(2.4, 2, 2.4), L(-9, H + 2.3, 4), C(170, 124, 84), M.WoodPlanks, m, true)
	P(V3(1.8, 1.6, 1.8), L(-9.4, H + 4.1, 4.2) * CFrame.Angles(0, rad(20), 0), C(170, 124, 84), M.WoodPlanks, m, true)
	VCyl(2.4, 2, (L(9, H + 2.5, 4)).Position, C(40, 110, 170), M.Metal, m, true)
end

-- ── interior: taulell, prestatges i un crani de T-Rex a la paret ──
P(V3(9, 3.2, 1.6), L(0, 2.3, FRONT + 2.2), WOODL, M.WoodPlanks, m)
P(V3(9.4, 0.3, 2), L(0, 4.05, FRONT + 2.2), MOD.char, M.SmoothPlastic, m)
P(V3(9, 0.4, 0.1), L(0, 2.6, FRONT + 1.35), ORANGE, M.SmoothPlastic, m, true)
P(V3(1.4, 1, 1), L(3, 4.7, FRONT + 2.2), C(60, 60, 64), M.Metal, m, true) -- caixa registradora
P(V3(1.6, 0.8, 1.2), L(-3, 4.6, FRONT + 2.2), C(170, 124, 84), M.WoodPlanks, m, true)
VCyl(1, 0.9, (L(-1.2, 4.7, FRONT + 2.2)).Position, C(80, 150, 220), M.SmoothPlastic, m, true)
for k = 0, 2 do
	P(V3(W - 3, 0.3, 1.8), L(0, 2.6 + k * 2.6, D / 2 - 1.9), WOODL, M.WoodPlanks, m, true)
	for q = -5, 5 do
		if math.abs(q) > 1 or k == 0 then
			local col = ({ C(170, 124, 84), C(60, 140, 230), C(190, 196, 204), C(255, 200, 50), C(240, 130, 50) })[(q + k) % 5 + 1]
			P(V3(1.4, 1.4, 1.2), L(q * 1.9, 3.45 + k * 2.6, D / 2 - 1.9), col, M.SmoothPlastic, m, true)
		end
	end
end
Asset("trexSkull", L(0, 6.2, D / 2 - 1.5) * CFrame.Angles(0, math.pi, 0), 3.2, m)
-- llums de dins
for s = -1, 1, 2 do
	local lp = P(V3(0.8, 0.8, 0.8), L(s * 6, H - 1, 0), MOD.led, M.Neon, m, true)
	local pl = Instance.new("PointLight")
	pl.Range = 16
	pl.Brightness = 0.9
	pl.Color = C(255, 226, 180)
	pl.Parent = lp
end

-- ── davant de la botiga: pissarra, barrils, carretó, testos ──
do
	local bp = L(-W / 2 - 1.5, 0.5, FRONT - 3)
	-- pissarra de peu
	local board = P(V3(2.6, 3.4, 0.2), bp * CF(0, 2.2, 0) * CFrame.Angles(rad(-12), 0, 0), C(40, 46, 44), M.SmoothPlastic, m, true)
	Label(board, "BETTER TOOL = MORE LUCK 🍀", MOD.white, Enum.Font.FredokaOne, Enum.NormalId.Front)
	P(V3(2.9, 3.7, 0.15), bp * CF(0, 2.2, 0.12) * CFrame.Angles(rad(-12), 0, 0), WOODL, M.WoodPlanks, m, true)
	-- barril amb pales dins
	local br = L(W / 2 + 1.6, 0.5, FRONT - 2.2)
	VCyl(2.6, 2.2, (br * CF(0, 1.3, 0)).Position, C(120, 84, 56), M.WoodPlanks, m)
	for k = 0, 3 do
		local a = k * 1.6
		local hc = br * CF(math.cos(a) * 0.4, 3.2, math.sin(a) * 0.4) * CFrame.Angles(rad(math.cos(a) * 12), 0, rad(math.sin(a) * 12))
		P(V3(0.2, 3, 0.2), hc, COL.woodDark, M.Wood, m, true)
		P(V3(0.8, 1, 0.12), hc * CF(0, 1.7, 0), TOOL_COLS[k + 1], M.Metal, m, true)
	end
	Asset("wheelbarrow", L(W / 2 + 2, 0.5, FRONT + 3) * CFrame.Angles(0, rad(-70), 0), 2.6, m)
	-- testos amb arbusts a banda i banda de l'entrada
	for s = -1, 1, 2 do
		local pp = L(s * 5.6, 0.7, FRONT - 4.4)
		VCyl(1.4, 2, pp.Position + UP * 0.7, C(190, 110, 80), M.SmoothPlastic, m)
		Asset("bushRound", pp * CF(0, 1.3, 0), 2.2, m)
	end
end
m.Parent = F

-- ═════════ FOSSIL BUYER: la parada de la Bonnie, al costat de la botiga ═════════
-- Aquí es venen els fòssils (ShopService posa la Bonnie a SellerSpot).
do
	local k = Instance.new("Model")
	k.Name = "FossilBuyer"
	local SX, SZ = -21, -1 -- centre de la parada (local de la botiga)
	local GREEN = C(70, 160, 110)
	local GREEN_D = C(46, 120, 84)
	local function S(x, y, z)
		return L(SX + x, y, SZ + z)
	end
	P(V3(12, 0.5, 9), S(0, 0.25, 0), MOD.concD, M.Concrete, k)
	P(V3(11, 0.3, 8), S(0, 0.6, 0), WOODL, M.WoodPlanks, k)
	-- parets de fusta pintada: fons i costats
	P(V3(11, 8, 0.6), S(0, 4.7, 3.7), GREEN, M.WoodPlanks, k)
	for sx = -1, 1, 2 do
		P(V3(0.6, 8, 8), S(sx * 5.2, 4.7, 0), GREEN, M.WoodPlanks, k)
		P(V3(0.7, 8.2, 0.7), S(sx * 5.2, 4.8, -3.8), GREEN_D, M.WoodPlanks, k)
	end
	-- teulada i tendal a ratlles verd i crema
	P(V3(12.4, 0.6, 9.4), S(0, 9, 0.2), MOD.char, M.SmoothPlastic, k)
	for i = 0, 7 do
		local x = -5.5 + (i + 0.5) * 11 / 8
		local col = i % 2 == 0 and GREEN or CREAM
		P(V3(11 / 8, 0.2, 4), S(x, 8.5, -5.6) * CFrame.Angles(rad(-18), 0, 0), col, M.Fabric, k, true).CastShadow = true
		Wd(V3(11 / 8 - 0.1, 0.7, 0.12), S(x, 7.5, -7.6) * CFrame.Angles(math.pi, 0, 0) * WEDGE_FIX, col, M.Fabric, k, true)
	end
	-- rètol
	local sign = P(V3(10, 2.2, 0.5), S(0, 10.6, -3.7), MOD.char, M.SmoothPlastic, k)
	Label(sign, "FOSSIL BUYER", C(140, 230, 170), Enum.Font.FredokaOne, Enum.NormalId.Front, 60)
	P(V3(10.6, 2.8, 0.4), S(0, 10.6, -3.5), GREEN, M.SmoothPlastic, k, true)
	local sub = P(V3(7, 1.1, 0.15), S(0, 2.2, -3.4), C(255, 206, 110), M.SmoothPlastic, k, true)
	Label(sub, "WE BUY BONES 💰", MOD.char, Enum.Font.GothamBlack)
	-- taulell amb balança, caixes d'ossos i una pila de monedes
	P(V3(9, 3, 1.4), S(0, 2.1, -2.6), WOODL, M.WoodPlanks, k)
	P(V3(9.4, 0.3, 1.8), S(0, 3.75, -2.6), MOD.char, M.SmoothPlastic, k)
	local sc = S(-2.5, 3.9, -2.6)
	VCyl(1.6, 0.2, (sc * CF(0, 0.8, 0)).Position, C(200, 160, 60), M.Metal, k, true)
	P(V3(2.6, 0.12, 0.12), sc * CF(0, 1.6, 0), C(200, 160, 60), M.Metal, k, true)
	for sx = -1, 1, 2 do
		VCyl(0.12, 1, (sc * CF(sx * 1.2, 1.1, 0)).Position, C(220, 180, 70), M.Metal, k, true)
	end
	Ball(0.5, (sc * CF(-1.2, 1.35, 0)).Position, COL.bone, M.Marble, k, true)
	for q = 0, 5 do
		VCyl(0.18, 0.9, (S(2.4 + (q % 3) * 0.2, 4 + q * 0.18, -2.6 + (q % 2) * 0.2)).Position, C(255, 200, 50), M.Metal, k, true)
	end
	for sx = -1, 1, 2 do
		local cb = S(sx * 3.8, 0.75, -4.6)
		P(V3(2.2, 1.6, 1.8), cb * CF(0, 0.8, 0) * CFrame.Angles(0, rad(sx * 12), 0), C(170, 124, 84), M.WoodPlanks, k)
		for q = -1, 1 do
			local bp = (cb * CF(q * 0.6, 1.75, 0)).Position
			beam(bp - V3(0.5, 0, 0.2), bp + V3(0.5, 0.2, 0.2), 0.25, COL.bone, M.Marble, k, true)
			Ball(0.4, bp + V3(0.5, 0.2, 0.2), COL.bone, M.Marble, k, true)
		end
	end
	-- pissarra amb els preus
	local board = P(V3(3.2, 2.4, 0.2), S(4.2, 5.4, 3.35), C(40, 46, 44), M.SmoothPlastic, k, true)
	Label(board, "COMMON 4 · RARE 16 · EPIC 40 · LEGENDARY 100", MOD.white, Enum.Font.FredokaOne, Enum.NormalId.Front)
	-- llum a dins
	local lp = P(V3(0.7, 0.7, 0.7), S(0, 8.2, 0.5), MOD.led, M.Neon, k, true)
	local pl = Instance.new("PointLight")
	pl.Range = 14
	pl.Brightness = 0.8
	pl.Color = C(255, 230, 190)
	pl.Parent = lp
	k.Parent = F
	-- on es posa la Bonnie: darrere el taulell, mirant a fora
	local sp = S(0, 0.9, -1)
	local spot = P(V3(2, 0.2, 2), CFrame.lookAt(sp.Position, sp.Position + O.LookVector), COL.brass, M.SmoothPlastic, F, true)
	spot.Name = "SellerSpot"
	spot.Transparency = 1
	spot.CanQuery = false
	tag(spot, "SellerSpot")
end

-- ── on es posa en Rex: darrere el taulell, mirant a fora ──
do
	local sp = L(0, 0.9, FRONT + 3.8)
	local spot = P(V3(2, 0.2, 2), CFrame.lookAt(sp.Position, sp.Position + O.LookVector), COL.brass, M.SmoothPlastic, F, true)
	spot.Name = "ShopkeeperSpot"
	spot.Transparency = 1
	spot.CanQuery = false
	tag(spot, "ShopkeeperSpot")
end

-- ── les eines, soltes en semicercle davant la botiga ──
local stands = Instance.new("Model")
stands.Name = "ToolStands"
local RING = 13 -- distància des del centre de la façana
local centre = L(0, 0, FRONT - 1)
for i, id in ipairs(TOOL_IDS) do
	-- de -62° a +62° al voltant de la direcció de la façana
	local a = rad(-62 + (i - 1) * 124 / (#TOOL_IDS - 1))
	local pos = (centre * CFrame.Angles(0, a, 0) * CF(0, 0, -RING)).Position
	local face = CFrame.lookAt(V3(pos.X, TOP, pos.Z), V3(centre.Position.X, TOP, centre.Position.Z))
	-- sòcol: base de formigó fosc, cos de fusta i tapa d'acer amb filet de llum
	P(V3(3.6, 0.4, 3.6), face * CF(0, 0.2, 0), MOD.char, M.Concrete, stands)
	local stand = P(V3(2.6, 2.4, 2.6), face * CF(0, 1.6, 0), WOODL, M.WoodPlanks, stands)
	stand.Name = "ToolStand_" .. id
	stand:SetAttribute("ToolId", id)
	tag(stand, "ToolStand")
	P(V3(2.8, 0.18, 2.8), face * CF(0, 2.88, 0), DARKM, M.Metal, stands, true)
	for _, e in ipairs({ { 0, 1.36, 2.8, 0.1 }, { 0, -1.36, 2.8, 0.1 }, { 1.36, 0, 0.1, 2.8 }, { -1.36, 0, 0.1, 2.8 } }) do
		P(V3(e[3], 0.06, e[4]), face * CF(e[1], 2.99, e[2]), TOOL_COLS[i], M.Neon, stands, true)
	end
	-- placa amb el nom, a la cara que mira fora (cap al jugador que arriba)
	local plaque = P(V3(2.3, 0.7, 0.1), face * CF(0, 1.6, 1.36), MOD.char, M.SmoothPlastic, stands, true)
	Label(plaque, TOOL_NAMES[i], TOOL_COLS[i]:Lerp(C(255, 255, 255), 0.35), Enum.Font.GothamBlack, Enum.NormalId.Back)
	-- número de l'eina (la botiga es llegeix d'esquerra a dreta)
	local num = P(V3(0.8, 0.8, 0.1), face * CF(0, 0.75, 1.36), TOOL_COLS[i], M.SmoothPlastic, stands, true)
	Label(num, tostring(i), MOD.white, Enum.Font.FredokaOne, Enum.NormalId.Back)
end
stands.Parent = F
-- catifa de pedra sota el semicercle
Cyl(0.08, RING * 2 + 8, CF(centre.Position.X, TOP + 0.03, centre.Position.Z) * UPRIGHT, C(214, 196, 164), M.Slate, F, true)
Cyl(0.08, RING * 2 - 5, CF(centre.Position.X, TOP + 0.05, centre.Position.Z) * UPRIGHT, C(196, 176, 142), M.Slate, F, true)

-- ── punt d'arribada: davant el semicercle, mirant la botiga ──
do
	local p = (centre * CF(0, 0, -RING - 6)).Position
	local tp = P(V3(4, 0.2, 4), CFrame.lookAt(V3(p.X, TOP + 0.1, p.Z), V3(centre.Position.X, TOP + 0.1, centre.Position.Z)), COL.brass, M.SmoothPlastic, F, true)
	tp.Name = "TravelPoint"
	tp.Transparency = 1
	tp.CanQuery = false
	tp:SetAttribute("Destination", "shop")
	tag(tp, "TravelPoint")
end
print("Dig & Co. a la plaça: botiga, en Rex, " .. #TOOL_IDS .. " eines en semicercle i la parada de la Bonnie (Fossil Buyer)")

end }
STEPS[#STEPS + 1] = { "10_signs", function()
-- ═══════════════════════════ 10 · INDICADORS ═══════════════════════════
-- Pals indicadors moderns a les cruïlles: rètols de colors amb fletxa cap
-- a la plaça, l'obra (Dig Site) i la platja. Decoren i, sobretot, fan que
-- el mapa s'entengui (un provador va dir que costava orientar-s'hi).
--
-- Cada rètol apunta pel carrer que més s'acosta al destí. Abans de posar un
-- pal es mira que ni el pal ni els rètols toquin cap arbre, fanal o casa: si
-- a una cantonada no hi cap, es prova a la següent.
local F = folder("Signs", WORLD)
local WALK_TOP = 0.65
local PZ = LAYOUT.PLAZA
local PC = LAYOUT.PLAZA_CORE
local OB = LAYOUT.OBRA

local DESTS = {
	{ text = "⛲ PLAZA", color = C(64, 176, 96), pos = V3((PC.x0 + PC.x1) / 2, 0, (PC.z0 + PC.z1) / 2) },
	{ text = "🏗️ DIG SITE", color = C(230, 150, 30), pos = V3((OB.x0 + OB.x1) / 2, 0, (OB.z0 + OB.z1) / 2) },
	{ text = "🏖️ BEACH", color = C(40, 160, 210), pos = nil }, -- sempre cap a l'est
}
local BOARD_L, BOARD_H = 6.4, 1.15

-- què hi ha al voltant (tot menys els carrers, on el pal s'aguanta)
local around = OverlapParams.new()
around.FilterType = Enum.RaycastFilterType.Include
do
	local list = {}
	for _, name in ipairs({ "Houses", "Props", "Plaza", "ToolShop", "Beach", "Signs" }) do
		local f = WORLD:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	table.insert(list, MUSEUMS)
	table.insert(list, ZONES)
	around.FilterDescendantsInstances = list
end
local function free(cf, size)
	return #Workspace:GetPartBoundsInBox(cf, size, around) == 0
end

-- direcció de carrer (±X o ±Z) que més s'acosta a `v`
local function snap(v)
	if math.abs(v.X) >= math.abs(v.Z) then
		return V3(v.X >= 0 and 1 or -1, 0, 0)
	end
	return V3(0, 0, v.Z >= 0 and 1 or -1)
end

-- Rètols d'aquesta cruïlla: {text, color, dir}. Sense el destí on ja ets.
local function boardsFor(c)
	local out = {}
	for _, d in ipairs(DESTS) do
		local target = d.pos or V3(LAYOUT.PROM.x1, 0, c.Z)
		local v = target - c
		if V3(v.X, 0, v.Z).Magnitude > 45 then
			table.insert(out, { text = d.text, color = d.color, dir = snap(v) })
		end
	end
	return out
end

-- Prova de posar un pal a `p` amb aquests rètols. Torna true si hi cap.
local function signpost(p, boards)
	if not free(CF(p + UP * 5), V3(1.2, 8.6, 1.2)) then
		return false
	end
	for k, b in ipairs(boards) do
		local y = 8.2 - (k - 1) * (BOARD_H + 0.25)
		local c = p + b.dir * (BOARD_L / 2 + 0.2) + UP * y
		if not free(CF(c), V3(math.abs(b.dir.X) * BOARD_L + 0.6, BOARD_H, math.abs(b.dir.Z) * BOARD_L + 0.6)) then
			return false
		end
	end
	local m = Instance.new("Model")
	m.Name = "Signpost"
	P(V3(1.1, 0.3, 1.1), CF(p + UP * 0.15), MOD.concD, M.Concrete, m)
	P(V3(0.36, 9.2, 0.36), CF(p + UP * 4.6), MOD.steel, M.Metal, m)
	P(V3(0.5, 0.3, 0.5), CF(p + UP * 9.3), MOD.steel, M.Metal, m, true)
	for k, b in ipairs(boards) do
		local y = 8.2 - (k - 1) * (BOARD_H + 0.25)
		local c = p + b.dir * (BOARD_L / 2 + 0.2) + UP * y
		-- la cara Front mira cap a dir × amunt: així el text de davant corre
		-- en la direcció del rètol i la fletxa ➡ hi apunta; al darrere, ⬅
		local cf = CFrame.lookAt(c, c + b.dir:Cross(UP))
		local board = P(V3(BOARD_L, BOARD_H, 0.22), cf, b.color, M.SmoothPlastic, m, true)
		board.CastShadow = true
		Label(board, `{b.text}  ➡`, MOD.white, Enum.Font.FredokaOne, Enum.NormalId.Front, 60)
		Label(board, `⬅  {b.text}`, MOD.white, Enum.Font.FredokaOne, Enum.NormalId.Back, 60)
		-- vora fosca de dalt i de baix (0,26 de gruix: no al pla del rètol)
		for _, s in ipairs({ -1, 1 }) do
			P(V3(BOARD_L, 0.1, 0.26), cf * CF(0, s * (BOARD_H / 2 + 0.05), 0), MOD.char, M.SmoothPlastic, m, true)
		end
	end
	m.Parent = F
	return true
end

-- ── les cruïlles ──
local horiz, vert = {}, {}
for _, r in ipairs(LAYOUT.ROADS) do
	if r[2] == r[4] then
		table.insert(horiz, r)
	else
		table.insert(vert, r)
	end
end
local n = 0
for _, h in ipairs(horiz) do
	for _, v in ipairs(vert) do
		local x, z = v[1], h[2]
		local inH = x >= math.min(h[1], h[3]) and x <= math.max(h[1], h[3])
		local inV = z >= math.min(v[2], v[4]) and z <= math.max(v[2], v[4])
		local inPlaza = x > PZ.x0 - 6 and x < PZ.x1 + 6 and z > PZ.z0 - 6 and z < PZ.z1 + 6
		if inH and inV and not inPlaza then
			local c = V3(x, WALK_TOP, z)
			local boards = boardsFor(c)
			if #boards > 0 then
				-- a la vorera, a tocar de la cantonada (s'hi prova a les quatre)
				local off = math.min(h[5], v[5]) / 2 - 1.6
				for _, q in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
					if signpost(c + V3(q[1] * off, 0, q[2] * off), boards) then
						n += 1
						break
					end
				end
			end
		end
	end
end
print(("Indicadors: %d pals a les cruïlles (plaça, obra i platja)"):format(n))

end }
STEPS[#STEPS + 1] = { "11_egypt", function()
-- ═══════════════════════════ 11 · EGIPTE (zona 3) ═══════════════════════════
-- Una illa al mig del mar, MOLT lluny del continent: el mar de 01 acaba a
-- x = 1100 i l'illa comença a ~1.740; entremig no hi ha res (el buit). No
-- s'hi pot arribar ni caminant ni nedant: només amb el botó ✈️ Travel
-- (TravelPoint "egypt"). Ha d'anar DESPRÉS de 01 (que fa Terrain:Clear()).
--
-- Què hi ha: moll d'arribada amb obeliscs, portalada egípcia (pilons) on es
-- desbloqueja la zona (ZoneUnlock), el camp d'excavació (cràters "desert"
-- amb DigSpot, Zone = "egypt"), tres piràmides, una esfinx, un temple en
-- ruïnes, un oasi amb palmeres, parades de mercat, roques i dunes.
-- Escales: el jugador fa 5; la piràmide gran és el fons (com la grua de l'obra).
local F = folder("Egypt", WORLD)
local Terrain = Workspace.Terrain
local rng = Random.new(3000)

local EX, EZ = 2000, 0 -- centre de l'illa
local ISLAND = 130 -- mig costat de l'illa de sorra
local SEA = 260 -- mig costat del mar que l'envolta
local SAND_Y = -0.3 -- alçada de la sorra (com la platja)

-- paleta egípcia (càlida; dins de la família del CLAUDE.md)
local STONE = C(214, 186, 136) -- gres
local STONE_D = C(186, 156, 108)
local STONE_L = C(232, 212, 168)
local GOLD = C(214, 170, 72)
local LAPIS = C(46, 84, 150)
local TERRA = C(178, 96, 58)

-- ── terreny: mar al voltant i illa de sorra ──
do
	for x = EX - SEA, EX + SEA - 1, 256 do
		for z = EZ - SEA, EZ + SEA - 1, 256 do
			local sx = math.min(256, EX + SEA - x)
			local sz = math.min(256, EZ + SEA - z)
			Terrain:FillBlock(CF(x + sx / 2, -11, z + sz / 2), V3(sx, 14, sz), M.Water)
			Terrain:FillBlock(CF(x + sx / 2, -24, z + sz / 2), V3(sx, 12, sz), M.Sand)
		end
	end
	for x = EX - ISLAND, EX + ISLAND - 1, 130 do
		for z = EZ - ISLAND, EZ + ISLAND - 1, 130 do
			Terrain:FillBlock(CF(x + 65, -10.3, z + 65), V3(130, 16, 130), M.Sand)
		end
	end
	-- vora suau: boles de sorra a tot el perímetre (no queda un tall recte)
	for k = 0, 47 do
		local a = k / 48 * math.pi * 2
		local r = ISLAND * 1.02
		local p = V3(EX + math.cos(a) * r, -15, EZ + math.sin(a) * r)
		Terrain:FillBall(p, 12 + rng:NextNumber(0, 3), M.Sand)
	end
	-- dunes a les vores (lluny del camp d'excavació i del camí)
	for _, d in ipairs({ { 100, -112, 22 }, { 110, 95, 26 }, { -40, 118, 18 }, { 20, -122, 20 } }) do
		Terrain:FillBall(V3(EX + d[1], -d[3] * 0.72, EZ + d[2]), d[3], M.Sand)
	end
	-- l'oasi: un estany d'aigua enmig de la sorra
	Terrain:FillBlock(CF(EX - 20, -2.6, EZ + 84), V3(32, 3, 22), M.Air)
	Terrain:FillBlock(CF(EX - 20, -3.4, EZ + 84), V3(30, 2.6, 20), M.Water)
end

-- ── moll d'arribada (TravelPoint) ──
local LX = EX - 100 -- on arriba l'avió
do
	local m = Instance.new("Model")
	m.Name = "Landing"
	P(V3(40, 1, 36), CF(LX, -0.2, EZ), STONE_L, M.Limestone, m)
	-- vora de pedra fosca (0,05 més baixa: no comparteix pla amb la llosa)
	for s = -1, 1, 2 do
		P(V3(40.6, 0.9, 1.2), CF(LX, -0.25, EZ + s * 18.3), STONE_D, M.Limestone, m)
	end
	-- catifa de rajoles blaves cap a la portalada
	P(V3(30, 0.1, 6), CF(LX + 5, 0.35, EZ), LAPIS, M.SmoothPlastic, m, true)
	-- obeliscs a banda i banda del moll
	for s = -1, 1, 2 do
		local p = V3(LX - 12, 0.3, EZ + s * 12)
		P(V3(3.2, 1.2, 3.2), CF(p + UP * 0.6), STONE_D, M.Limestone, m)
		for k = 0, 2 do
			local w = 2.2 - k * 0.3
			P(V3(w, 5, w), CF(p + UP * (1.2 + 2.5 + k * 5)), STONE, M.Limestone, m)
		end
		Pyramid(CF(p + UP * 16.25), 1.6, 1.8, GOLD, M.Metal, m)
		-- placa amb un anj al tram del mig (1,9 d'ample: 0,05 per fora)
		local glyph = P(V3(1.4, 4.2, 0.1), CF(p + UP * 8.7) * CF(0, 0, 1.0), STONE_L, M.Limestone, m, true)
		Label(glyph, "☥", C(120, 84, 40), Enum.Font.GothamBlack, Enum.NormalId.Front, 30)
	end
	m.Parent = F
	-- punt d'arribada del botó "Egypt" (TravelService), mirant cap a l'illa
	local tp = P(V3(4, 0.2, 4), CF(LX - 6, 0.45, EZ) * CFrame.Angles(0, math.rad(-90), 0), COL.brass, M.SmoothPlastic, F, true)
	tp.Name = "TravelPoint"
	tp.Transparency = 1
	tp.CanQuery = false
	tp:SetAttribute("Destination", "egypt")
	tag(tp, "TravelPoint")
end

-- ── portalada (dos pilons) on es desbloqueja la zona ──
local GX = EX - 64
do
	local m = Instance.new("Model")
	m.Name = "EgyptGate"
	for s = -1, 1, 2 do
		local z = EZ + s * 9
		-- pilò: base més ampla i cos a sobre (el perfil de talús egipci)
		P(V3(7, 5, 9.4), CF(GX, 2.5, z), STONE_D, M.Limestone, m)
		P(V3(6, 9, 8), CF(GX, 9.5, z), STONE, M.Limestone, m)
		P(V3(6.6, 0.8, 8.6), CF(GX, 14.4, z), STONE_D, M.Limestone, m) -- cornisa
		-- franges pintades (lapislàtzuli i or)
		P(V3(6.1, 0.5, 8.1), CF(GX, 12.2, z), LAPIS, M.SmoothPlastic, m, true)
		P(V3(6.1, 0.3, 8.1), CF(GX, 11.6, z), GOLD, M.Metal, m, true)
	end
	-- llinda amb el rètol
	local lintel = P(V3(4, 2.6, 12), CF(GX, 12.6, EZ), STONE_L, M.Limestone, m)
	Label(lintel, "EGYPT", C(140, 90, 30), Enum.Font.GothamBlack, Enum.NormalId.Left)
	Label(lintel, "EGYPT", C(140, 90, 30), Enum.Font.GothamBlack, Enum.NormalId.Right)
	-- disc solar alat a la cara de la llinda que mira al moll
	Cyl(0.3, 1.6, CF(GX - 2.2, 12.6, EZ), GOLD, M.Metal, m, true)
	for q = -1, 1, 2 do
		P(V3(0.2, 0.6, 2.6), CF(GX - 2.2, 12.6, EZ + q * 2.2), LAPIS, M.SmoothPlastic, m, true)
	end
	-- aquí es desbloqueja Egipte (ShopService hi posa el botó)
	local unlock = P(V3(4, 0.2, 10), CF(GX, 0.8, EZ), COL.brass, M.SmoothPlastic, m, true)
	unlock.Name = "EgyptUnlock"
	unlock.Transparency = 1
	unlock.CanQuery = false
	unlock:SetAttribute("Zone", "egypt")
	tag(unlock, "ZoneUnlock")
	m.Parent = F
end

-- ── camp d'excavació: cràters de sorra del desert ──
local digs = 0
do
	local field = Instance.new("Model")
	field.Name = "EgyptDigField"
	field.Parent = F
	for _, gx in ipairs({ -36, -12, 12, 36 }) do
		for _, gz in ipairs({ -24, 0, 24 }) do
			digs += 1
			-- centre múltiple de 4 (graella del terreny) i una mica de desordre
			local x = EX + gx + rng:NextInteger(-1, 1) * 4
			local z = EZ + gz + rng:NextInteger(-1, 1) * 4
			digPit(V3(x, SAND_Y, z), "egypt", "EgyptDig" .. digs, "desert", rng, field)
		end
	end
	-- cartells "DIG HERE" a l'entrada del camp
	for _, s in ipairs({ -1, 1 }) do
		local p = V3(GX + 10, SAND_Y, EZ + s * 14)
		P(V3(0.4, 5, 0.4), CF(p + UP * 2.5), MOD.steel, M.Metal, F, true)
		local sg = P(V3(0.3, 2.4, 5), CF(p + UP * 5.4), MOD.char, M.SmoothPlastic, F, true)
		Label(sg, "DIG HERE ⛏", C(255, 206, 110), Enum.Font.GothamBlack, Enum.NormalId.Left)
	end
end

-- ── les piràmides (fons) ──
local function pyramid(p, base, h)
	local m = Instance.new("Model")
	m.Name = "Pyramid"
	-- sòcol de blocs i la piràmide amb les quatre cares en tons diferents
	P(V3(base + 2, 1, base + 2), CF(p + UP * 0.2), STONE_D, M.Limestone, m)
	Pyramid(CF(p + UP * 0.75), base, h, STONE, M.Limestone, m, { STONE, STONE_L, STONE, STONE_D })
	-- punta d'or: una mica més ampla que la piràmide a la mateixa alçada
	-- (+0,4 de base), perquè les cares no quedin al mateix pla
	Pyramid(CF(p + UP * (0.75 + h * 0.9)), base * 0.1 + 0.4, h * 0.1, GOLD, M.Metal, m)
	m.Parent = F
end
pyramid(V3(EX + 96, SAND_Y, EZ + 6), 64, 42)
pyramid(V3(EX + 72, SAND_Y, EZ - 70), 38, 25)
pyramid(V3(EX + 64, SAND_Y, EZ + 74), 30, 20)

-- ── l'esfinx ──
do
	local m = Instance.new("Model")
	m.Name = "Sphinx"
	local base = V3(EX + 44, SAND_Y, EZ - 44)
	local cf = CF(base) * CFrame.Angles(0, math.rad(-90), 0) -- mira cap a l'oest (cap al moll)
	P(V3(9, 1, 22), cf * CF(0, 0.5, 0), STONE_D, M.Limestone, m) -- plataforma
	P(V3(7, 5, 14), cf * CF(0, 3.5, -2), STONE, M.Limestone, m) -- cos
	Ellipsoid(V3(7, 5.4, 6), cf * CF(0, 3.6, -9), STONE, M.Limestone, m) -- anques
	for s = -1, 1, 2 do
		P(V3(2, 1.6, 7), cf * CF(s * 2.2, 1.8, 7.2), STONE_L, M.Limestone, m) -- potes
	end
	P(V3(5, 3.6, 3.2), cf * CF(0, 5.2, 5.8), STONE, M.Limestone, m) -- pit
	-- cap amb el nemes (tocat de franges blaves i daurades)
	local head = cf * CF(0, 8.6, 6.6)
	P(V3(3.6, 3.8, 3.4), head, STONE_L, M.Limestone, m)
	for s = -1, 1, 2 do
		for k = 0, 3 do
			local col = if k % 2 == 0 then LAPIS else GOLD
			P(V3(0.5, 0.9, 3.6), head * CF(s * 2.05, 1.2 - k * 0.95, -0.2), col, M.SmoothPlastic, m, true)
		end
	end
	P(V3(4.2, 0.9, 4), head * CF(0, 2.35, -0.3), GOLD, M.Metal, m, true)
	P(V3(1, 1.2, 0.6), head * CF(0, 0.2, 1.95), STONE_D, M.Limestone, m, true) -- nas
	P(V3(0.8, 1.6, 0.8), head * CF(0, -2.4, 1.4), GOLD, M.Metal, m, true) -- barba
	m.Parent = F
end

-- ── temple en ruïnes (columnes, algunes trencades) ──
do
	local m = Instance.new("Model")
	m.Name = "TempleRuins"
	local c = V3(EX - 8, SAND_Y, EZ - 82)
	P(V3(38, 1.2, 18), CF(c + UP * 0.3), STONE_D, M.Limestone, m)
	-- trencades: tres columnes concretes (les llindes van sobre les senceres)
	local BROKEN = { ["2,1"] = true, ["4,-1"] = true, ["5,1"] = true }
	for i = 0, 5 do
		for s = -1, 1, 2 do
			local p = c + V3(-15 + i * 6, 0.9, s * 6)
			local h = if BROKEN[`{i},{s}`] then rng:NextNumber(4, 7) else 12
			VCyl(h, 2.4, p + UP * (h / 2), STONE, M.Limestone, m)
			VCyl(0.6, 3, p + UP * 0.3, STONE_D, M.Limestone, m, true)
			if h >= 12 then
				-- capitell de flor de lotus
				VCyl(1, 3.2, p + UP * (h + 0.5), STONE_L, M.Limestone, m)
				P(V3(2.5, 0.35, 2.5), CF(p + UP * (h - 1.5)), LAPIS, M.SmoothPlastic, m, true)
			end
		end
	end
	-- dues llindes que encara aguanten, damunt dels capitells (0,9 + 12 + 1)
	P(V3(13, 1.6, 3.2), CF(c + V3(-12, 0.9 + 13 + 0.85, -6)), STONE_L, M.Limestone, m)
	P(V3(13, 1.6, 3.2), CF(c + V3(6, 0.9 + 13 + 0.85, 6)), STONE_L, M.Limestone, m)
	-- un tros de columna caigut, estirat a la sorra
	Cyl(8, 2.4, CF(c + V3(4, 1.2, 12)) * CFrame.Angles(0, rad(30), 0), STONE, M.Limestone, m)
	m.Parent = F
end

-- ── oasi: palmeres i canyes al voltant de l'estany ──
local palmN = 0
local function palm(p, h)
	palmN += 1
	Asset(palmN % 3 == 0 and "palmCoco" or "palmChunky", CF(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), h, F)
end
for k = 0, 9 do
	local a = k / 10 * math.pi * 2
	palm(V3(EX - 20 + math.cos(a) * 21, SAND_Y, EZ + 84 + math.sin(a) * 15), rng:NextNumber(15, 21))
end
for k = 0, 14 do
	local a = rng:NextNumber(0, math.pi * 2)
	local p = V3(EX - 20 + math.cos(a) * 16, SAND_Y, EZ + 84 + math.sin(a) * 11)
	P(V3(0.25, rng:NextNumber(2.5, 4), 0.25), CF(p + UP * 1.5) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), C(96, 128, 64), M.Grass, F, true)
end
-- palmeres sueltes al camí i al moll
for _, pp in ipairs({ { -90, 26 }, { -90, -26 }, { -70, 30 }, { -70, -30 }, { 30, -60 }, { 40, 60 } }) do
	palm(V3(EX + pp[1], SAND_Y, EZ + pp[2]), rng:NextNumber(16, 22))
end

-- ── parades de mercat (tendals de ratlles) prop del moll ──
local CLOTH = { C(200, 70, 60), C(60, 110, 170), C(220, 170, 60) }
for i, pp in ipairs({ { -84, 40 }, { -72, 44 }, { -84, -40 } }) do
	local m = Instance.new("Model")
	m.Name = "MarketStall"
	local p = V3(EX + pp[1], SAND_Y, EZ + pp[2])
	for q = -1, 1, 2 do
		for r = -1, 1, 2 do
			P(V3(0.3, 5, 0.3), CF(p + V3(q * 2.8, 2.5, r * 2.2)), COL.wood, M.Wood, m)
		end
	end
	P(V3(6, 1, 1.8), CF(p + V3(0, 1.1, 1.4)), COL.wood, M.WoodPlanks, m) -- taulell
	for k = 0, 5 do
		local col = if k % 2 == 0 then CLOTH[i] else C(240, 232, 214)
		P(V3(1.05, 0.2, 5.4), CF(p + V3(-2.6 + k * 1.05, 5.1, 0)) * CFrame.Angles(rad(8), 0, 0), col, M.Fabric, m, true)
	end
	-- gerres i cistelles al taulell
	for k = -1, 1 do
		Ellipsoid(V3(0.9, 1.1, 0.9), CF(p + V3(k * 1.6, 2.15, 1.4)), if k == 0 then TERRA else C(200, 150, 80), M.SmoothPlastic, m, true)
	end
	m.Parent = F
end

-- ── roques al voltant de l'illa ──
for k, rp in ipairs({ { -118, -60, 6 }, { -110, 70, 5 }, { 60, 118, 7 }, { -30, -118, 5 }, { 120, 50, 6 }, { 4, 116, 4 } }) do
	for q = 0, 2 do
		local a = q * 2.1 + k
		Rock(CF(EX + rp[1] + math.cos(a) * rp[3] * 0.5, SAND_Y, EZ + rp[2] + math.sin(a) * rp[3] * 0.5) * CFrame.Angles(0, a, 0), rp[3] * (1 - q * 0.25), F, k + q, C(176, 146, 104))
	end
end

print(("Egipte: illa a x=%d (només en avió), portalada, piràmides, esfinx, temple, oasi i %d forats per excavar"):format(EX, digs))

end }

	for i, s in ipairs(STEPS) do
		print(("[Món] %d/%d %s..."):format(i, #STEPS, s[1]))
		local ok, err = pcall(s[2])
		if not ok then
			warn("[Món] error a " .. s[1] .. ": " .. tostring(err))
		end
		task.wait()
	end
end

local CHS = game:GetService("ChangeHistoryService")
local toolbar = plugin:CreateToolbar("Museu de Fòssils · Món")
local button = toolbar:CreateButton("Construir el món", "Construeix el món nou sencer (esborra l'anterior)", "rbxasset://textures/StudioToolbox/AssetPreview/Rating_Up.png")
button.ClickableWhenViewportHidden = true
local busy = false
button.Click:Connect(function()
	if busy then
		return
	end
	busy = true
	local rec = CHS:TryBeginRecording("Construir el món")
	local t0 = os.clock()
	local ok, err = pcall(BuildWorld)
	if not ok then
		warn("[Món] " .. tostring(err))
	end
	if rec then
		CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	print(("[Món] Fet en %.1f s. Desa amb Ctrl+S!"):format(os.clock() - t0))
	button:SetActive(false)
	busy = false
end)
