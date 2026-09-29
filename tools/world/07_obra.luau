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
