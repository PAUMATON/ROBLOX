--!strict

-- Quests — la cadena de missions que es veu a dalt (el "quest tracker").
-- Una missió a la vegada: quan la compleixes, la cobres i surt la següent.
-- Quan s'acaba la cadena, en surten de repetibles (ENDLESS) per sempre.
--
-- COM ES COMPTEN: res d'esdeveniments que es puguin perdre ni falsejar. Cada
-- missió mira un número del perfil (Quests.Value). Les de `delta` compten
-- des que comença la missió: en començar-la, el servidor en guarda el valor
-- d'aquell moment (`base`) i el progrés és la diferència. Les altres miren
-- l'estat actual (vitrines plenes, eines, zones...). Tot ho calcula el
-- servidor a partir del perfil.
--
-- Els premis són en minuts de renda de museu (Rewards.CoinsFor), com les
-- recompenses diàries: valen el mateix al principi que al final del joc.

local Bones = require(script.Parent.Bones)
local Museum = require(script.Parent.Museum)

local Quests = {}

export type Quest = {
	text: string, -- el que veu el jugador (anglès)
	stat: string, -- què es mira (Quests.Value)
	arg: string?, -- per a "finds": la raresa mínima
	target: number,
	delta: boolean, -- true: compta des que comença · false: valor actual
	reward: { kind: string, minutes: number, label: string, icon: string },
	-- on s'ha d'anar (el client hi apunta amb el raig de llum o la rajola):
	-- "construction" | "beach" | "egypt" | "shop" | "seller" | "backpack" | "trade" | "store"
	go: string?,
}

local function coins(minutes: number)
	return { kind = "coins", minutes = minutes, label = "Coins", icon = "$" }
end
local function luck(minutes: number)
	return { kind = "luck", minutes = minutes, label = `x2 Luck {minutes}m`, icon = "🍀" }
end
local function money(minutes: number)
	return { kind = "money", minutes = minutes, label = `x2 Money {minutes}m`, icon = "$" }
end

