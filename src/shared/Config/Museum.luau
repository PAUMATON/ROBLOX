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
Museum.INCOME_CAP = 6000 -- monedes/minut màximes (CLAUDE.md: renda amb sostre)
Museum.TICK = 10 -- cada quants segons s'acumula la renda en línia
Museum.EXHIBIT_GAP = 0.3 -- aire entre el sòcol i la part més baixa de l'exhibició
Museum.SKELETON_MAX_SPAN = 7.4 -- un esquelet muntat ha de cabre dins el vidre
Museum.SKELETON_MAX_HEIGHT = 6
Museum.FOSSIL_MAX_SPAN = 4.2 -- un fòssil sol es veu gran però no toca el vidre
Museum.EMPTY_PLAQUE = "EMPTY CASE"
Museum.FREE_SIGN = "FREE MUSEUM"

-- museumLayout: clau de vitrina ("1".."10") -> peça o esquelet exposat
function Museum.IncomeRate(museumLayout: { [string]: any }): number
	local rate = 0
	for slot = 1, Museum.SLOTS do
		rate += Bones.IncomeOf(museumLayout[tostring(slot)])
	end
	return math.min(rate, Museum.INCOME_CAP)
end

return Museum
