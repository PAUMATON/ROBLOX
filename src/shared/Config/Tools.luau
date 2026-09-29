--!strict

-- Tools — les eines d'arqueòleg que es compren a Dig & Co., a la plaça.
-- A la botiga estan exposades soltes (estil Fisch): t'hi acostes, mantens E
-- i surt la fitxa de l'eina amb el botó de comprar.
--
-- Una eina millor NOMÉS dona SORT (`luck`): els fòssils rars surten més.
-- No toca el minijoc (les franges verdes són iguals per a tothom) ni la
-- velocitat. La sort de l'eina es multiplica per la del minijoc (fins a
-- x1) i pels passis de sort (Monetization); Dig.LuckMultiplier ho talla al sostre.
--
-- Els preus són en monedes del joc, no en Robux.

local Tools = {}

export type ToolDef = {
	id: string,
	name: string,
	price: number, -- monedes
	luck: number, -- multiplicador de sort (x1 .. x20)
	model: string, -- "shovel" | "trowel" | "pickaxe" | "brush" | "drill" (Util/ToolModels)
	blade: Color3, -- color de la part de metall (el jugador veu quina porta)
	handle: Color3,
	blurb: string, -- una frase per a la fitxa de la botiga
	-- Zona que cal tenir oberta per comprar-la. Les d'Egipte es venen al
	-- mercat de l'illa (tools/world/11_egypt), no a Dig & Co.
	zone: string?,
}

Tools.DEFAULT = "rusty_shovel" -- ha de coincidir amb ProfileSchema (ownedTools/equippedTool)
-- La millor paleta arriba sola al sostre (el minijoc ja no dona sort).
-- 29/09/2026: de x3 a x20 (decisió del propietari). Perquè el Legendary,
-- el Mythic i el Secret continuïn sent rars, les seves N van pujar alhora
-- (Bones.RARITY_ODDS), i el sostre total (Constants.MAX_LUCK) és x20 × x32.
Tools.MAX_LUCK = 20

local C3 = Color3.fromRGB

-- Corba de preus (tools/economy_sim.py, jugant sol i sense comerç).
-- Totes són paletes d'arqueòleg. Les id de les sis primeres són les de
-- sempre (els perfils desats les porten): el que es veu és `name`.
local LIST: { ToolDef } = {
	-- Dig & Co. (plaça)
	{ id = "rusty_shovel", name = "Rusty Trowel", model = "trowel", price = 0, luck = 1.0, blade = C3(150, 96, 60), handle = C3(139, 111, 71), blurb = "Old, bent and yours. Every digger starts here." },
	{ id = "steel_trowel", name = "Steel Trowel", model = "trowel", price = 9000, luck = 1.5, blade = C3(190, 196, 204), handle = C3(120, 84, 56), blurb = "A real archaeologist's trowel. +50% luck!" },
	{ id = "bronze_trowel", name = "Bronze Trowel", model = "trowel", price = 33000, luck = 2, blade = C3(205, 127, 50), handle = C3(92, 62, 40), blurb = "Warm bronze, cool finds. DOUBLE luck!" },
	{ id = "field_pickaxe", name = "Pro Trowel", model = "trowel", price = 80000, luck = 3, blade = C3(60, 140, 230), handle = C3(40, 44, 50), blurb = "Used by museum experts. TRIPLE luck!" },
	{ id = "pro_brush", name = "Ruby Trowel", model = "trowel", price = 240000, luck = 4, blade = C3(230, 50, 80), handle = C3(60, 40, 30), blurb = "Shines red. Epic fossils love it." },
	{ id = "emerald_trowel", name = "Emerald Trowel", model = "trowel", price = 650000, luck = 5.5, blade = C3(40, 200, 110), handle = C3(40, 50, 44), blurb = "Green as a jungle. Legendary bones wake up." },
	{ id = "golden_shovel", name = "Golden Trowel", model = "trowel", price = 1700000, luck = 7, blade = C3(255, 200, 50), handle = C3(60, 40, 30), blurb = "Pure gold. Legends say it smells Mythic bones." },
	{ id = "sonic_drill", name = "Diamond Trowel", model = "trowel", price = 4200000, luck = 9, blade = C3(120, 230, 255), handle = C3(34, 36, 40), blurb = "The best trowel in the city. x9 luck!" },
	-- Egipte (mercat de l'illa): les millors
	{ id = "scarab_trowel", name = "Scarab Trowel", model = "trowel", price = 10000000, luck = 12, blade = C3(30, 170, 160), handle = C3(214, 170, 72), blurb = "Blessed by the sacred scarab. x12 luck!", zone = "egypt" },
	{ id = "anubis_trowel", name = "Anubis Trowel", model = "trowel", price = 22000000, luck = 15, blade = C3(36, 36, 44), handle = C3(214, 170, 72), blurb = "The jackal god guards the rarest bones. x15!", zone = "egypt" },
	{ id = "pharaoh_trowel", name = "Pharaoh's Trowel", model = "trowel", price = 45000000, luck = 20, blade = C3(255, 214, 90), handle = C3(46, 84, 150), blurb = "The trowel of the Pharaoh himself. MAX luck x20!", zone = "egypt" },
}
Tools.LIST = LIST

Tools.ById = {} :: { [string]: ToolDef }
do
	local prevLuck = 0
	for _, t in LIST do
		if Tools.ById[t.id] then
			error(`[Tools] eina repetida: {t.id}`, 0)
		end
		if t.luck < 1 or t.luck > Tools.MAX_LUCK + 1e-6 then
			error(`[Tools] {t.id}: la sort ha d'anar de x1 a x{Tools.MAX_LUCK}`, 0)
		end
		if t.luck < prevLuck then
			error(`[Tools] {t.id}: una eina més cara no pot tenir menys sort`, 0)
		end
		prevLuck = t.luck
		Tools.ById[t.id] = t
	end
	if not Tools.ById[Tools.DEFAULT] or Tools.ById[Tools.DEFAULT].price ~= 0 then
		error("[Tools] l'eina per defecte ha d'existir i ser gratis", 0)
	end
end

-- L'eina que fa servir el jugador (si el perfil porta una id estranya, la de defecte).
function Tools.Get(id: any): ToolDef
	return (type(id) == "string" and Tools.ById[id]) or Tools.ById[Tools.DEFAULT]
end

-- "x1.5" (sense decimals sobrers)
function Tools.LuckText(luck: number): string
	local s = string.format("%.2f", luck):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. s
end

return Tools
