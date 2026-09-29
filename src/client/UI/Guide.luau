--!strict

-- Guide — el raig de llum que va dels peus del jugador fins on ha d'anar,
-- amb una fletxa a sobre. Ho fan servir el tutorial i les missions.
--
-- Només hi ha un raig. Qui el posa n'és l'amo (`owner`), i Clear només
-- l'apaga si el demana l'amo: així el tutorial, en acabar, no apaga el
-- raig que acaba de posar la missió.
--
-- També sap trobar els llocs on s'envia la gent (entrada de l'obra, munt
-- més proper, la parada de la Bonnie...), perquè no ho hagi de saber cada
-- controlador pel seu compte.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)

local C = Theme.C
local player = Players.LocalPlayer

local Guide = {}

Guide.NEAR = 70 -- studs: a partir d'aquí ja ets "a la zona"

local owner: string? = nil
local beam: Beam? = nil
local fromAtt: Attachment? = nil
local toAtt: Attachment? = nil
local arrow: BillboardGui? = nil

local function root(): BasePart?
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function destroyAll()
	for _, obj in { beam, fromAtt, toAtt, arrow } :: { Instance? } do
		if obj then
			obj:Destroy()
		end
	end
	beam, fromAtt, toAtt, arrow = nil, nil, nil, nil
end

-- Apaga el raig, però només si és de `who`
function Guide.Clear(who: string)
	if owner == who then
		owner = nil
		destroyAll()
	end
end

-- Apunta a `target` (nil = apagar). `who` en passa a ser l'amo.
function Guide.PointAt(who: string, target: BasePart?)
	local r = root()
	if not target or not r then
		Guide.Clear(who)
		return
	end
	owner = who
	if not fromAtt or fromAtt.Parent ~= r then
		destroyAll()
		fromAtt = Instance.new("Attachment")
		fromAtt.Name = "GuideFrom"
		fromAtt.Position = Vector3.new(0, -1.5, 0)
		fromAtt.Parent = r
		toAtt = Instance.new("Attachment")
		toAtt.Name = "GuideTo"
		toAtt.Parent = workspace.Terrain
		local b = Instance.new("Beam")
		b.Attachment0 = fromAtt
		b.Attachment1 = toAtt
		b.Width0 = 1.4
		b.Width1 = 1.4
		b.FaceCamera = true
		b.LightEmission = 1
		b.Segments = 12
		b.CurveSize0 = 0
		b.Color = ColorSequence.new(C.yellow, C.green)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		b.Parent = workspace.Terrain
		beam = b
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(90, 90)
		bb.AlwaysOnTop = true
		bb.StudsOffset = Vector3.new(0, 6, 0)
		bb.Parent = player:WaitForChild("PlayerGui")
		local icon = Theme.Icon(bb, "⬇️", {})
		Effects.Pulse(icon, 0.2, 0.7)
		arrow = bb
	end
	local ta = toAtt :: Attachment
	ta.WorldPosition = target.Position + Vector3.new(0, target.Size.Y / 2 + 0.5, 0)
	local bb = arrow :: BillboardGui
	bb.Adornee = target
end

-- ─────────────────────────── LLOCS ───────────────────────────

-- El punt d'arribada d'un viatge (entrada de l'obra, platja, botiga)
function Guide.TravelPoint(destination: string): BasePart?
	for _, p in CollectionService:GetTagged("TravelPoint") do
		if p:IsA("BasePart") and p:GetAttribute("Destination") == destination then
			return p
		end
	end
	return nil
end

-- Munt llest per excavar més proper d'una zona
function Guide.NearestMound(zone: string): BasePart?
	local r = root()
	if not r then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, spot in CollectionService:GetTagged("DigSpot") do
		if spot:IsA("BasePart") and spot:GetAttribute("Zone") == zone then
			local empty = spot:GetAttribute("EmptyUntil")
			local ready = not (type(empty) == "number" and workspace:GetServerTimeNow() < empty)
			local d = (spot.Position - r.Position).Magnitude
			if ready and d < bestD then
				best, bestD = spot, d
			end
		end
	end
	return best
end

-- Ets a prop d'aquest punt?
function Guide.Near(part: BasePart?, dist: number?): boolean
	local r = root()
	return r ~= nil and part ~= nil and (r.Position - part.Position).Magnitude < (dist or Guide.NEAR)
end

-- La peça d'un botiguer (el que té el ProximityPrompt `promptName`). Es busca
-- un cop i es guarda: recórrer tot el món cada mig segon costaria massa.
local keeperCache: { [string]: BasePart } = {}
local keeperMiss: { [string]: number } = {} -- si no hi és, no es torna a buscar fins d'aquí a 5 s
function Guide.Keeper(promptName: string): BasePart?
	local cached = keeperCache[promptName]
	if cached and cached:IsDescendantOf(workspace) then
		return cached
	end
	if keeperMiss[promptName] and os.clock() - keeperMiss[promptName] < 5 then
		return nil
	end
	keeperMiss[promptName] = os.clock()
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == promptName and d.Parent and d.Parent:IsA("BasePart") then
			keeperCache[promptName] = d.Parent :: BasePart
			return d.Parent :: BasePart
		end
	end
	return nil
end

-- On ha d'anar el jugador per fer una cosa d'una zona: al munt més proper
-- si en té un a prop; si no, a l'entrada de la zona (si n'és lluny)
function Guide.ZoneTarget(zone: string): BasePart?
	local mound = Guide.NearestMound(zone)
	if mound and Guide.Near(mound, 60) then
		return mound
	end
	local entrance = Guide.TravelPoint(zone)
	if entrance and not Guide.Near(entrance) then
		return entrance
	end
	return mound
end

return Guide
