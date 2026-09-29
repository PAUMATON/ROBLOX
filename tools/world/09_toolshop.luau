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
