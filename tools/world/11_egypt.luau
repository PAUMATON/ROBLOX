-- ═══════════════════════════ 11 · EGIPTE (zona 3) ═══════════════════════════
-- Un DESERT que arriba fins a l'horitzó, MOLT lluny del continent: el mar de
-- 01 acaba a x = 1100 i el desert comença a x = 4600; entremig no hi ha res
-- (el buit) i des d'aquí no es veu la ciutat. No s'hi pot arribar ni
-- caminant ni nedant: només amb el botó ✈️ Travel (TravelPoint "egypt").
-- La zona jugable és un quadrat de ±BORDER amb parets invisibles; fora,
-- dunes i més dunes fins a la boira. Ha d'anar DESPRÉS de 01 (Terrain:Clear()).
--
-- Què hi ha: plaça d'arribada amb obeliscs, portalada egípcia (pilons) on es
-- desbloqueja la zona (ZoneUnlock), els forats (cràters "desert" amb
-- DigSpot, Zone = "egypt") repartits a l'atzar, tres piràmides GEGANTS al
-- fons (l'excepció d'escala del CLAUDE.md: es veuen de tot arreu), una
-- esfinx gran, un temple en ruïnes, un oasi, mercat i el basar de paletes.
local F = folder("Egypt", WORLD)
local Terrain = Workspace.Terrain
local rng = Random.new(3000)

local EX, EZ = 6000, 0 -- centre de la zona
local DESERT = 1400 -- mig costat del desert (fins a la boira)
local BORDER = 480 -- mig costat de la zona jugable (parets invisibles)
local SAND_Y = -0.3 -- alçada de la sorra (com la platja)

-- paleta egípcia (càlida; dins de la família del CLAUDE.md)
local STONE = C(214, 186, 136) -- gres
local STONE_D = C(186, 156, 108)
local STONE_L = C(232, 212, 168)
local GOLD = C(214, 170, 72)
local LAPIS = C(46, 84, 150)
local TERRA = C(178, 96, 58)

-- ── terreny: desert fins a l'horitzó ──
do
	for x = EX - DESERT, EX + DESERT - 1, 256 do
		for z = EZ - DESERT, EZ + DESERT - 1, 256 do
			local sx = math.min(256, EX + DESERT - x)
			local sz = math.min(256, EZ + DESERT - z)
			Terrain:FillBlock(CF(x + sx / 2, -10.3, z + sz / 2), V3(sx, 16, sz), M.Sand)
		end
	end
	-- dunes: suaus a prop de la tanca i cada cop més grosses cap a
	-- l'horitzó, perquè la vista no s'acabi mai (i la vora quedi amagada)
	for _ = 1, 140 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(BORDER + 40, DESERT + 60)
		local r = 30 + (d - BORDER) / (DESERT - BORDER) * rng:NextNumber(60, 140)
		Terrain:FillBall(V3(EX + math.cos(a) * d, -r * 0.8, EZ + math.sin(a) * d), r, M.Sand)
	end
	-- l'oasi: un estany d'aigua enmig de la sorra
	Terrain:FillBlock(CF(EX - 20, -2.6, EZ + 84), V3(32, 3, 22), M.Air)
	Terrain:FillBlock(CF(EX - 20, -3.4, EZ + 84), V3(30, 2.6, 20), M.Water)
end

-- ── parets invisibles de la zona jugable (el desert continua a fora) ──
do
	local m = Instance.new("Model")
	m.Name = "EgyptBorder"
	for _, w in ipairs({ { BORDER, 0, 2, BORDER * 2 }, { -BORDER, 0, 2, BORDER * 2 }, { 0, BORDER, BORDER * 2, 2 }, { 0, -BORDER, BORDER * 2, 2 } }) do
		local wall = P(V3(w[3], 200, w[4]), CF(EX + w[1], 100, EZ + w[2]), C(255, 255, 255), M.SmoothPlastic, m)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
	end
	m.Parent = F
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

-- ── forats: cràters repartits a l'atzar per la sorra ──
-- Es tria un lloc a l'atzar dins la zona de cavar i es descarta si toca
-- res (temple, oasi, esfinx, palmeres, roques, un altre forat).
local digs = 0
do
	local field = Instance.new("Model")
	field.Name = "EgyptDigField"
	field.Parent = F
	-- cercles ocupats {x, z, radi} relatius a (EX, EZ)
	local busy = {
		{ -8, -82, 26 }, -- temple
		{ -20, 84, 26 }, -- oasi
		{ 150, 0, 34 }, -- esfinx
		{ 30, -60, 8 }, { 40, 60, 8 }, -- palmeres
		{ 60, 118, 12 }, { 120, 50, 12 }, { 4, 116, 10 }, { -30, -118, 10 }, -- roques
	}
	local function free(x, z)
		for _, b in ipairs(busy) do
			if (V3(x, 0, z) - V3(b[1], 0, b[2])).Magnitude < b[3] + 10 then
				return false
			end
		end
		return true
	end
	local tries = 0
	while digs < 12 and tries < 4000 do
		tries += 1
		-- a l'est de la portalada, entre el temple i l'oasi fins a l'esfinx;
		-- centre múltiple de 4 (graella del terreny)
		local x = math.floor(rng:NextNumber(-30, 175) / 4 + 0.5) * 4
		local z = math.floor(rng:NextNumber(-150, 150) / 4 + 0.5) * 4
		if free(x, z) then
			digs += 1
			table.insert(busy, { x, z, 13 })
			digPit(V3(EX + x, SAND_Y, EZ + z), "egypt", "EgyptDig" .. digs, "desert", rng, field)
		end
	end
	-- cartells "DIG HERE" a l'entrada
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
-- gegants, al fons (es veuen des de tot arreu i fan de punt de referència)
pyramid(V3(EX + 340, SAND_Y, EZ), 200, 130)
pyramid(V3(EX + 262, SAND_Y, EZ - 300), 150, 97)
pyramid(V3(EX + 232, SAND_Y, EZ + 292), 120, 78)

