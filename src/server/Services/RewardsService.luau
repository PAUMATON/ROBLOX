--!strict

-- RewardsService — recompenses diàries, regals per estona de joc i
-- invitacions (Config/Rewards). Tot ho decideix el servidor:
--   · el dia i la ratxa surten de os.time() del servidor;
--   · l'estona de joc es compta des que el perfil ha carregat en AQUEST
--     servidor (no es desa: cada sessió torna a començar);
--   · una invitació compta si el nou jugador entra amb la LaunchData que
--     posa la invitació (l'id de qui convida) i són amics a Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Museum = require(Config:WaitForChild("Museum"))
local Rewards = require(Config:WaitForChild("Rewards"))
local Zones = require(Config:WaitForChild("Zones"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local log = Logger.new("RewardsService")

local RewardsService = {}

local limiter = RateLimiter.new(2)
local sessionStart: { [Player]: number } = {}
local giftsClaimed: { [Player]: { [number]: boolean } } = {}
local rng = Random.new()

local function notify(player: Player, message: string, icon: string)
	Remotes.Notify:FireClient(player, { kind = "shop", ok = true, message = message, icon = icon, fx = "fanfare" })
end

-- ─────────────────────────── DONAR ───────────────────────────

-- Dona una recompensa i torna el text per ensenyar-la
local function give(player: Player, reward: Rewards.Reward): string?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local p = profile :: any
	local now = os.time()
	if reward.kind == "coins" then
		local coins = Rewards.CoinsFor(Museum.IncomeRate(profile.museumLayout), reward.minutes or 0)
		profile.coins += coins
		return `+{coins} coins`
	elseif reward.kind == "money" then
		p.boostUntil = math.max(p.boostUntil or 0, now) + (reward.minutes or 0) * 60
		return `x2 Money for {reward.minutes} min`
	elseif reward.kind == "luck" then
		p.luckBoostUntil = math.max(p.luckBoostUntil or 0, now) + (reward.minutes or 0) * 60
		return `x2 Luck for {reward.minutes} min`
	elseif reward.kind == "fossil" then
		local pool = Zones.PiecesByRarity.construction[reward.rarity or "Epic"]
		if pool and #pool > 0 then
			local key = pool[rng:NextInteger(1, #pool)]
			-- bloquejat: els fòssils de regal no es poden comerciar
			InventoryService.AddBone(player, key, 1, true)
			return `a {reward.rarity} fossil`
		end
	end
	return nil
end

-- Les missions (QuestService) donen els premis per aquí mateix
RewardsService.Give = give

-- ─────────────────────────── ESTAT (per al client) ───────────────────────────

function RewardsService.State(player: Player): { [string]: any }?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local p = profile :: any
	local today = Rewards.Day(os.time())
	local last = p.daily.lastDay or -1
	local streak = p.daily.streak or 0
	-- el dia que toca avui (1..7): continua la ratxa si ahir vas cobrar
	local nextDay = if last == today - 1 then streak % #Rewards.DAILY + 1 elseif last == today then streak else 1
	return {
		dailyCan = last ~= today,
		dailyDay = nextDay, -- el que cobraràs (o el que has cobrat avui)
		dailyNextIn = (today + 1) * 86400 - os.time(),
		played = os.clock() - (sessionStart[player] or os.clock()),
		gifts = (function()
			-- claus de text: les taules amb forats no viatgen bé pels remotes
			local out = {}
			for i in giftsClaimed[player] or {} do
				out[tostring(i)] = true
			end
			return out
		end)(),
		invites = p.invites.count or 0,
	}
end

local function push(player: Player)
	Remotes.RewardUpdate:FireClient(player, RewardsService.State(player))
end

-- ─────────────────────────── COBRAR ───────────────────────────

local function claimDaily(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local p = profile :: any
	local today = Rewards.Day(os.time())
	if p.daily.lastDay == today then
		return
	end
	local streak = if p.daily.lastDay == today - 1 then (p.daily.streak or 0) % #Rewards.DAILY + 1 else 1
	local reward = Rewards.DAILY[streak]
	local text = give(player, reward)
	if not text then
		return
	end
	p.daily.lastDay = today
	p.daily.streak = streak
	InventoryService.Push(player)
	push(player)
	notify(player, `Day {streak} reward: {text}!`, reward.icon)
	task.spawn(DataService.Save, player)
end

local function claimGift(player: Player, index: any)
	if type(index) ~= "number" or index ~= math.floor(index) then
		return
	end
	local gift = Rewards.GIFTS[index]
	local claimed = giftsClaimed[player]
	if not gift or not claimed or claimed[index] or not sessionStart[player] then
		return
	end
	if os.clock() - sessionStart[player] < gift.at * 60 then
		return -- encara no
	end
	local text = give(player, gift.reward)
	if not text then
		return
	end
	claimed[index] = true
	InventoryService.Push(player)
	push(player)
	notify(player, `Gift: {text}!`, gift.reward.icon)
end

-- ─────────────────────────── INVITACIONS ───────────────────────────

local function checkInvite(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	local launch = ok and data and data.LaunchData
	local inviterId = tonumber(launch)
	if not inviterId or inviterId == player.UserId then
		return
	end
	local inviter = Players:GetPlayerByUserId(inviterId)
	local inviterProfile = inviter and DataService.Get(inviter)
	if not inviter or not inviterProfile then
		return
	end
	local friends = false
	pcall(function()
		friends = player:IsFriendsWith(inviterId)
	end)
	if not friends then
		return
	end
	local inv = (inviterProfile :: any).invites
	inv.rewarded = inv.rewarded or {}
	local key = tostring(player.UserId)
	if inv.rewarded[key] or (inv.count or 0) >= Rewards.MAX_INVITES then
		return
	end
	inv.rewarded[key] = true
	inv.count = (inv.count or 0) + 1
	local a = give(inviter, Rewards.INVITER)
	local b = give(inviter, Rewards.INVITER_COINS)
	InventoryService.Push(inviter)
	push(inviter)
	notify(inviter, `{player.DisplayName} joined from your invite! {a} and {b}`, "💌")
	local c = give(player, Rewards.INVITEE)
	InventoryService.Push(player)
	notify(player, `You joined with {inviter.DisplayName}'s invite: {c}!`, "🎁")
	log:Info(`{inviter.Name} ha convidat {player.Name}`)
	task.spawn(DataService.Save, inviter)
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function RewardsService.Init()
	DataService.ProfileLoaded:Connect(function(player: Player)
		sessionStart[player] = os.clock()
		giftsClaimed[player] = {}
		task.defer(function()
			push(player)
			checkInvite(player)
		end)
	end)
end

function RewardsService.Start()
	Remotes.RewardRequest.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if not limiter:Check(player) then
			return
		end
		if action == "daily" then
			claimDaily(player)
		elseif action == "gift" then
			claimGift(player, payload)
		elseif action == "state" then
			push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessionStart[player] = nil
		giftsClaimed[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) and not sessionStart[player] then
			sessionStart[player] = os.clock()
			giftsClaimed[player] = {}
			push(player)
		end
	end
end

return RewardsService