-- La cadena: ensenya el joc pas a pas (el tutorial fa els 3 primers passos
-- i això en continua) i va pujant fins als objectius llargs.
local CHAIN: { Quest } = {
	{ text = "Dig 5 fossils", stat = "digs", target = 5, delta = true, reward = coins(5), go = "construction" },
	{ text = "Show 2 fossils in your museum", stat = "displayed", target = 2, delta = false, reward = coins(5), go = "backpack" },
	{ text = "Find an Uncommon fossil", stat = "finds", arg = "Uncommon", target = 1, delta = true, reward = coins(8), go = "construction" },
	{ text = "Sell 3 fossils to Bonnie", stat = "sold", target = 3, delta = true, reward = coins(8), go = "seller" },
	{ text = "Buy a better trowel at Dig & Co.", stat = "tools", target = 2, delta = false, reward = luck(10), go = "shop" },
	{ text = "Dig 25 fossils", stat = "digs", target = 25, delta = true, reward = coins(12), go = "construction" },
	{ text = "Fill 5 museum cases", stat = "displayed", target = 5, delta = false, reward = coins(12), go = "backpack" },
	{ text = "Find a Rare fossil", stat = "finds", arg = "Rare", target = 1, delta = true, reward = coins(15), go = "construction" },
	{ text = "Discover 12 different fossils", stat = "discovered", target = 12, delta = false, reward = money(15), go = "construction" },
	{ text = "Build your first full skeleton", stat = "built", target = 1, delta = false, reward = coins(20), go = "backpack" },
	{ text = `Make your museum earn {Museum.PerSecondText(2400)} $/s`, stat = "income", target = 2400, delta = false, reward = coins(20), go = "backpack" },
	{ text = "Trade with another player", stat = "trades", target = 1, delta = true, reward = luck(15), go = "trade" },
	{ text = "Dig 75 fossils", stat = "digs", target = 75, delta = true, reward = coins(25), go = "construction" },
	{ text = "Fill all 10 museum cases", stat = "displayed", target = 10, delta = false, reward = coins(25), go = "backpack" },
	{ text = "Find an Epic fossil", stat = "finds", arg = "Epic", target = 1, delta = true, reward = coins(30), go = "construction" },
	{ text = "Buy the Pro Trowel", stat = "tools", target = 3, delta = false, reward = luck(20), go = "shop" },
	{ text = "Discover 25 different fossils", stat = "discovered", target = 25, delta = false, reward = money(20), go = "construction" },
	{ text = "Build 3 full skeletons", stat = "built", target = 3, delta = false, reward = coins(40), go = "backpack" },
	{ text = "Unlock Fossil Beach", stat = "zones", target = 2, delta = false, reward = coins(40), go = "beach" },
	{ text = `Make your museum earn {Museum.PerSecondText(12000)} $/s`, stat = "income", target = 12000, delta = false, reward = coins(45), go = "backpack" },
	{ text = "Find a Legendary fossil", stat = "finds", arg = "Legendary", target = 1, delta = true, reward = luck(30), go = "construction" },
	{ text = "Sell 50 fossils to Bonnie", stat = "sold", target = 50, delta = true, reward = coins(50), go = "seller" },
	{ text = "Fly to Egypt and unlock it", stat = "zones", target = 3, delta = false, reward = luck(30), go = "egypt" },
	{ text = "Discover every fossil in the Index", stat = "discovered", target = #Bones.ALL_KEYS, delta = false, reward = money(60), go = "construction" },
}
Quests.CHAIN = CHAIN

-- Repetibles, en roda, quan s'acaba la cadena
local ENDLESS: { Quest } = {
	{ text = "Dig 100 fossils", stat = "digs", target = 100, delta = true, reward = coins(30), go = "construction" },
	{ text = "Find an Epic fossil", stat = "finds", arg = "Epic", target = 1, delta = true, reward = luck(15), go = "construction" },
	{ text = "Sell 30 fossils to Bonnie", stat = "sold", target = 30, delta = true, reward = coins(25), go = "seller" },
	{ text = "Find a Legendary fossil", stat = "finds", arg = "Legendary", target = 1, delta = true, reward = money(30), go = "construction" },
}

-- La missió número `index` (1..): de la cadena o de les repetibles
function Quests.Get(index: number): Quest
	if index <= #CHAIN then
		return CHAIN[index]
	end
	return ENDLESS[(index - #CHAIN - 1) % #ENDLESS + 1]
end

-- Peces trobades excavant d'aquesta raresa o millor (no compten les de regal)
local function findsAtLeast(finds: { [string]: number }?, rarity: string): number
	local from = Bones.RARITY_ORDER[rarity] or 1
	local n = 0
	for r, count in finds or {} do
		if (Bones.RARITY_ORDER[r] or 0) >= from and type(count) == "number" then
			n += count
		end
	end
	return n
end

-- El número del perfil que mira cada tipus de missió
function Quests.Value(profile: any, quest: Quest): number
	local stats = profile.stats or {}
	local stat = quest.stat
	if stat == "digs" then
		return stats.totalDigs or 0
	elseif stat == "finds" then
		return findsAtLeast(stats.rarityFinds, quest.arg or "Common")
	elseif stat == "sold" then
		return stats.totalSold or 0
	elseif stat == "trades" then
		return stats.totalTrades or 0
	elseif stat == "built" then
		return stats.totalAssembled or 0
	elseif stat == "tools" then
		return #(profile.ownedTools or {})
	elseif stat == "zones" then
		return #(profile.unlockedZones or {})
	elseif stat == "income" then
		return Museum.IncomeRate(profile.museumLayout or {})
	elseif stat == "displayed" then
		local n = 0
		for _, item in profile.museumLayout or {} do
			if type(item) == "string" then
				n += 1
			end
		end
		return n
	elseif stat == "discovered" then
		local n = 0
		for key in profile.discovered or {} do
			if Bones.IsPieceKey(key) then
				n += 1
			end
		end
		return n
	end
	return 0
end

-- (progrés, objectiu): el progrés ja porta restada la base i té sostre
function Quests.Progress(profile: any, quest: Quest, base: number?): (number, number)
	local value = Quests.Value(profile, quest)
	local p = if quest.delta then value - (base or value) else value
	return math.clamp(math.floor(p), 0, quest.target), quest.target
end

return Quests
