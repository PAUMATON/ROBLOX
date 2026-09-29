--!strict

-- TradeService — el comerc. El codi mes perillos del joc (CLAUDE.md), i per
-- aixo el mes desconfiat.
--
-- Garanties:
--  · Cap objecte de valor viu al Player: tot surt del perfil del servidor.
--  · Qualsevol canvi d'oferta esborra les confirmacions de TOTS DOS. Es el
--    que impedeix l'estafa classica de canviar l'oferta a l'ultim moment.
--  · ESCROW ATOMIC: l'intercanvi es valida sencer i despres es fa sencer,
--    sense cap yield pel mig. En Luau (cooperatiu) no cedir el control es el
--    que fa que sigui atomic: o passa tot, o no passa res.
--  · Les ofertes no reserven res: el que compta es el que hi ha al perfil
--    en el moment d'executar. Si alguna peca ja no hi es, no es fa res.
--  · Nomes es comercia amb peces comerciables: les de recompensa estan
--    bloquejades (InventoryService.TradeableCount).
--  · Cal haver jugat Constants.TRADE_MIN_PLAY_MINUTES i tenir el perfil
--    desant-se de debo (un perfil de memoria no pot donar res a un de real).
--  · DESPRES del canvi, els dos perfils es desen ALHORA (DataService.SaveMany)
--    i cap dels dos pot tornar a comerciar fins que s'han desat. El canvi
--    queda apuntat als dos perfils amb el mateix id (tradeLog).
--
-- LIMIT CONEGUT: dues claus del DataStore no es poden escriure en una sola
-- transaccio. Si el servidor caigues just entre les dues escriptures (una
-- fraccio de segon), un perfil tindria el canvi i l'altre no. El tradeLog
-- ho fa visible: el mateix id nomes a un dels dos perfils.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Constants = require(Config:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local log = Logger.new("TradeService")

local TradeService = {}

type Offer = { [string]: number }
type Trade = {
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	confirmed: { [Player]: boolean },
	accepted: { [Player]: boolean },
	lockedAt: number?, -- os.clock() de quan s'han confirmat tots dos
}

local tradeOf: { [Player]: Trade } = {}
local inviteFrom: { [Player]: Player } = {} -- convidat -> qui convida
local inviteAt: { [Player]: number } = {} -- convidat -> quan (caduca: TRADE_INVITE_TTL)
local lastTradeAt: { [Player]: number } = {} -- quan va acabar el seu últim canvi
local lastRequest: { [Player]: number } = {}
local saving: { [Player]: boolean } = {} -- l'ultim canvi encara s'esta desant
local limiter = RateLimiter.new(6)

-- ─────────────────────────── AJUDES ───────────────────────────

local function minutesText(seconds: number): string
	local m = math.ceil(seconds / 60)
	return if m == 1 then "1 more minute" else `{m} more minutes`
end

-- Pot comerciar ara mateix? Si no, torna el motiu (en angles, per a la UI).
-- `you` = true si el motiu s'ha de dir en segona persona.
local function blockedReason(player: Player, you: boolean): string?
	if not DataService.IsReady(player) then
		return if you then "Your data is still loading" else `{player.DisplayName} is still loading`
	end
	if saving[player] then
		return if you then "Saving your last trade, try again in a moment" else `{player.DisplayName} is finishing another trade`
	end
	local since = lastTradeAt[player]
	if since and os.clock() - since < Constants.TRADE_AFTER_COOLDOWN then
		return if you then "Wait a few seconds before your next trade" else `{player.DisplayName} just finished a trade, try again in a moment`
	end
	-- Un perfil que no es desa (DataStore caigut) no pot donar ni rebre res
	-- de debo. A Studio es deixa per poder provar-ho sense API.
	if not DataService.IsPersisted(player) and not RunService:IsStudio() then
		return if you then "Trading is off: your data isn't saving right now" else `{player.DisplayName} can't trade right now`
	end
	local wait = InventoryService.TradeWait(player)
	if wait > 0 then
		return if you
			then `You can trade after {Constants.TRADE_MIN_PLAY_MINUTES} min of play ({minutesText(wait)})`
			else `{player.DisplayName} is new here and can't trade yet`
	end
	return nil
end

local function tellIdle(player: Player, reason: string)
	Remotes.TradeUpdate:FireClient(player, { state = "idle", reason = reason })
end

-- Es comercia amb tot el servidor: nomes cal que tots dos hi siguin encara
local function together(a: Player, b: Player): boolean
	return a.Parent == Players and b.Parent == Players
end

local function other(t: Trade, player: Player): Player
	return if t.a == player then t.b else t.a
end

local function countKinds(offer: Offer): number
	local n = 0
	for _ in offer do
		n += 1
	end
	return n
end

local function pushState(t: Trade)
	for _, player in { t.a, t.b } do
		local o = other(t, player)
		Remotes.TradeUpdate:FireClient(player, {
			state = "active",
			other = o.DisplayName,
			myOffer = t.offers[player],
			theirOffer = t.offers[o],
			myConfirmed = t.confirmed[player],
			theirConfirmed = t.confirmed[o],
			myAccepted = t.accepted[player],
			theirAccepted = t.accepted[o],
			locked = t.confirmed[t.a] and t.confirmed[t.b],
			-- segons que falten perquè ACCEPT funcioni (veure TRADE_ACCEPT_DELAY)
			acceptIn = if t.lockedAt then math.max(0, Constants.TRADE_ACCEPT_DELAY - (os.clock() - t.lockedAt)) else nil,
		})
	end
end

local function closeTrade(t: Trade, reason: string, done: boolean?)
	for _, player in { t.a, t.b } do
		if tradeOf[player] == t then
			tradeOf[player] = nil
		end
		if player.Parent then
			Remotes.TradeUpdate:FireClient(player, { state = "idle", reason = reason, done = done == true })
		end
	end
end

-- Qualsevol moviment d'oferta invalida les confirmacions dels dos.
local function resetConfirmations(t: Trade)
	t.confirmed[t.a] = false
	t.confirmed[t.b] = false
	t.accepted[t.a] = false
	t.accepted[t.b] = false
	t.lockedAt = nil
end

-- ─────────────────────────── L'INTERCANVI ───────────────────────────

local function executeTrade(t: Trade): boolean
	-- 1) VALIDACIO SENCERA. Encara no s'ha tocat cap perfil.
	local pa, pb = DataService.Get(t.a), DataService.Get(t.b)
	if not pa or not pb then
		return false
	end
	for player, profile in { [t.a] = pa, [t.b] = pb } do
		for key, n in t.offers[player] do
			if not Bones.IsPieceKey(key) or type(n) ~= "number" or n < 1 or n ~= math.floor(n) then
				return false
			end
			if InventoryService.TradeableCount(profile, key) < n then
				return false
			end
		end
	end

	-- 2) MUTACIO SENCERA. D'aqui fins al final no hi ha cap crida que cedeixi
	--    el control: ningu no pot colar-se entremig ni deixar-ho a mig fer.
	InventoryService.MoveBones(pa, pb, t.offers[t.a])
	InventoryService.MoveBones(pb, pa, t.offers[t.b])
	pa.stats.totalTrades += 1
	pb.stats.totalTrades += 1

	-- 3) REGISTRE, als dos perfils i amb el mateix id
	local id = HttpService:GenerateGUID(false)
	local now = os.time()
	local function note(profile: DataService.Profile, other: Player, gave: Offer, got: Offer)
		table.insert(profile.tradeLog, 1, {
			id = id,
			t = now,
			with = other.UserId,
			withName = other.Name,
			gave = table.clone(gave),
			got = table.clone(got),
		})
		while #profile.tradeLog > Constants.TRADE_LOG_SIZE do
			table.remove(profile.tradeLog)
		end
	end
	note(pa, t.b, t.offers[t.a], t.offers[t.b])
	note(pb, t.a, t.offers[t.b], t.offers[t.a])
	return true
