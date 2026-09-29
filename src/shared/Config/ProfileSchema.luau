--!strict

-- ProfileSchema — la forma canonica del perfil i les seves migracions.
--
-- UNA SOLA FONT DE VERITAT: els valors per defecte i la migracio surten de
-- la MATEIXA taula (PROFILE_FIELDS). Si estiguessin escrits dos cops, tard o
-- d'hora un perfil nou i un de migrat acabarien amb formes diferents, i aixo
-- es el tipus de bug que no es veu fins mesos despres.
--
-- LA REGLA IMPORTANT: MigrateProfile NO ESBORRA MAI RES. Nomes afegeix el
-- que falta. Aixo no es una manía: un perfil pot arribar d'una versio MES
-- NOVA que la d'aquest servidor (has publicat una actualitzacio pero encara
-- queden servidors vells engegats, o has fet rollback). Si reconstruissim la
-- taula amb els camps que coneixem, li esborrariem en silenci tot el que hi
-- ha guardat la versio nova. Per aixo la migracio treballa SOBRE la taula que
-- arriba en comptes de fer-ne una de nova.

local ProfileSchema = {}

-- Puja aquest numero i afegeix el pas corresponent a STEPS.
ProfileSchema.VERSION = 3

-- ─────────────────────────── TIPUS ───────────────────────────

export type Settings = {
	musicVolume: number, -- música i ambient (0..1)
	sfxVolume: number, -- efectes de la UI (0..1)
	uiScale: number, -- mida del HUD triada pel jugador (Theme.UI_SCALES)
	menuScale: number, -- mida de les finestres i menús que s'obren
	lowGraphics: boolean, -- sense efectes de llum ni partícules (mòbils fluixos)
	allowTrades: boolean, -- si altres jugadors et poden demanar trades
	quickRewards: boolean, -- la targeta del premi dura menys
}

export type Stats = {
	totalDigs: number,
	totalBones: number,
	totalTrades: number,
	joinCount: number,
	firstJoin: number,
	playSeconds: number, -- estona de joc total (per al mínim de comerç)
	totalSold: number, -- fòssils venuts a la Bonnie (missions)
	totalAssembled: number, -- esquelets muntats (missions)
	rarityFinds: { [string]: number }, -- raresa -> peces trobades EXCAVANT (missions)
}

-- Una línia del registre de comerç. El mateix `id` surt als DOS perfils:
-- si algun dia un perfil el té i l'altre no, el desat d'aquell canvi es va
-- quedar a mitges i ho veuràs.
export type TradeLogEntry = {
	id: string,
	t: number, -- os.time()
	with: number, -- UserId de l'altre
	withName: string,
	gave: { [string]: number },
	got: { [string]: number },
}

