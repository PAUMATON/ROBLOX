--!strict

-- Theme — l'estil de la UI: colors vius, contorns negres gruixuts, lletra
-- rodona i grossa. Estil "simulador" (CLAUDE.md > ESTIL > UI). El mon 3D
-- continua amb la paleta del museu; aixo nomes es la interficie.
--
-- Tot el que es visual i es repeteix viu aqui: si vols canviar el to de
-- la UI, es toca aquest fitxer i prou.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

-- ─────────────────────────── COLORS ───────────────────────────

Theme.C = {
	ink = Color3.fromRGB(24, 20, 34), -- contorns i ombres
	white = Color3.fromRGB(255, 255, 255),
	cream = Color3.fromRGB(255, 246, 225),
	muted = Color3.fromRGB(190, 184, 205),
	panel = Color3.fromRGB(44, 38, 64), -- fons de finestra
	panelLight = Color3.fromRGB(64, 56, 92),

	red = Color3.fromRGB(240, 52, 72),
	orange = Color3.fromRGB(255, 146, 38),
	yellow = Color3.fromRGB(255, 210, 40),
	gold = Color3.fromRGB(255, 190, 30),
	green = Color3.fromRGB(64, 220, 110),
	mint = Color3.fromRGB(60, 230, 190),
	cyan = Color3.fromRGB(40, 196, 245),
	blue = Color3.fromRGB(64, 118, 255),
	purple = Color3.fromRGB(150, 84, 255),
	pink = Color3.fromRGB(255, 72, 186),
	grey = Color3.fromRGB(120, 116, 140),
}

-- Arc de Sant Marti per als botons especials (comerç)
Theme.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 64, 160)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 150, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 60)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 220, 160)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255)),
})

-- ─────────────────────────── LLETRA ───────────────────────────

Theme.FONT = Enum.Font.FredokaOne
Theme.STROKE = 3 -- gruix del contorn de botons i panells
Theme.TEXT_STROKE = 2.5 -- gruix del contorn de les lletres

-- ─────────────────────────── SONS ───────────────────────────
-- Tots publicats pel compte oficial de Roblox: es poden fer servir a
-- qualsevol experiencia. Si un falla, simplement no sona.

Theme.SOUNDS = {
	click = "rbxassetid://15675059323", -- Roblox_UI_Bright_Click
	hover = "rbxassetid://15675032796", -- Roblox_UI_Small_Click
	pop = "rbxassetid://15675055424", -- Roblox_UI_Cute_Pop
	open = "rbxassetid://15674975792", -- Roblox_UI_Whoosh_03
	reward = "rbxassetid://15675043410", -- Roblox_UI_Tonal_Stinger
	notify = "rbxassetid://15675085146", -- Roblox_UI_Indicator
	error = "rbxassetid://15675075163", -- Roblox_UI_Delete
}

local soundCache: { [string]: Sound } = {}

-- Volums triats pel jugador a la configuració (0..1)
Theme.SfxVolume = 1
Theme.MusicVolume = 1
local musicListeners: { (number) -> () } = {}

function Theme.SetSfxVolume(v: number)
	Theme.SfxVolume = math.clamp(v, 0, 1)
end

function Theme.SetMusicVolume(v: number)
	Theme.MusicVolume = math.clamp(v, 0, 1)
	for _, fn in musicListeners do
		task.spawn(fn, Theme.MusicVolume)
	end
end

function Theme.OnMusicVolume(fn: (number) -> ())
	table.insert(musicListeners, fn)
	fn(Theme.MusicVolume)
end

function Theme.Play(name: string, volume: number?, pitch: number?)
	local id = Theme.SOUNDS[name]
	if not id then
		return
	end
	local template = soundCache[name]
	if not template then
		local s = Instance.new("Sound")
		s.Name = "UI_" .. name
		s.SoundId = id
		s.Parent = SoundService
		soundCache[name] = s
		template = s
	end
	if Theme.SfxVolume <= 0 then
		return
	end
	template.Volume = (volume or 0.5) * Theme.SfxVolume
	template.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(template)
