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
