--!strict

-- DataService — perfils persistents amb session locking.
--
-- EL PROBLEMA QUE RESOL: un mateix jugador pot acabar a dos servidors alhora
-- (reconnexio rapida, teleport, dos servidors de la mateixa experiencia). Si
-- tots dos carreguen i desen el perfil, l'ultim que desa esborra el que ha
-- fet l'altre. El lock fa que nomes un servidor sigui l'amo del perfil.
--
-- COM FUNCIONA EL LOCK: el document desat porta dos camps al capdamunt,
-- `sessionJobId` (quin servidor el te) i `lastHeartbeat` (quan ho va dir per
-- ultim cop). En carregar:
--   · si no hi ha amo, o l'amo som nosaltres, o el batec te mes de
--     SESSION_LOCK_TIMEOUT segons (el servidor va caure) -> l'agafem.
--   · si l'amo es un altre i el batec es viu -> esperem
--     SESSION_LOCK_RETRY_WAIT i tornem a provar.
--   · despres de SESSION_LOCK_ATTEMPTS intents encara bloquejat -> fora.
--
-- El batec s'ha de refrescar SOL, cada SESSION_HEARTBEAT_INTERVAL. Sense
-- aixo una partida llarga passaria del timeout i un altre servidor podria
-- robar el lock amb el jugador encara jugant. Per aixo l'interval de batec
-- (20s) es molt mes curt que l'autosave (120s): son dues coses diferents.
--
-- TOT ES FA AMB UpdateAsync, mai GetAsync + SetAsync. UpdateAsync es atomic:
-- la comprovacio del lock i el fet d'agafar-lo passen dins de la mateixa
-- transaccio, i dos servidors no poden colar-se pel mig.
--
-- ORDRE DELS DESATS: cada desat porta un numero (`saveSeq`) que puja. Si
-- dos desats del mateix jugador van alhora (el d'un comerç i el de sortir,
-- per exemple) i el vell arriba l'ultim, no trepitja el nou: el DataStore
-- ja te un numero mes alt i el vell s'avorta.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Constants = require(Config:WaitForChild("Constants"))
local ProfileSchema = require(Config:WaitForChild("ProfileSchema"))
local Logger = require(Shared:WaitForChild("Util"):WaitForChild("Logger"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local log = Logger.new("DataService")

local STORE_NAME = "Profiles_v1"
local KICK_MESSAGE = "Your profile is still open on another server. Please try again in a minute."

-- ─────────────────────────── TIPUS ───────────────────────────

export type Profile = ProfileSchema.Profile

-- El que hi ha realment al DataStore. Les metadades del lock viuen FORA del
-- perfil a proposit: aixi el batec pot tocar el lock sense arriscar-se a
-- reescriure les dades de joc. El schemaVersion viu DINS del perfil, que es
-- qui migra.
type Stored = {
	sessionJobId: string?,
	lastHeartbeat: number?,
	saveSeq: number?, -- numero de l'ultim desat (veure ORDRE DELS DESATS)
	profile: Profile,
}

-- ────────────────────────── ESTAT ──────────────────────────

local DataService = {}

-- Altres serveis s'hi enganxen en lloc d'anar preguntant si ja esta llest.
DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.ProfileReleased = Signal.new() -- (player)

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local ready: { [Player]: boolean } = {}
local persisted: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}
local seqOf: { [Player]: number } = {} -- ultim saveSeq fet servir
local playStart: { [Player]: number } = {} -- os.clock() des de l'ultim cop que es va sumar l'estona
local connections: { RBXScriptConnection } = {}
local closing = false

-- ───────────────────────── HELPERS ─────────────────────────

-- A Studio JobId es buit. Fer servir una constant vol dir que una segona
-- sessio de Studio es reconeix a si mateixa i recupera el seu propi lock en
-- comptes d'esperar-se un minut.
local function jobKey(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function profileKey(player: Player): string
	return "p_" .. player.UserId
end

-- Llegeix el document del DataStore i migra el perfil de dins. Treballa
-- SOBRE la taula que arriba en comptes de fer-ne una de nova: aixi tampoc no
-- perdem claus del sobre que aquesta versio no conegui.
local function readStored(raw: any): Stored
	local stored: any = if type(raw) == "table" then raw else {}
	-- `data` era el nom d'aquest camp a la primera versio del fitxer.
	if stored.profile == nil and stored.data ~= nil then
		stored.profile = stored.data
		stored.data = nil
	end
	stored.profile = ProfileSchema.MigrateProfile(stored.profile)
	return stored :: Stored
end

-- Copia per desar. Ha de ser PROFUNDA i GENERICA per dues raons: desar fa
-- yield i el jugador podria estar modificant ownedBones mentre s'envia; i
-- copiar camp a camp perdria els camps que aquesta versio del joc no coneix,
-- que es justament el que ProfileSchema promet no fer mai.
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in value do
		out[key] = deepCopy(inner)
	end
	return out
end

-- Pressupost d'escriptura. UpdateAsync gasta pressupost de LECTURA i
-- d'ESCRIPTURA alhora; mirem el d'escriptura (SetIncrementAsync), que es el
-- que s'esgota primer quan hi ha molts jugadors desant a la vegada.
local function writeBudget(): number
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync)
	end)
	return if ok then budget else 0
