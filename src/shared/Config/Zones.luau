--!strict

-- Zones — on es cava i que hi surt.
--
-- REGLA DE ZONES (CLAUDE.md): cada esquelet es completable DINS de la seva
-- zona. Les 5 peces d'un esquelet surten totes de la mateixa zona; si no,
-- un jugador de zona 1 necessitaria una peca que nomes te qui juga a la
-- zona 2, i no tenen res per intercanviar-se. Nomes un esquelet marcat
-- `multiZone` a Bones.luau (raresa molt alta) pot sortir a mes d'una zona.
-- El modul peta en carregar si la regla no es compleix.
--
-- Cada zona pot tenir esquelets de qualsevol raresa. Si a una zona hi
-- falta una raresa (p.ex. la platja no té Secret), aquella raresa no hi
-- surt i les altres es reparteixen el seu pes.
--
-- Al mapa, cada munt excavable porta l'etiqueta "DigSpot" i l'atribut
-- `Zone` amb l'id d'aqui sota. El servidor nomes es fia d'aquest atribut.
--
-- Tres zones (29/09/2026: el propietari va afegir Egipte). Egipte és una
-- illa lluny de tot: només s'hi arriba amb el botó ✈️ Travel.

local Bones = require(script.Parent.Bones)

local Zones = {}

export type ZoneDef = {
	id: string,
	name: string,
	number: number,
	-- Preu de desbloqueig en monedes. 0 = oberta des del principi.
	unlockCost: number,
	-- Monedes per excavació (abans del bonus del minijoc). És la renda
	-- ACTIVA; la del museu és la PASSIVA.
	coinsPerDig: number,
	skeletons: { string },
	-- Cal tenir aquesta zona oberta abans de poder obrir aquesta
	requires: string?,
	-- On es desbloqueja (per al missatge "is locked · unlock it ...")
	unlockAt: string?,
	icon: string, -- per a la UI (menú Travel, índex)
	-- Només s'hi arriba volant (✈️ Travel): la guia de missions no hi pot
	-- apuntar caminant i marca el botó del viatge
	flyOnly: boolean?,
	-- Mythic i Secret són aquestes vegades més difícils aquí que a la zona 1
	-- (Bones.ZONE_HARD_FROM). Com més lluny la zona, més alt. nil = 1.
	rareHardness: number?,
}

Zones.DEFAULT = "construction" -- ha de coincidir amb ProfileSchema.unlockedZones

local LIST: { ZoneDef } = {
	{
		id = "construction",
		name = "Construction Site",
		number = 1,
		unlockCost = 0,
		coinsPerDig = 270,
		icon = "🏗️",
		-- una raresa per esquelet: Common → Secret
		skeletons = { "Rat", "Pigeon", "Cat", "Dog", "Dodo", "Sabertooth", "TRex" },
	},
	{
		id = "beach",
		name = "Fossil Beach",
		number = 2,
		unlockCost = 320000,
		coinsPerDig = 720,
		icon = "🏖️",
		unlockAt = "at the beach gate",
		rareHardness = 1.5,
		skeletons = { "Seagull", "Otter", "Cormorant" },
	},
	{
		id = "egypt",
		name = "Egypt",
		number = 3,
		unlockCost = 3200000,
		coinsPerDig = 3600,
		icon = "🐫",
		requires = "beach",
		unlockAt = "at the Egypt gate (fly there with ✈️ Travel)",
		rareHardness = 2, -- el Crocodile (Mythic): 1 de cada 4.000
		flyOnly = true,
		-- zona alta: no hi ha Common ni Uncommon; la més "comuna" és Rare
		skeletons = { "Ibis", "Jackal", "Camel", "Crocodile" },
	},
	{
		-- 30/09/2026: glacera de l'Edat de Gel, com Egipte: lluny de tot, només
		-- en avió, gel i neu fins a l'horitzó (tools/world/12_glacier.luau)
		id = "glacier",
		name = "Ice Age Glacier",
		number = 4,
		unlockCost = 25000000,
		coinsPerDig = 12000,
		icon = "🏔️",
		requires = "egypt",
		unlockAt = "at the Glacier gate (fly there with ✈️ Travel)",
		rareHardness = 2.5, -- el Mammoth (Mythic): 1 de cada 5.000
		flyOnly = true,
		skeletons = { "ArcticHare", "DireWolf", "GiantDeer", "WoollyRhino", "Mammoth" },
	},
}
Zones.LIST = LIST

Zones.MAX_ZONES = 4 -- 30/09/2026: la glacera (decisió del propietari)

-- ────────────────────────── DERIVATS ──────────────────────────

Zones.ById = {} :: { [string]: ZoneDef }
Zones.OfSkeleton = {} :: { [string]: { string } } -- esquelet -> zones on surt
-- zona -> raresa -> totes les peces d'aquella raresa que hi surten (per sortejar)
Zones.PiecesByRarity = {} :: { [string]: { [string]: { string } } }

do
	if #Zones.LIST > Zones.MAX_ZONES then
		error(`[Zones] {#Zones.LIST} zones: el CLAUDE.md en permet {Zones.MAX_ZONES}`, 0)
	end
	for _, zone in Zones.LIST do
		if Zones.ById[zone.id] then
			error(`[Zones] zona repetida: {zone.id}`, 0)
		end
		Zones.ById[zone.id] = zone
		local byRarity: { [string]: { string } } = {}
		Zones.PiecesByRarity[zone.id] = byRarity
		for _, skeletonId in zone.skeletons do
			if not Bones.ById[skeletonId] then
				error(`[Zones] {zone.id}: l'esquelet {skeletonId} no existeix a Bones`, 0)
			end
			local rarity = Bones.ById[skeletonId].rarity
			byRarity[rarity] = byRarity[rarity] or {}
			for _, piece in Bones.PiecesOf(skeletonId) do
				table.insert(byRarity[rarity], Bones.PieceKey(skeletonId, piece.id))
			end
			local list = Zones.OfSkeleton[skeletonId] or {}
			table.insert(list, zone.id)
			Zones.OfSkeleton[skeletonId] = list
		end
	end
	for _, zone in Zones.LIST do
		if zone.requires and not Zones.ById[zone.requires] then
			error(`[Zones] {zone.id} demana {zone.requires}, que no existeix`, 0)
		end
	end
	if not Zones.ById[Zones.DEFAULT] then
		error(`[Zones] la zona per defecte {Zones.DEFAULT} no existeix`, 0)
	end
	for _, def in Bones.SKELETONS do
		local where = Zones.OfSkeleton[def.id]
		if not where then
			error(`[Zones] l'esquelet {def.id} no surt a cap zona: no es podria completar mai`, 0)
		end
		if #where > 1 and not def.multiZone then
			error(`[Zones] {def.id} surt a {#where} zones sense ser multiZone (Regla de zones)`, 0)
		end
	end
end

function Zones.IsZoneId(id: any): boolean
	return type(id) == "string" and Zones.ById[id] ~= nil
end

function Zones.IsUnlocked(unlockedZones: { string }, zoneId: string): boolean
	return table.find(unlockedZones, zoneId) ~= nil
end

return Zones
