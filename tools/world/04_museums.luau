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
