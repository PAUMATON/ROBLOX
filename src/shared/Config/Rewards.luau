--!strict

-- Rewards — recompenses gratis que fan tornar i quedar-se:
--   · DIÀRIA: una per dia (dia UTC), en ratxa de 7. Si et saltes un dia, la
--     ratxa torna al dia 1. El dia 7 és el gros (un fòssil Epic).
--   · REGALS PER ESTONA DE JOC: en cada sessió, als 5, 10, 15, 25, 40 i 60
--     minuts. Es compta des que entres (ho mesura el servidor).
--   · INVITACIONS: si un amic entra al joc amb la teva invitació, tots dos
--     guanyeu un premi (un cop per amic, fins a MAX_INVITES).
--   · LIKE: SENSE recompensa. Les normes de Roblox prohibeixen donar premis
--     a canvi de likes o preferits; només es demana amablement.
--
-- Les monedes es donen en "minuts de la teva renda de museu" perquè valguin
-- el mateix al principi que al final del joc (mínim MIN_RATE/min).

local Rewards = {}

export type Reward = {
	kind: string, -- "coins" | "money" (x2 diners) | "luck" (x2 sort) | "fossil"
	minutes: number?, -- coins: minuts de renda · money/luck: durada del boost
	rarity: string?, -- fossil: la raresa (una peça a l'atzar de l'obra)
	label: string,
	icon: string,
}

Rewards.MIN_RATE = 20 -- renda mínima per calcular les monedes (jugadors nous)

Rewards.DAILY = {
	{ kind = "coins", minutes = 10, label = "Coins", icon = "💰" },
	{ kind = "coins", minutes = 20, label = "Coins", icon = "💰" },
	{ kind = "money", minutes = 15, label = "x2 Money 15m", icon = "💰" },
	{ kind = "coins", minutes = 40, label = "Big coins", icon = "💸" },
	{ kind = "luck", minutes = 15, label = "x2 Luck 15m", icon = "🍀" },
	{ kind = "coins", minutes = 60, label = "Huge coins", icon = "🏦" },
	{ kind = "fossil", rarity = "Epic", label = "EPIC fossil!", icon = "🦖" },
} :: { Reward }

-- Regals d'una sessió: minut en què es poden obrir i què donen
Rewards.GIFTS = {
	{ at = 5, reward = { kind = "coins", minutes = 5, label = "Coins", icon = "💰" } },
	{ at = 10, reward = { kind = "coins", minutes = 10, label = "Coins", icon = "💰" } },
	{ at = 15, reward = { kind = "luck", minutes = 10, label = "x2 Luck 10m", icon = "🍀" } },
	{ at = 25, reward = { kind = "coins", minutes = 20, label = "Big coins", icon = "💸" } },
	{ at = 40, reward = { kind = "money", minutes = 15, label = "x2 Money 15m", icon = "💰" } },
	{ at = 60, reward = { kind = "fossil", rarity = "Epic", label = "EPIC fossil!", icon = "🦖" } },
} :: { { at: number, reward: Reward } }

Rewards.INVITER = { kind = "luck", minutes = 20, label = "x2 Luck 20m", icon = "🍀" } :: Reward
Rewards.INVITER_COINS = { kind = "coins", minutes = 30, label = "Coins", icon = "💰" } :: Reward
Rewards.INVITEE = { kind = "coins", minutes = 30, label = "Welcome coins", icon = "🎁" } :: Reward
Rewards.MAX_INVITES = 20 -- amics diferents que et poden donar premi

-- Quin dia (UTC) és ara: canvia a mitjanit UTC per a tothom
function Rewards.Day(t: number): number
	return math.floor(t / 86400)
end

-- Monedes d'una recompensa "coins" amb aquesta renda de museu
function Rewards.CoinsFor(rate: number, minutes: number): number
	return math.floor(math.max(rate, Rewards.MIN_RATE) * minutes)
end

return Rewards
