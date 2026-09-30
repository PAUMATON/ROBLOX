--!strict

-- VisitorService — els visitants dels museus i les propines (Config/Visitors).
--
-- El servidor NO mou cap personatge: només decideix les visites (quan
-- arriben, quines vitrines miren, quant temps) i les envia als clients, que
-- dibuixen els visitants localment (VisitorController). Així no costa res
-- al servidor ni a la xarxa, i tothom els veu igual perquè el camí surt del
-- mateix codi (Util/VisitorPath) i de la mateixa hora del servidor.
--
-- La PROPINA la decideix el servidor en el moment que el visitant és davant
-- la vitrina (amb el que hi ha exposat en AQUELL moment), i la cobra l'amo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Museum = require(Config:WaitForChild("Museum"))
local Visitors = require(Config:WaitForChild("Visitors"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local VisitorPath = require(Shared:WaitForChild("Util"):WaitForChild("VisitorPath"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MuseumService = require(script.Parent.MuseumService)

local VisitorService = {}

type Visit = {
	id: number,
	plot: Model,
	owner: Player,
	t0: number, -- hora del servidor en què entra
	slots: { number },
	looks: { number },
	sides: { number },
	look: string, -- nom del model de visitant a ReplicatedStorage.VisitorRigs
	plan: VisitorPath.Plan,
}

local rng = Random.new()
local nextId = 0
local active: { [Model]: { Visit } } = {}
local nextArrival: { [Model]: number } = {}
local NUM_LOOKS = 10 -- personatges genèrics (si ningú del servidor té amics)
local MAX_FRIEND_RIGS = 60 -- avatars d'amics guardats alhora
local rigFolder: Folder
local friendPool: { number } = {} -- tots els amics de tots els jugadors del servidor (sense repetir)
local friendsOf: { [Player]: { number } } = {}
local friendRigOrder: { string } = {}

-- ─────────────────────────── ELS VISITANTS (models) ───────────────────────────
-- Uns quants personatges fets un cop a ReplicatedStorage; els clients els cloneN.
local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(140, 94, 64), Color3.fromRGB(96, 64, 46) }
local SHIRT = { Color3.fromRGB(240, 80, 80), Color3.fromRGB(70, 150, 230), Color3.fromRGB(90, 190, 110), Color3.fromRGB(250, 200, 60), Color3.fromRGB(170, 110, 230), Color3.fromRGB(245, 245, 240), Color3.fromRGB(255, 140, 60), Color3.fromRGB(60, 60, 70) }
local PANTS = { Color3.fromRGB(50, 60, 90), Color3.fromRGB(40, 40, 44), Color3.fromRGB(120, 96, 70), Color3.fromRGB(90, 110, 140) }

local function prepareRig(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Anchored = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function buildRigs()
	local folder = Instance.new("Folder")
	folder.Name = "VisitorRigs"
	local rr = Random.new(2024)
	for i = 1, NUM_LOOKS do
		local ok, rig = pcall(function()
			local d = Instance.new("HumanoidDescription")
			local skin = SKIN[rr:NextInteger(1, #SKIN)]
			d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
			d.TorsoColor = SHIRT[rr:NextInteger(1, #SHIRT)]
			local pants = PANTS[rr:NextInteger(1, #PANTS)]
			d.LeftLegColor, d.RightLegColor = pants, pants
			d.HeightScale = rr:NextNumber(0.9, 1.05)
			return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
		end)
		if ok and rig then
			local model = rig :: Model
			model.Name = "Visitor" .. i
			prepareRig(model)
			model.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
	rigFolder = folder
end

-- ─────────────────────────── AMICS ───────────────────────────
-- Els visitants són els AMICS de tots els jugadors del servidor, amb el seu
-- avatar de debò. Tots amb la mateixa probabilitat (sense repetir: si dos
-- jugadors tenen el mateix amic, compta un cop).

local function rebuildPool()
	local seen, pool = {}, {}
	for _, list in friendsOf do
		for _, id in list do
			if not seen[id] then
				seen[id] = true
				table.insert(pool, id)
			end
		end
	end
	friendPool = pool
end

local function loadFriends(player: Player)
	local list = {}
	local ok, pages = pcall(Players.GetFriendsAsync, Players, player.UserId)
	if ok and pages then
		while true do
			for _, f in pages:GetCurrentPage() do
				table.insert(list, f.Id)
			end
			if pages.IsFinished or #list >= 200 then
				break
			end
			local okNext = pcall(pages.AdvanceToNextPageAsync, pages)
			if not okNext then
				break
			end
		end
	end
	if player.Parent then
		friendsOf[player] = list
		rebuildPool()
	end
end

-- El model de l'avatar d'un amic (es fa un cop i es guarda)
local function friendRig(userId: number): string?
	local name = "U" .. userId
	if rigFolder:FindFirstChild(name) then
		return name
	end
	local ok, rig = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(userId)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		return nil
	end
	local model = rig :: Model
	model.Name = name
	prepareRig(model)
	model.Parent = rigFolder
	table.insert(friendRigOrder, name)
	-- no en guardem infinits: fora el més antic
	if #friendRigOrder > MAX_FRIEND_RIGS then
		local old = rigFolder:FindFirstChild(table.remove(friendRigOrder, 1) :: string)
		if old then
			old:Destroy()
		end
	end
	return name
end

-- L'aparença d'un visitant nou: un amic a l'atzar, o un genèric si no n'hi ha
local function pickLook(): string
	if #friendPool > 0 then
		for _ = 1, 3 do
			local look = friendRig(friendPool[rng:NextInteger(1, #friendPool)])
			if look then
				return look
			end
		end
	end
	return "Visitor" .. rng:NextInteger(1, NUM_LOOKS)
end

-- ─────────────────────────── VISITES ───────────────────────────

local function filledSlots(layout: { [string]: any }): { number }
	local out = {}
	for slot = 1, Museum.SLOTS do
		if type(layout[tostring(slot)]) == "string" then
			table.insert(out, slot)
		end
	end
	return out
end

local function visitData(v: Visit): { [string]: any }
	return { id = v.id, plot = v.plot, t0 = v.t0, slots = v.slots, looks = v.looks, sides = v.sides, look = v.look }
end

-- Tria vitrines: les més rares criden més (pes = 1 + ordre de raresa)
local function pickSlots(layout: { [string]: any }, filled: { number }): { number }
	local want = math.min(rng:NextInteger(Visitors.STOPS[1], Visitors.STOPS[2]), #filled)
	local pool = table.clone(filled)
	local out = {}
	for _ = 1, want do
		local total = 0
		local weights = {}
		for i, slot in pool do
			local item = layout[tostring(slot)]
			local w = 1 + (Bones.RARITY_ORDER[Bones.RarityOf(item)] or 1)
			weights[i] = w
			total += w
		end
		local r = rng:NextNumber() * total
		for i, w in weights do
			r -= w
			if r <= 0 then
				table.insert(out, table.remove(pool, i) :: number)
				break
			end
		end
	end
	-- per ordre de la visita: de davant cap al fons, com faria una persona
	table.sort(out, function(a, b)
		return VisitorPath.CASES[a].Z < VisitorPath.CASES[b].Z
	end)
	return out
end

local function tip(v: Visit, stop: number)
	if not v.owner.Parent then
		return
	end
	local profile = DataService.Get(v.owner)
	if not profile then
		return
	end
	local item = profile.museumLayout[tostring(v.slots[stop])]
	if type(item) ~= "string" then
		return -- l'han tret mentrestant
	end
	local chance = Visitors.TIP_CHANCE[Bones.RarityOf(item)] or 0
	if Bones.IsSkeletonItem(item) then
		chance *= Visitors.SKELETON_CHANCE
	end
	if rng:NextNumber() >= chance then
		return
	end
	local minutes = rng:NextNumber(Visitors.TIP_MINUTES[1], Visitors.TIP_MINUTES[2])
	local wow = rng:NextInteger(1, Visitors.WOW_ODDS) == 1
	local mult = Monetization.MoneyMultiplier(profile.gamepasses, profile.boostUntil)
	local amount = math.max(Visitors.MIN_TIP, math.floor(Bones.IncomeOf(item) * minutes * mult * (if wow then Visitors.WOW_MULT else 1)))
	profile.coins += amount
	InventoryService.Push(v.owner)
	Remotes.VisitorUpdate:FireAllClients({ type = "tip", plot = v.plot, id = v.id, amount = amount, wow = wow, owner = v.owner.UserId })
end

local function spawnVisit(owner: Player, plot: Model, layout: { [string]: any }, filled: { number })
	nextId += 1
	local id = nextId
	local slots = pickSlots(layout, filled)
	local looks, sides = {}, {}
	for i = 1, #slots do
		looks[i] = rng:NextNumber(Visitors.LOOK_TIME[1], Visitors.LOOK_TIME[2])
		sides[i] = if rng:NextNumber() < 0.5 then -1 else 1
	end
	local v: Visit = {
		id = id,
		plot = plot,
		owner = owner,
		t0 = workspace:GetServerTimeNow() + 0.5,
		slots = slots,
		looks = looks,
		sides = sides,
		look = pickLook(),
		plan = VisitorPath.Plan(slots, looks, sides),
	}
	local list = active[plot] or {}
	active[plot] = list
	table.insert(list, v)
	Remotes.VisitorUpdate:FireAllClients({ type = "spawn", visit = visitData(v) })
	-- les propines, cadascuna en el seu moment
	for stop, t in v.plan.stopTimes do
		task.delay(0.5 + t + Visitors.TIP_AT, function()
			tip(v, stop)
		end)
	end
	-- i fora de la llista quan surt
	task.delay(0.5 + v.plan.duration + 1, function()
		local l = active[plot]
		if l then
			local i = table.find(l, v)
			if i then
				table.remove(l, i)
			end
		end
	end)
end

local function tick()
	local now = os.clock()
	for _, owner in Players:GetPlayers() do
		local plot = MuseumService.GetPlot(owner)
		local profile = DataService.Get(owner)
		if plot and profile then
			local filled = filledSlots(profile.museumLayout)
			local list = active[plot] or {}
			if #filled > 0 and #list < Visitors.MAX_ACTIVE and now >= (nextArrival[plot] or 0) then
				local every = Visitors.ArriveEvery(#filled, Museum.SLOTS)
				nextArrival[plot] = now + every * rng:NextNumber(0.7, 1.3)
				-- a part: carregar l'avatar d'un amic pot trigar una mica
				task.spawn(spawnVisit, owner, plot, profile.museumLayout, filled)
			end
		end
	end
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function VisitorService.Init()
	buildRigs()
end

function VisitorService.Start()
	-- qui entra rep les visites que ja són en marxa
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(loadFriends, player)
		task.wait(3)
		local all = {}
		for _, list in active do
			for _, v in list do
				table.insert(all, visitData(v))
			end
		end
		Remotes.VisitorUpdate:FireClient(player, { type = "snapshot", visits = all })
	end)
	-- quan un museu canvia d'amo, els seus visitants marxen
	for _, player in Players:GetPlayers() do
		task.spawn(loadFriends, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		friendsOf[player] = nil
		rebuildPool()
		for plot, list in active do
			for i = #list, 1, -1 do
				if list[i].owner == player then
					Remotes.VisitorUpdate:FireAllClients({ type = "remove", plot = plot, id = list[i].id })
					table.remove(list, i)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return VisitorService
