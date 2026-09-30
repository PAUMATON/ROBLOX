--!strict

-- Potions — pocions que es guarden a la motxilla i es fan servir quan vols
-- (barra de baix, HotbarController). Donen boosts temporals, que s'apilen
-- en temps (una poció més = més minuts, no més multiplicador):
--   · luck  → x2 de sort (profile.luckBoostUntil, el mateix que les recompenses)
--   · money → x2 de diners (profile.boostUntil, el mateix que els productes)
--   · haste → excavar el doble de sovint (profile.digBoostUntil)
--   · super → x2 de sort i x2 de diners alhora
-- D'on surten: recompenses diàries, regals per estona de joc, missions i, de
-- tant en tant, en excavar (DROP_CHANCE). Tot ho decideix el servidor.
-- No es poden comerciar (no són fòssils) ni comprar amb Robux (CLAUDE.md:
-- res aleatori de pagament).

local Potions = {}

export type PotionDef = {
	id: string,
	name: string,
	icon: string,
	color: Color3,
	minutes: number,
	text: string, -- què fa, per a la UI (anglès)
	luck: boolean?,
	money: boolean?,
	haste: boolean?,
}

local LIST: { PotionDef } = {
	{ id = "luck", name = "Luck Potion", icon = "🍀", color = Color3.fromRGB(64, 220, 110), minutes = 15, text = "x2 Luck for 15 min", luck = true },
	{ id = "money", name = "Money Potion", icon = "💸", color = Color3.fromRGB(255, 190, 30), minutes = 15, text = "x2 Money for 15 min", money = true },
	{ id = "haste", name = "Haste Potion", icon = "⚡", color = Color3.fromRGB(40, 196, 245), minutes = 10, text = "Dig 2x faster for 10 min", haste = true },
	{ id = "super", name = "Super Potion", icon = "🌟", color = Color3.fromRGB(255, 72, 186), minutes = 10, text = "x2 Luck AND x2 Money for 10 min", luck = true, money = true },
}
Potions.LIST = LIST

Potions.ById = {} :: { [string]: PotionDef }
for _, p in LIST do
	Potions.ById[p.id] = p
end

Potions.MAX_STACK = 99 -- com a molt, de cada
Potions.HASTE_MULT = 0.5 -- amb haste, l'espera entre excavacions es multiplica per això
-- En cada excavació, 1 de cada DROP_CHANCE surt una poció (i quina, amb aquests pesos)
Potions.DROP_CHANCE = 100
Potions.DROP_WEIGHTS = { luck = 45, money = 35, haste = 15, super = 5 } :: { [string]: number }

function Potions.IsPotion(id: any): boolean
	return type(id) == "string" and Potions.ById[id] ~= nil
end

return Potions
