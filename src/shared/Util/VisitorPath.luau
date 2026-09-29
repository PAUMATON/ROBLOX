--!strict

-- VisitorPath — per on camina un visitant dins d'un museu. Ho fan servir el
-- servidor (per saber QUAN és davant de cada vitrina i donar la propina en
-- aquell moment) i el client (per dibuixar-lo). Mateix codi = mateix camí.
--
-- Tot en coordenades LOCALS del museu (les del constructor, 04_museums):
--   · entrada al sud (z = -14), interior x ∈ [-30.8, 30.8], z ∈ [-12.8, 24.8]
--   · 10 vitrines (CASES); tres passadissos nord-sud: x = 0 i x = ±16.5
--   · dos passadissos est-oest per canviar de passadís: z = -8 i z = 22.5
-- El marc local del museu surt de la peça "Entry": O = Entry * (0, -1.35, 10).

local Visitors = require(script.Parent.Parent.Config.Visitors)

local VisitorPath = {}

local V = Vector3.new

VisitorPath.FLOOR = 1.2
VisitorPath.CASES = {
	V(-24, 0, -2), V(-24, 0, 9), V(-24, 0, 20),
	V(-9, 0, 3.5), V(-9, 0, 15),
	V(9, 0, 3.5), V(9, 0, 15),
	V(24, 0, -2), V(24, 0, 9), V(24, 0, 20),
}
local CROSS = { -8, 22.5 }
local OUTSIDE = V(0, 0, -21) -- sota la marquesina
local DOOR = V(0, 0, -12)

export type Segment = {
	from: Vector3, -- local (y = 0: terra)
	to: Vector3,
	t0: number, -- segons des de l'inici de la visita
	t1: number,
	look: Vector3?, -- si és una parada: cap on mira
	stop: number?, -- índex de la parada (1, 2, ...) si és una parada
	slot: number?, -- vitrina que mira
}

export type Plan = { segments: { Segment }, duration: number, stopTimes: { number } }

-- El passadís d'on es mira una vitrina, i el punt on es para
local function aisleOf(slot: number): number
	local c = VisitorPath.CASES[slot]
	if math.abs(c.X) > 15 then
		return 16.5 * math.sign(c.X)
	end
	return 0
end

local function standOf(slot: number, side: number): Vector3
	local c = VisitorPath.CASES[slot]
	if math.abs(c.X) > 15 then
		return V(18.2 * math.sign(c.X), 0, c.Z + side * 1.2)
	end
	return V(3.4 * math.sign(c.X), 0, c.Z + side * 1.2)
end

-- Punts per anar d'un lloc a un altre pels passadissos
local function route(fromPos: Vector3, fromAisle: number, toPos: Vector3, toAisle: number): { Vector3 }
	local pts = {}
	if fromAisle == toAisle then
		table.insert(pts, V(fromAisle, 0, fromPos.Z))
		table.insert(pts, V(toAisle, 0, toPos.Z))
	else
		-- el passadís de través més a prop
		local best, bestCost = CROSS[1], math.huge
		for _, cz in CROSS do
			local cost = math.abs(fromPos.Z - cz) + math.abs(toPos.Z - cz)
			if cost < bestCost then
				best, bestCost = cz, cost
			end
		end
		table.insert(pts, V(fromAisle, 0, fromPos.Z))
		table.insert(pts, V(fromAisle, 0, best))
		table.insert(pts, V(toAisle, 0, best))
		table.insert(pts, V(toAisle, 0, toPos.Z))
	end
	table.insert(pts, toPos)
	return pts
end

-- El pla d'una visita: entra, mira les vitrines `slots` per ordre i surt.
-- `looks` = segons davant de cada una; `sides` = -1/1 (una mica a un costat,
-- perquè dos visitants no se sobreposin del tot).
function VisitorPath.Plan(slots: { number }, looks: { number }, sides: { number }): Plan
	local segments: { Segment } = {}
	local stopTimes: { number } = {}
	local t = 0
	local pos = OUTSIDE
	local aisle = 0
	local function walkTo(p: Vector3)
		local d = (p - pos).Magnitude
		if d > 0.01 then
			local dur = d / Visitors.WALK_SPEED
			table.insert(segments, { from = pos, to = p, t0 = t, t1 = t + dur })
			t += dur
			pos = p
		end
	end
	walkTo(DOOR)
	for i, slot in slots do
		local stand = standOf(slot, sides[i] or 1)
		local target = aisleOf(slot)
		local pts = route(pos, aisle, stand, target)
		for _, p in pts do
			walkTo(p)
		end
		aisle = target
		local case = VisitorPath.CASES[slot]
		table.insert(stopTimes, t)
		table.insert(segments, { from = pos, to = pos, t0 = t, t1 = t + looks[i], look = V(case.X, 0, case.Z), stop = i, slot = slot })
		t += looks[i]
	end
	for _, p in route(pos, aisle, DOOR, 0) do
		walkTo(p)
	end
	walkTo(OUTSIDE)
	return { segments = segments, duration = t, stopTimes = stopTimes }
end

-- On és (i cap on mira) el visitant `elapsed` segons després d'entrar.
-- Torna la posició local, la direcció local i si està caminant.
function VisitorPath.At(plan: Plan, elapsed: number): (Vector3, Vector3, boolean)
	for _, s in plan.segments do
		if elapsed <= s.t1 then
			if s.look then
				return s.from, (s.look - s.from).Unit, false
			end
			local a = math.clamp((elapsed - s.t0) / math.max(s.t1 - s.t0, 1e-3), 0, 1)
			local dir = s.to - s.from
			return s.from:Lerp(s.to, a), if dir.Magnitude > 0 then dir.Unit else V(0, 0, 1), true
		end
	end
	local last = plan.segments[#plan.segments]
	return if last then last.to else OUTSIDE, V(0, 0, -1), false
end

-- El marc local del museu a partir de la seva peça "Entry"
function VisitorPath.Frame(plot: Model): CFrame?
	local entry = plot:FindFirstChild("Entry", true)
	if not entry or not entry:IsA("BasePart") then
		return nil
	end
	return entry.CFrame * CFrame.new(0, -(VisitorPath.FLOOR + 0.15), 10)
end

return VisitorPath
