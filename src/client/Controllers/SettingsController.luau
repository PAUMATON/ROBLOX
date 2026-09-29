--!strict

-- SettingsController — el botó ⚙️ de dalt a la dreta i la finestra de
-- configuració. Tot es desa al perfil (SettingsService) i s'aplica en
-- tornar a entrar:
--   · mida del HUD i mida dels menús que s'obren (per separat)
--   · música i ambient, efectes de so
--   · gràfics alts/baixos (sense resplendor, rajos de sol, ombres ni partícules)
--   · peticions de trade (de tothom o de ningú; ho comprova el servidor)
--   · premis: animació completa o ràpida

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C

local SettingsController = {}

local window: Widgets.Window
local list: ScrollingFrame
local applied = false
local VOLUMES = { { 0, "Off" }, { 0.5, "Low" }, { 1, "On" } }

-- estat de les opcions que no viuen al Theme
local lowGraphics = false
local allowTrades = true

-- ─────────────────────────── GRÀFICS ───────────────────────────
-- Els canvis a Lighting des del client només afecten aquest jugador.
local originalShadows: boolean? = nil
local function applyGraphics()
	if originalShadows == nil then
		originalShadows = Lighting.GlobalShadows
	end
	Lighting.GlobalShadows = if lowGraphics then false else originalShadows :: boolean
	for _, fx in Lighting:GetChildren() do
		if fx:IsA("BloomEffect") or fx:IsA("SunRaysEffect") or fx:IsA("DepthOfFieldEffect") then
			fx.Enabled = not lowGraphics
		end
	end
	local character = game:GetService("Players").LocalPlayer.Character
	for _, d in workspace:GetDescendants() do
		if d:IsA("ParticleEmitter") and not (character and d:IsDescendantOf(character)) then
			d.Enabled = not lowGraphics
		end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = not lowGraphics
	end
end

-- ─────────────────────────── DESAR ───────────────────────────
local saveToken = 0
local function save()
	-- s'espera una mica: si el jugador toca molts botons seguits, un sol enviament
	saveToken += 1
	local mine = saveToken
	task.delay(0.6, function()
		if mine ~= saveToken then
			return
		end
		Remotes.SettingsRequest:FireServer({
			musicVolume = Theme.MusicVolume,
			sfxVolume = Theme.SfxVolume,
			uiScale = Theme.GetUserScale(),
			menuScale = Theme.GetMenuScale(),
			lowGraphics = lowGraphics,
			allowTrades = allowTrades,
			quickRewards = Theme.QuickRewards,
		})
	end)
end

-- ─────────────────────────── FINESTRA ───────────────────────────
local redraw: () -> ()
local order = 0

local function row(title: string, hint: string, options: { { any } }, isOn: (any) -> boolean, pick: (any) -> ())
	order += 1
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -16, 0, 118)
	box.LayoutOrder = order
	box.Parent = list
	Theme.Text(box, title, {
		Size = UDim2.new(1, -10, 0, 30),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.cream,
	})
	Theme.Text(box, hint, {
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(4, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
		StrokeThickness = 1.5,
	})
	local total = 580
	local w = math.floor((total - (#options - 1) * 10) / #options)
	for i, opt in options do
		local value = opt[1]
		local on = isOn(value)
		Widgets.Button({
			Parent = box,
			Size = UDim2.fromOffset(w, 52),
			Position = UDim2.fromOffset(4 + (i - 1) * (w + 10), 56),
			Color = if on then C.green else C.panelLight,
			Text = (if on then "✅ " else "") .. tostring(opt[2]),
			Radius = 14,
			OnClick = function()
				pick(value)
				save()
				redraw()
			end,
		})
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.01
end

redraw = function()
	if not Windows.IsOpen("Settings") then
		return
	end
	local keep = list.CanvasPosition
	Widgets.Clear(list)
	order = 0
	row("🔍 HUD SIZE", "Buttons and bars on the screen", Theme.UI_SCALES, function(v)
		return near(Theme.GetUserScale(), v)
	end, Theme.SetUserScale)
	row("🪟 MENU SIZE", "Backpack, Index, Museum, Trade, shops and this window", Theme.UI_SCALES, function(v)
		return near(Theme.GetMenuScale(), v)
	end, Theme.SetMenuScale)
	row("🎵 MUSIC & AMBIENCE", "Birds, waves and the fountain", VOLUMES, function(v)
		return near(Theme.MusicVolume, v)
	end, Theme.SetMusicVolume)
	row("🔊 SOUND EFFECTS", "Clicks, pops and rewards", VOLUMES, function(v)
		return near(Theme.SfxVolume, v)
	end, Theme.SetSfxVolume)
	row("⚡ GRAPHICS", "Low = no glow, sun rays, shadows or particles (faster phones)", { { false, "High" }, { true, "Low" } }, function(v)
		return lowGraphics == v
	end, function(v)
		lowGraphics = v
		applyGraphics()
	end)
	row("🤝 TRADE REQUESTS", "Who can send you trade requests", { { true, "Everyone" }, { false, "Nobody" } }, function(v)
		return allowTrades == v
	end, function(v)
		allowTrades = v
	end)
	row("✨ REWARD POPUPS", "How long the new fossil card stays on screen", { { false, "Full" }, { true, "Quick" } }, function(v)
		return Theme.QuickRewards == v
	end, function(v)
		Theme.QuickRewards = v
	end)
	list.CanvasPosition = keep
end

function SettingsController.Start()
	window = Widgets.Window({
		Name = "Settings",
		Title = "SETTINGS",
		Icon = "⚙️",
		Color = C.grey,
		Size = Vector2.new(660, 600),
	})
	window.onOpen = redraw
	window.footer.Text = "Your settings are saved with your game"
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C.muted
	list.Parent = window.body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = list

	-- el botó, a dalt a la dreta
	local gui = Theme.Screen("SettingsButtonGui", 4)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -18, 0, 12)
	holder.Size = UDim2.fromOffset(64, 64)
	holder.Parent = gui
	Theme.AutoScale(holder)
	Widgets.Button({
		Parent = holder,
		Size = UDim2.fromScale(1, 1),
		Color = C.grey,
		Icon = "⚙️",
		Radius = 16,
		OnClick = function()
			Windows.Toggle("Settings")
		end,
	})

	-- la configuració desada, un sol cop en carregar el perfil
	local function apply(snapshot: ProfileController.Snapshot)
		local st = snapshot.settings
		if applied or not st then
			return
		end
		applied = true
		Theme.SetUserScale(st.uiScale or 1)
		Theme.SetMenuScale(st.menuScale or 1)
		Theme.SetMusicVolume(st.musicVolume or 1)
		Theme.SetSfxVolume(st.sfxVolume or 1)
		Theme.QuickRewards = st.quickRewards == true
		allowTrades = st.allowTrades ~= false
		lowGraphics = st.lowGraphics == true
		if lowGraphics then
			applyGraphics()
		end
	end
	ProfileController.Changed:Connect(apply)
	local snapshot = ProfileController.Get()
	if snapshot then
		apply(snapshot)
	end
end

return SettingsController
