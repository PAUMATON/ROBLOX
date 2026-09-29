--!strict

-- Limitador de crides per jugador (token bucket).
--
-- Un diposit de fitxes per jugador que es reomple a `callsPerSec` fitxes/segon.
-- Cada :Check() gasta una fitxa; si no n'hi ha, retorna false. Aixo permet una
-- rafega curta (fins a la capacitat) sense penalitzar el joc normal, pero
-- l'atacant que crida en bucle es queda sec de seguida.
--
-- Un limitador per remote. El servidor SEMPRE comprova abans de fer res:
--   if not limiter:Check(player) then return end

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = {
	tokens: number,
	lastRefill: number,
}

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_rate: number,
		_capacity: number,
		_buckets: { [Player]: Bucket },
		_leaving: RBXScriptConnection,
	},
	RateLimiter
))

-- callsPerSec: crides sostingudes per segon. La capacitat de rafega es la
-- mateixa xifra (minim 1), aixi un limit de 2/s tolera 2 clics seguits.
function RateLimiter.new(callsPerSec: number): RateLimiter
	assert(callsPerSec > 0, "[RateLimiter] callsPerSec ha de ser > 0")

	local self = setmetatable({
		_rate = callsPerSec,
		_capacity = math.max(1, callsPerSec),
		_buckets = {},
	}, RateLimiter) :: any

	-- Sense aixo, la taula guardaria Players que ja no hi son (fuita de memoria).
	self._leaving = Players.PlayerRemoving:Connect(function(player: Player)
		self._buckets[player] = nil
	end)

	return self
end

-- Retorna true si la crida es permesa (i gasta la fitxa), false si toca ignorar-la.
function RateLimiter.Check(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]

	if not bucket then
		bucket = { tokens = self._capacity, lastRefill = now }
		self._buckets[player] = bucket
	end

	local elapsed = now - bucket.lastRefill
	bucket.lastRefill = now
	bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._rate)

	if bucket.tokens < 1 then
		return false
	end

	bucket.tokens -= 1
	return true
end

-- Neteja manual (p.ex. en acabar un intercanvi, per no arrossegar l'estat).
function RateLimiter.Reset(self: RateLimiter, player: Player)
	self._buckets[player] = nil
end

function RateLimiter.Destroy(self: RateLimiter)
	self._leaving:Disconnect()
	table.clear(self._buckets)
end

return RateLimiter
