--!strict

-- Visitors — els visitants dels museus i les seves propines.
--
-- Mentre el museu té coses exposades i l'amo és al joc, hi entren visitants
-- que miren unes quantes vitrines. A cada vitrina que miren hi ha una
-- probabilitat de PROPINA (monedes extra, a part de la renda per minut).
--
-- PROBABILITATS (a cada vitrina que mira un visitant):
--   probabilitat = TIP_CHANCE[raresa] × (SKELETON_CHANCE si és un esquelet muntat)
--   propina      = renda/min d'aquella peça × uns minuts a l'atzar (TIP_MINUTES)
--                  × multiplicador de diners dels passis
--   1 de cada WOW_ODDS propines és un "WOW!" i val WOW_MULT vegades més.
-- Com més rars els fòssils, més propines i més grosses: val la pena exposar
-- el millor. Balanç: amb el museu ple, les propines sumen més o menys un
-- +25% a la renda (ho pots comprovar amb Visitors.ExpectedBonus).

local Visitors = {}

Visitors.TIP_CHANCE = {
	Common = 0.008,
	Uncommon = 0.01,
	Rare = 0.013,
	Epic = 0.018,
	Legendary = 0.028,
	Mythic = 0.04,
	Secret = 0.06,
} :: { [string]: number }
Visitors.SKELETON_CHANCE = 1.5 -- un esquelet sencer crida més l'atenció
Visitors.TIP_MINUTES = { 2, 5 } -- la propina val entre 2 i 5 minuts de renda d'aquella peça
Visitors.WOW_ODDS = 40
Visitors.WOW_MULT = 5
Visitors.MIN_TIP = 1

-- Quants i cada quan
Visitors.MAX_ACTIVE = 5 -- visitants alhora en un museu
Visitors.ARRIVE_MIN = 7 -- segons entre visitants amb el museu ple
Visitors.ARRIVE_MAX = 25 -- ... i amb una sola vitrina plena
Visitors.STOPS = { 3, 5 } -- vitrines que mira cada visitant
Visitors.LOOK_TIME = { 3.5, 6.5 } -- segons davant de cada vitrina
Visitors.WALK_SPEED = 6 -- studs/s (passejant)
Visitors.TIP_AT = 1.5 -- segons després d'aturar-se davant la vitrina, surt la propina

-- Segons entre arribades segons quantes vitrines tenen alguna cosa
function Visitors.ArriveEvery(filled: number, slots: number): number
	local t = math.clamp((filled - 1) / math.max(1, slots - 1), 0, 1)
	return Visitors.ARRIVE_MAX + (Visitors.ARRIVE_MIN - Visitors.ARRIVE_MAX) * t
end

-- Bonus aproximat de les propines, en fracció de la renda (per balancejar)
function Visitors.ExpectedBonus(avgChance: number, filled: number, slots: number): number
	local perMin = 60 / Visitors.ArriveEvery(filled, slots)
	local stops = (Visitors.STOPS[1] + Visitors.STOPS[2]) / 2
	local minutes = (Visitors.TIP_MINUTES[1] + Visitors.TIP_MINUTES[2]) / 2
	local wow = 1 + (Visitors.WOW_MULT - 1) / Visitors.WOW_ODDS
	-- cada propina val "minutes" de la renda d'UNA peça ≈ renda / filled
	return perMin * stops * avgChance * minutes * wow / math.max(1, filled)
end

return Visitors
