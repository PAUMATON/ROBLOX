--!strict

-- PotionService — les pocions de la motxilla (Config/Potions): donar-ne,
-- fer-ne servir i la que surt de tant en tant en excavar.
--
-- El client només demana ("use", id). El servidor mira que en tinguis, en
-- treu una i allarga el boost: el temps el compta el servidor (os.time()).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Potions = require(Shared:WaitForChild("Config"):WaitForChild("Potions"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("Util"):WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local PotionService = {}

local limiter = RateLimiter.new(2)
local rng = Random.new()

-- Dona `n` pocions `id`. Torna el text per ensenyar-ho ("2x Luck Potion").
function PotionService.Give(player: Player, id: string, n: number?): string?
	local profile = DataService.Get(player)
	local def = Potions.ById[id]
	if not profile or not def then
		return nil
	end
	local amount = math.max(1, math.floor(n or 1))
	local have = profile.potions[id] or 0
	profile.potions[id] = math.min(Potions.MAX_STACK, have + amount)
	return if amount == 1 then `a {def.name}` else `{amount}x {def.name}`
end

-- En excavar: 1 de cada Potions.DROP_CHANCE en surt una. Torna quina (o nil).
function PotionService.RollDrop(player: Player): string?
	if rng:NextInteger(1, Potions.DROP_CHANCE) ~= 1 then
		return nil
	end
	local total = 0
	for _, w in Potions.DROP_WEIGHTS do
		total += w
	end
	local roll = rng:NextNumber() * total
	for _, def in Potions.LIST do
		roll -= Potions.DROP_WEIGHTS[def.id] or 0
		if roll <= 0 then
			if PotionService.Give(player, def.id, 1) then
				return def.id
			end
			return nil
		end
	end
	return nil
end

local function extend(current: number?, minutes: number): number
	return math.max(current or 0, os.time()) + minutes * 60
end

local function use(player: Player, id: any)
	local profile = DataService.Get(player)
	if not profile or not Potions.IsPotion(id) then
		return
	end
	local def = Potions.ById[id :: string]
	local have = profile.potions[def.id] or 0
	if have < 1 then
		return
	end
	-- cap yield d'aquí fins al final: o es gasta i s'aplica, o res
	profile.potions[def.id] = if have > 1 then have - 1 else nil
	if def.luck then
		profile.luckBoostUntil = extend(profile.luckBoostUntil, def.minutes)
	end
	if def.money then
		profile.boostUntil = extend(profile.boostUntil, def.minutes)
	end
	if def.haste then
		profile.digBoostUntil = extend(profile.digBoostUntil, def.minutes)
	end
	InventoryService.Push(player)
	Remotes.Notify:FireClient(player, { kind = "shop", ok = true, icon = def.icon, message = `{def.name}: {def.text}!`, fx = "fanfare" })
end

function PotionService.Start()
	Remotes.PotionRequest.OnServerEvent:Connect(function(player: Player, action: any, id: any)
		if not limiter:Check(player) then
			return
		end
		if action == "use" then
			use(player, id)
		end
	end)
end

return PotionService
