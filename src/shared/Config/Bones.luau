--!strict

-- Bones — quins fòssils hi ha, de quin esquelet són i quina raresa tenen.
--
-- COM FUNCIONA (CLAUDE.md > Joc):
--   · Cada excavació dona UN fòssil (una peça d'un esquelet).
--   · Cada esquelet té UNA raresa i les seves 5 peces tenen aquesta raresa.
--   · Dins d'una mateixa raresa, TOTES les peces són igual de probables.
--     No hi ha "pietat": si tens 3 peces del T-Rex, les 2 que et falten
--     surten igual de sovint que qualsevol altra peça Secret.
--   · Un fòssil sol ja es pot exposar al museu. Si reuneixes les 5 peces
--     d'un esquelet, el pots muntar i rendeix el doble (SKELETON_BONUS).
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
-- La sort DIVIDEIX la N (de Rare cap amunt): amb sort x164 el Secret és
-- 1 de cada ~150; sense sort, 1 de cada 25.000.
-- Balancejat amb tools/economy_sim.py.
local RARITY_ODDS: { [string]: number } = {
	Uncommon = 4,
	Rare = 15,
	Epic = 80,
	Legendary = 600,
	Mythic = 4000,
	Secret = 25000,
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

-- Monedes per minut d'UN fòssil exposat sol al museu
local PIECE_INCOME: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 4,
	Epic = 10,
	Legendary = 25,
	Mythic = 70,
	Secret = 200,
}
Bones.PIECE_INCOME = PIECE_INCOME

-- Un esquelet muntat rendeix com les seves 5 peces soltes multiplicat per això
Bones.SKELETON_BONUS = 2

-- Ordre de cada raresa (per ordenar: 1 = Common)
Bones.RARITY_ORDER = {} :: { [string]: number }
for i, r in RARITIES do
	Bones.RARITY_ORDER[r] = i
end

-- ─────────────────────────── PECES ───────────────────────────

-- Les mateixes 5 peces per a tots els esquelets
local PIECES: { PieceDef } = {
	{ id = "Skull" },
	{ id = "Spine" },
	{ id = "ForeLimbs" },
	{ id = "HindLimbs" },
	{ id = "Tail" },
}
Bones.PIECES = PIECES

local PIECE_NAMES: { [string]: { [string]: string } } = {
	mammal = {
		Skull = "Skull",
		Spine = "Spine & Ribs",
		ForeLimbs = "Front Legs",
		HindLimbs = "Hind Legs",
		Tail = "Tail",
	},
	bird = {
		Skull = "Skull & Beak",
		Spine = "Spine & Keel",
		ForeLimbs = "Wings",
		HindLimbs = "Legs",
		Tail = "Tail Fan",
	},
	theropod = {
		Skull = "Skull",
		Spine = "Spine & Ribs",
		ForeLimbs = "Tiny Arms",
		HindLimbs = "Legs",
		Tail = "Tail",
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
}
Bones.PIECE_ICONS = PIECE_ICONS

-- ────────────────────────── ESQUELETS ──────────────────────────

-- Zona 1 · Construction Site: un esquelet per raresa, dels animals de ciutat
-- fins als extingits. Zona 2 · Fossil Beach: animals de costa.
local SKELETONS: { SkeletonDef } = {
	{ id = "Rat", icon = "🐀", name = "Rat", rarity = "Common", kind = "mammal", s = 0.5, snout = 0.9, ribs = 5, tailLen = 2.2, tailSegs = 16 },
	{ id = "Pigeon", icon = "🐦", name = "Pigeon", rarity = "Uncommon", kind = "bird", s = 0.7 },
	{ id = "Cat", icon = "🐈", name = "Cat", rarity = "Rare", kind = "mammal", s = 1, snout = 0.45, ribs = 6 },
	{ id = "Dog", icon = "🐕", name = "Dog", rarity = "Epic", kind = "mammal", s = 1.5, snout = 0.9, ribs = 7 },
	{ id = "Dodo", icon = "🦤", name = "Dodo", rarity = "Legendary", kind = "bird", s = 1.1, beak = 1.8, stocky = true },
	{ id = "Sabertooth", icon = "🐅", name = "Sabertooth", rarity = "Mythic", kind = "mammal", s = 1.7, snout = 0.5, ribs = 8, fangs = 1, tailLen = 0.8 },
	{ id = "TRex", icon = "🦖", name = "T-Rex", rarity = "Secret", kind = "theropod", s = 1 },

	{ id = "Seagull", icon = "🕊️", name = "Seagull", rarity = "Uncommon", kind = "bird", s = 0.9 },
	{ id = "Otter", icon = "🦦", name = "Otter", rarity = "Rare", kind = "mammal", s = 0.9, snout = 0.35, ribs = 8, tailLen = 1.9, tailSegs = 14 },
	{ id = "Cormorant", icon = "🦆", name = "Cormorant", rarity = "Epic", kind = "bird", s = 1.2 },
}
Bones.SKELETONS = SKELETONS

-- ────────────────────────── DERIVATS ──────────────────────────
-- Es calculen un sol cop en carregar. Ningú no els ha d'escriure a mà.

Bones.ById = {} :: { [string]: SkeletonDef }
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
		for _, piece in PIECES do
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

function Bones.IsPieceKey(key: any): boolean
	return type(key) == "string" and Bones.PieceInfo[key] ~= nil
end

function Bones.IsSkeletonId(id: any): boolean
	return type(id) == "string" and Bones.ById[id] ~= nil
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
	for _, piece in PIECES do
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
		return PIECE_INCOME[def.rarity] * #PIECES * Bones.SKELETON_BONUS
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