end

-- ─────────────────────────── NUMEROS ───────────────────────────

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 950 -> "950" · 12345 -> "12.3K" · 3260000 -> "3.26M"
function Theme.Short(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local text = if math.abs(v) >= 100 then string.format("%d", math.floor(v))
		elseif math.abs(v) >= 10 then string.format("%.1f", math.floor(v * 10) / 10)
		else string.format("%.2f", math.floor(v * 100) / 100)
	-- Fora els zeros sobrers, pero nomes darrere la coma: "100" no es toca
	if string.find(text, ".", 1, true) then
		text = (text:gsub("0+$", ""))
		text = (text:gsub("%.$", ""))
	end
	return text .. SUFFIXES[i]
end

-- ─────────────────────── PECES DE BASE ───────────────────────

function Theme.Corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function Theme.Stroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or Theme.STROKE
	s.Color = color or Theme.C.ink
	s.LineJoinMode = Enum.LineJoinMode.Round
	-- Sempre la vora: el contorn de les lletres el posa Theme.Text
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Ombrejat de dalt a baix: el color de base es multiplica per aquest degradat.
function Theme.Shade(parent: Instance, top: number?, bottom: number?)
	local g = Instance.new("UIGradient")
	local a = math.floor(255 * (top or 1))
	local b = math.floor(255 * (bottom or 0.72))
	g.Color = ColorSequence.new(Color3.fromRGB(a, a, a), Color3.fromRGB(b, b, b))
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Text blanc amb contorn negre: la marca de la casa.
function Theme.Text(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.FONT
	label.Text = text
	label.TextColor3 = Theme.C.white
	label.TextScaled = true
	for key, value in props or {} do
		if key ~= "StrokeThickness" then
			(label :: any)[key] = value
		end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if props and props.StrokeThickness then props.StrokeThickness else Theme.TEXT_STROKE
	stroke.Color = Theme.C.ink
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Emoji com a icona (sense contorn: el contorn negre els embruta).
function Theme.Icon(parent: Instance, emoji: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.FONT
	label.Text = emoji
	label.TextScaled = true
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- ─────────────────────── ESCALA DE PANTALLA ───────────────────────
-- Tot es dissenya per a 1920x1080. En pantalles petites o estretes (mòbil,
-- finestres verticals) s'encongeix: mana la dimensió que queda més justa.
--
-- AL MÒBIL: la pantalla és petita però el dit no, i encongir-ho tot en
-- proporció deixava els botons impossibles de tocar. Per això:
--   · el HUD hi és més gros (TOUCH_HUD) i els controladors en canvien la
--     disposició quan Theme.IsCompact() (mòbil apaïsat);
--   · les finestres s'escalen per OMPLIR la pantalla fins on hi caben
--     (no per l'alçada de 1080), que al mòbil les fa gairebé un 50% més grans.

local DESKTOP_HUD = 0.88 -- a l'ordinador el HUD era massa gros (un provador)
local TOUCH_HUD = 1.45 -- amb el dit calen botons més grossos
local TOUCH_MENU = 3 -- al mòbil la finestra creix fins que ja no hi cap
local FIT_MARGIN = 14 -- marge mínim entre una finestra i la vora

local scaled: { { s: UIScale, menu: boolean, design: Vector2? } } = {}
local scaleListeners: { (number) -> () } = {}
local currentScale = 1
-- Mida triada pel jugador (botó de configuració): multiplica l'automàtica
Theme.UI_SCALES = { { 0.8, "Small" }, { 0.9, "Medium" }, { 1, "Normal" }, { 1.15, "Big" } }
local userScale = 1 -- el HUD (botons i barres de la pantalla)
local menuScale = 1 -- les finestres i menús que s'obren

-- A Studio es pot fer veure que és un mòbil, per provar-ho i fer captures,
-- amb atributs al LocalPlayer: EmulateViewport (Vector2) i EmulateTouch.
-- Fora de Studio no es miren mai.
local function emulated(name: string): any
	if not RunService:IsStudio() then
		return nil
	end
	local player = Players.LocalPlayer
	return if player then player:GetAttribute(name) else nil
end

-- Mida de la pantalla en punts
function Theme.Viewport(): Vector2
	local v = emulated("EmulateViewport")
	if typeof(v) == "Vector2" then
		return v
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

-- Es juga amb el dit (mòbil o tauleta sense ratolí)
function Theme.IsTouch(): boolean
	local e = emulated("EmulateTouch")
	if type(e) == "boolean" then
		return e
	end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Mòbil apaïsat: tàctil i poca alçada. El HUD canvia de disposició.
function Theme.IsCompact(): boolean
	return Theme.IsTouch() and Theme.Viewport().Y < 700
end

local function computeScale(menu: boolean?, design: Vector2?): number
	local size = Theme.Viewport()
	local touch = Theme.IsTouch()
	local base = math.min(size.Y / 1080, size.X / 1600)
	if not menu then
		return math.clamp(base * (if touch then TOUCH_HUD else DESKTOP_HUD) * userScale, 0.3, 1.4)
	end
	local s = base * (if touch then TOUCH_MENU else 1) * menuScale
	-- una finestra no pot sortir de la pantalla (ni tapar la barra de Roblox)
	if design and design.X > 0 and design.Y > 0 then
		local inset = GuiService:GetGuiInset()
		local fitX = (size.X - 2 * FIT_MARGIN) / design.X
		local fitY = (size.Y - inset.Y - 2 * FIT_MARGIN) / design.Y
		s = math.min(s, fitX, fitY)
	end
	return math.clamp(s, 0.3, 1.4)
end

local function refreshScale()
	currentScale = computeScale(false)
	for _, e in scaled do
		e.s.Scale = if e.menu then computeScale(true, e.design) else currentScale
	end
	for _, fn in scaleListeners do
		task.spawn(fn, currentScale)
	end
end

function Theme.SetUserScale(v: number)
	userScale = math.clamp(v, 0.7, 1.3)
	refreshScale()
end

function Theme.GetUserScale(): number
	return userScale
end

function Theme.SetMenuScale(v: number)
	menuScale = math.clamp(v, 0.7, 1.3)
	refreshScale()
end

function Theme.GetMenuScale(): number
	return menuScale
end

-- Altres opcions de la configuració (les llegeixen els controladors)
Theme.QuickRewards = false

-- Per a posicions que depenen de l'escala (p.ex. apilar un bloc sobre un altre)
function Theme.OnScale(fn: (number) -> ())
	table.insert(scaleListeners, fn)
	fn(currentScale)
end

-- `kind` = "menu" per a finestres i menús que s'obren (tenen la seva mida).
-- La mida de disseny d'un menú és el seu Size en píxels (Offset): amb
-- això se sap fins on pot créixer sense sortir de la pantalla.
function Theme.AutoScale(guiObject: GuiObject, kind: string?)
	local s = Instance.new("UIScale")
	local menu = kind == "menu"
	local design = if menu then Vector2.new(guiObject.Size.X.Offset, guiObject.Size.Y.Offset) else nil
	s.Scale = computeScale(menu, design)
	s.Parent = guiObject
	table.insert(scaled, { s = s, menu = menu, design = design })
end

function Theme.GetScale(): number
	return currentScale
end

do
	local function hook()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
		end
		refreshScale()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	if RunService:IsStudio() and Players.LocalPlayer then
		Players.LocalPlayer.AttributeChanged:Connect(function(name: string)
			if name == "EmulateViewport" or name == "EmulateTouch" then
				refreshScale()
			end
		end)
	end
	hook()
end

-- ScreenGui nova, sense reapareixer amb el personatge.
function Theme.Screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

return Theme
