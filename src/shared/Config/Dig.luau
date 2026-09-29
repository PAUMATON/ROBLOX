--!strict

-- Dig — els numeros del minijoc d'excavacio.
--
-- La linia de la barra fa una ona triangular DETERMINISTA a partir d'un
-- instant d'inici que posa el servidor. El client la dibuixa; el servidor
-- la torna a calcular amb el seu rellotge quan li arriba el clic. Cap dels
-- dos es fia de l'altre: el client no envia mai on era la linia.

local Constants = require(script.Parent.Constants)
local Bones = require(script.Parent.Bones)

local Dig = {}

-- L'eina de cavar es reconeix per aquest atribut (cada eina té el seu nom)
Dig.TOOL_ATTRIBUTE = "DigTool"

Dig.ATTEMPTS = 3
Dig.SPEED = 0.9 -- anada i tornada = 2 / SPEED segons
Dig.PERFECT_HALF = 0.08 -- mig ample de la franja verd fort (escala -1..1)
Dig.GOOD_HALF = 0.26 -- mig ample de la franja verd fluix
Dig.PERFECT_BONUS = 50 -- % de sort per clic perfecte
Dig.GOOD_BONUS = 30
Dig.MIN_CLICK_INTERVAL = 0.12 -- clics mes seguits que aixo s'ignoren
-- Perquè no sigui estàtic: després de cada cop la franja verda salta a un
-- altre lloc, la línia torna a sortir de l'esquerra i va una mica més ràpid.
Dig.BAND_CENTER_MAX = 0.55 -- on pot anar el centre de la franja (-0.55 .. 0.55)
Dig.SPEED_UP = 0.18 -- +18% de velocitat a cada intent
Dig.RESTART_DELAY = 0.35 -- pausa entre un cop i el següent
Dig.SESSION_TIMEOUT = 20 -- una excavacio sense acabar es tanca sola

-- Un munt excavat queda buit una estona: obliga a moure's per l'obra i
-- fa que el mapa es vegi viu. Es per munt, no per jugador.
Dig.RESPAWN_TIME = 20

-- MUNT DAURAT (esdeveniment): cada GOLDEN_EVERY segons (a l'atzar entre els
-- dos), un munt a l'atzar brilla GOLDEN_TIME segons. Qui l'excava té x3 de
-- sort (dins del sostre), x3 de monedes i una poció de regal. Ho avisa a tot
-- el servidor.
Dig.GOLDEN_EVERY = { 240, 420 }
Dig.GOLDEN_TIME = 120
Dig.GOLDEN_LUCK = 3
Dig.GOLDEN_COINS = 3
Dig.GOLDEN_POTION = "super"
Dig.DEPLETED_SCALE = 0.35 -- mida del munt buit respecte de l'original
Dig.PROMPT_DISTANCE = 11 -- des d'on surt el boto "Dig" (mobil i teclat)

-- Compensacio de latencia: el clic arriba al servidor un tros tard, i la
-- linia ja s'ha mogut. El servidor ho corregeix amb el ping que MESURA ELL
-- (el client no hi diu res), i amb sostre perque un ping inflat no doni
-- marge per triar posicio.
Dig.MAX_LAG_COMPENSATION = 0.25
-- El client diu QUAN ha clicat (en temps del servidor). El servidor només
-- s'ho creu si és a prop del que ell calcula amb el ping que mesura: marge
-- de CLICK_TIME_SLACK segons. Així el lag no fa trampes al jugador, i un
-- tramposo no pot triar el moment que vulgui.
Dig.CLICK_TIME_SLACK = 0.07

-- Posicio de la linia (-1..1) als `elapsed` segons de l'inici.
function Dig.MarkerAt(elapsed: number, speed: number?): number
	if elapsed < 0 then
		return -1 -- encara no ha sortit (pausa entre cops)
	end
	local p = (elapsed * (speed or Dig.SPEED)) % 2
	if p < 1 then
		return p * 2 - 1
	end
	return 3 - p * 2
end

-- Mig ample de les franges. Són iguals per a tothom: l'eina no toca el
-- minijoc, només la sort (Config/Tools).
function Dig.Bands(): (number, number)
	return Dig.PERFECT_HALF, Dig.GOOD_HALF
end

function Dig.ScoreFor(pos: number, center: number?): number
	local perfect, good = Dig.Bands()
	local d = math.abs(pos - (center or 0))
	if d <= perfect then
		return Dig.PERFECT_BONUS
	elseif d <= good then
		return Dig.GOOD_BONUS
	end
	return 0
end

-- Velocitat de l'intent número `attempt` (1, 2, 3...)
function Dig.SpeedFor(attempt: number): number
	return Dig.SPEED * (1 + Dig.SPEED_UP * (attempt - 1))
end

-- Monedes d'una excavació: les de la zona, amb el bonus del minijoc
-- (fins a x2.5 amb tres clics perfectes). Els multiplicadors de diners de
-- la Fase 5 s'aplicaran aquí.
function Dig.CoinsFor(coinsPerDig: number, bonus: number): number
	return math.floor(coinsPerDig * (1 + bonus / 100))
end

-- La sort surt de dos llocs que es multipliquen:
--   · el minijoc: ara x1 sempre (MINIGAME_MAX_LUCK); només dona monedes;
--   · la paleta equipada (Config/Tools): de x1 a x3.
-- La millor paleta = x3 just: el sostre del CLAUDE.md.
-- `extra` serà el dels passis de sort (Fase 5); el sostre x3 s'aplica al
-- producte de tot, no a cada part.
Dig.MINIGAME_MAX_LUCK = 1 -- el minijoc ja no dona sort (només monedes): tota surt de la paleta

function Dig.MinigameLuck(bonus: number): number
	local best = Dig.ATTEMPTS * Dig.PERFECT_BONUS
	return 1 + math.clamp(bonus / best, 0, 1) * (Dig.MINIGAME_MAX_LUCK - 1)
end

function Dig.LuckMultiplier(bonus: number, toolLuck: number?, extra: number?): number
	return math.clamp(Dig.MinigameLuck(bonus) * (toolLuck or 1) * (extra or 1), 1, Constants.MAX_LUCK)
end

-- Probabilitat de cada raresa amb aquesta sort (només les que hi ha a la
-- zona, `present`). Es tira de la més rara cap avall: 1 de cada N/sort.
function Dig.RarityChances(luck: number, present: { [string]: any }?): { [string]: number }
	local out = {}
	local left = 1
	local from = Bones.RARITY_ORDER[Bones.LUCKY_FROM]
	local lowest: string? = nil
	for i = #Bones.RARITIES, 1, -1 do
		local rarity = Bones.RARITIES[i]
		if not present or present[rarity] then
			lowest = rarity
			local n = Bones.RARITY_ODDS[rarity]
			if n then
				local l = if Bones.RARITY_ORDER[rarity] >= from then luck else 1
				local p = math.min(l / n, Bones.MAX_CHANCE)
				out[rarity] = left * p
				left -= left * p
			end
		end
	end
	-- el que queda és per a la més comuna de la zona
	if lowest then
		out[lowest] = (out[lowest] or 0) + left
	end
	return out
end

return Dig
