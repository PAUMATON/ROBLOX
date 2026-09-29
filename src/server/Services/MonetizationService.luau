--!strict

-- MonetizationService — gamepasses i productes per Robux (Config/Monetization).
--
-- · Què tens: profile.gamepasses[key] = true. Es desa al perfil (així la
--   renda offline ja sap els teus passis en carregar, sense esperar Roblox)
--   i es torna a comprovar amb Roblox cada cop que entres.
-- · Comprar: el client demana ("pass" | "product", key); el servidor mira
--   que existeixi i que tinguis el passi anterior de la cadena, i obre la
--   finestra de compra de Roblox. Roblox ens avisa quan s'ha pagat.
-- · Productes: ProcessReceipt, idempotent amb profile.purchaseHistory (una
--   mateixa compra pot arribar dos cops). Es desa ABANS de dir "fet".
-- · A Studio, un passi amb id = 0 es dona gratis per poder-lo provar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Monetization = require(Config:WaitForChild("Monetization"))
local Museum = require(Config:WaitForChild("Museum"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = Shared:WaitForChild("Util")
local Logger = require(Util:WaitForChild("Logger"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local log = Logger.new("MonetizationService")

local MonetizationService = {}

local limiter = RateLimiter.new(1)
local BASE_WALK = 16

local function reply(player: Player, ok: boolean, message: string, icon: string?, fx: string?)
	Remotes.Notify:FireClient(player, { kind = "shop", ok = ok, message = message, icon = icon, fx = fx })
end

-- ─────────────────────────── CONSULTES ───────────────────────────

function MonetizationService.Owns(player: Player, key: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and profile.gamepasses[key] == true
end

-- Multiplicador de TOTES les monedes (cadena de diners, VIP i boost)
function MonetizationService.Money(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	return Monetization.MoneyMultiplier(profile.gamepasses, (profile :: any).boostUntil)
end

-- ─────────────────────────── EFECTES ───────────────────────────

local function applyCharacter(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if MonetizationService.Owns(player, "speed") then BASE_WALK * Monetization.SPEED_MULT else BASE_WALK
	end
	-- el VIP es veu (el client hi posa l'etiqueta al cap i al xat)
	player:SetAttribute("VIP", MonetizationService.Owns(player, "vip"))
end

local function grantPass(player: Player, pass: Monetization.Pass)
	local profile = DataService.Get(player)
	if not profile or profile.gamepasses[pass.key] then
		return
	end
	profile.gamepasses[pass.key] = true
	applyCharacter(player)
	InventoryService.Push(player)
	reply(player, true, `{pass.name} unlocked! Thank you!`, pass.icon, "big")
	log:Info(`{player.Name} té {pass.key}`)
	task.spawn(DataService.Save, player)
end

-- Comprova amb Roblox els passis que ja tens (per si els vas comprar fora
-- del joc o el perfil no ho sabia)
local function syncOwned(player: Player)
	for _, pass in Monetization.PASSES do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				local profile = DataService.Get(player)
				if profile and not profile.gamepasses[pass.key] then
					profile.gamepasses[pass.key] = true
				end
			end
		end
	end
	applyCharacter(player)
	InventoryService.Push(player)
end

-- ─────────────────────────── COMPRES ───────────────────────────

local function giveProduct(player: Player, product: Monetization.Product): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local p = profile :: any
	if product.boostMinutes then
		local now = os.time()
		p.boostUntil = math.max(p.boostUntil or 0, now) + product.boostMinutes * 60
		reply(player, true, `x2 Money for {product.boostMinutes} more minutes!`, product.icon)
	elseif product.coinsMinutes then
		local rate = math.max(Museum.IncomeRate(profile.museumLayout), Monetization.COINS_MIN_RATE)
		local coins = math.floor(rate * product.coinsMinutes)
		profile.coins += coins
		reply(player, true, `+{coins} coins!`, product.icon)
	end
	InventoryService.Push(player)
	return true
end

local function onRequest(player: Player, kind: any, key: any)
	if not limiter:Check(player) or type(key) ~= "string" then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if kind == "pass" then
		local pass = Monetization.PassByKey[key]
		if not pass or profile.gamepasses[key] then
			return
		end
		if pass.requires and not profile.gamepasses[pass.requires] then
			local before = Monetization.PassByKey[pass.requires]
			reply(player, false, `Get {before.name} first!`, "🔒")
			return
		end
		if pass.id == 0 then
			if RunService:IsStudio() then
				-- només per provar a Studio: s'apunta com a prova i s'esborra en tornar a entrar
				local p = profile :: any
				p.studioTestPasses = p.studioTestPasses or {}
				p.studioTestPasses[pass.key] = true
				grantPass(player, pass)
			else
				reply(player, false, "Coming soon!", "⏳")
			end
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif kind == "product" then
		local product = Monetization.ProductByKey[key]
		if not product then
			return
		end
		if product.id == 0 then
			if RunService:IsStudio() then
				giveProduct(player, product)
			else
				reply(player, false, "Coming soon!", "⏳")
			end
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and DataService.Get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if profile.purchaseHistory[purchaseId] then
		-- Ja donat en aquesta sessió. Si el desat d'aquell cop va fallar,
		-- Roblox ho reintenta: NOMÉS es torna a provar de desar, sense
		-- tornar a donar res.
		if DataService.Save(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Monetization.ProductById[info.ProductId]
	if not product then
		log:Warn(`producte desconegut {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not giveProduct(player, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.purchaseHistory[purchaseId] = { product = product.key, at = os.time() }
	-- desat abans de dir a Roblox que s'ha donat: si falla, Roblox ho
	-- reintenta. El registre NO s'esborra: les monedes ja són al perfil i,
	-- si l'esborréssim, el reintent les tornaria a donar.
	if not DataService.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	log:Info(`{player.Name} ha comprat {product.key}`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ───────────────────────── CICLE DE VIDA ─────────────────────────

function MonetizationService.Init()
	DataService.ProfileLoaded:Connect(function(player: Player, profile: any)
		-- les "compres" de prova de Studio no es queden mai
		if type(profile.studioTestPasses) == "table" then
			for key in profile.studioTestPasses do
				profile.gamepasses[key] = nil
			end
			profile.studioTestPasses = nil
		end
		task.spawn(syncOwned, player)
	end)
end

function MonetizationService.Start()
	Remotes.PurchaseRequest.OnServerEvent:Connect(onRequest)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		local pass = Monetization.PassById[passId]
		if bought and pass then
			grantPass(player, pass)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait()
			applyCharacter(player)
		end)
		if player.Character then
			applyCharacter(player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return MonetizationService
