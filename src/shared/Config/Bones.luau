--!strict

-- Bones — quins fòssils hi ha, de quin esquelet són i quina raresa tenen.
--
-- COM FUNCIONA (CLAUDE.md > Joc):
--   · Cada excavació dona UN fòssil (una peça d'un esquelet).
--   · Cada esquelet té UNA raresa i les seves 5 peces tenen aquesta raresa.
--   · Dins d'una mateixa raresa, TOTES les peces són igual de probables.
--     No hi ha "pietat": si tens 3 peces del T-Rex, les 2 que et falten
--     surten igual de sovint que qualsevol altra peça Secret.
--   · Un fòssil sol ja es pot exposar al museu. Si reuneixes TOTES les
--     peces d'un esquelet (de 5 a 8, segons l'esquelet: `pieces`), el pots
--     muntar i rendeix la suma de les peces x SKELETON_BONUS (x5).
--
-- Una peça es desa al perfil amb la clau "<esquelet>_<peça>#<estat>", p.ex.
-- "Rat_Skull#4" (una peça Clean). L'esquelet muntat, "<esquelet>#<estats>"
-- amb un dígit per peça en l'ordre de PiecesOf, p.ex. "Rat#34425". La part
-- de davant ("Rat_Skull", "Rat") és la clau de BASE: l'índex, les
-- probabilitats i els models van per la base. No canviïs mai les claus
-- d'un esquelet ja publicat.
-- La zona de cada esquelet la diu Zones.luau (Regla de zones).

local Bones = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type Kind = "mammal" | "bird" | "theropod"

export type PieceDef = {
	id: string,
}

export type SkeletonDef = {
	id: string,
	name: string,
	icon: string, -- emoji per a la UI
	rarity: Rarity,
	kind: Kind,
	-- Forma del model (parts bàsiques: el pla B del CLAUDE.md)
	s: number, -- escala del model
	snout: number?, -- llargada del morro (mamífers)
	ribs: number?, -- parells de costelles (mamífers)
	tailLen: number?, -- llargada de la cua (mamífers)
	tailSegs: number?, -- vèrtebres de la cua (mamífers)
	fangs: number?, -- ullals de sabre (mamífers)
	beak: number?, -- bec gros (ocells)
	stocky: boolean?, -- ocell rodanxó que no vola (dodo)
	-- Només els esquelets de raresa molt alta poden sortir a més d'una zona
	-- (Regla de zones). Zones.luau ho comprova.
	multiZone: boolean?,
	-- Quantes peces té (5..8). Les 5 de base i, per sobre, les d'EXTRA_PIECES
	-- del seu tipus per ordre. Com més alta la raresa, més peces.
	pieces: number?,
}

export type PieceInfo = {
	key: string,
	skeleton: string,
	piece: string,
	rarity: Rarity,
}

-- ─────────────────────────── RARESES ───────────────────────────

local RARITIES: { Rarity } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
Bones.RARITIES = RARITIES

-- "1 de cada N" de cada raresa, sense sort. Es tira de la més rara cap
-- avall: la primera que surt guanya; si no en surt cap, Common.
-- La sort DIVIDEIX la N (de Rare cap amunt). 29/09/2026: les paletes van
-- fins a x20 i el sostre és x640, i per això Legendary, Mythic i Secret
-- tenen la N més alta (Rare i Epic no: el principi del joc no canvia).
-- Secret: 1 de cada 100.000 sense sort, ~5.000 amb la millor paleta
-- (x20) i ~156 amb el sostre (x640). Mythic: 1 de cada 20.000, 1.000 i 31.
-- Balancejat amb tools/economy_sim.py.
local RARITY_ODDS: { [string]: number } = {
	Uncommon = 4,
	Rare = 15,
	Epic = 80,
	Legendary = 1500,
	Mythic = 20000,
	Secret = 100000,
}
Bones.RARITY_ODDS = RARITY_ODDS
Bones.MAX_CHANCE = 0.9 -- cap raresa passa del 90% encara que la sort sigui enorme

