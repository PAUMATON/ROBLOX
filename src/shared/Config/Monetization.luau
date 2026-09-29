--!strict

-- Monetization — els gamepasses i productes per Robux (Fase 5), estil
-- "+1 Speed Keyboard Escape": molts passis, i els de diners en cadena
-- (x2 → x4 → x8 ...): per comprar-ne un cal tenir l'anterior.
--
-- Hi ha passis de sort per Robux: ho va decidir el propietari del joc
-- (CLAUDE.md actualitzat). La sort dels passis es multiplica per la de la
-- paleta; el sostre total és Constants.MAX_LUCK.
--
-- ⚠️ Els `id` són els números que dona Roblox quan crees el passi o el
-- producte al Creator Dashboard (Monetization > Passes / Developer Products).
-- Mentre valgui 0, el passi no es pot comprar al joc publicat; a Studio es
-- pot "comprar" gratis per provar-lo (MonetizationService).

local Monetization = {}

export type Pass = {
	key: string,
	id: number, -- id del Game Pass a Roblox (0 = encara no creat)
	name: string,
	icon: string,
	price: number, -- Robux (el preu real el poses al Dashboard; aquí és per ensenyar-lo)
	desc: string,
	group: string, -- "luck" | "money" | "boost" | "vip"
	money: number?, -- multiplicador de diners (els de la cadena)
	luck: number?, -- multiplicador de sort (els de la cadena)
	requires: string?, -- el passi que cal tenir abans
}

export type Product = {
	key: string,
	id: number, -- id del Developer Product (0 = encara no creat)
	name: string,
	icon: string,
	price: number,
	desc: string,
	coinsMinutes: number?, -- monedes = minuts de la teva renda de museu (mínim COINS_MIN)
	boostMinutes: number?, -- x2 de diners durant aquests minuts
}