export type Profile = {
	schemaVersion: number,
	coins: number,
	ownedBones: { [string]: number }, -- id de peça -> quantitat (la motxilla)
	-- Quantes de les de la motxilla són de recompensa i no es poden
	-- comerciar. Sempre <= ownedBones[clau] (InventoryService ho manté).
	lockedBones: { [string]: number },
	discovered: { [string]: boolean }, -- peces trobades algun cop (l'índex)
	ownedSkeletons: { [string]: number }, -- id d'esquelet -> muntats sense exposar
	ownedTools: { string },
	equippedTool: string,
	unlockedZones: { string },
	museumLayout: { [string]: any }, -- vitrina ("1".."6") -> id d'esquelet
	-- Vitrines on hi ha una peça de recompensa: en treure-la, torna a la
	-- motxilla igual de bloquejada (si no, exposar-la la "rentaria").
	museumLocked: { [string]: boolean },
	tradeLog: { TradeLogEntry }, -- els últims canvis, el més nou primer
	-- Missió en curs (Config/Quests): número i, per a les que compten des
	-- que comencen, el valor del perfil en començar-la (nil = encara no fixat)
	quests: { index: number, base: number? },
	lastOnline: number,
	-- Fins quan s'ha cobrat la renda del museu. NO es lastOnline: aquest el
	-- reescriu DataService en carregar, i la renda offline necessita saber
	-- l'hora de l'ultim cobrament.
	lastIncomeAt: number,
	gamepasses: { [string]: boolean }, -- clau (Config/Monetization) -> true
	boostUntil: number, -- x2 de diners fins aquest os.time() (producte o recompensa)
	luckBoostUntil: number, -- x2 de sort fins aquest os.time() (recompensa)
	daily: { lastDay: number, streak: number }, -- recompensa diària (Config/Rewards)
	invites: { count: number, rewarded: { [string]: boolean } }, -- amics convidats
	settings: Settings,
	stats: Stats,
	-- Indexat per PurchaseId, no una llista: ProcessReceipt pot arribar dos
	-- cops per la mateixa compra i cal poder respondre "aixo ja ho he donat"
	-- en temps constant. Amb una llista caldria recorrer-la sencera.
	purchaseHistory: { [string]: any },
}

-- ────────────────── DESCRIPCIO DELS CAMPS ──────────────────

type Field = {
	kind: string,
	default: () -> any,
	children: { [string]: any }?,
}
type Spec = { [string]: Field }

local function emptyTable(): any
	return {}
end

-- Construeix una taula nova a partir d'una descripcio. Cada crida torna
-- taules DIFERENTS: si les compartissim, dos jugadors tindrien el mateix
-- `settings` i tocar-ne un tocaria l'altre.
local function buildFrom(spec: Spec): any
	local out = {}
	for key, field in spec do
		out[key] = field.default()
	end
	return out
end

local SETTINGS_FIELDS: Spec = {
	musicVolume = { kind = "number", default = function()
		return 0.5
	end },
	sfxVolume = { kind = "number", default = function()
		return 1
	end },
	uiScale = { kind = "number", default = function()
		return 1
	end },
	menuScale = { kind = "number", default = function()
		return 1
	end },
	lowGraphics = { kind = "boolean", default = function()
		return false
	end },
	allowTrades = { kind = "boolean", default = function()
		return true
	end },
	quickRewards = { kind = "boolean", default = function()
		return false
	end },
}

local STATS_FIELDS: Spec = {
	totalDigs = { kind = "number", default = function()
		return 0
	end },
	totalBones = { kind = "number", default = function()
		return 0
	end },
	totalTrades = { kind = "number", default = function()
		return 0
	end },
	joinCount = { kind = "number", default = function()
		return 1
	end },
	-- os.time() s'ha d'avaluar EN EL MOMENT, no a la carrega del modul: si
	-- fos una constant, tots els perfils creats en aquell servidor tindrien
	-- la mateixa data de primera entrada.
	firstJoin = { kind = "number", default = function()
		return os.time()
	end },
	playSeconds = { kind = "number", default = function()
		return 0
	end },
	totalSold = { kind = "number", default = function()
		return 0
	end },
	totalAssembled = { kind = "number", default = function()
		return 0
	end },
	rarityFinds = { kind = "table", default = emptyTable },
}

local PROFILE_FIELDS: Spec = {
	schemaVersion = { kind = "number", default = function()
		return ProfileSchema.VERSION
	end },
	coins = { kind = "number", default = function()
		return 6000
	end },
	ownedBones = { kind = "table", default = emptyTable },
	lockedBones = { kind = "table", default = emptyTable },
	discovered = { kind = "table", default = emptyTable },
	ownedSkeletons = { kind = "table", default = emptyTable },
	ownedTools = { kind = "table", default = function()
		return { "rusty_shovel" }
	end },
	equippedTool = { kind = "string", default = function()
		return "rusty_shovel"
	end },
	unlockedZones = { kind = "table", default = function()
		return { "construction" }
	end },
	museumLayout = { kind = "table", default = emptyTable },
	museumLocked = { kind = "table", default = emptyTable },
	tradeLog = { kind = "table", default = emptyTable },
	quests = {
		kind = "table",
		default = function()
			return { index = 1 }
		end,
	},
	lastOnline = { kind = "number", default = function()
		return os.time()
	end },
	lastIncomeAt = { kind = "number", default = function()
		return os.time()
	end },
	gamepasses = { kind = "table", default = emptyTable },
	boostUntil = { kind = "number", default = function()
		return 0
	end },
	luckBoostUntil = { kind = "number", default = function()
		return 0
	end },
	daily = {
		kind = "table",
		default = function()
			return { lastDay = -1, streak = 0 }
		end,
	},
	invites = {
		kind = "table",
		default = function()
			return { count = 0, rewarded = {} }
		end,
	},
	settings = {
		kind = "table",
		default = function()
			return buildFrom(SETTINGS_FIELDS)
		end,
		children = SETTINGS_FIELDS,
	},
	stats = {
		kind = "table",
		default = function()
			return buildFrom(STATS_FIELDS)
		end,
		children = STATS_FIELDS,
	},
	purchaseHistory = { kind = "table", default = emptyTable },
}

-- ─────────────────────── PERFIL NOU ───────────────────────

function ProfileSchema.NewProfile(): Profile
	return buildFrom(PROFILE_FIELDS) :: Profile
end

-- ──────────────────────── MIGRACIO ────────────────────────

-- Passos indexats per la versio DE LA QUAL surten. Cada pas nomes ha de fer
-- les transformacions que no es poden resoldre afegint camps: canviar el
-- nom d'un camp, partir-ne un en dos, reescalar valors... Afegir camps
-- nous NO necessita pas: se n'encarrega fillMissing.
--
-- Els passos antics no es borren mai. Sempre hi ha algu que fa mesos que no
-- entra i el seu perfil encara es de la versio vella.
local STEPS: { [number]: (any) -> () } = {
	-- v0 = perfils d'abans que existis schemaVersion. Nomes cal deixar que
	-- fillMissing hi posi els valors per defecte de v1.
	[0] = function(_profile: any) end,
	-- v1 -> v2: arriba stats.playSeconds (el mínim de joc per comerciar).
	-- Abans no es comptava, i començar de zero castigaria qui ja hi ha
	-- jugat: se n'estima una mica per excavació (el minijoc i la
	-- recàrrega fan uns 6 s). Els fòssils que ja tenien es queden
	-- comerciables: no se sap quins eren de recompensa.
	[1] = function(profile: any)
		local stats = profile.stats
		if type(stats) == "table" and type(stats.playSeconds) ~= "number" then
			local digs = if type(stats.totalDigs) == "number" then stats.totalDigs else 0
			stats.playSeconds = digs * 6
		end
	end,
	-- v2 -> v3: tots els diners del joc x60 (renda per segon en lloc de per
	-- minut). Les monedes que ja tenies també, perquè valguin el mateix.
	[2] = function(profile: any)
		if type(profile.coins) == "number" then
			profile.coins *= 60
		end
	end,
}

