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