-- A partir d'aquesta raresa la sort divideix la N
Bones.LUCKY_FROM = "Rare"

local RARITY_NAMES: { [string]: string } = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
	Secret = "Secret",
}
Bones.RARITY_NAMES = RARITY_NAMES

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(176, 186, 204),
	Uncommon = Color3.fromRGB(86, 210, 110),
	Rare = Color3.fromRGB(56, 148, 255),
	Epic = Color3.fromRGB(190, 78, 255),
	Legendary = Color3.fromRGB(255, 190, 30),
	Mythic = Color3.fromRGB(255, 64, 110),
	Secret = Color3.fromRGB(40, 36, 52),
}
Bones.RARITY_COLORS = RARITY_COLORS

-- Monedes per minut d'UN fòssil exposat sol al museu. El jugador les veu
-- per SEGON (Museum.PerSecondText): un Common fa 60/min = 1 $/s.
-- (29/09/2026: TOTS els diners del joc x60 alhora, perquè el que abans
-- donava 1 per minut en doni 1 per segon; el ritme del joc és el mateix)
local PIECE_INCOME: { [string]: number } = {
	Common = 60,
	Uncommon = 120,
	Rare = 240,
	Epic = 600,
	Legendary = 1500,
	Mythic = 4200,
	Secret = 12000,
}
Bones.PIECE_INCOME = PIECE_INCOME

-- Un esquelet muntat rendeix com TOTES les seves peces soltes sumades,
-- multiplicat per això (29/09/2026: x5, decisió del propietari)
Bones.SKELETON_BONUS = 5

