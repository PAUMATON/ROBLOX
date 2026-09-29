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