-- ── l'esfinx ──
do
	local m = Instance.new("Model")
	m.Name = "Sphinx"
	local base = V3(EX + 150, SAND_Y, EZ) -- davant la piràmide gran
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
	-- gran: s'escala des de la base (el pivot), així es queda a terra
	m.WorldPivot = CF(base)
	m.Parent = F
	m:ScaleTo(2.4)
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
for i, pp in ipairs({ { -84, 40 }, { -72, 44 }, { -66, -42 } }) do
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

-- ── basar de paletes: les tres millors del joc només es venen aquí ──
-- (ToolStand amb ToolId, com a Dig & Co.: ShopService hi posa el model i el botó)
do
	local m = Instance.new("Model")
	m.Name = "TrowelBazaar"
	local c = V3(EX - 96, SAND_Y, EZ - 48) -- al sud del moll, abans de la portalada
	-- terra de pedra i tendal de ratlles daurades i blaves
	P(V3(22, 0.6, 12), CF(c + UP * 0.3), STONE_L, M.Limestone, m)
	for q = -1, 1, 2 do
		for r = -1, 1, 2 do
			VCyl(7, 0.6, c + V3(q * 10, 4.1, r * 5.4), STONE, M.Limestone, m)
		end
	end
	for k = 0, 9 do
		local col = if k % 2 == 0 then GOLD else LAPIS
		P(V3(2.1, 0.2, 12), CF(c + V3(-9.45 + k * 2.1, 7.75, 0)) * CFrame.Angles(rad(6), 0, 0), col, M.Fabric, m, true)
	end
	local sign = P(V3(12, 1.6, 0.3), CF(c + V3(0, 9.2, 6.2)), LAPIS, M.SmoothPlastic, m)
	Label(sign, "PHARAOH'S TROWELS", GOLD, Enum.Font.GothamBlack, Enum.NormalId.Back)
	Label(sign, "PHARAOH'S TROWELS", GOLD, Enum.Font.GothamBlack, Enum.NormalId.Front)
	local ids = { "scarab_trowel", "anubis_trowel", "pharaoh_trowel" }
	local names = { "SCARAB", "ANUBIS", "PHARAOH" }
	local cols = { C(30, 170, 160), C(90, 90, 110), C(255, 214, 90) }
	for i, id in ipairs(ids) do
		-- la placa (+Z local) mira al nord, cap al moll, d'on arriba la gent
		local face = CF(c + V3(-6 + (i - 1) * 6, 0.6, 1))
		P(V3(3.6, 0.4, 3.6), face * CF(0, 0.2, 0), STONE_D, M.Limestone, m)
		local stand = P(V3(2.6, 2.4, 2.6), face * CF(0, 1.6, 0), STONE, M.Limestone, m)
		stand.Name = "ToolStand_" .. id
		stand:SetAttribute("ToolId", id)
		tag(stand, "ToolStand")
		P(V3(2.8, 0.18, 2.8), face * CF(0, 2.88, 0), GOLD, M.Metal, m, true)
		for _, e in ipairs({ { 0, 1.36, 2.8, 0.1 }, { 0, -1.36, 2.8, 0.1 }, { 1.36, 0, 0.1, 2.8 }, { -1.36, 0, 0.1, 2.8 } }) do
			P(V3(e[3], 0.06, e[4]), face * CF(e[1], 2.99, e[2]), cols[i], M.Neon, m, true)
		end
		local plaque = P(V3(2.3, 0.7, 0.1), face * CF(0, 1.6, 1.36), C(40, 34, 30), M.SmoothPlastic, m, true)
		Label(plaque, names[i], cols[i]:Lerp(C(255, 255, 255), 0.35), Enum.Font.GothamBlack, Enum.NormalId.Back)
	end
	m.Parent = F
end

-- ── roques ──
for k, rp in ipairs({ { -118, -60, 6 }, { -110, 70, 5 }, { 60, 118, 7 }, { -30, -118, 5 }, { 120, 50, 6 }, { 4, 116, 4 } }) do
	for q = 0, 2 do
		local a = q * 2.1 + k
		Rock(CF(EX + rp[1] + math.cos(a) * rp[3] * 0.5, SAND_Y, EZ + rp[2] + math.sin(a) * rp[3] * 0.5) * CFrame.Angles(0, a, 0), rp[3] * (1 - q * 0.25), F, k + q, C(176, 146, 104))
	end
end

print(("Egipte: illa a x=%d (només en avió), portalada, piràmides, esfinx, temple, oasi i %d forats per excavar"):format(EX, digs))
