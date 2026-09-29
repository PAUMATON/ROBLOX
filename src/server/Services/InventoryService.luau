--!strict

-- InventoryService — l'unic lloc que toca ossos i esquelets del perfil, i
-- l'unic que envia l'estat del perfil al client.
--
-- Els altres serveis (excavar, museu, comerc) no fan `ownedBones[x] += 1`
-- pel seu compte: criden aqui. Aixi la regla "cap accio abans que el perfil
-- hagi carregat" es comprova en un sol lloc.
--
-- FOSSILS BLOQUEJATS: els de recompensa (diaria, regals) no es poden
-- comerciar; si no, els comptes secundaris farien de granja per al
-- principal. `lockedBones[clau]` diu quantes de les `ownedBones[clau]` ho
-- son, i sempre n'hi ha menys o igual. Quan una peça surt de la motxilla
-- (vendre, exposar, muntar) surt primer una de bloquejada: al jugador li
-- queden les que SI pot comerciar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Constants = require(Config:WaitForChild("Constants"))
local Museum = require(Config:WaitForChild("Museum"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

local InventoryService = {}

-- Es dispara després de cada Push (el perfil ha canviat i el client ho sap):
-- les missions s'hi enganxen per tornar a mirar el progrés.
InventoryService.Pushed = Signal.new() -- (player, profile)

-- Treu `n` d'una entrada d'un recompte i esborra la clau si queda a zero:
-- el perfil no s'omple de zeros que despres viatgen a cada ProfileUpdate.
local function take(counts: { [string]: number }, key: string, n: number)
	local left = (counts[key] or 0) - n
	counts[key] = if left > 0 then left else nil
end

-- ─────────────────────────── OSSOS ───────────────────────────

function InventoryService.CountBone(profile: Profile, key: string): number
	return profile.ownedBones[key] or 0
end

-- Les que es poden posar en un canvi (les de la motxilla menys les bloquejades)
function InventoryService.TradeableCount(profile: Profile, key: string): number
	return math.max(0, (profile.ownedBones[key] or 0) - (profile.lockedBones[key] or 0))
end

-- `locked` a true: és una recompensa i no es podrà comerciar.
function InventoryService.AddBone(player: Player, key: string, n: number?, locked: boolean?): boolean
	local profile = DataService.Get(player)
	if not profile or not Bones.IsPieceKey(key) then
		return false
	end
	local amount = n or 1
	profile.ownedBones[key] = (profile.ownedBones[key] or 0) + amount
	if locked then
		profile.lockedBones[key] = (profile.lockedBones[key] or 0) + amount
	end
	profile.discovered[key] = true
	profile.stats.totalBones += amount
	return true
end

-- Mou peces d'un recompte a l'altre. Nomes per al comerc, que ja ho ha
-- validat tot abans amb TradeableCount (i no fa cap yield entre validar i
-- cridar aixo). Com que nomes surten peces comerciables, les bloquejades de
-- `from` no es toquen, i les que rep `to` arriben lliures.
function InventoryService.MoveBones(from: Profile, to: Profile, offer: { [string]: number })
	for key, n in offer do
		take(from.ownedBones, key, n)
		to.ownedBones[key] = (to.ownedBones[key] or 0) + n
		to.discovered[key] = true -- el que et donen també compta per a l'índex
	end
end

-- Treu una peça de la motxilla (per exposar-la o vendre-la). Si n'hi ha de
-- bloquejades, surt una d'aquestes. Torna (hi era, era bloquejada).
function InventoryService.TakeBone(profile: Profile, key: string): (boolean, boolean)
	if (profile.ownedBones[key] or 0) < 1 then
		return false, false
	end
	take(profile.ownedBones, key, 1)
	local wasLocked = (profile.lockedBones[key] or 0) > 0
	if wasLocked then
		take(profile.lockedBones, key, 1)
	end
	return true, wasLocked
end

-- Torna una peça a la motxilla (de la vitrina), bloquejada si ho era.
function InventoryService.GiveBone(profile: Profile, key: string, locked: boolean?)
	profile.ownedBones[key] = (profile.ownedBones[key] or 0) + 1
	if locked then
		profile.lockedBones[key] = (profile.lockedBones[key] or 0) + 1
	end
end

-- Segons que falten perquè pugui comerciar (0 = ja pot). A Studio, 0: si
-- no, provar el comerç voldria dir esperar mitja hora cada cop.
function InventoryService.TradeWait(player: Player): number
	if RunService:IsStudio() then
		return 0
	end
	return math.max(0, Constants.TRADE_MIN_PLAY_MINUTES * 60 - DataService.PlaySeconds(player))
end

-- ────────────────────────── ESQUELETS ──────────────────────────

-- Gasta una peca de cada i suma un esquelet muntat. O tot o res.
function InventoryService.Assemble(player: Player, skeletonId: string): boolean
	local profile = DataService.Get(player)
	if not profile or not Bones.CanAssemble(profile.ownedBones, skeletonId) then
		return false
	end
	for _, piece in Bones.PiecesOf(skeletonId) do
		InventoryService.TakeBone(profile, Bones.PieceKey(skeletonId, piece.id))
	end
	profile.ownedSkeletons[skeletonId] = (profile.ownedSkeletons[skeletonId] or 0) + 1
	profile.stats.totalAssembled += 1
	return true
end

function InventoryService.TakeSkeleton(profile: Profile, skeletonId: string): boolean
	if (profile.ownedSkeletons[skeletonId] or 0) < 1 then
		return false
	end
	take(profile.ownedSkeletons, skeletonId, 1)
	return true
end

function InventoryService.GiveSkeleton(profile: Profile, skeletonId: string)
	profile.ownedSkeletons[skeletonId] = (profile.ownedSkeletons[skeletonId] or 0) + 1
end

-- ───────────────────────── AL CLIENT ─────────────────────────

-- Instantania sencera del perfil. Es petita (desenes de claus) i aixi el
-- client no ha de reconstruir res a partir de diferencies.
function InventoryService.Push(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	Remotes.ProfileUpdate:FireClient(player, {
		coins = math.floor(profile.coins),
		bones = profile.ownedBones,
		locked = profile.lockedBones,
		tradeWait = InventoryService.TradeWait(player),
		skeletons = profile.ownedSkeletons,
		museum = profile.museumLayout,
		rate = Museum.IncomeRate(profile.museumLayout),
		cap = Museum.INCOME_CAP,
		slots = Museum.SLOTS,
		zones = profile.unlockedZones,
		discovered = profile.discovered,
		tools = profile.ownedTools,
		equippedTool = profile.equippedTool,
		digs = profile.stats.totalDigs,
		settings = profile.settings,
		passes = profile.gamepasses,
		money = Monetization.MoneyMultiplier(profile.gamepasses, profile.boostUntil),
		boostLeft = math.max(0, profile.boostUntil - os.time()),
		luckBoostLeft = math.max(0, profile.luckBoostUntil - os.time()),
		hasteLeft = math.max(0, profile.digBoostUntil - os.time()),
		potions = profile.potions,
		persisted = DataService.IsPersisted(player),
	})
	InventoryService.Pushed:Fire(player, profile)
end

function InventoryService.Init()
	DataService.ProfileLoaded:Connect(function(player: Player, profile: Profile)
		-- perfils d'abans de l'índex: el que tens ja està descobert
		for key in profile.ownedBones do
			profile.discovered[key] = true
		end
		-- Mai més bloquejades que les que hi ha (si alguna cosa s'ha
		-- desquadrat, guanya el jugador: sobren bloquejos, no peces).
		for key, n in profile.lockedBones do
			local owned = profile.ownedBones[key] or 0
			if type(n) ~= "number" or n < 1 or owned < 1 then
				profile.lockedBones[key] = nil
			elseif n > owned then
				profile.lockedBones[key] = owned
			end
		end
		for slot, item in profile.museumLayout do
			if Bones.IsPieceKey(item) then
				profile.discovered[item] = true
			end
		end
		InventoryService.Push(player)
	end)
end

function InventoryService.Start()
	-- Qui ja estigues carregat abans que ens connectessim.
	for _, player in Players:GetPlayers() do
		InventoryService.Push(player)
	end
end

return InventoryService
