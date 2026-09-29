--!strict

-- ShopController — la botiga Dig & Co. vista pel jugador (estil Fisch):
--   · les eines exposades giren a poc a poc al seu sòcol;
--   · mantens E sobre una eina i surt la seva FITXA: el model en 3D, la
--     sort que dona, què et canvia respecte de la teva, i el botó de
--     comprar (o equipar);
--   · la fitxa es tanca sola si te n'allunyes.
-- Comprar ho decideix el servidor (ShopService torna a mirar distància i preu).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Tools = require(Config:WaitForChild("Tools"))
local Zones = require(Config:WaitForChild("Zones"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ToolModels = require(Shared:WaitForChild("Util"):WaitForChild("ToolModels"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C
local player = Players.LocalPlayer

local ShopController = {}

-- Més lluny d'això la fitxa es tanca sola
local CLOSE_DISTANCE = 16

local gui: ScreenGui
local holder: Frame
local card: Frame
local header: Frame
local title: TextLabel
local viewport: ViewportFrame
local luckLabel: TextLabel
local compareLabel: TextLabel
local blurbLabel: TextLabel
local priceLabel: TextLabel
local actionSlot: Frame
local current: { stand: BasePart, def: Tools.ToolDef, model: Model? }? = nil
local spinAngle = 0

-- ─────────────────────────── LA FITXA ───────────────────────────

local function build()
	gui = Theme.Screen("ToolInfoGui", 12)
	gui.Enabled = false

	holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -24)
	holder.Size = UDim2.fromOffset(600, 330)
	holder.Parent = gui
	Theme.AutoScale(holder, "menu")

	card = Widgets.Card(holder, { Size = UDim2.fromScale(1, 1) }, C.panel, 24)

	header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BorderSizePixel = 0
	header.Parent = card
	Theme.Corner(header, 24)
	Theme.Shade(header)
	title = Theme.Text(header, "", {
		Size = UDim2.new(1, -90, 0, 42),
		Position = UDim2.fromOffset(20, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	})
	Widgets.CloseButton({
		Parent = card,
		ZIndex = 8,
		OnClick = function()
			ShopController.Close()
		end,
	})

	-- l'eina en 3D, girant, sobre un fons fosc amb un raig de llum
	local stage = Widgets.Card(card, {
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.fromOffset(18, 74),
		ClipsDescendants = true,
	}, Color3.fromRGB(30, 26, 46), 18)
	Effects.Sunburst(stage, C.yellow, 320)
	viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 244, 220)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	viewport.ZIndex = 3
	viewport.Parent = stage
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, 9.5), Vector3.new(0, 0.2, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- la sort, ben grossa: és l'únic que dona una eina
	luckLabel = Theme.Text(card, "", {
		Size = UDim2.fromOffset(350, 56),
		Position = UDim2.fromOffset(234, 72),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.green,
		StrokeThickness = 3.5,
	})
	compareLabel = Theme.Text(card, "", {
		Size = UDim2.fromOffset(350, 28),
		Position = UDim2.fromOffset(234, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.cyan,
	})
	blurbLabel = Theme.Text(card, "", {
		Size = UDim2.fromOffset(350, 44),
		Position = UDim2.fromOffset(234, 162),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.muted,
		TextWrapped = true,
		StrokeThickness = 1.5,
	})
	priceLabel = Theme.Text(card, "", {
		Size = UDim2.fromOffset(350, 38),
		Position = UDim2.fromOffset(234, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.yellow,
		StrokeThickness = 3,
	})
	actionSlot = Instance.new("Frame")
	actionSlot.BackgroundTransparency = 1
	actionSlot.Size = UDim2.fromOffset(350, 62)
	actionSlot.Position = UDim2.fromOffset(234, 254)
	actionSlot.Parent = card
end

local function fillAction(snapshot: ProfileController.Snapshot?, def: Tools.ToolDef)
	Widgets.Clear(actionSlot)
	local owned = snapshot ~= nil and table.find(snapshot.tools or {}, def.id) ~= nil
	local equipped = snapshot ~= nil and snapshot.equippedTool == def.id
	local coins = if snapshot then snapshot.coins else 0
	local props: Widgets.ButtonProps = {
		Parent = actionSlot,
		Size = UDim2.fromScale(1, 1),
		Radius = 18,
	}
	if equipped then
		props.Color = C.grey
		props.Text = "EQUIPPED ✅"
	elseif owned then
		props.Color = C.cyan
		props.Text = "EQUIP"
		props.Icon = "🎒"
		props.OnClick = function()
			Remotes.ShopRequest:FireServer("equip", def.id)
		end
	elseif def.zone and not Zones.IsUnlocked(snapshot and snapshot.zones or {}, def.zone) then
		-- les d'Egipte: primer cal obrir Egipte
		props.Color = C.grey
		props.Text = `UNLOCK {string.upper(Zones.ById[def.zone].name)} FIRST`
		props.Icon = "🔒"
		props.Sound = "error"
	elseif coins >= def.price then
		props.Color = C.green
		props.Text = `BUY · {Theme.Short(def.price)}`
		props.Icon = "$"
		props.OnClick = function()
			Remotes.ShopRequest:FireServer("buy", def.id)
		end
	else
		props.Color = C.grey
		props.Text = `NEED {Theme.Short(def.price - coins)} MORE`
		props.Icon = "🔒"
		props.Sound = "error"
	end
	local b = Widgets.Button(props)
	if not equipped and (owned or coins >= def.price) then
		Effects.Shine(b.button, 18, 2.5)
	end
end

local function refresh()
	local open = current
	if not open then
		return
	end
	local def = open.def
	local snapshot = ProfileController.Get()
	header.BackgroundColor3 = def.blade
	title.Text = string.upper(def.name)
	luckLabel.Text = `🍀 {Tools.LuckText(def.luck)} LUCK`
	local mine = Tools.Get(snapshot and snapshot.equippedTool)
	if mine.id == def.id then
		compareLabel.Text = "This is the tool in your hands"
		compareLabel.TextColor3 = C.cyan
	elseif def.luck > mine.luck then
		local pct = math.floor((def.luck / mine.luck - 1) * 100 + 0.5)
		compareLabel.Text = `⬆️ +{pct}% luck vs your {mine.name}`
		compareLabel.TextColor3 = C.green
	else
		compareLabel.Text = `Your {mine.name} is already {Tools.LuckText(mine.luck)}`
		compareLabel.TextColor3 = C.muted
	end
	blurbLabel.Text = def.blurb .. " Luck makes rarer fossils show up more often."
	priceLabel.Text = if def.price > 0 then `$ {Theme.Short(def.price)} coins` else "🎁 Free"
	fillAction(snapshot, def)
end

function ShopController.Close()
	local open = current
	if not open then
		return
	end
	current = nil
	if open.model then
		open.model:Destroy()
	end
	gui.Enabled = false
end

function ShopController.Open(stand: BasePart, def: Tools.ToolDef)
	ShopController.Close()
	local model = ToolModels.MakeDisplay(def, CFrame.identity)
	-- centrat al mig del visor, sigui quina sigui la mida de l'eina
	local cf, size = model:GetBoundingBox()
	local fit = 5.2 / math.max(size.X, size.Y, size.Z)
	model:ScaleTo(fit)
	cf = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - cf.Position)
	for _, d in model:GetDescendants() do
		if d:IsA("Light") then
			d:Destroy()
		end
	end
	model.Parent = viewport
	current = { stand = stand, def = def, model = model }
	gui.Enabled = true
	refresh()
	Effects.PopIn(card, 0.3)
	Theme.Play("open", 0.4, 1.2)
end

-- ─────────────────────── ELS SÒCOLS DEL MAPA ───────────────────────

local function standPrompt(stand: Instance): ProximityPrompt?
	local prompt = stand:FindFirstChild("BuyTool")
	return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

-- El prompt és el mateix per a tothom al servidor; aquí el retoquem només
-- per a aquest jugador (no es replica)
local function refreshPrompts(snapshot: ProfileController.Snapshot)
	for _, stand in CollectionService:GetTagged("ToolStand") do
		local def = Tools.ById[stand:GetAttribute("ToolId") :: any]
		local prompt = standPrompt(stand)
		if def and prompt then
			local owned = table.find(snapshot.tools or {}, def.id) ~= nil
			prompt.ObjectText = if snapshot.equippedTool == def.id then `{def.name} ✅` elseif owned then `{def.name} (owned)` else def.name
			prompt.ActionText = "View"
		end
	end
	-- el desbloqueig de la platja desapareix quan ja és teva
	for _, part in CollectionService:GetTagged("ZoneUnlock") do
		local prompt = part:FindFirstChild("UnlockZone")
		local zoneId = part:GetAttribute("Zone")
		if prompt and prompt:IsA("ProximityPrompt") and Zones.IsZoneId(zoneId) then
			prompt.Enabled = not Zones.IsUnlocked(snapshot.zones, zoneId :: string)
		end
	end
end

function ShopController.Start()
	build()

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "BuyTool" then
			return
		end
		local stand = prompt.Parent
		if not stand or not stand:IsA("BasePart") or not CollectionService:HasTag(stand, "ToolStand") then
			return
		end
		local def = Tools.ById[stand:GetAttribute("ToolId") :: any]
		if def then
			ShopController.Open(stand, def)
		end
	end)

	ProfileController.Changed:Connect(function(snapshot: ProfileController.Snapshot)
		refreshPrompts(snapshot)
		refresh()
	end)
	local snapshot = ProfileController.Get()
	if snapshot then
		refreshPrompts(snapshot)
	end
	CollectionService:GetInstanceAddedSignal("ToolStand"):Connect(function()
		local s = ProfileController.Get()
		if s then
			refreshPrompts(s)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and current then
			ShopController.Close()
		end
	end)

	-- les eines exposades giren a poc a poc (només aquí: no costa res al servidor),
	-- la de la fitxa també, i la fitxa es tanca si te n'allunyes
	RunService.RenderStepped:Connect(function(dt: number)
		spinAngle += dt * 0.8
		for _, display in CollectionService:GetTagged("ToolDisplay") do
			if display:IsA("Model") and display.Parent and display.Parent:IsA("BasePart") then
				local stand = display.Parent :: BasePart
				local base = stand.CFrame * CFrame.new(0, stand.Size.Y / 2 + 2.6 + math.sin(spinAngle * 2) * 0.25, 0)
				display:PivotTo(base * CFrame.Angles(0, spinAngle, math.rad(12)))
			end
		end
		local open = current
		if open then
			if open.model then
				open.model:PivotTo(CFrame.Angles(0, spinAngle * 1.6, 0) * CFrame.Angles(0, 0, math.rad(20)))
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - open.stand.Position).Magnitude > CLOSE_DISTANCE then
				ShopController.Close()
			end
		end
	end)
end

return ShopController