end

-- REGISTRE GLOBAL: cada canvi també es guarda a part (TradeAudit_v1, clau =
-- id del canvi), amb els dos jugadors i què ha donat cadascun. Serveix per
-- investigar una queixa o un duplicat encara que els perfils ja hagin
-- canviat. No és imprescindible: si falla, només queda al log.
local auditStore: DataStore? = nil
pcall(function()
	auditStore = DataStoreService:GetDataStore("TradeAudit_v1")
end)
local function audit(entry: any, a: Player, b: Player, gaveA: Offer, gaveB: Offer, saved: boolean)
	local store = auditStore
	if not store or type(entry) ~= "table" or not DataService.IsPersisted(a) then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(entry.id, {
			t = entry.t,
			a = a.UserId,
			b = b.UserId,
			gaveA = gaveA,
			gaveB = gaveB,
			saved = saved, -- false: un dels dos desats no es va poder confirmar
			job = game.JobId,
		}, { a.UserId, b.UserId })
	end)
	if not ok then
		log:Warn(`no s'ha pogut guardar el registre del canvi {entry.id}:`, err)
	end
end

local function describe(offer: Offer): string
	local parts = {}
	for key, n in offer do
		table.insert(parts, `{key}x{n}`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else "(res)"
end

-- ─────────────────────────── ACCIONS ───────────────────────────

local actions: { [string]: (Player, any) -> () } = {}

function actions.request(player: Player, targetId: any)
	if type(targetId) ~= "number" or tradeOf[player] or not DataService.IsReady(player) then
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < Constants.TRADE_REQUEST_COOLDOWN then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player or not together(player, target) then
		return
	end
	local mine = blockedReason(player, true)
	if mine then
		tellIdle(player, mine)
		return
	end
	lastRequest[player] = now
	if tradeOf[target] then
		tellIdle(player, `{target.DisplayName} is already trading`)
		return
	end
	local theirs = blockedReason(target, false)
	if theirs then
		tellIdle(player, theirs)
		return
	end
	-- el jugador pot tancar les peticions de trade a la configuració
	local targetProfile = DataService.Get(target)
	if targetProfile and targetProfile.settings and targetProfile.settings.allowTrades == false then
		tellIdle(player, `{target.DisplayName} isn't accepting trades right now`)
		return
	end
	lastRequest[player] = now
	inviteFrom[target] = player
	inviteAt[target] = os.clock()
	Remotes.TradeUpdate:FireClient(target, { state = "invite", from = player.DisplayName })
end

function actions.accept_invite(player: Player)
	local from = inviteFrom[player]
	local at = inviteAt[player]
	inviteFrom[player] = nil
	inviteAt[player] = nil
	if not from or not from.Parent then
		return
	end
	-- una invitació vella no val (l'avís ja ha marxat de la pantalla)
	if not at or os.clock() - at > Constants.TRADE_INVITE_TTL then
		tellIdle(player, "That trade request expired")
		return
	end
	if tradeOf[player] or tradeOf[from] then
		return
	end
	if not together(player, from) then
		return
	end
	-- tornar-ho a mirar: entre la invitacio i el si pot haver canviat
	local reason = blockedReason(player, true) or blockedReason(from, false)
	if reason then
		tellIdle(player, reason)
		return
	end
	local t: Trade = {
		a = from,
		b = player,
		offers = { [from] = {}, [player] = {} },
		confirmed = { [from] = false, [player] = false },
		accepted = { [from] = false, [player] = false },
	}
	tradeOf[from] = t
	tradeOf[player] = t
	pushState(t)
end

function actions.decline_invite(player: Player)
	local from = inviteFrom[player]
	inviteFrom[player] = nil
	inviteAt[player] = nil
	if from and from.Parent then
		Remotes.TradeUpdate:FireClient(from, { state = "idle", reason = `{player.DisplayName} declined your trade` })
	end
end

function actions.offer(player: Player, payload: any)
	local t = tradeOf[player]
	if not t or (t.confirmed[t.a] and t.confirmed[t.b]) then
		-- Amb l'oferta bloquejada per les dues confirmacions ja no s'hi toca.
		return
	end
	if type(payload) ~= "table" then
		return
	end
	local key, delta = payload.key, payload.delta
	if not Bones.IsPieceKey(key) or (delta ~= 1 and delta ~= -1) then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local offer = t.offers[player]
	local wanted = (offer[key] or 0) + delta
	-- No es pot oferir mes del que es te ara mateix (sense les bloquejades)
	if wanted < 0 or wanted > InventoryService.TradeableCount(profile, key) then
		return
	end
	if wanted > 0 and offer[key] == nil and countKinds(offer) >= Constants.TRADE_MAX_KINDS then
		return
	end
	offer[key] = if wanted > 0 then wanted else nil
	resetConfirmations(t)
	pushState(t)
end

function actions.confirm(player: Player, value: any)
	local t = tradeOf[player]
	if not t or type(value) ~= "boolean" then
		return
	end
	t.confirmed[player] = value
	if not value then
		t.accepted[t.a] = false
		t.accepted[t.b] = false
		t.lockedAt = nil
	elseif t.confirmed[t.a] and t.confirmed[t.b] and not t.lockedAt then
		-- ofertes bloquejades: comença el compte enrere d'ACCEPT
		t.lockedAt = os.clock()
		task.delay(Constants.TRADE_ACCEPT_DELAY, function()
			-- el client torna a dibuixar el botó quan ja es pot acceptar
			if tradeOf[t.a] == t and t.lockedAt then
				pushState(t)
			end
		end)
	end
	pushState(t)
end

function actions.accept(player: Player)
	local t = tradeOf[player]
	if not t or not (t.confirmed[t.a] and t.confirmed[t.b]) then
		return
	end
	if not together(t.a, t.b) then
		closeTrade(t, "The other player left")
		return
	end
	-- massa d'hora: encara no han passat els segons per mirar l'oferta
	if not t.lockedAt or os.clock() - t.lockedAt < Constants.TRADE_ACCEPT_DELAY then
		pushState(t)
		return
	end
	t.accepted[player] = true
	if not (t.accepted[t.a] and t.accepted[t.b]) then
		pushState(t)
		return
	end

	local ok = executeTrade(t)
	closeTrade(t, if ok then "Trade complete!" else "Trade failed: an item is no longer there", ok)
	if ok then
		local a, b = t.a, t.b
		log:Info(`canvi fet: {a.Name} dona [{describe(t.offers[a])}] · {b.Name} dona [{describe(t.offers[b])}]`)
		for _, p in { a, b } do
			InventoryService.Push(p)
		end
		-- Es desen els DOS alhora, just despres. Aixo SI que cedeix el
		-- control, pero l'intercanvi ja es fet i els dos perfils son
		-- coherents; mentrestant, cap dels dos pot començar un altre canvi.
		saving[a] = true
		saving[b] = true
		lastTradeAt[a] = os.clock()
		lastTradeAt[b] = os.clock()
		local entry = (DataService.Get(a) :: any).tradeLog[1]
		task.spawn(function()
			local saved = DataService.SaveMany({ a, b })
			if not saved then
				log:Warn(`el desat del canvi entre {a.Name} i {b.Name} no s'ha pogut confirmar (el tornara a provar l'autosave)`)
			end
			saving[a] = nil
			saving[b] = nil
			audit(entry, a, b, t.offers[a], t.offers[b], saved)
		end)
	end
end

function actions.cancel(player: Player)
	local t = tradeOf[player]
	if t then
		closeTrade(t, `{player.DisplayName} cancelled the trade`)
	end
	inviteFrom[player] = nil
	inviteAt[player] = nil
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function TradeService.IsTrading(player: Player): boolean
	return tradeOf[player] ~= nil
end

function TradeService.Start()
	Remotes.TradeRequest.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if type(action) ~= "string" or not limiter:Check(player) then
			return
		end
		local handler = actions[action]
		if handler then
			handler(player, payload)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local t = tradeOf[player]
		if t then
			closeTrade(t, `{player.DisplayName} left the game`)
		end
		inviteFrom[player] = nil
		inviteAt[player] = nil
		lastRequest[player] = nil
		lastTradeAt[player] = nil
		saving[player] = nil
		for invited, from in inviteFrom do
			if from == player then
				inviteFrom[invited] = nil
				inviteAt[invited] = nil
			end
		end
	end)
end

return TradeService