-- ─────────────────────────── ESTAT ───────────────────────────
-- Cada fòssil surt de terra en un de 7 estats, del pitjor al millor. Els
-- multiplicadors pugen cada cop més (+0,2, +0,3, +0,4 … +0,7): cada graó
-- val més que l'anterior. L'estat
-- multiplica el que rendeix al museu i el que en paga la Bonnie.
--   · Com més RARA la peça, més fàcil que surti malmesa (és més antiga).
--   · Com millor la PALETA (la seva sort), més fàcil que surti neta. Només
--     la paleta: ni els passis de sort ni les pocions hi compten.
-- Fórmula (GradeChances): pes_i = BASE_i · e^(inclinació · (i − 3,5)) amb
-- inclinació = 0,8·t − 0,8·r + 0,1, t = ln(sort paleta)/ln(20) (0 → 1) i
-- r = (ordre de raresa − 1)/6 (0 → 1).
-- Mitjana del multiplicador (tools/economy_sim.py): Common amb la Rusty
-- x1,35 i amb la Pharaoh's x2,28; Secret x0,81 → x1,35. Els perfils vells
-- passen tots a Dusty (x1): ningú no hi perd.
export type Grade = {
	id: string,
	name: string,
	mult: number,
	color: Color3,
	weight: number,
}
local GRADES: { Grade } = {
	{ id = "Crushed", name = "Crushed", mult = 0.5, color = Color3.fromRGB(122, 92, 70), weight = 10 },
	{ id = "Cracked", name = "Cracked", mult = 0.7, color = Color3.fromRGB(190, 120, 70), weight = 18 },
	{ id = "Dusty", name = "Dusty", mult = 1, color = Color3.fromRGB(205, 186, 150), weight = 30 },
	{ id = "Clean", name = "Clean", mult = 1.4, color = Color3.fromRGB(120, 210, 90), weight = 20 },
	{ id = "Polished", name = "Polished", mult = 1.9, color = Color3.fromRGB(70, 160, 255), weight = 12 },
	{ id = "Mint", name = "Mint", mult = 2.5, color = Color3.fromRGB(80, 240, 200), weight = 7 },
	{ id = "Pristine", name = "Pristine", mult = 3.2, color = Color3.fromRGB(255, 120, 230), weight = 3 },
}
Bones.GRADES = GRADES
Bones.DEFAULT_GRADE = 3 -- Dusty: el de les peces d'abans que hi hagués estat
Bones.GRADE_TILT_TOOL = 0.8
Bones.GRADE_TILT_RARITY = 0.8
Bones.GRADE_TILT_BASE = 0.1
Bones.GRADE_TOOL_TOP = 20 -- la sort de paleta que val t = 1 (la Pharaoh's)
-- Esquelet muntat: bonus de conjunt segons la peça PITJOR (la baula feble):
-- +10% per cada estat per sobre de Crushed (Crushed +0% … Pristine +60%).
-- Així val la pena canviar (comerç) o tornar a excavar una sola peça bruta.
Bones.SET_BONUS_STEP = 0.1

-- Ordre de cada raresa (per ordenar: 1 = Common)
Bones.RARITY_ORDER = {} :: { [string]: number }
for i, r in RARITIES do
	Bones.RARITY_ORDER[r] = i
end

-- ─────────────────────────── PECES ───────────────────────────

-- Les 5 peces de base, que tenen tots els esquelets
local PIECES: { PieceDef } = {
	{ id = "Skull" },
	{ id = "Spine" },
	{ id = "ForeLimbs" },
	{ id = "HindLimbs" },
	{ id = "Tail" },
}
Bones.PIECES = PIECES

-- Les peces de més (fins a 8 en total), per ordre, segons el tipus. Surten
-- de partir una peça de base (BoneBuilder): la caixa toràcica surt de la
-- columna, la pelvis de les potes del darrere, la mandíbula del crani i el
-- coll de la columna. Muntat, l'esquelet es veu igual de sencer.
local EXTRA_PIECES: { [string]: { string } } = {
	mammal = { "Ribs", "Pelvis", "Jaw" },
	bird = { "Ribs", "Pelvis", "Neck" },
	theropod = { "Ribs", "Pelvis", "Jaw" },
}
Bones.EXTRA_PIECES = EXTRA_PIECES

local PIECE_NAMES: { [string]: { [string]: string } } = {
	mammal = {
		Skull = "Skull",
		Spine = "Spine & Ribs",
		ForeLimbs = "Front Legs",
		HindLimbs = "Hind Legs",
		Tail = "Tail",
		Ribs = "Ribcage",
		Pelvis = "Pelvis",
		Jaw = "Jaw",
	},
	bird = {
		Skull = "Skull & Beak",
		Spine = "Spine & Keel",
		ForeLimbs = "Wings",
		HindLimbs = "Legs",
		Tail = "Tail Fan",
		Ribs = "Ribcage & Keel",
		Pelvis = "Pelvis",
		Neck = "Neck",
	},
	theropod = {
		Skull = "Skull",
		Spine = "Spine & Ribs",
		ForeLimbs = "Tiny Arms",
		HindLimbs = "Legs",
		Tail = "Tail",
		Ribs = "Ribcage",
		Pelvis = "Pelvis",
		Jaw = "Jaw",
	},
}
Bones.PIECE_NAMES = PIECE_NAMES

-- Icones de la UI (emoji: no cal pujar imatges)
local PIECE_ICONS: { [string]: string } = {
	Skull = "💀",
	Spine = "🦴",
	ForeLimbs = "🦴",
	HindLimbs = "🦴",
	Tail = "🦴",
	Ribs = "🦴",
	Pelvis = "🦴",
	Jaw = "💀",
	Neck = "🦴",
}
Bones.PIECE_ICONS = PIECE_ICONS

-- ────────────────────────── ESQUELETS ──────────────────────────

-- Zona 1 · Construction Site: un esquelet per raresa, dels animals de ciutat
-- fins als extingits. Zona 2 · Fossil Beach: animals de costa.
-- Zona 3 · Egypt (illa, només en avió): animals del Nil, de Rare a Mythic.
local SKELETONS: { SkeletonDef } = {
	{ id = "Rat", icon = "🐀", name = "Rat", rarity = "Common", kind = "mammal", s = 0.5, snout = 0.9, ribs = 5, tailLen = 2.2, tailSegs = 16, pieces = 5 },
	{ id = "Pigeon", icon = "🐦", name = "Pigeon", rarity = "Uncommon", kind = "bird", s = 0.7, pieces = 5 },
	{ id = "Cat", icon = "🐈", name = "Cat", rarity = "Rare", kind = "mammal", s = 1, snout = 0.45, ribs = 6, pieces = 6 },
	{ id = "Dog", icon = "🐕", name = "Dog", rarity = "Epic", kind = "mammal", s = 1.5, snout = 0.9, ribs = 7, pieces = 6 },
	{ id = "Dodo", icon = "🦤", name = "Dodo", rarity = "Legendary", kind = "bird", s = 1.1, beak = 1.8, stocky = true, pieces = 7 },
	{ id = "Sabertooth", icon = "🐅", name = "Sabertooth", rarity = "Mythic", kind = "mammal", s = 1.7, snout = 0.5, ribs = 8, fangs = 1, tailLen = 0.8, pieces = 8 },
	{ id = "TRex", icon = "🦖", name = "T-Rex", rarity = "Secret", kind = "theropod", s = 1, pieces = 8 },

	{ id = "Seagull", icon = "🕊️", name = "Seagull", rarity = "Uncommon", kind = "bird", s = 0.9, pieces = 5 },
	{ id = "Otter", icon = "🦦", name = "Otter", rarity = "Rare", kind = "mammal", s = 0.9, snout = 0.35, ribs = 8, tailLen = 1.9, tailSegs = 14, pieces = 6 },
	{ id = "Cormorant", icon = "🦆", name = "Cormorant", rarity = "Epic", kind = "bird", s = 1.2, pieces = 7 },

	{ id = "Ibis", icon = "🦩", name = "Sacred Ibis", rarity = "Rare", kind = "bird", s = 1, beak = 1.6, pieces = 6 },
	{ id = "Jackal", icon = "🐺", name = "Jackal", rarity = "Epic", kind = "mammal", s = 1.2, snout = 0.85, ribs = 6, tailLen = 1.4, pieces = 7 },
	{ id = "Camel", icon = "🐪", name = "Camel", rarity = "Legendary", kind = "mammal", s = 1.9, snout = 0.7, ribs = 8, tailLen = 0.7, pieces = 7 },
	{ id = "Crocodile", icon = "🐊", name = "Nile Crocodile", rarity = "Mythic", kind = "mammal", s = 1.5, snout = 1.7, ribs = 9, tailLen = 3, tailSegs = 20, pieces = 8 },
}
Bones.SKELETONS = SKELETONS

-- ────────────────────────── DERIVATS ──────────────────────────
-- Es calculen un sol cop en carregar. Ningú no els ha d'escriure a mà.

Bones.ById = {} :: { [string]: SkeletonDef }
Bones.PiecesById = {} :: { [string]: { PieceDef } } -- esquelet -> les seves peces
Bones.PieceInfo = {} :: { [string]: PieceInfo } -- clau de peça -> info
Bones.ALL_KEYS = {} :: { string } -- totes les peces, en ordre (per a l'índex)

-- Les taules de base també responen a una clau amb estat: PieceInfo["Rat_Skull#4"]
-- és la info de "Rat_Skull" i ById["Rat#34425"] la definició del Rat. Així
-- tot el que només vol saber l'esquelet, la peça o la raresa funciona igual
-- amb un objecte de la motxilla. Per VALIDAR, IsPieceKey / IsSkeletonItem.
local function baseIndex(t: any, k: any): any
	if type(k) == "string" then
		local base = string.match(k, "^([^#]+)#")
		if base then
			return rawget(t, base)
		end
	end
	return nil
end
setmetatable(Bones.ById :: any, { __index = baseIndex })
setmetatable(Bones.PieceInfo :: any, { __index = baseIndex })

function Bones.PieceKey(skeletonId: string, pieceId: string): string
	return `{skeletonId}_{pieceId}`
end

do
	for _, def in SKELETONS do
		if Bones.ById[def.id] then
			error(`[Bones] esquelet repetit: {def.id}`, 0)
		end
		if not Bones.RARITY_ORDER[def.rarity] then
			error(`[Bones] {def.id}: raresa desconeguda {def.rarity}`, 0)
		end
		if not PIECE_NAMES[def.kind] then
			error(`[Bones] {def.id}: tipus desconegut {def.kind}`, 0)
		end
		Bones.ById[def.id] = def
		local n = def.pieces or #PIECES
		local extras = EXTRA_PIECES[def.kind]
		if n < #PIECES or n > #PIECES + #extras then
			error(`[Bones] {def.id}: ha de tenir de {#PIECES} a {#PIECES + #extras} peces`, 0)
		end
		local list: { PieceDef } = table.clone(PIECES)
		for i = 1, n - #PIECES do
			table.insert(list, { id = extras[i] })
		end
		Bones.PiecesById[def.id] = list
		for _, piece in list do
			local key = Bones.PieceKey(def.id, piece.id)
			Bones.PieceInfo[key] = {
				key = key,
				skeleton = def.id,
				piece = piece.id,
				rarity = def.rarity,
			}
			table.insert(Bones.ALL_KEYS, key)
		end
	end
end

-- ─────────────────────────── AJUDES ───────────────────────────

-- Les peces d'un esquelet (de 5 a 8); si no existeix, cap
function Bones.PiecesOf(skeletonId: string): { PieceDef }
	return Bones.PiecesById[skeletonId] or {}
end

-- Aquest esquelet té aquesta peça? (BoneBuilder: parteix o no les de base)
function Bones.HasPiece(def: SkeletonDef, pieceId: string): boolean
	for _, piece in Bones.PiecesById[def.id] or PIECES do
		if piece.id == pieceId then
			return true
		end
	end
	return false
end

-- ─────────────────────── CLAUS AMB ESTAT ───────────────────────

-- "Rat_Skull#4" -> "Rat_Skull", "4" · "Rat" -> "Rat", nil
local function split(item: string): (string, string?)
	local base, tail = string.match(item, "^([^#]+)#(%d+)$")
	if base then
		return base, tail
	end
	return item, nil
end

-- La clau de base (sense estat)
function Bones.BaseOf(item: string): string
	return (split(item))
end

-- Una peça de la motxilla: la base amb un estat (1..7)
function Bones.PieceItem(baseKey: string, grade: number): string
	return `{baseKey}#{grade}`
end

-- Un esquelet muntat: l'id amb l'estat de cada peça (en l'ordre de PiecesOf)
function Bones.SkeletonItem(skeletonId: string, grades: { number }): string
	return `{skeletonId}#{table.concat(grades)}`
end

local function validGrade(n: number?): boolean
	return n ~= nil and n >= 1 and n <= #GRADES and n == math.floor(n)
end

-- Estat d'una peça (sense estat = Dusty)
function Bones.GradeOf(item: string): number
	local _, tail = split(item)
	local n = tonumber(tail)
	return if tail and #tail == 1 and validGrade(n) then n :: number else Bones.DEFAULT_GRADE
end

-- Estat de cada peça d'un esquelet muntat (sense estats = totes Dusty)
function Bones.GradesOf(item: string): { number }
	local base, tail = split(item)
	local out = {}
	for i = 1, #Bones.PiecesOf(base) do
		local n = if tail then tonumber(string.sub(tail, i, i)) else nil
		out[i] = if validGrade(n) then n :: number else Bones.DEFAULT_GRADE
	end
	return out
end

function Bones.GradeDef(grade: number): Grade
	return GRADES[grade] or GRADES[Bones.DEFAULT_GRADE]
end

-- Una clau de BASE de peça ("Rat_Skull"): l'índex i les missions de descobrir
function Bones.IsBaseKey(key: any): boolean
	return type(key) == "string" and rawget(Bones.PieceInfo :: any, key) ~= nil
end

-- Una peça de la motxilla ben formada: base existent i UN dígit d'estat.
-- És el que validen els remotes (comerç, vendre, exposar).
function Bones.IsPieceKey(key: any): boolean
	if type(key) ~= "string" then
		return false
	end
	local base, tail = split(key)
	return tail ~= nil and #tail == 1 and validGrade(tonumber(tail)) and rawget(Bones.PieceInfo :: any, base) ~= nil
end

-- Un id d'esquelet de BASE ("Rat"): muntar, l'índex
function Bones.IsSkeletonId(id: any): boolean
	return type(id) == "string" and rawget(Bones.ById :: any, id) ~= nil
end

-- Un esquelet muntat ben format: "Rat#34425" (un dígit vàlid per peça)
function Bones.IsSkeletonItem(item: any): boolean
	if type(item) ~= "string" then
		return false
	end
	local base, tail = split(item)
	if not tail or rawget(Bones.ById :: any, base) == nil or #tail ~= #Bones.PiecesOf(base) then
		return false
	end
	for i = 1, #tail do
		if not validGrade(tonumber(string.sub(tail, i, i))) then
			return false
		end
	end
	return true
end

-- ─────────────────────────── ESTATS ───────────────────────────

-- Probabilitat de cada estat (1..7) per a una peça d'aquesta raresa trobada
-- amb una paleta d'aquesta sort (la fórmula és a dalt, a ESTAT)
function Bones.GradeChances(rarity: string, toolLuck: number): { number }
	local t = math.clamp(math.log(math.max(1, toolLuck)) / math.log(Bones.GRADE_TOOL_TOP), 0, 1)
	local r = ((Bones.RARITY_ORDER[rarity] or 1) - 1) / (#RARITIES - 1)
	local tilt = Bones.GRADE_TILT_TOOL * t - Bones.GRADE_TILT_RARITY * r + Bones.GRADE_TILT_BASE
	local weights, total = {}, 0
	for i, g in GRADES do
		weights[i] = g.weight * math.exp(tilt * (i - (#GRADES + 1) / 2))
		total += weights[i]
	end
	for i in weights do
		weights[i] /= total
	end
	return weights
end

function Bones.RollGrade(rarity: string, toolLuck: number, rng: Random): number
	local roll = rng:NextNumber()
	for i, p in Bones.GradeChances(rarity, toolLuck) do
		roll -= p
		if roll <= 0 then
			return i
		end
	end
	return #GRADES
end

-- Bonus de conjunt d'un esquelet muntat (x1 … x1,6 segons la peça pitjor)
function Bones.SetBonus(item: string): number
	local worst = #GRADES
	for _, g in Bones.GradesOf(item) do
		worst = math.min(worst, g)
	end
	return 1 + Bones.SET_BONUS_STEP * (worst - 1)
end

-- "Pristine x3.2" (peça) o "Set +30%" (esquelet), per a la UI
function Bones.GradeText(item: string): string
	if Bones.PieceInfo[item] then
		local g = Bones.GradeDef(Bones.GradeOf(item))
		return `{g.name} x{g.mult}`
	end
	return `Set bonus +{math.floor((Bones.SetBonus(item) - 1) * 100 + 0.5)}%`
end

-- Una frase curta de cada animal (anglès), per al rètol de sobre la vitrina
-- del museu (MuseumService) i qualsevol altra fitxa.
Bones.FACTS = {
	Rat = "City survivor. Its teeth never stop growing!",
	Pigeon = "Can find its way home from 1,000 km away.",
	Cat = "Ancient hunter. Always lands on its feet.",
	Dog = "Humanity's best friend for 15,000 years.",
	Dodo = "Flightless bird, gone forever since 1681.",
	Sabertooth = "Its fangs were as long as a banana!",
	TRex = "King of the dinosaurs. Bite of 6 tons!",
	Seagull = "Beach thief. Your fries are never safe.",
	Otter = "Holds hands with friends while sleeping.",
	Cormorant = "Dives 45 m deep to catch fish.",
	Ibis = "Sacred bird of Thoth, god of wisdom.",
	Jackal = "Anubis, guardian of the tombs, had its head.",
	Camel = "Walks the desert for a week without water.",
	Crocodile = "River god Sobek. Older than the pyramids!",
} :: { [string]: string }

function Bones.FactOf(item: string): string
	local info = Bones.PieceInfo[item]
	return Bones.FACTS[if info then info.skeleton else Bones.BaseOf(item)] or ""
end

-- "Rat · Skull", i la raresa. Per a la UI.
function Bones.Describe(key: string): (string, Rarity)
	local info = Bones.PieceInfo[key]
	if not info then
		return key, "Common"
	end
	local def = Bones.ById[info.skeleton]
	return `{def.name} · {PIECE_NAMES[def.kind][info.piece]}`, info.rarity
end

-- Les peces que es farien servir per muntar-lo: de cada peça, la de MILLOR
-- estat que tinguis. nil si en falta alguna.
function Bones.BestPieces(ownedBones: { [string]: number }, skeletonId: string): { string }?
	if not Bones.IsSkeletonId(skeletonId) then
		return nil
	end
	local chosen = {}
	for i, piece in Bones.PiecesOf(skeletonId) do
		local base = Bones.PieceKey(skeletonId, piece.id)
		for grade = #GRADES, 1, -1 do
			local item = Bones.PieceItem(base, grade)
			if (ownedBones[item] or 0) > 0 then
				chosen[i] = item
				break
			end
		end
		if not chosen[i] then
			return nil
		end
	end
	return chosen
end

-- Té totes les peces d'aquest esquelet (de qualsevol estat)?
function Bones.CanAssemble(ownedBones: { [string]: number }, skeletonId: string): boolean
	return Bones.BestPieces(ownedBones, skeletonId) ~= nil
end

-- Renda per minut d'una cosa exposada:
--   · peça ("Rat_Skull#4"): renda de la raresa x l'estat
--   · esquelet ("Rat#34425"): (suma de les peces, cadascuna x el seu estat)
--     x SKELETON_BONUS (x5) x bonus de conjunt (la peça pitjor: x1 … x1,5)
function Bones.IncomeOf(item: any): number
	if type(item) ~= "string" then
		return 0
	end
	local info = Bones.PieceInfo[item]
	if info then
		return PIECE_INCOME[info.rarity] * Bones.GradeDef(Bones.GradeOf(item)).mult
	end
	local def = Bones.ById[item]
	if def then
		local sum = 0
		for _, grade in Bones.GradesOf(item) do
			sum += PIECE_INCOME[def.rarity] * Bones.GradeDef(grade).mult
		end
		return sum * Bones.SKELETON_BONUS * Bones.SetBonus(item)
	end
	return 0
end

-- ─────────────────────────── VENDA ───────────────────────────
-- A la parada del Fossil Buyer (plaça) es venen peces soltes per monedes.
-- Una peça val els minuts de renda de museu que diu SELL_MINUTES: així
-- vendre-la i exposar-la no competeixen (exposar sempre surt més a compte
-- si tens vitrina lliure). Els esquelets muntats no es venen.
Bones.SELL_MINUTES = 4

function Bones.SellValue(key: string): number
	local info = Bones.PieceInfo[key]
	return if info then math.floor(Bones.IncomeOf(key) * Bones.SELL_MINUTES) else 0
end

-- Raresa d'una cosa exposada (peça o esquelet)
function Bones.RarityOf(item: string): Rarity
	local info = Bones.PieceInfo[item]
	if info then
		return info.rarity
	end
	local def = Bones.ById[item]
	return if def then def.rarity else "Common"
end

return Bones
