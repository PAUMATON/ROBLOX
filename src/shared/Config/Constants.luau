--!strict

-- Constants globals. Un unic lloc per a tot el que pot canviar sense redisenya.
-- Aqui, no dins de cada servei.

export type Constants = {
	-- Excavacio
	DIG_COOLDOWN: number,
	MAX_DIG_DISTANCE: number,

	-- Dades
	-- (la versio de l'esquema del perfil viu a ProfileSchema.VERSION, no
	--  aqui: declarar-la dos cops es com acaben divergint)
	AUTOSAVE_INTERVAL: number,
	SAVE_ATTEMPTS: number,
	SAVE_BACKOFF: { number },
	MIN_WRITE_BUDGET: number,
	OFFLINE_CAP_HOURS: number,

	-- Session locking
	SESSION_LOCK_TIMEOUT: number,
	SESSION_HEARTBEAT_INTERVAL: number,
	SESSION_LOCK_ATTEMPTS: number,
	SESSION_LOCK_RETRY_WAIT: number,

	-- Comerc
	TRADE_REQUEST_COOLDOWN: number,
	TRADE_MAX_KINDS: number,
	TRADE_MIN_PLAY_MINUTES: number,
	TRADE_LOG_SIZE: number,
	TRADE_UNFAIR_RATIO: number,
	TRADE_INVITE_TTL: number,
	TRADE_ACCEPT_DELAY: number,
	TRADE_AFTER_COOLDOWN: number,

	-- Monetitzacio
	MAX_LUCK: number,

	-- Debug
	DEBUG: boolean,
}

local Constants: Constants = {
	DIG_COOLDOWN = 1.2,
	MAX_DIG_DISTANCE = 12,

	AUTOSAVE_INTERVAL = 120,
	-- Un intent i tres reintents. L'espera va DESPRES de cada intent fallit i
	-- nomes si encara en queda un altre, o sigui 1s + 2s + 4s. Si la posessim
	-- sempre, el quart intent fallit encara faria esperar per res.
	SAVE_ATTEMPTS = 4,
	SAVE_BACKOFF = { 1, 2, 4 },
	-- Per sota d'aquest pressupost d'escriptura, l'autosave passa de llarg i
	-- ho deixa per al cicle seguent. Alliberar el lock, en canvi, no espera
	-- mai: no hi ha cap cicle seguent per a un jugador que marxa.
	MIN_WRITE_BUDGET = 5,
	OFFLINE_CAP_HOURS = 8,

	-- Un lock amb el batec mes vell que SESSION_LOCK_TIMEOUT es considera
	-- mort: el servidor que el tenia ha caigut. L'interval de batec ha de
	-- ser bastant mes petit que el timeout, si no una partida normal es
	-- quedaria sense lock a mitges.
	SESSION_LOCK_TIMEOUT = 60,
	SESSION_HEARTBEAT_INTERVAL = 20,
	SESSION_LOCK_ATTEMPTS = 3,
	SESSION_LOCK_RETRY_WAIT = 5,

	-- Es pot comerciar amb qualsevol jugador del servidor, sense importar
	-- on sigui. El cooldown evita que algu empipi a tothom amb peticions.
	TRADE_REQUEST_COOLDOWN = 3,
	-- Tipus de peca diferents per oferta: posa sostre a la mida del remote.
	TRADE_MAX_KINDS = 12,
	-- Estona de joc (total, no d'una sessió) abans de poder comerciar. Frena
	-- els comptes secundaris que només entren per passar coses al principal.
	-- A Studio no compta, per poder provar el comerç.
	TRADE_MIN_PLAY_MINUTES = 30,
	-- Canvis que es guarden al perfil de cada jugador (el més nou primer)
	TRADE_LOG_SIZE = 30,
	-- Avís a la finestra de comerç si dones X vegades més renda de la que reps
	TRADE_UNFAIR_RATIO = 3,
	-- Una invitació caduca als X segons (el servidor, no només l'avís)
	TRADE_INVITE_TTL = 20,
	-- Quan tots dos confirmen, ACCEPT no funciona fins passats X segons: dona
	-- temps de mirar l'oferta final (la trampa clàssica és canviar-la i
	-- esperar que l'altre accepti sense mirar)
	TRADE_ACCEPT_DELAY = 3,
	-- Segons entre acabar un canvi i poder-ne començar un altre
	TRADE_AFTER_COOLDOWN = 5,

	-- sostre de sort total: paleta (x3) × passi de sort (x32)
	MAX_LUCK = 96,
	DEBUG = true,
}

return Constants