-- Dues cadenes (per comprar-ne un cal tenir l'anterior):
--   · SORT: multiplica la sort de la paleta (per sobre del x3 de les paletes)
--   · DINERS: multiplica TOTES les monedes (museu, excavar i vendre)
local PASSES: { Pass } = {
	{ key = "luck2", id = 0, name = "x2 Luck", icon = "🍀", price = 4, group = "luck", luck = 2, desc = "Double luck: rare fossils show up way more!" },
	{ key = "luck4", id = 0, name = "x4 Luck", icon = "🍀", price = 12, group = "luck", luck = 4, requires = "luck2", desc = "x4 luck!" },
	{ key = "luck8", id = 0, name = "x8 Luck", icon = "☘️", price = 29, group = "luck", luck = 8, requires = "luck4", desc = "x8 luck!" },
	{ key = "luck16", id = 0, name = "x16 Luck", icon = "🌈", price = 59, group = "luck", luck = 16, requires = "luck8", desc = "x16 luck!" },
	{ key = "luck32", id = 0, name = "x32 Luck", icon = "🌟", price = 99, group = "luck", luck = 32, requires = "luck16", desc = "x32 luck! The MAX." },
	{ key = "money2", id = 0, name = "x2 Money", icon = "$", price = 99, group = "money", money = 2, desc = "Double ALL coins: museum, digging and selling." },
	{ key = "money4", id = 0, name = "x4 Money", icon = "💸", price = 129, group = "money", money = 4, requires = "money2", desc = "x4 ALL coins!" },
	{ key = "money8", id = 0, name = "x8 Money", icon = "🤑", price = 179, group = "money", money = 8, requires = "money4", desc = "x8 ALL coins! The MAX." },
	-- Boosts i comoditat
	{ key = "fastDig", id = 0, name = "Fast Dig", icon = "⚡", price = 149, group = "boost", desc = "Dig twice as often (half the wait between digs)." },
	{ key = "speed", id = 0, name = "Speed Boots", icon = "👟", price = 79, group = "boost", desc = "Run 50% faster around the city." },
	{ key = "offline2", id = 0, name = "x2 Offline Income", icon = "🌙", price = 99, group = "boost", desc = "Your museum earns double while you're away." },
	{ key = "offline24", id = 0, name = "24h Offline", icon = "⏰", price = 149, group = "boost", desc = "Your museum keeps earning for 24h offline (not 8h)." },
	{ key = "sell2", id = 0, name = "x2 Sell Price", icon = "🦴", price = 99, group = "boost", desc = "Bonnie pays you double for every fossil." },
	-- Per lluir
	{ key = "vip", id = 0, name = "VIP", icon = "⭐", price = 249, group = "vip", desc = "Golden VIP tag over your head and in chat, and +20% coins." },
}
Monetization.PASSES = PASSES

local PRODUCTS: { Product } = {
	{ key = "boost15", id = 0, name = "x2 Money · 15 min", icon = "⏱️", price = 29, boostMinutes = 15, desc = "Double coins for 15 minutes. Stacks time!" },
	{ key = "boost60", id = 0, name = "x2 Money · 1 hour", icon = "⏱️", price = 79, boostMinutes = 60, desc = "Double coins for a whole hour!" },
	{ key = "coinsS", id = 0, name = "Pile of Coins", icon = "$", price = 25, coinsMinutes = 30, desc = "30 minutes of your museum income, right now." },
	{ key = "coinsM", id = 0, name = "Bag of Coins", icon = "$", price = 99, coinsMinutes = 150, desc = "150 minutes of your museum income, right now." },
	{ key = "coinsL", id = 0, name = "Vault of Coins", icon = "🏦", price = 399, coinsMinutes = 720, desc = "12 HOURS of your museum income, right now!" },
}
Monetization.PRODUCTS = PRODUCTS

Monetization.VIP_BONUS = 1.2
Monetization.SPEED_MULT = 1.5
Monetization.FAST_DIG_MULT = 0.5 -- el temps entre excavacions es multiplica per això
Monetization.OFFLINE_MULT = 2
Monetization.OFFLINE_LONG_HOURS = 24
Monetization.SELL_MULT = 2
Monetization.COINS_MIN_RATE = 20 -- un paquet de monedes compta almenys aquesta renda/min

-- ─────────────────────────── DERIVATS ───────────────────────────
Monetization.PassByKey = {} :: { [string]: Pass }
Monetization.PassById = {} :: { [number]: Pass }
Monetization.ProductByKey = {} :: { [string]: Product }
Monetization.ProductById = {} :: { [number]: Product }
do
	for _, p in PASSES do
		assert(not Monetization.PassByKey[p.key], "passi repetit " .. p.key)
		Monetization.PassByKey[p.key] = p
		if p.id ~= 0 then
			Monetization.PassById[p.id] = p
		end
	end
	for _, p in PASSES do
		if p.requires then
			assert(Monetization.PassByKey[p.requires], `{p.key} demana {p.requires}, que no existeix`)
		end
	end
	for _, p in PRODUCTS do
		Monetization.ProductByKey[p.key] = p
		if p.id ~= 0 then
			Monetization.ProductById[p.id] = p
		end
	end
end

-- El multiplicador de sort dels passis (el més alt de la cadena)
function Monetization.LuckMultiplier(owned: { [string]: boolean }): number
	local best = 1
	for _, p in PASSES do
		if p.luck and owned[p.key] and p.luck > best then
			best = p.luck
		end
	end
	return best
end

-- El multiplicador de diners que dona el que tens (el més alt de la cadena,
-- el VIP i el boost temporal, tot multiplicat).
function Monetization.MoneyMultiplier(owned: { [string]: boolean }, boostUntil: number?): number
	local chain = 1
	for _, p in PASSES do
		if p.money and owned[p.key] and p.money > chain then
			chain = p.money
		end
	end
	local vip = if owned.vip then Monetization.VIP_BONUS else 1
	local boost = if boostUntil and boostUntil > os.time() then 2 else 1
	return chain * vip * boost
end

return Monetization
