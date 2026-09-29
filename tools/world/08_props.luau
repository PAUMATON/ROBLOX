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
-- ── parets invisibles del món: a la filera d'arbres de les vores, i per la
-- platja i el mar fins on s'acaba (x = 1100), perquè ningú no pugui sortir
-- vorejant el bosc per la sorra ni nedant fins al buit ──
do
	local m = Instance.new("Model")
	m.Name = "WorldBounds"
	local H, TH = 90, 2 -- alçada (no s'hi pot saltar per sobre) i gruix
	local SEA_END = 1100
	local function wall(x0, z0, x1, z1)
		local w = P(V3(math.max(x1 - x0, TH), H, math.max(z1 - z0, TH)), CF((x0 + x1) / 2, H / 2 - 20, (z0 + z1) / 2), C(255, 255, 255), M.SmoothPlastic, m)
		w.Transparency = 1
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
	end
	local WX = L.x0 + 3 -- a l'oest, entre els troncs (a x0 + 5) i el límit
	local NZ, SZ = L.z0 + 1, L.z1 - 1 -- al nord i al sud, just darrere els arbres
	local BZ = 305 -- a la platja, la sorra va una mica més enllà
	wall(WX, NZ, WX, SZ) -- oest
	wall(WX, NZ, LAYOUT.PROM.x0, NZ) -- nord (terra)
	wall(WX, SZ, LAYOUT.PROM.x0, SZ) -- sud (terra)
	wall(LAYOUT.PROM.x0, -BZ, LAYOUT.PROM.x0, NZ) -- tram que baixa a la platja (nord)
	wall(LAYOUT.PROM.x0, SZ, LAYOUT.PROM.x0, BZ) -- (sud)
	wall(LAYOUT.PROM.x0, -BZ, SEA_END, -BZ) -- nord (platja i mar)
	wall(LAYOUT.PROM.x0, BZ, SEA_END, BZ) -- sud (platja i mar)
	wall(SEA_END - 40, -BZ, SEA_END - 40, BZ) -- est: abans que s'acabi el mar
	m.Parent = F
end

print(("Carrer: %d fanals, %d arbres de vorera; passeig, patis, bosc, turons i parets invisibles fets"):format(nLamps, nTrees))
