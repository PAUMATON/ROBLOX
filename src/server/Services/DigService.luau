--!strict

-- DigService — el minijoc d'excavacio i el botí.
--
-- AUTORITAT TOTAL AL SERVIDOR: el client nomes diu "vull cavar aquest munt"
-- i "he clicat". On era la linia en el moment del clic ho recalcula el
-- servidor amb el seu rellotge (Config/Dig.MarkerAt). Que surt, quina
-- raresa i a quin perfil va, tambe.
--
-- Validacions de "start": tipus, etiqueta DigSpot, zona coneguda i
-- desbloquejada, munt ple, perfil carregat, cooldown, pala i distancia.
--
-- Es pot arrencar de dues maneres: clicant el munt amb la pala (ordinador)
-- o amb el boto "Dig" del ProximityPrompt del munt (mobil i consola).
-- Totes dues passen per la mateixa funcio i les mateixes validacions.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Constants = require(Config:WaitForChild("Constants"))
local Dig = require(Config:WaitForChild("Dig"))
local Tools = require(Config:WaitForChild("Tools"))
local Museum = require(Config:WaitForChild("Museum"))
local Zones = require(Config:WaitForChild("Zones"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Logger = require(Shared:WaitForChild("Util"):WaitForChild("Logger"))
local RateLimiter = require(Shared:WaitForChild("Util"):WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ToolService = require(script.Parent.ToolService)
local PotionService = require(script.Parent.PotionService)
local Potions = require(Config:WaitForChild("Potions"))
local Monetization = require(Config:WaitForChild("Monetization"))

local log = Logger.new("DigService")

local DigService = {}

type Session = {
	id: number,
	spot: BasePart,
	zone: string,
	toolLuck: number, -- de l'eina equipada en començar (no canvia a mitges)
	startTime: number, -- quan surt la línia de l'intent actual (temps del servidor)
	center: number, -- on és la franja verda de l'intent actual
	speed: number,
	attempts: number,
	total: number,
	lastClick: number,
	golden: boolean, -- era un munt daurat quan va començar
}

local sessions: { [Player]: Session } = {}
local lastDig: { [Player]: number } = {}
local nextSessionId = 0

-- Un limitador per tipus d'accio: arrencar es car, clicar es barat.
local startLimiter = RateLimiter.new(1)
local clickLimiter = RateLimiter.new(8)
local rng = Random.new()

-- ─────────────────────────── BOTI ───────────────────────────

-- Primer la raresa (només les que hi ha a la zona: Regla de zones), i
-- després UNA peça d'aquella raresa, totes igual de probables. No hi ha
-- pietat: el que ja tens no fa més ni menys probable el que et falta.
local function rollPiece(zoneId: string, bonus: number, toolLuck: number): string?
	local byRarity = Zones.PiecesByRarity[zoneId]
	if not byRarity then
		return nil
	end
	local weights = Dig.RarityChances(Dig.LuckMultiplier(bonus, toolLuck), byRarity)
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber() * total
	local rarity: string? = nil
	for _, r in Bones.RARITIES do
		local w = weights[r]
		if w then
			roll -= w
			if roll <= 0 then
				rarity = r
				break
			end
		end
	end
	if not rarity then
		-- (per errors d'arrodoniment) l'última raresa present
		for _, r in Bones.RARITIES do
			if weights[r] then
				rarity = r
			end
		end
	end
	local pool = byRarity[rarity :: string]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- ─────────────────────────── MUNTS ───────────────────────────
-- Un munt excavat s'encongeix i queda buit Dig.RESPAWN_TIME segons. L'estat
-- es un atribut del munt (EmptyUntil, en temps del servidor): el veuen tots
-- els clients, pero nomes el servidor el canvia.

-- Munt daurat (esdeveniment): atribut Golden = fins quan (temps del servidor)
local function isGolden(spot: BasePart): boolean
	local untilTime = spot:GetAttribute("Golden")
	return type(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
end

local function isDepleted(spot: BasePart): boolean
	local untilTime = spot:GetAttribute("EmptyUntil")
	return type(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
end

local function originalSize(spot: BasePart): Vector3
	local size = spot:GetAttribute("FullSize")
	if typeof(size) ~= "Vector3" then
		spot:SetAttribute("FullSize", spot.Size)
		return spot.Size
	end
	return size
end

local function setPrompt(spot: BasePart, enabled: boolean)
	local prompt = spot:FindFirstChild("DigPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

-- El que hi ha damunt del munt (l'os que treu el nas, pedretes): peces
-- filles amb l'atribut Fill. Quan el munt és buit, no hi són.
local function setFill(spot: BasePart, visible: boolean)
	for _, child in spot:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Fill") then
			TweenService:Create(child, TweenInfo.new(0.3), { Transparency = if visible then 0 else 1 }):Play()
		end
	end
end

local function deplete(spot: BasePart)
	if not spot.Parent then
		return
	end
	local full = originalSize(spot)
	local untilTime = workspace:GetServerTimeNow() + Dig.RESPAWN_TIME
	spot:SetAttribute("EmptyUntil", untilTime)
	setPrompt(spot, false)
	setFill(spot, false)
	TweenService:Create(spot, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = full * Dig.DEPLETED_SCALE,
	}):Play()
	task.delay(Dig.RESPAWN_TIME, function()
		-- Si mentrestant l'ha buidat un altre, ja el tornara a omplir aquell
		if spot.Parent and spot:GetAttribute("EmptyUntil") == untilTime then
			spot:SetAttribute("EmptyUntil", nil)
			setPrompt(spot, true)
			setFill(spot, true)
			TweenService:Create(spot, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = full }):Play()
		end
	end)
end

-- ─────────────────────────── SESSIO ───────────────────────────

local function deny(player: Player, reason: string)
	Remotes.DigUpdate:FireClient(player, { phase = "denied", reason = reason })
end

local function finish(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	deplete(session.spot)

	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local key = rollPiece(session.zone, session.total, session.toolLuck)
	profile.stats.totalDigs += 1
	-- Renda activa: monedes per cada excavació, més com millor ho fas
	local zone = Zones.ById[session.zone]
	local coins = if zone then Dig.CoinsFor(zone.coinsPerDig, session.total) else 0
	coins = math.floor(coins * Monetization.MoneyMultiplier(profile.gamepasses, profile.boostUntil) * (if session.golden then Dig.GOLDEN_COINS else 1))
	profile.coins += coins
	local isNew = key ~= nil and not profile.discovered[key]
	local stored = key ~= nil and InventoryService.AddBone(player, key)
	if stored and key then
		-- per a les missions "troba un fòssil X" (només compta el que s'excava)
		local r = Bones.PieceInfo[key].rarity
		profile.stats.rarityFinds[r] = (profile.stats.rarityFinds[r] or 0) + 1
	end
	-- de tant en tant, una poció de regal (i sempre, al munt daurat)
	local potion = PotionService.RollDrop(player)
	if session.golden and PotionService.Give(player, Dig.GOLDEN_POTION, 1) then
		potion = Dig.GOLDEN_POTION
	end
	InventoryService.Push(player)

	local text, rarity = nil, nil
	if key then
		text, rarity = Bones.Describe(key)
	end
	-- una troballa grossa s'anuncia a tot el servidor
	if rarity == "Legendary" or rarity == "Mythic" or rarity == "Secret" then
		Remotes.Notify:FireAllClients({
			kind = "announce",
			rarity = rarity,
			userId = player.UserId, -- (qui l'ha trobat ja té la seva carta: no li cal l'avís)
			message = `{player.DisplayName} found a {string.upper(rarity :: string)} fossil: {text}!`,
		})
	end
	Remotes.DigUpdate:FireClient(player, {
		phase = "result",
		bonus = session.total,
		key = key,
		text = text,
		rarity = rarity,
		coins = coins,
		luck = Dig.LuckMultiplier(session.total, session.toolLuck),
		new = isNew,
		stored = stored and DataService.IsPersisted(player),
		potion = potion,
	})
end

local function onStart(player: Player, spot: any)
	if not startLimiter:Check(player) then
		return
	end
	if typeof(spot) ~= "Instance" or not spot:IsA("BasePart") then
		return
	end
	if not CollectionService:HasTag(spot, "DigSpot") or not spot:IsDescendantOf(workspace) then
		return
	end
	local zoneId = spot:GetAttribute("Zone")
	if not Zones.IsZoneId(zoneId) then
		log:Warn(`munt sense zona valida: {spot:GetFullName()}`)
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if sessions[player] then
		return
	end
	local now = os.clock()
	local tool = Tools.Get(profile.equippedTool)
	local cooldown = Constants.DIG_COOLDOWN
		* (if profile.gamepasses.fastDig then Monetization.FAST_DIG_MULT else 1)
		* (if profile.digBoostUntil > os.time() then Potions.HASTE_MULT else 1)
	if lastDig[player] and now - lastDig[player] < cooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - spot.Position).Magnitude > Constants.MAX_DIG_DISTANCE then
		return
	end
	if not Zones.IsUnlocked(profile.unlockedZones, zoneId :: string) then
		local zone = Zones.ById[zoneId :: string]
		deny(player, `{zone.name} is locked · unlock it {zone.unlockAt or "at its gate"} ({Museum.MoneyText(zone.unlockCost)} $)`)
		return
	end
	if isDepleted(spot) then
		deny(player, "This mound is empty. It refills in a few seconds!")
		return
	end
	-- Cal tenir la pala; si es a la motxilla, se li posa a la ma
	if not ToolService.EquipShovel(player) then
		deny(player, "You need your shovel to dig")
		return
	end

	lastDig[player] = now
	nextSessionId += 1
	-- el munt daurat és d'un sol ús: el primer que el cava se l'emporta
	local golden = isGolden(spot)
	if golden then
		spot:SetAttribute("Golden", nil)
	end
	local session: Session = {
		id = nextSessionId,
		spot = spot,
		zone = zoneId :: string,
		toolLuck = tool.luck
			* Monetization.LuckMultiplier(profile.gamepasses)
			* (if profile.luckBoostUntil > os.time() then 2 else 1)
			* (if golden then Dig.GOLDEN_LUCK else 1),
		startTime = workspace:GetServerTimeNow(),
		center = rng:NextNumber(-Dig.BAND_CENTER_MAX, Dig.BAND_CENTER_MAX),
		speed = Dig.SpeedFor(1),
		attempts = 0,
		total = 0,
		lastClick = 0,
		golden = golden,
	}
	sessions[player] = session
	Remotes.DigUpdate:FireClient(player, {
		phase = "start",
		startTime = session.startTime,
		attempts = Dig.ATTEMPTS,
		spot = spot,
		toolLuck = session.toolLuck,
		center = session.center,
		speed = session.speed,
	})

	-- Una excavacio oberta i abandonada no pot bloquejar el jugador per
	-- sempre. Es tanca sense boti: si no, arrencar i no clicar seria gratis.
	task.delay(Dig.SESSION_TIMEOUT, function()
		if sessions[player] == session then
			sessions[player] = nil
			Remotes.DigUpdate:FireClient(player, { phase = "cancel" })
		end
	end)
end

local function onClick(player: Player, clickTime: any)
	if not clickLimiter:Check(player) then
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	if now - session.lastClick < Dig.MIN_CLICK_INTERVAL then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	if serverNow < session.startTime then
		return -- la línia encara no ha sortit (pausa entre cops)
	end
	session.lastClick = now

	-- Aquí mana el servidor. Quan va clicar el jugador? El que calcula ell
	-- amb el ping que mesura; el client pot dir la seva hora, però només
	-- s'accepta dins d'un marge petit al voltant d'aquesta estimació.
	local lag = math.clamp(player:GetNetworkPing() * 0.5, 0, Dig.MAX_LAG_COMPENSATION)
	local estimate = serverNow - lag
	local t = estimate
	if type(clickTime) == "number" and clickTime == clickTime then
		t = math.clamp(clickTime, estimate - Dig.CLICK_TIME_SLACK, math.min(estimate + Dig.CLICK_TIME_SLACK, serverNow))
	end
	local pos = Dig.MarkerAt(t - session.startTime, session.speed)
	local gained = Dig.ScoreFor(pos, session.center)
	session.attempts += 1
	session.total += gained

	local update: { [string]: any } = {
		phase = "hit",
		attempt = session.attempts,
		gained = gained,
		total = session.total,
		pos = pos,
	}
	if session.attempts < Dig.ATTEMPTS then
		-- el següent intent: la franja salta, la línia torna a sortir i va més ràpid
		session.startTime = serverNow + Dig.RESTART_DELAY
		session.center = rng:NextNumber(-Dig.BAND_CENTER_MAX, Dig.BAND_CENTER_MAX)
		session.speed = Dig.SpeedFor(session.attempts + 1)
		update.nextStart = session.startTime
		update.nextCenter = session.center
		update.nextSpeed = session.speed
	end
	Remotes.DigUpdate:FireClient(player, update)

	if session.attempts >= Dig.ATTEMPTS then
		finish(player)
	end
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function DigService.Start()
	Remotes.DigRequest.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
		if action == "start" then
			onStart(player, payload)
		elseif action == "click" then
			onClick(player, payload)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
		lastDig[player] = nil
	end)

	-- Boto "Dig" a cada munt (mobil, consola i tecla E). Es posa per codi i
	-- no al mapa: es gameplay, i aixi el mapa no depen de cap script.
	local missing = 0
	for _, spot in CollectionService:GetTagged("DigSpot") do
		if not spot:IsA("BasePart") then
			continue
		end
		if not Zones.IsZoneId(spot:GetAttribute("Zone")) then
			missing += 1
			continue
		end
		originalSize(spot)
		local prompt = spot:FindFirstChild("DigPrompt")
		if not prompt then
			local created = Instance.new("ProximityPrompt")
			created.Name = "DigPrompt"
			created.ActionText = "Dig"
			created.ObjectText = if spot:GetAttribute("Zone") == "construction" then "Dirt mound" else "Sand mound"
			created.KeyboardKeyCode = Enum.KeyCode.E
			created.GamepadKeyCode = Enum.KeyCode.ButtonX
			created.HoldDuration = 0
			created.MaxActivationDistance = Dig.PROMPT_DISTANCE
			created.RequiresLineOfSight = false
			created.Style = Enum.ProximityPromptStyle.Default
			created.Parent = spot
			prompt = created
		end
		(prompt :: ProximityPrompt).Triggered:Connect(function(player: Player)
			onStart(player, spot)
		end)
	end
	if missing > 0 then
		log:Warn(`{missing} munts DigSpot sense atribut Zone: torna a construir el mon`)
	end

	-- Esdeveniment del munt daurat: cada estona, un munt ple a l'atzar
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(Dig.GOLDEN_EVERY[1], Dig.GOLDEN_EVERY[2]))
			if #Players:GetPlayers() == 0 then
				continue
			end
			local candidates = {}
			for _, spot in CollectionService:GetTagged("DigSpot") do
				if spot:IsA("BasePart") and Zones.IsZoneId(spot:GetAttribute("Zone")) and not isDepleted(spot) and not isGolden(spot) then
					table.insert(candidates, spot)
				end
			end
			if #candidates > 0 then
				local spot = candidates[rng:NextInteger(1, #candidates)]
				local untilTime = workspace:GetServerTimeNow() + Dig.GOLDEN_TIME
				spot:SetAttribute("Golden", untilTime)
				local zone = Zones.ById[spot:GetAttribute("Zone") :: string]
				Remotes.Notify:FireAllClients({
					kind = "event",
					message = `⭐ A GOLDEN MOUND appeared at {zone.name}! x{Dig.GOLDEN_LUCK} luck for whoever digs it first!`,
					zone = zone.id,
				})
				task.delay(Dig.GOLDEN_TIME, function()
					if spot:GetAttribute("Golden") == untilTime then
						spot:SetAttribute("Golden", nil)
					end
				end)
			end
		end
	end)
end

return DigService
