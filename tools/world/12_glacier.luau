-- ═══════════════════════ 12 · GLACERA DE L'EDAT DE GEL (zona 4) ═══════════════════════
-- Com Egipte (11), però cap a l'OEST i de gel: una plana de neu i gel que
-- arriba fins a l'horitzó, MOLT lluny del continent (x = -6000). No hi ha mar
-- ni camí: només s'hi arriba amb el botó ✈️ Travel (TravelPoint "glacier").
-- La zona jugable és un quadrat de ±BORDER amb parets invisibles; fora,
-- turons de neu i muntanyes de gel fins a la boira. Ha d'anar DESPRÉS de 01
-- (Terrain:Clear()).
--
-- Què hi ha: moll d'arribada de fusta amb banderes d'expedició, portalada de
-- gel on es desbloqueja la zona (ZoneUnlock), els forats (cràters "ice" amb
-- DigSpot, Zone = "glacier") repartits a l'atzar, un MAMUT congelat dins un
-- bloc de gel (el punt de referència, com l'esfinx), muntanyes de gel
-- gegants al fons (terreny: l'excepció d'escala, com les piràmides), un
-- llac glaçat, iglús, el campament de l'expedició amb foguera, la cabana de
-- paletes i una aurora boreal al cel.
local F = folder("Glacier", WORLD)
local Terrain = Workspace.Terrain
local rng = Random.new(4000)

local EX, EZ = -6000, 0 -- centre de la zona
local FIELD = 1400 -- mig costat de la plana de neu (fins a la boira)
local BORDER = 480 -- mig costat de la zona jugable (parets invisibles)
local SNOW_Y = -0.3 -- alçada de la neu (com la sorra d'Egipte)

-- paleta freda (neu, gel, fusta d'expedició i taronja de tenda)
local SNOW = C(240, 246, 252)
local SNOW_D = C(214, 226, 240)
local ICE = C(170, 214, 240)
local ICE_D = C(120, 176, 214)
local FUR = C(118, 80, 52)
local FUR_D = C(88, 58, 38)
local IVORY = C(246, 238, 216)
local TENT = C(236, 110, 40)
local WOOD = COL.wood
local WOOD_D = COL.woodDark

-- ── terreny: neu fins a l'horitzó, muntanyes de gel i un llac glaçat ──
do
	Terrain:SetMaterialColor(M.Snow, SNOW)
	Terrain:SetMaterialColor(M.Glacier, ICE)
	for x = EX - FIELD, EX + FIELD - 1, 256 do
		for z = EZ - FIELD, EZ + FIELD - 1, 256 do
			local sx = math.min(256, EX + FIELD - x)
			local sz = math.min(256, EZ + FIELD - z)
			Terrain:FillBlock(CF(x + sx / 2, -10.3, z + sz / 2), V3(sx, 16, sz), M.Snow)
		end
	end
	-- turons de neu: suaus a prop de la tanca i cada cop més grossos cap a
	-- l'horitzó (la vora de la plana queda amagada)
	for _ = 1, 140 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(BORDER + 40, FIELD + 60)
		local r = 30 + (d - BORDER) / (FIELD - BORDER) * rng:NextNumber(60, 140)
		Terrain:FillBall(V3(EX + math.cos(a) * d, -r * 0.8, EZ + math.sin(a) * d), r, M.Snow)
	end
	-- muntanyes de gel a tot l'horitzó (menys per l'est, d'on arriba l'avió),
	-- amb el cim nevat
	for _ = 1, 26 do
		local a = rng:NextNumber(math.rad(100), math.rad(260)) -- oest, nord i sud
		local d = rng:NextNumber(720, FIELD - 60)
		local r = rng:NextNumber(90, 190)
		local c = V3(EX + math.cos(a) * d, -r * 0.45, EZ + math.sin(a) * d)
		Terrain:FillBall(c, r, M.Glacier)
		Terrain:FillBall(c + V3(0, r * 0.62, 0), r * 0.42, M.Snow)
	end
	-- el llac glaçat: una làmina de gel una mica per sota de la neu
	Terrain:FillBlock(CF(EX - 20, -2.6, EZ + 96), V3(40, 3, 28), M.Air)
	Terrain:FillBlock(CF(EX - 20, -3.4, EZ + 96), V3(38, 2.6, 26), M.Glacier)
end

-- ── les tres muntanyes de gel GEGANTS del fons (el punt de referència) ──
-- terreny, com les piràmides d'Egipte: l'excepció d'escala del CLAUDE.md
do
	for _, mnt in ipairs({ { -360, 0, 150 }, { -300, -290, 115 }, { -270, 300, 100 } }) do
		local c = V3(EX + mnt[1], -mnt[3] * 0.25, EZ + mnt[2])
		Terrain:FillBall(c, mnt[3], M.Glacier)
		Terrain:FillBall(c + V3(0, mnt[3] * 0.55, 0), mnt[3] * 0.5, M.Snow)
		-- esquerdes de gel blau fosc a la falda (roca glaçada)
		for k = 0, 4 do
			local a = k * 1.3 + mnt[2]
			Terrain:FillBall(c + V3(math.cos(a) * mnt[3] * 0.8, mnt[3] * 0.2, math.sin(a) * mnt[3] * 0.8), mnt[3] * 0.18, M.Rock)
		end
	end
end

-- ── parets invisibles de la zona jugable (la neu continua a fora) ──
do
	local m = Instance.new("Model")
	m.Name = "GlacierBorder"
	for _, w in ipairs({ { BORDER, 0, 2, BORDER * 2 }, { -BORDER, 0, 2, BORDER * 2 }, { 0, BORDER, BORDER * 2, 2 }, { 0, -BORDER, BORDER * 2, 2 } }) do
		local wall = P(V3(w[3], 200, w[4]), CF(EX + w[1], 100, EZ + w[2]), C(255, 255, 255), M.SmoothPlastic, m)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
	end
	m.Parent = F
end

-- ── moll d'arribada: una plataforma de fusta sobre la neu (TravelPoint) ──
local LX = EX + 100 -- on arriba l'avió (a l'est: es mira cap a l'oest)
do
	local m = Instance.new("Model")
	m.Name = "Landing"
	P(V3(40, 1, 36), CF(LX, -0.2, EZ), WOOD, M.WoodPlanks, m)
	-- vora de fusta fosca (0,05 més baixa: no comparteix pla amb la llosa)
	for s = -1, 1, 2 do
		P(V3(40.6, 0.9, 1.2), CF(LX, -0.25, EZ + s * 18.3), WOOD_D, M.Wood, m)
	end
	-- catifa de neu trepitjada cap a la portalada
	P(V3(30, 0.1, 6), CF(LX - 5, 0.35, EZ), SNOW_D, M.Snow, m, true)
	-- pals amb banderes de l'expedició (colors vius sobre el blanc)
	local FLAGS = { C(230, 60, 60), C(60, 140, 230), C(250, 200, 50), C(80, 190, 110) }
	for i, pz in ipairs({ -15, -8, 8, 15 }) do
		local p = V3(LX + 14, 0.3, EZ + pz)
		VCyl(10, 0.4, p + UP * 5, C(70, 74, 82), M.Metal, m)
		P(V3(0.1, 2, 3.2), CF(p + V3(0, 9, 1.65)), FLAGS[i], M.Fabric, m, true)
	end
	-- caixes de subministraments
	for i, cp in ipairs({ { 8, 14 }, { 10, 12 }, { 8, -14 } }) do
		P(V3(2.4, 2.4, 2.4), CF(LX + cp[1], 1.5, EZ + cp[2]) * CFrame.Angles(0, rad(i * 17), 0), C(170, 126, 76), M.WoodPlanks, m)
	end
	m.Parent = F
	-- punt d'arribada del botó "Glacier" (TravelService), mirant cap a la zona
	local tp = P(V3(4, 0.2, 4), CF(LX + 6, 0.45, EZ) * CFrame.Angles(0, math.rad(90), 0), COL.brass, M.SmoothPlastic, F, true)
	tp.Name = "TravelPoint"
	tp.Transparency = 1
	tp.CanQuery = false
	tp:SetAttribute("Destination", "glacier")
	tag(tp, "TravelPoint")
end

-- ── portalada de gel (dos pilars de glaç i una llinda de fusta) ──
local GX = EX + 64
do
	local m = Instance.new("Model")
	m.Name = "GlacierGate"
	for s = -1, 1, 2 do
		local z = EZ + s * 9
		-- pilar: base de neu i blocs de gel que s'estrenyen
		P(V3(7, 3, 8), CF(GX, 1.5, z), SNOW_D, M.Snow, m)
		P(V3(5.6, 8, 6.4), CF(GX, 7, z), ICE, M.Glass, m).Transparency = 0.2
		P(V3(4.6, 4, 5.4), CF(GX, 13, z), ICE_D, M.Glass, m).Transparency = 0.2
		-- punxa de gel a dalt de tot
		Pyramid(CF(V3(GX, 15, z)), 3.6, 4, ICE, M.Glass, m)
	end
	-- llinda de fusta amb el rètol
	local lintel = P(V3(3, 2.6, 12), CF(GX, 12.4, EZ), WOOD, M.WoodPlanks, m)
	Label(lintel, "ICE AGE GLACIER", C(255, 255, 255), Enum.Font.GothamBlack, Enum.NormalId.Left)
	Label(lintel, "ICE AGE GLACIER", C(255, 255, 255), Enum.Font.GothamBlack, Enum.NormalId.Right)
	-- neu sobre la llinda (0,1 més ampla: no comparteix cares)
	P(V3(3.1, 0.5, 12.1), CF(GX, 13.95, EZ), SNOW, M.Snow, m, true)
	-- aquí es desbloqueja la glacera (ShopService hi posa el botó)
	local unlock = P(V3(4, 0.2, 10), CF(GX, 0.8, EZ), COL.brass, M.SmoothPlastic, m, true)
	unlock.Name = "GlacierUnlock"
	unlock.Transparency = 1
	unlock.CanQuery = false
	unlock:SetAttribute("Zone", "glacier")
	tag(unlock, "ZoneUnlock")
	m.Parent = F
end

-- ── forats: cràters de neu repartits a l'atzar ──
local digs = 0
do
	local field = Instance.new("Model")
	field.Name = "GlacierDigField"
	field.Parent = F
	-- cercles ocupats {x, z, radi} relatius a (EX, EZ)
	local busy = {
		{ -150, 0, 36 }, -- mamut congelat
		{ -20, 96, 28 }, -- llac
		{ -8, -92, 26 }, -- campament
		{ -100, -118, 12 }, { -120, 110, 12 }, { 30, 130, 12 }, -- iglús
		{ 40, -60, 8 }, { 50, 60, 8 }, { -60, 40, 8 }, { -70, -50, 8 }, -- cristalls de gel
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
		-- a l'oest de la portalada fins al mamut; centre múltiple de 4
		local x = math.floor(rng:NextNumber(-175, 30) / 4 + 0.5) * 4
		local z = math.floor(rng:NextNumber(-150, 150) / 4 + 0.5) * 4
		if free(x, z) then
			digs += 1
			table.insert(busy, { x, z, 13 })
			digPit(V3(EX + x, SNOW_Y, EZ + z), "glacier", "GlacierDig" .. digs, "ice", rng, field)
		end
	end
	-- cartells "DIG HERE" a l'entrada
	for _, s in ipairs({ -1, 1 }) do
		local p = V3(GX - 10, SNOW_Y, EZ + s * 14)
		P(V3(0.4, 5, 0.4), CF(p + UP * 2.5), MOD.steel, M.Metal, F, true)
		local sg = P(V3(0.3, 2.4, 5), CF(p + UP * 5.4), MOD.char, M.SmoothPlastic, F, true)
		Label(sg, "DIG HERE ⛏", C(170, 225, 255), Enum.Font.GothamBlack, Enum.NormalId.Right)
	end
end

-- ── el mamut congelat dins un bloc de gel (com l'esfinx d'Egipte) ──
-- La figura es veu a través del gel a propòsit: és l'únic lloc on una peça
-- va dins d'una altra (el gel és transparent).
do
	local m = Instance.new("Model")
	m.Name = "FrozenMammoth"
	local base = V3(EX - 150, SNOW_Y, EZ)
	local cf = CF(base) * CFrame.Angles(0, math.rad(-90), 0) -- mira cap a l'est (cap al moll)
	-- sòcol de neu
	P(V3(18, 1, 30), cf * CF(0, 0.5, -3), SNOW_D, M.Snow, m)
	-- cos, gepa i cap (pelatge marró)
	Ellipsoid(V3(8, 7, 12), cf * CF(0, 8, 0), FUR, M.SmoothPlastic, m)
	Ellipsoid(V3(5.4, 3.4, 5.4), cf * CF(0, 11.4, -2.6), FUR_D, M.SmoothPlastic, m)
	Ellipsoid(V3(5, 5.6, 5), cf * CF(0, 10, -7), FUR, M.SmoothPlastic, m)
	-- orelles petites i ulls
	for s = -1, 1, 2 do
		Ellipsoid(V3(0.6, 1.8, 1.4), cf * CF(s * 2.5, 10.6, -6), FUR_D, M.SmoothPlastic, m, true)
		Ball(0.5, (cf * CF(s * 1.7, 10.8, -9.2)).Position, C(30, 26, 24), M.SmoothPlastic, m, true)
	end
	-- quatre potes gruixudes
	for _, lp in ipairs({ { -2.6, -3.6 }, { 2.6, -3.6 }, { -2.6, 3.6 }, { 2.6, 3.6 } }) do
		VCyl(5, 2.6, (cf * CF(lp[1], 3.5, lp[2])).Position, FUR_D, M.SmoothPlastic, m)
	end
	-- trompa: boles que baixen corbant-se
	local trunk = { V3(0, 8.6, -9.3), V3(0, 6.6, -10.2), V3(0, 4.6, -10.4), V3(0, 2.8, -9.9), V3(0, 1.8, -9) }
	for i = 1, #trunk - 1 do
		beam((cf * CF(trunk[i])).Position, (cf * CF(trunk[i + 1])).Position, 1.4 - i * 0.18, FUR_D, M.SmoothPlastic, m, true)
	end
	-- ullals d'ivori corbats (endavant, enfora i amunt)
	for s = -1, 1, 2 do
		local pts = { V3(s * 1.2, 7.8, -9), V3(s * 2.4, 5.4, -11.6), V3(s * 3.2, 5.6, -14.2), V3(s * 2.8, 7.8, -16) }
		for i = 1, #pts - 1 do
			beam((cf * CF(pts[i])).Position, (cf * CF(pts[i + 1])).Position, 0.9 - i * 0.15, IVORY, M.SmoothPlastic, m, true)
		end
	end
	-- el bloc de gel que l'embolcalla
	local block = P(V3(14, 17, 28), cf * CF(0, 9.5, -3.5), ICE, M.Glass, m)
	block.Transparency = 0.55
	block.Reflectance = 0.1
	-- placa davant
	local plaque = P(V3(6, 1.6, 0.3), cf * CF(0, 1.8, -18.4), WOOD_D, M.Wood, m)
	Label(plaque, "WOOLLY MAMMOTH · FROZEN 40,000 YEARS", C(255, 255, 255), Enum.Font.GothamBlack, Enum.NormalId.Front)
	-- gran: s'escala des de la base, així es queda a terra
	m.WorldPivot = CF(base)
	m.Parent = F
	m:ScaleTo(1.8)
end

-- ── iglús (cúpula de neu mig enterrada i túnel d'entrada) ──
for i, ip in ipairs({ { -100, -118 }, { -120, 110 }, { 30, 130 } }) do
	local m = Instance.new("Model")
	m.Name = "Igloo"
	local c = V3(EX + ip[1], SNOW_Y, EZ + ip[2])
	Ball(12, c, SNOW, M.Snow, m).CanCollide = true
	local a = rad(i * 70)
	local dir = V3(math.cos(a), 0, math.sin(a))
	Cyl(4, 4.4, CF(c + dir * 6.4 + UP * 0.2, c + dir * 10) * CFrame.Angles(0, rad(90), 0), SNOW_D, M.Snow, m)
	-- la porta fosca
	Ball(3.6, c + dir * 8.4 + UP * 0.2, C(40, 50, 70), M.SmoothPlastic, m, true)
	m.Parent = F
end

-- ── campament de l'expedició: tendes, foguera i caixes ──
do
	local m = Instance.new("Model")
	m.Name = "ExpeditionCamp"
	local c = V3(EX - 8, SNOW_Y, EZ - 92)
	-- tres tendes canadenques (dos panells inclinats i els triangles)
	for i, tp in ipairs({ { -12, 0, 0 }, { 0, -8, 30 }, { 12, 0, -20 } }) do
		local tcf = CF(c + V3(tp[1], 0, tp[2])) * CFrame.Angles(0, rad(tp[3]), 0)
		for s = -1, 1, 2 do
			P(V3(0.2, 4.4, 6), tcf * CF(s * 1.55, 1.7, 0) * CFrame.Angles(0, 0, rad(s * 35)), if i == 2 then C(60, 140, 230) else TENT, M.Fabric, m)
		end
		P(V3(0.3, 0.3, 6.4), tcf * CF(0, 3.55, 0), C(70, 74, 82), M.Metal, m, true)
	end
	-- foguera: pedres, troncs i foc (efecte i llum)
	local fire = c + V3(0, 0, 10)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		Ball(1, fire + V3(math.cos(a) * 2, 0.2, math.sin(a) * 2), C(120, 118, 114), M.Slate, m, true)
	end
	for k = 0, 2 do
		Cyl(3, 0.5, CF(fire + UP * 0.4) * CFrame.Angles(0, k * math.pi / 3, 0), WOOD_D, M.Wood, m, true)
	end
	local flame = Ball(1.2, fire + UP * 1, C(255, 150, 40), M.Neon, m, true)
	local f = Instance.new("Fire")
	f.Heat = 6
	f.Size = 4
	f.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = C(255, 170, 90)
	light.Range = 22
	light.Brightness = 1.5
	light.Parent = flame
	-- troncs per seure
	for s = -1, 1, 2 do
		Cyl(4, 1, CF(fire + V3(s * 4.5, 0.2, 0)) * CFrame.Angles(0, rad(90), 0), WOOD, M.Wood, m)
	end
	-- caixes i un trineu
	for k, bp in ipairs({ { 16, 6 }, { 17.5, 8.4 }, { -16, 8 } }) do
		P(V3(2.2, 2.2, 2.2), CF(c + V3(bp[1], 1.1, bp[2])) * CFrame.Angles(0, rad(k * 23), 0), C(170, 126, 76), M.WoodPlanks, m)
	end
	local sled = CF(c + V3(-6, 0.6, 16)) * CFrame.Angles(0, rad(20), 0)
	P(V3(2.6, 0.3, 6), sled * CF(0, 0.5, 0), C(190, 60, 50), M.WoodPlanks, m)
	for s = -1, 1, 2 do
		P(V3(0.2, 0.3, 6.6), sled * CF(s * 1.1, 0, 0.2), C(70, 74, 82), M.Metal, m, true)
	end
	m.Parent = F
end

-- ── cabana de paletes: les tres millors del joc només es venen aquí ──
-- (ToolStand amb ToolId, com a Dig & Co. i al basar d'Egipte)
do
	local m = Instance.new("Model")
	m.Name = "TrowelHut"
	local c = V3(EX + 96, SNOW_Y, EZ - 48) -- al sud del moll, abans de la portalada
	-- terra de fusta, pals i sostre de fusta amb neu a sobre
	P(V3(22, 0.6, 12), CF(c + UP * 0.3), WOOD, M.WoodPlanks, m)
	for q = -1, 1, 2 do
		for r = -1, 1, 2 do
			VCyl(7, 0.6, c + V3(q * 10, 4.1, r * 5.4), WOOD_D, M.Wood, m)
		end
	end
	P(V3(23, 0.5, 13), CF(c + V3(0, 7.85, 0)) * CFrame.Angles(rad(6), 0, 0), WOOD_D, M.WoodPlanks, m)
	P(V3(23.2, 0.4, 13.2), CF(c + V3(0, 8.3, 0)) * CFrame.Angles(rad(6), 0, 0), SNOW, M.Snow, m, true)
	local sign = P(V3(12, 1.6, 0.3), CF(c + V3(0, 9.6, 6.9)), C(40, 70, 110), M.SmoothPlastic, m)
	Label(sign, "FROST TROWELS", C(190, 235, 255), Enum.Font.GothamBlack, Enum.NormalId.Back)
	Label(sign, "FROST TROWELS", C(190, 235, 255), Enum.Font.GothamBlack, Enum.NormalId.Front)
	local ids = { "frost_trowel", "aurora_trowel", "mammoth_trowel" }
	local names = { "FROST", "AURORA", "MAMMOTH" }
	local cols = { C(170, 225, 255), C(120, 255, 190), C(246, 238, 216) }
	for i, id in ipairs(ids) do
		local face = CF(c + V3(-6 + (i - 1) * 6, 0.6, 1))
		P(V3(3.6, 0.4, 3.6), face * CF(0, 0.2, 0), SNOW_D, M.Snow, m)
		local stand = P(V3(2.6, 2.4, 2.6), face * CF(0, 1.6, 0), ICE, M.Glass, m)
		stand.Transparency = 0.15
		stand.Name = "ToolStand_" .. id
		stand:SetAttribute("ToolId", id)
		tag(stand, "ToolStand")
		P(V3(2.8, 0.18, 2.8), face * CF(0, 2.88, 0), C(70, 74, 82), M.Metal, m, true)
		for _, e in ipairs({ { 0, 1.36, 2.8, 0.1 }, { 0, -1.36, 2.8, 0.1 }, { 1.36, 0, 0.1, 2.8 }, { -1.36, 0, 0.1, 2.8 } }) do
			P(V3(e[3], 0.06, e[4]), face * CF(e[1], 2.99, e[2]), cols[i], M.Neon, m, true)
		end
		local plaque = P(V3(2.3, 0.7, 0.1), face * CF(0, 1.6, 1.36), C(30, 40, 56), M.SmoothPlastic, m, true)
		Label(plaque, names[i], cols[i], Enum.Font.GothamBlack, Enum.NormalId.Back)
	end
	m.Parent = F
end

-- ── cristalls de gel (grups de punxes transparents) ──
for k, cp in ipairs({ { 40, -60 }, { 50, 60 }, { -60, 40 }, { -70, -50 }, { 110, 70 }, { -30, -140 }, { 120, -130 } }) do
	local c = V3(EX + cp[1], SNOW_Y, EZ + cp[2])
	for q = 0, 4 do
		local a = q * 1.26 + k
		local h = rng:NextNumber(3, 7)
		local p = c + V3(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)
		local spike = P(V3(1.1, h, 1.1), CF(p + UP * (h / 2 - 0.3)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), a, rng:NextNumber(-0.35, 0.35)), if q % 2 == 0 then ICE else C(200, 235, 255), M.Glass, F)
		spike.Transparency = 0.25
	end
end

-- ── pins nevats i roques amb neu ──
for _, pp in ipairs({ { 120, 30 }, { 126, -26 }, { 90, 60 }, { 80, -70 }, { 140, 90 }, { -40, 150 }, { -130, -150 }, { 60, 150 } }) do
	Asset("pine", CF(EX + pp[1], SNOW_Y, EZ + pp[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(12, 18), F)
end
for k, rp in ipairs({ { -118, -60, 6 }, { -40, 120, 5 }, { 60, 118, 7 }, { 90, -110, 5 }, { 140, 40, 6 } }) do
	for q = 0, 2 do
		local a = q * 2.1 + k
		Rock(CF(EX + rp[1] + math.cos(a) * rp[3] * 0.5, SNOW_Y, EZ + rp[2] + math.sin(a) * rp[3] * 0.5) * CFrame.Angles(0, a, 0), rp[3] * (1 - q * 0.25), F, k + q, C(150, 164, 180))
	end
end

-- ── aurora boreal: cintes de llum molt amunt, cap al nord ──
-- (Neon només per a efectes i llums: això és un efecte del cel)
do
	local m = Instance.new("Model")
	m.Name = "Aurora"
	local COLORS = { C(90, 255, 170), C(80, 220, 255), C(170, 110, 255) }
	for i = 0, 17 do
		local x = EX - 700 + i * 80
		local band = P(V3(90, rng:NextNumber(40, 70), 1), CF(x, 300 + math.sin(i * 0.7) * 30, EZ - 900 + math.cos(i * 0.5) * 60) * CFrame.Angles(rad(-20), rad(math.sin(i) * 25), 0), COLORS[i % 3 + 1], M.Neon, m, true)
		band.Transparency = 0.6
		band.CastShadow = false
	end
	m.Parent = F
end

print(("Glacera: a x=%d (només en avió), portalada, mamut congelat, muntanyes de gel, iglús, campament i %d forats per excavar"):format(EX, digs))
