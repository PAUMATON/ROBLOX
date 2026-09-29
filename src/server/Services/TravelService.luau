--!strict

-- TravelService — tots els teletransports: els botons de viatge de la UI i
-- les portes del mapa (coixins "ToMuseum" a la placa i "ToCity" als museus).
--
-- El client nomes diu el NOM del desti; on es aquell lloc ho decideix el
-- servidor. Viatjar a una zona tancada es permet (el mapa hi es igualment):
-- el que esta tancat es CAVAR-hi, i aixo ho vigila DigService.
--
-- Contracte amb el mapa:
--   · SpawnLocation "CitySpawn" (placa)
--   · Plot<n>.Entry (museu propi, via MuseumService)
--   · parts amb etiqueta "TravelPoint" i atribut Destination = id de zona o "shop"

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local MuseumService = require(script.Parent.MuseumService)

local log = Logger.new("TravelService")

local TravelService = {}

-- Destins que són un TravelPoint del mapa (a més de les zones)
local POINT_DESTINATIONS = { shop = true }

local function isPointDestination(destination: string): boolean
	return POINT_DESTINATIONS[destination] == true or Zones.IsZoneId(destination)
end

-- Mig viatge per segon: prou per anar i tornar, massa poc per fer-ne un exploit.
local limiter = RateLimiter.new(0.5)

local function resolve(player: Player, destination: string): CFrame?
	if destination == "museum" then
		local plot = MuseumService.GetPlot(player)
		local entry = plot and plot:FindFirstChild("Entry")
		if entry and entry:IsA("BasePart") then
			-- L'Entry mira cap al carrer: es gira perque arribis mirant endins.
			return entry.CFrame * CFrame.Angles(0, math.pi, 0)
		end
		return nil
	elseif destination == "city" then
		local spawnPad = workspace:FindFirstChild("CitySpawn", true)
		if spawnPad and spawnPad:IsA("BasePart") then
			return spawnPad.CFrame
		end
		return nil
	elseif isPointDestination(destination) then
		for _, point in CollectionService:GetTagged("TravelPoint") do
			if point:IsA("BasePart") and point:GetAttribute("Destination") == destination and point:IsDescendantOf(workspace) then
				return point.CFrame
			end
		end
		log:Warn(`no hi ha cap TravelPoint per a {destination}: torna a construir el mon`)
	end
	return nil
end

function TravelService.Send(player: Player, destination: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local target = resolve(player, destination)
	if not target then
		return false
	end
	character:PivotTo(target + Vector3.new(0, 4, 0))
	return true
end

local function hookPads(tagName: string, destination: string)
	for _, pad in CollectionService:GetTagged(tagName) do
		local prompt = pad:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				if limiter:Check(player) then
					TravelService.Send(player, destination)
				end
			end)
		end
	end
end

function TravelService.Start()
	Remotes.TravelRequest.OnServerEvent:Connect(function(player: Player, destination: any)
		if type(destination) ~= "string" or not limiter:Check(player) then
			return
		end
		if destination ~= "museum" and destination ~= "city" and not isPointDestination(destination) then
			return
		end
		TravelService.Send(player, destination)
	end)

	hookPads("ToMuseum", "museum")
	hookPads("ToCity", "city")
end

return TravelService
