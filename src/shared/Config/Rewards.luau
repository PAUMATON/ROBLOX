--!strict

-- Rewards — recompenses gratis que fan tornar i quedar-se:
--   · DIÀRIA: una per dia (dia UTC), en ratxa de 7. Si et saltes un dia, la
--     ratxa torna al dia 1. El dia 7 és el gros (un fòssil Legendary).
--   · REGALS PER ESTONA DE JOC: en cada sessió, als 2, 5, 10, 20, 35 i 60
--     minuts. Es compta des que entres (ho mesura el servidor).
--   · Molts premis són "paquets" (bundle): monedes + pocions + fòssil alhora.
--   · INVITACIONS: si un amic entra al joc amb la teva invitació, tots dos
--     guanyeu un premi (un cop per amic, fins a MAX_INVITES).
--   · LIKE: SENSE recompensa. Les normes de Roblox prohibeixen donar premis
--     a canvi de likes o preferits; només es demana amablement.
--
-- Les monedes es donen en "minuts de la teva renda de museu" perquè valguin
-- el mateix al principi que al final del joc (mínim MIN_RATE/min).

local Rewards = {}

export type Reward = {
	kind: string, -- "coins" | "money" (x2 diners) | "luck" (x2 sort) | "fossil" | "potion" | "bundle"
	minutes: number?, -- coins: minuts de renda · money/luck: durada del boost
	rarity: string?, -- fossil: la raresa (una peça a l'atzar de l'obra)
	potion: string?, -- potion: quina (Config/Potions)
	count: number?, -- potion: quantes
	items: { Reward }?, -- bundle: tot això alhora
	label: string,
	icon: string,
}

Rewards.MIN_RATE = 1200 -- renda mínima per calcular les monedes (jugadors nous)

-- Ajudes per escriure els premis de sota
local function coins(minutes: number): Reward
	return { kind = "coins", minutes = minutes, label = "Coins", icon = "$" }
end
local function potion(id: string, count: number?): Reward
	return { kind = "potion", potion = id, count = count or 1, label = "Potion", icon = "🧪" }
end
local function fossil(rarity: string): Reward
	return { kind = "fossil", rarity = rarity, label = "Fossil", icon = "🦴" }
end
local function bundle(label: string, icon: string, items: { Reward }): Reward
	return { kind = "bundle", items = items, label = label, icon = icon }
end

-- 29/09/2026: molt més generoses (el propietari les volia "chetades").
-- Els fòssils de regal van bloquejats (no es poden comerciar).
Rewards.DAILY = {
	bundle("Coins + 🍀", "$", { coins(30), potion("luck") }),
	bundle("Coins + 💸", "$", { coins(45), potion("money") }),
	bundle("Big coins + ⚡⚡", "💸", { coins(60), potion("haste", 2) }),
	bundle("Big coins + 🍀🍀", "💸", { coins(90), potion("luck", 2) }),
	bundle("EPIC fossil + 🌟", "🦴", { fossil("Epic"), potion("super") }),
	bundle("Huge coins + 🌟🌟", "🏦", { coins(180), potion("super", 2) }),
	bundle("LEGENDARY fossil!", "🦖", { fossil("Legendary"), potion("super", 3), coins(120) }),
} :: { Reward }

-- Regals d'una sessió: minut en què es poden obrir i què donen
Rewards.GIFTS = {
	{ at = 2, reward = bundle("Coins + 🍀", "$", { coins(15), potion("luck") }) },
	{ at = 5, reward = bundle("Coins + 💸", "$", { coins(30), potion("money") }) },
	{ at = 10, reward = bundle("⚡ + 🍀 Potions", "🧪", { potion("haste"), potion("luck") }) },
	{ at = 20, reward = bundle("Big coins + 🌟", "💸", { coins(60), potion("super") }) },
	{ at = 35, reward = bundle("EPIC fossil + 🍀🍀", "🦴", { fossil("Epic"), potion("luck", 2) }) },
	{ at = 60, reward = bundle("Huge coins + 🌟🌟", "🏦", { coins(150), potion("super", 2) }) },
} :: { { at: number, reward: Reward } }

Rewards.INVITER = { kind = "potion", potion = "super", count = 2, label = "2 Super Potions", icon = "🌟" } :: Reward
Rewards.INVITER_COINS = { kind = "coins", minutes = 30, label = "Coins", icon = "$" } :: Reward
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