end

local function hasWriteBudget(): boolean
	return writeBudget() >= Constants.MIN_WRITE_BUDGET
end

-- Reintents amb espera creixent (1s, 2s, 4s). Nomes per a errors de xarxa
-- del DataStore: que el perfil estigui bloquejat NO es un error i no passa
-- per aqui.
local function retry(label: string, fn: () -> any): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, Constants.SAVE_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		-- Nomes s'espera si encara queda un altre intent.
		local backoff = Constants.SAVE_BACKOFF[attempt]
		if backoff then
			task.wait(backoff)
		end
	end
	log:Error(`{label}: ha fallat {Constants.SAVE_ATTEMPTS} cops:`, lastErr)
	return false, lastErr
end

-- ──────────────────────── AGAFAR EL LOCK ────────────────────────

-- Un sol intent. Torna "ok" | "locked" | "error", el perfil i el saveSeq
-- que hi ha desat (els desats d'aquesta sessio en continuen el compte).
local function tryAcquire(player: Player): (string, Profile?, number)
	local s = store
	if not s then
		return "error", nil, 0
	end

	local me = jobKey()
	local blocked = false

	local ok, result = retry(`agafar el lock de {player.Name}`, function()
		-- Es reinicia a cada intent: UpdateAsync pot cridar el transform mes
		-- d'un cop si hi ha contencio.
		blocked = false
		return s:UpdateAsync(profileKey(player), function(old)
			local stored = readStored(old)
			local now = os.time()
			local owner = stored.sessionJobId
			local age = now - (stored.lastHeartbeat or 0)

			-- Un altre servidor el te i encara batega: no el toquem.
			-- Retornar nil avorta l'escriptura sencera.
			if owner ~= nil and owner ~= me and age < Constants.SESSION_LOCK_TIMEOUT then
				blocked = true
				return nil
			end

			stored.sessionJobId = me
			stored.lastHeartbeat = now
			-- Entrada comptada i ultima connexio. Un perfil nou ja neix amb
			-- joinCount = 1 (aquesta mateixa entrada), o sigui que nomes s'hi
			-- suma als que ja existien. Va dins de la MATEIXA transaccio que
			-- agafa el lock: si l'UpdateAsync no arriba a escriure, tampoc no
			-- s'ha comptat l'entrada.
			if old ~= nil then
				stored.profile.stats.joinCount += 1
			end
			stored.profile.lastOnline = now
			return stored
		end)
	end)

	if not ok then
		return "error", nil, 0
	end
	if blocked or result == nil then
		return "locked", nil, 0
	end
	local stored = result :: Stored
	return "ok", stored.profile, stored.saveSeq or 0
end

-- (més avall; loadProfile la necessita si el jugador marxa mentre carrega)
local onPlayerRemoving: (Player) -> ()

local function loadProfile(player: Player)
	if loading[player] or ready[player] then
		return
	end
	loading[player] = true

	for attempt = 1, Constants.SESSION_LOCK_ATTEMPTS do
		-- Si marxa mentre esperem, no te sentit continuar ni expulsar-lo.
		if not player:IsDescendantOf(Players) then
			loading[player] = nil
			return
		end

		local status, data, seq = tryAcquire(player)

		-- Ha marxat MENTRE carregava: el seu PlayerRemoving ja ha passat i
		-- no ha trobat res per desar. Si ens quedessim el perfil, el lock
		-- quedaria agafat (tornaria a entrar i l'expulsarien) i les taules
		-- d'aquest i d'altres serveis no es buidarien mai. Es fa la sortida
		-- ara: es desa, s'allibera el lock i es neteja tot.
		if not player:IsDescendantOf(Players) then
			loading[player] = nil
			if status == "ok" then
				profiles[player] = data :: Profile
				persisted[player] = true
				ready[player] = true
				seqOf[player] = seq
				playStart[player] = os.clock()
				onPlayerRemoving(player)
			end
			return
		end

		if status == "ok" then
			profiles[player] = data :: Profile
			persisted[player] = true
			ready[player] = true
			loading[player] = nil
			seqOf[player] = seq
			playStart[player] = os.clock()
			log:Info(`perfil de {player.Name} carregat (intent {attempt})`)
			DataService.ProfileLoaded:Fire(player, profiles[player])
			return
		elseif status == "error" then
			-- A Studio sense "Enable Studio Access to API Services" el
			-- DataStore no respon MAI. Val mes deixar jugar amb un perfil de
			-- memoria que no pas deixar el joc mort, pero s'ha de dir ben
			-- clar que la partida no es desa.
			log:Warn(
				`{player.Name} juga SENSE DESAR: el DataStore no respon.`,
				`A Studio: publica el lloc (File > Publish to Roblox) i activa`,
				`Game Settings > Security > Enable Studio Access to API Services.`
			)
			profiles[player] = ProfileSchema.NewProfile()
			persisted[player] = false
			ready[player] = true
			loading[player] = nil
			seqOf[player] = 0
			playStart[player] = os.clock()
			DataService.ProfileLoaded:Fire(player, profiles[player])
			return
		end

		-- status == "locked"
		log:Warn(
			`perfil de {player.Name} bloquejat per un altre servidor`,
			`(intent {attempt}/{Constants.SESSION_LOCK_ATTEMPTS})`
		)
		if attempt < Constants.SESSION_LOCK_ATTEMPTS then
			task.wait(Constants.SESSION_LOCK_RETRY_WAIT)
		end
	end

	loading[player] = nil
	if player:IsDescendantOf(Players) then
		log:Error(`{player.Name} expulsat: el lock no s'ha alliberat en {Constants.SESSION_LOCK_ATTEMPTS} intents`)
		player:Kick(KICK_MESSAGE)
	end
end

-- ───────────────────────── BATEC I DESAR ─────────────────────────

-- Refresca nomes lastHeartbeat. Manté el perfil tal com esta al DataStore:
-- qui ha de desar les dades de joc es l'autosave, no el batec.
--
-- AIXO NO MIRA EL PRESSUPOST a proposit, al reves que l'autosave. Si el
-- saltessim, el lock caducaria als 60 segons i un altre servidor el podria
-- robar amb el jugador encara jugant; aixo si que fa perdre la partida. Un
-- autosave saltat, en canvi, nomes vol dir esperar al cicle seguent.
local function heartbeat()
	local s = store
	if not s then
		return
	end
	local me = jobKey()

	-- Llista feta abans de començar: cada batec cedeix el control, i
	-- mentrestant hi pot haver jugadors que entren o surten. Recórrer
	-- `profiles` directament mentre canvia pot petar ("invalid key to
	-- 'next'") i mataria el bucle del batec: els locks caducarien sols.
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	for _, player in list do
		if persisted[player] and player:IsDescendantOf(Players) then
			retry(`batec de {player.Name}`, function()
				return s:UpdateAsync(profileKey(player), function(old)
					local stored = readStored(old)
					-- Si mentrestant l'ha agafat un altre, ell mana. I si no
					-- es de ningu, el jugador acaba de marxar i ja s'ha
					-- alliberat: tornar-lo a agafar el deixaria fora un minut.
					if stored.sessionJobId ~= me then
						return nil
					end
					stored.sessionJobId = me
					stored.lastHeartbeat = os.time()
					return stored
				end)
			end)
		end
	end
end

-- Suma al perfil l'estona jugada des de l'ultim cop. Es fa en desar, aixi
-- el que queda al DataStore sempre porta l'estona fins aquell moment.
local function flushPlaytime(player: Player)
	local data = profiles[player]
	local since = playStart[player]
	if data and since then
		local now = os.clock()
		data.stats.playSeconds += now - since
		playStart[player] = now
	end
end

-- `release` a true allibera el lock. `deferrable` a true vol dir que aquesta
-- escriptura es pot saltar si el pressupost esta baix, perque ja tornara al
-- cicle seguent; les de sortida i les de tancament no ho son mai.
local function saveProfile(player: Player, release: boolean, deferrable: boolean?): boolean
	if not ready[player] or not persisted[player] then
		return false
	end
	if deferrable and not hasWriteBudget() then
		log:Info(`autosave de {player.Name} saltat: pressupost a {writeBudget()}`)
		return false
	end
	local data = profiles[player]
	local s = store
	if not data or not s then
		return false
	end

	local me = jobKey()
	flushPlaytime(player)
	local payload = deepCopy(data)
	payload.lastOnline = os.time()
	-- El numero s'agafa ABANS de cap yield, igual que la copia: aixi el
	-- numero i les dades que porta son del mateix moment.
	local mySeq = (seqOf[player] or 0) + 1
	seqOf[player] = mySeq

	local ok = retry(`desar {player.Name}`, function()
		return s:UpdateAsync(profileKey(player), function(old)
			local stored = readStored(old)
			local owner = stored.sessionJobId
			-- Si el lock ja no es nostre, un altre servidor mana: no li
			-- sobreescrivim les dades amb les nostres, que ja son velles.
			if owner ~= nil and owner ~= me then
				return nil
			end
			-- Un desat normal que troba el lock alliberat arriba tard: el
			-- jugador ja ha marxat i el desat de sortida (mes nou) ja hi es.
			if owner == nil and not release then
				return nil
			end
			-- Ja hi ha un desat mes nou: aquest porta dades velles.
			if (stored.saveSeq or 0) >= mySeq then
				return nil
			end
			stored.saveSeq = mySeq
			stored.profile = payload
			if release then
				stored.sessionJobId = nil
				stored.lastHeartbeat = nil
			else
				stored.sessionJobId = me
				stored.lastHeartbeat = os.time()
			end
			return stored
		end)
	end)
	return ok
end

onPlayerRemoving = function(player: Player)
	loading[player] = nil
	saveProfile(player, true)
	profiles[player] = nil
	ready[player] = nil
	persisted[player] = nil
	seqOf[player] = nil
	playStart[player] = nil
	DataService.ProfileReleased:Fire(player)
end

-- ────────────────────────── API PUBLICA ──────────────────────────

-- Cap altre servei pot tocar el perfil abans que aixo torni true.
function DataService.IsReady(player: Player): boolean
	return ready[player] == true
end

-- false vol dir que es juga en memoria i NO es desara res.
function DataService.IsPersisted(player: Player): boolean
	return persisted[player] == true
end

function DataService.Get(player: Player): Profile?
	if not ready[player] then
		return nil
	end
	return profiles[player]
end

function DataService.Save(player: Player): boolean
	return saveProfile(player, false)
end

-- Desa uns quants jugadors ALHORA i espera que acabin tots. Torna true si
-- tots s'han desat. Es el que fa servir el comerç: els dos perfils surten
-- junts cap al DataStore, i la finestra en que un esta desat i l'altre no
-- queda en el temps d'una sola escriptura.
function DataService.SaveMany(players: { Player }): boolean
	local pending = #players
	local allOk = true
	for _, player in players do
		task.spawn(function()
			local ok = saveProfile(player, false)
			if not ok then
				allOk = false
			end
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
	return allOk
end

-- Estona de joc total en segons, comptant la d'aquesta sessio.
function DataService.PlaySeconds(player: Player): number
	local data = profiles[player]
	if not data then
		return 0
	end
	local since = playStart[player]
	return data.stats.playSeconds + (if since then os.clock() - since else 0)
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		log:Error(`no s'ha pogut obrir el DataStore "{STORE_NAME}":`, result)
	end

	-- PlayerRemoving i BindToClose van a Init(), no a Start(): si el servidor
	-- es tanques entre les dues passades, hi hauria perfils amb el lock posat
	-- i ningu per alliberar-lo, i el jugador es quedaria fora un minut.
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	game:BindToClose(function()
		closing = true

		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end

		-- Marge minim perque les corutines arrenquin i acabin el cas normal.
		task.wait(3)

		-- Pero tres segons SOLS no basten si algun desat ha hagut de
		-- reintentar: amb 1s+2s+4s d'espera, un sol perfil problematic ja
		-- passa dels set. Si encara en queda algun viu, l'esperem. Roblox
		-- dona uns 30s abans de matar el servidor; parem abans.
		local deadline = os.clock() + 22
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
		if pending > 0 then
			log:Error(`tancat amb {pending} perfils sense acabar de desar`)
		end
	end)
end

function DataService.Start()
	table.insert(connections, Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end))

	-- Qui hagi entrat entre Init() i Start() no hauria disparat PlayerAdded i
	-- es quedaria per sempre sense perfil.
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	task.spawn(function()
		while not closing do
			task.wait(Constants.SESSION_HEARTBEAT_INTERVAL)
			heartbeat()
		end
	end)

	task.spawn(function()
		while not closing do
			task.wait(Constants.AUTOSAVE_INTERVAL)
			if closing then
				break
			end
			-- Comprovacio de cicle: si el pressupost esta baix no val la pena
			-- ni començar, i aixi no es desen els primers jugadors de la
			-- llista i els ultims no.
			if not hasWriteBudget() then
				log:Warn(`autosave saltat: pressupost d'escriptura a {writeBudget()}`)
				continue
			end
			for _, player in Players:GetPlayers() do
				saveProfile(player, false, true)
				-- Un respir entre jugadors: amb la sala plena, desar-los tots
				-- seguits es menja el pressupost de cop.
				task.wait(0.2)
			end
		end
	end)
end

return DataService
