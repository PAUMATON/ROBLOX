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
	luck: number, -- multiplicador de sort (x1 .. x3)
	model: string, -- "shovel" | "trowel" | "pickaxe" | "brush" | "drill" (Util/ToolModels)
	blade: Color3, -- color de la part de metall (el jugador veu quina porta)
	handle: Color3,
	blurb: string, -- una frase per a la fitxa de la botiga
}

Tools.DEFAULT = "rusty_shovel" -- ha de coincidir amb ProfileSchema (ownedTools/equippedTool)
-- La millor paleta arriba sola al sostre (el minijoc ja no dona sort)
Tools.MAX_LUCK = 3 -- les paletes van de x1 a x3 (els passis de sort multipliquen a sobre)

-- Corba de preus (tools/economy_sim.py, jugant sol i sense comerç).
-- Totes són paletes d'arqueòleg. (Les id són les de sempre perquè els
-- perfils desats les porten; el que es veu és `name`.)
local LIST: { ToolDef } = {
	{ id = "rusty_shovel", name = "Rusty Trowel", model = "trowel", price = 0, luck = 1.0, blade = Color3.fromRGB(150, 96, 60), handle = Color3.fromRGB(139, 111, 71), blurb = "Old, bent and yours. Every digger starts here." },
	{ id = "steel_trowel", name = "Steel Trowel", model = "trowel", price = 45000, luck = 1.5, blade = Color3.fromRGB(190, 196, 204), handle = Color3.fromRGB(120, 84, 56), blurb = "A real archaeologist's trowel. +50% luck!" },
	{ id = "field_pickaxe", name = "Pro Trowel", model = "trowel", price = 360000, luck = 2.0, blade = Color3.fromRGB(60, 140, 230), handle = Color3.fromRGB(40, 44, 50), blurb = "Used by museum experts. DOUBLE luck!" },
	{ id = "pro_brush", name = "Ruby Trowel", model = "trowel", price = 2400000, luck = 2.4, blade = Color3.fromRGB(230, 50, 80), handle = Color3.fromRGB(60, 40, 30), blurb = "Shines red. Epic fossils love it." },
	{ id = "golden_shovel", name = "Golden Trowel", model = "trowel", price = 12000000, luck = 2.7, blade = Color3.fromRGB(255, 200, 50), handle = Color3.fromRGB(60, 40, 30), blurb = "Pure gold. Legends say it smells Mythic bones." },
	{ id = "sonic_drill", name = "Diamond Trowel", model = "trowel", price = 54000000, luck = 3.0, blade = Color3.fromRGB(120, 230, 255), handle = Color3.fromRGB(34, 36, 40), blurb = "The best trowel ever made. MAX luck x3!" },
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
