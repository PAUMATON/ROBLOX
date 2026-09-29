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
-- Una peça es desa al perfil amb la clau "<esquelet>_<peça>", p.ex.
-- "Rat_Skull". No la canviïs mai d'un esquelet ja publicat.
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

function Bones.IsPieceKey(key: any): boolean
	return type(key) == "string" and Bones.PieceInfo[key] ~= nil
end

function Bones.IsSkeletonId(id: any): boolean
	return type(id) == "string" and Bones.ById[id] ~= nil
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
	return Bones.FACTS[if info then info.skeleton else item] or ""
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

-- Té les 5 peces d'aquest esquelet?
function Bones.CanAssemble(ownedBones: { [string]: number }, skeletonId: string): boolean
	if not Bones.ById[skeletonId] then
		return false
	end
	for _, piece in Bones.PiecesOf(skeletonId) do
		if (ownedBones[Bones.PieceKey(skeletonId, piece.id)] or 0) < 1 then
			return false
		end
	end
	return true
end

-- Renda per minut d'una cosa exposada: una peça ("Rat_Skull") o un esquelet muntat ("Rat")
function Bones.IncomeOf(item: any): number
	if type(item) ~= "string" then
		return 0
	end
	local info = Bones.PieceInfo[item]
	if info then
		return PIECE_INCOME[info.rarity]
	end
	local def = Bones.ById[item]
	if def then
		return PIECE_INCOME[def.rarity] * #Bones.PiecesOf(def.id) * Bones.SKELETON_BONUS
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
	return if info then PIECE_INCOME[info.rarity] * Bones.SELL_MINUTES else 0
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
