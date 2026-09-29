--!strict

-- Museum — vitrines, renda i sostres.
--
-- A cada vitrina hi va UNA cosa: un fòssil sol ("Rat_Skull") o un esquelet
-- muntat ("Rat"). Un esquelet rendeix com les seves 5 peces x Bones.SKELETON_BONUS.
--
-- La renda es calcula SEMPRE al servidor a partir del que hi ha exposat al
-- perfil. Aquest mòdul és compartit només perquè la UI pugui ensenyar els
-- mateixos números; el client no en decideix cap.

local Bones = require(script.Parent.Bones)

local Museum = {}

Museum.SLOTS = 10 -- vitrines per museu (Slot1..Slot10 al mapa)
Museum.INCOME_CAP = 360000 -- monedes/minut màximes = 6.000 $/s (CLAUDE.md: renda amb sostre)
Museum.TICK = 1 -- cada quants segons s'acumula la renda en línia (es veu entrar cada segon)
Museum.PUSH_EVERY = 10 -- cada quants TICK s'envia el perfil sencer (els altres, només les monedes)
Museum.EXHIBIT_GAP = 0.3 -- aire entre el sòcol i la part més baixa de l'exhibició
Museum.SKELETON_MAX_SPAN = 7.4 -- un esquelet muntat ha de cabre dins el vidre
Museum.SKELETON_MAX_HEIGHT = 6
Museum.FOSSIL_MAX_SPAN = 4.2 -- un fòssil sol es veu gran però no toca el vidre
-- Rètol petit de sobre cada vitrina (nom, $/s i una frase): alçada des del
-- centre del sòcol (la tapa de vidre queda a ~8) i fins on es veu
Museum.INFO_HEIGHT = 9.3
Museum.INFO_DISTANCE = 55
Museum.EMPTY_PLAQUE = "EMPTY CASE"
Museum.FREE_SIGN = "FREE MUSEUM"

-- La renda es compta per minut (tota l'economia i tools/economy_sim.py),
-- però el jugador la veu per segon: "0.02", "1.5", "12.3", "100".
function Museum.PerSecondText(perMinute: number): string
	local s = perMinute / 60
	local text
	if s >= 100 then
		text = string.format("%d", math.floor(s + 0.5))
	elseif s >= 10 then
		text = string.format("%.1f", math.floor(s * 10 + 0.5) / 10)
	else
		text = string.format("%.2f", math.floor(s * 100 + 0.5) / 100)
	end
	-- fora els zeros sobrers darrere la coma ("1.50" -> "1.5", "2.00" -> "2")
	if string.find(text, ".", 1, true) then
		text = (text:gsub("0+$", ""))
		text = (text:gsub("%.$", ""))
	end
	return text
end

-- Un preu sencer amb separadors, per als missatges: 8000000 -> "8,000,000"
function Museum.MoneyText(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign, s = "-", string.sub(s, 2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return sign .. out
end

-- museumLayout: clau de vitrina ("1".."10") -> peça o esquelet exposat
function Museum.IncomeRate(museumLayout: { [string]: any }): number
	local rate = 0
	for slot = 1, Museum.SLOTS do
		rate += Bones.IncomeOf(museumLayout[tostring(slot)])
	end
	return math.min(rate, Museum.INCOME_CAP)
end

return Museum