-- Afegeix el que falta i repara el que te el tipus canviat. No toca cap
-- clau que no surti a `spec`: aquestes son les que hem de preservar encara
-- que no sapiguem que son.
local function fillMissing(target: any, spec: Spec, path: string, notes: { string }): boolean
	local changed = false

	for key, field in spec do
		local value = target[key]
		local where = if path == "" then key else `{path}.{key}`

		if value == nil then
			target[key] = field.default()
			table.insert(notes, `+{where}`)
			changed = true
		elseif typeof(value) ~= field.kind then
			-- Un camp conegut amb el tipus equivocat peta el joc a la
			-- primera que s'hi toqui. Val mes perdre aquest camp que no pas
			-- tenir el jugador amb el joc trencat cada sessio.
			target[key] = field.default()
			table.insert(notes, `!{where} (era {typeof(value)}, s'esperava {field.kind})`)
			changed = true
		elseif field.children then
			if fillMissing(value, field.children, where, notes) then
				changed = true
			end
		end
	end

	return changed
end

-- Porta qualsevol perfil a la versio actual.
-- Torna (perfil, s_ha_canviat, notes). `notes` explica que s'ha tocat, per
-- si ho vols registrar.
function ProfileSchema.MigrateProfile(profile: any): (Profile, boolean, { string })
	local notes: { string } = {}

	-- No es una taula: o es un perfil nou, o les dades estan tan trencades
	-- que no hi ha res a salvar.
	if type(profile) ~= "table" then
		table.insert(notes, "perfil nou")
		return ProfileSchema.NewProfile(), true, notes
	end

	local changed = false
	local from = if type(profile.schemaVersion) == "number" then profile.schemaVersion else 0

	if from > ProfileSchema.VERSION then
		-- Ve d'un servidor MES NOU que aquest. No el tirem enrere ni li
		-- toquem el schemaVersion: quan torni al servidor nou, ha de seguir
		-- sent seu. Aqui nomes ens assegurem que hi ha el que necessitem per
		-- funcionar, i tot el que no coneixem viatja intacte.
		table.insert(notes, `perfil de v{from} en un servidor de v{ProfileSchema.VERSION}: no es toca la versio`)
	else
		while from < ProfileSchema.VERSION do
			local step = STEPS[from]
			if step then
				step(profile)
			end
			from += 1
			changed = true
			table.insert(notes, `v{from - 1}->v{from}`)
		end
		profile.schemaVersion = ProfileSchema.VERSION
	end

	if fillMissing(profile, PROFILE_FIELDS, "", notes) then
		changed = true
	end

	return profile :: Profile, changed, notes
end

return ProfileSchema
