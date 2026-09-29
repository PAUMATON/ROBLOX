--!strict

-- QuestService — la missió en curs de cada jugador (Config/Quests).
--
-- El progrés NO el diu mai el client: surt del perfil (Quests.Progress).
-- El client només demana "claim"; el servidor mira que la missió estigui
-- complerta, dona el premi i passa a la següent. Cada cop que el perfil
-- canvia (InventoryService.Pushed) es torna a mirar i, si ha canviat res,
-- s'envia el nou estat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Quests = require(Config:WaitForChild("Quests"))
local Museum = require(Config:WaitForChild("Museum"))
local Rewards = require(Config:WaitForChild("Rewards"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local RewardsService = require(script.Parent.RewardsService)

local log = Logger.new("QuestService")

local QuestService = {}

local limiter = RateLimiter.new(2)
local lastSent: { [Player]: string } = {} -- per no enviar el mateix estat dues vegades

-- Fixa la base de la missió en curs si encara no en té (missió nova, o
-- perfil d'abans de les missions)
local function ensureBase(profile: DataService.Profile)
	local q = profile.quests
	if type(q.index) ~= "number" or q.index < 1 then
		q.index = 1
	end
	local quest = Quests.Get(q.index)
	-- La base és d'una altra missió (s'ha canviat l'ordre de la cadena en una
	-- actualització): es torna a començar a comptar. Les bases d'abans que
	-- existís `baseFor` es respecten (nil = no se sap, però era aquesta).
	if q.base ~= nil and q.baseFor ~= nil and q.baseFor ~= quest.text then
		q.base = nil
	end
	if q.base == nil then
		q.base = Quests.Value(profile, quest)
	end
	q.baseFor = quest.text
end

local function stateFor(profile: DataService.Profile): { [string]: any }
	ensureBase(profile)
	local q = profile.quests
	local quest = Quests.Get(q.index)
	local progress, target = Quests.Progress(profile, quest, q.base)
	local reward = quest.reward
	local rewardText = if reward.kind == "coins"
		then `+{Rewards.CoinsFor(Museum.IncomeRate(profile.museumLayout), reward.minutes)} $`
		else `{reward.icon} {reward.label}`
	return {
		index = q.index,
		chain = #Quests.CHAIN,
		text = quest.text,
		progress = progress,
		target = target,
		done = progress >= target,
		-- la renda es compta per minut però es veu per segon
		progressText = if quest.stat == "income"
			then `{Museum.PerSecondText(progress)}/{Museum.PerSecondText(target)} $/s`
			else nil,
		go = quest.go,
		reward = rewardText,
	}
end

local function push(player: Player, force: boolean?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local state = stateFor(profile)
	local sig = `{state.index}|{state.progress}|{state.reward}`
	if not force and lastSent[player] == sig then
		return
	end
	lastSent[player] = sig
	Remotes.QuestUpdate:FireClient(player, state)
end

local function claim(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	ensureBase(profile)
	local q = profile.quests
	local quest = Quests.Get(q.index)
	local progress, target = Quests.Progress(profile, quest, q.base)
	if progress < target then
		return
	end
	local text = RewardsService.Give(player, quest.reward :: any)
	if not text then
		return
	end
	-- la següent: la seva base és el valor d'ARA
	q.index += 1
	q.base = Quests.Value(profile, Quests.Get(q.index))
	q.baseFor = Quests.Get(q.index).text
	log:Info(`{player.Name} ha acabat la missió {q.index - 1} ({quest.text})`)
	Remotes.Notify:FireClient(player, { kind = "shop", ok = true, icon = "📜", message = `Quest complete! {text}`, fx = "fanfare" })
	InventoryService.Push(player) -- (això ja torna a enviar l'estat de la missió)
	push(player, true)
	task.spawn(DataService.Save, player)
end

function QuestService.Init()
	InventoryService.Pushed:Connect(function(player: Player)
		push(player)
	end)
	DataService.ProfileLoaded:Connect(function(player: Player)
		task.defer(push, player, true)
	end)
end

function QuestService.Start()
	Remotes.QuestRequest.OnServerEvent:Connect(function(player: Player, action: any)
		if not limiter:Check(player) then
			return
		end
		if action == "claim" then
			claim(player)
		elseif action == "state" then
			push(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		push(player, true)
	end
end

return QuestService
