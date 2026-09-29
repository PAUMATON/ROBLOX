--!strict

-- Widgets — les peces de la UI: botons grossos amb contorn, rajoles,
-- insignies, barres de progres, finestres i rajoles de peça d'os.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bones = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Bones"))
local Theme = require(script.Parent.Theme)
local Effects = require(script.Parent.Effects)
local Windows = require(script.Parent.Windows)
local PieceView = require(script.Parent.PieceView)

local C = Theme.C

local Widgets = {}

-- Ombra de baix i brillantor de dalt: el que dona volum "de joguina".
local function gloss(parent: GuiObject, radius: number)
	local shade = Instance.new("Frame")
	shade.Name = "ShadeOverlay"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = C.ink
	shade.BorderSizePixel = 0
	shade.ZIndex = parent.ZIndex
	shade.Parent = parent
	Theme.Corner(shade, radius)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 0.62),
	})
	sg.Parent = shade

	local shine = Instance.new("Frame")
	shine.Name = "Gloss"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.new(0.5, 0, 0, 3)
	shine.Size = UDim2.new(1, -8, 0.42, 0)
	shine.BackgroundColor3 = C.white
	shine.BorderSizePixel = 0
	shine.ZIndex = parent.ZIndex
	shine.Parent = parent
	Theme.Corner(shine, math.max(4, radius - 3))
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new(0.6, 0.95)
	gg.Parent = shine
end

-- ─────────────────────────── BOTO ───────────────────────────

export type ButtonProps = {
	Parent: Instance,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Gradient: ColorSequence?, -- en lloc del color (p.ex. l'arc de Sant Marti)
	Text: string?,
	Icon: string?,
	Layout: string?, -- "row" (icona a l'esquerra) o "tile" (icona a dalt)
	Radius: number?,
	LayoutOrder: number?,
	ZIndex: number?,
	Sound: string?,
	OnClick: (() -> ())?,
}

export type Button = {
	button: TextButton,
	label: TextLabel?,
	icon: TextLabel?,
	gradient: UIGradient?,
}

function Widgets.Button(p: ButtonProps): Button
	local radius = p.Radius or 14
	local b = Instance.new("TextButton")
	b.Size = p.Size
	b.Position = p.Position or UDim2.new()
	b.AnchorPoint = p.AnchorPoint or Vector2.zero
	b.BackgroundColor3 = if p.Gradient then C.white else (p.Color or C.blue)
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.LayoutOrder = p.LayoutOrder or 0
	b.ZIndex = p.ZIndex or 1
	Theme.Corner(b, radius)
	Theme.Stroke(b, Theme.STROKE)
	local gradient: UIGradient? = nil
	if p.Gradient then
		local g = Instance.new("UIGradient")
		g.Color = p.Gradient
		g.Parent = b
		gradient = g
	end
	gloss(b, radius)

	local z = b.ZIndex + 1
	local icon: TextLabel? = nil
	local label: TextLabel? = nil
	if p.Layout == "tile" then
		if p.Icon then
			icon = Theme.Icon(b, p.Icon, {
				Size = UDim2.new(0.66, 0, 0.56, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.07, 0),
				ZIndex = z,
			})
		end
		if p.Text then
			label = Theme.Text(b, p.Text, {
				Size = UDim2.new(0.94, 0, 0.27, 0),
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0.96, 0),
				ZIndex = z,
			})
		end
	else
		local x = 0.08
		if p.Icon then
			icon = Theme.Icon(b, p.Icon, {
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Size = UDim2.fromScale(0.72, 0.72),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				ZIndex = z,
			})
		end
		if p.Text then
			label = Theme.Text(b, p.Text, {
				Size = UDim2.new(if p.Icon then 0.72 else 0.86, 0, 0.62, 0),
				AnchorPoint = Vector2.new(if p.Icon then 1 else 0.5, 0.5),
				Position = UDim2.new(if p.Icon then 1 - x * 0.6 else 0.5, 0, 0.5, 0),
				ZIndex = z,
			})
		end
	end

	Effects.Hoverable(b)
	b.Activated:Connect(function()
		Theme.Play(p.Sound or "click", 0.5)
		if p.OnClick then
			p.OnClick()
		end
	end)
	b.Parent = p.Parent
	return { button = b, label = label, icon = icon, gradient = gradient }
end

-- ─────────────────────────── INSIGNIA ───────────────────────────

export type Badge = {
	frame: Frame,
	set: (text: string?, color: Color3?) -> (),
}

-- Cercle vermell a la cantonada ("!", "3", "🔒"). set(nil) l'amaga.
function Widgets.Badge(parent: GuiObject, size: number?): Badge
	local d = size or 34
	local f = Instance.new("Frame")
	f.Name = "Badge"
	f.Size = UDim2.fromOffset(d, d)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(1, -6, 0, 6)
	f.BackgroundColor3 = C.red
	f.ZIndex = parent.ZIndex + 5
	f.Visible = false
	f.Parent = parent
	Theme.Corner(f, d)
	Theme.Stroke(f, 2.5)
	local label = Theme.Text(f, "!", {
		Size = UDim2.fromScale(0.72, 0.72),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = f.ZIndex + 1,
		StrokeThickness = 1.5,
	})
	Effects.Pulse(f, 0.14, 0.8)
	local shown: string? = nil
	return {
		frame = f,
		set = function(text: string?, color: Color3?)
			if text == shown then
				return
			end
			local wasHidden = shown == nil
			shown = text
			f.Visible = text ~= nil
			if text then
				label.Text = text
				f.BackgroundColor3 = color or C.red
				if wasHidden then
					Theme.Play("pop", 0.35, 1.2)
				end
			end
		end,
	}
end

-- ─────────────────────────── BARRA ───────────────────────────

export type Bar = {
	frame: Frame,
	fill: Frame,
	left: TextLabel,
	right: TextLabel,
	set: (fraction: number, left: string, right: string, color: Color3?) -> (),
}

function Widgets.Bar(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2?): Bar
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = Color3.fromRGB(58, 42, 30)
	f.Parent = parent
	Theme.Corner(f, 16)
	Theme.Stroke(f, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = C.gold
	fill.BorderSizePixel = 0
	fill.Parent = f
	Theme.Corner(fill, 16)
	gloss(fill, 16)

	local left = Theme.Text(f, "", {
		Size = UDim2.new(0.62, 0, 0.66, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 3,
	})
	local right = Theme.Text(f, "", {
		Size = UDim2.new(0.34, 0, 0.66, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		StrokeThickness = 3,
	})
	local bar: Bar
	bar = {
		frame = f,
		fill = fill,
		left = left,
		right = right,
		set = function(fraction: number, l: string, r: string, color: Color3?)
			left.Text = l
			right.Text = r
			if color then
				fill.BackgroundColor3 = color
			end
			local fr = math.clamp(fraction, 0, 1)
			-- Amb molt poc omplert, el cantell arrodonit queda lleig: minim visible
			local target = if fr <= 0 then 0 else math.max(fr, 0.04)
			Effects.Tween(fill, 0.45, { Size = UDim2.fromScale(target, 1) }, Enum.EasingStyle.Back)
		end,
	}
	return bar
end

-- ─────────────────────────── TARGETA ───────────────────────────

function Widgets.Card(parent: Instance, props: { [string]: any }?, color: Color3?, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or C.panelLight
	f.BorderSizePixel = 0
	for key, value in props or {} do
		(f :: any)[key] = value
	end
	Theme.Corner(f, radius or 14)
	Theme.Stroke(f, Theme.STROKE)
	f.Parent = parent
	return f
end

-- ─────────────────────── RÈTOL FLOTANT (hover) ───────────────────────
-- Un sol rètol per a tota la UI: segueix el ratolí i diu què és la peça.
local UserInputService = game:GetService("UserInputService")
local tipGui: ScreenGui? = nil
local tipCard: Frame? = nil
local tipTitle: TextLabel? = nil
local tipSub: TextLabel? = nil
local tipOwner: GuiObject? = nil

local function ensureTip()
	if tipGui then
		return
	end
	local gui = Theme.Screen("TooltipGui", 50)
	gui.IgnoreGuiInset = true
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(250, 62)
	card.BackgroundColor3 = C.ink
	card.BackgroundTransparency = 0.08
	card.Visible = false
	card.ZIndex = 50
	card.Parent = gui
	Theme.Corner(card, 12)
	Theme.Stroke(card, 2.5, C.white)
	tipTitle = Theme.Text(card, "", {
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
	})
	tipSub = Theme.Text(card, "", {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 33),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
	})
	tipGui = gui
	tipCard = card
	-- segueix el ratolí
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement and card.Visible then
			local p = UserInputService:GetMouseLocation()
			card.Position = UDim2.fromOffset(p.X + 18, p.Y + 10)
		end
	end)
end

-- Quan el ratolí passa per sobre de `obj`, ensenya el rètol
function Widgets.Tooltip(obj: GuiObject, title: string, sub: string, color: Color3?)
	obj.MouseEnter:Connect(function()
		ensureTip()
		local card = tipCard :: Frame
		;(tipTitle :: TextLabel).Text = title
		;(tipSub :: TextLabel).Text = sub
		;(tipSub :: TextLabel).TextColor3 = color or C.cream
		local p = UserInputService:GetMouseLocation()
		card.Position = UDim2.fromOffset(p.X + 18, p.Y + 10)
		card.Visible = true
		tipOwner = obj
	end)
	local function hide()
		if tipOwner == obj and tipCard then
			tipCard.Visible = false
			tipOwner = nil
		end
	end
	obj.MouseLeave:Connect(hide)
	obj.AncestryChanged:Connect(function()
		if not obj:IsDescendantOf(game) then
			hide()
		end
	end)
end

-- ─────────────────────── RAJOLA DE PEÇA ───────────────────────

-- Quadradet d'una peça d'os: color de raresa si la tens, fosc amb "?" si no.
function Widgets.PieceTile(parent: Instance, key: string, count: number, size: number, onClick: (() -> ())?, order: number?): GuiObject
	local info = Bones.PieceInfo[key]
	local owned = count > 0
	local rarity = if info then info.rarity else "Common"
	local tile: GuiObject
	if onClick then
		tile = Instance.new("TextButton")
		local tb = tile :: TextButton
		tb.Text = ""
		tb.AutoButtonColor = false
		Effects.Hoverable(tb)
		tb.Activated:Connect(function()
			Theme.Play("click", 0.45)
			onClick()
		end)
	else
		tile = Instance.new("Frame")
	end
	tile.Size = UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = if owned then Bones.RARITY_COLORS[rarity] else Color3.fromRGB(40, 36, 54)
	tile.LayoutOrder = order or 0
	tile.Parent = parent
	Theme.Corner(tile, 10)
	local stroke = Theme.Stroke(tile, 2.5)
	-- les Secret porten la vora d'arc de Sant Martí
	if owned and rarity == "Secret" then
		stroke.Color = C.white
		stroke.Thickness = 3.5
		local g = Instance.new("UIGradient")
		g.Color = Theme.RAINBOW
		g.Parent = stroke
		Effects.Spin(g, 90)
	end
	if owned then
		gloss(tile, 10)
	end
	if owned then
		-- la peça de veritat en 3D (quieta, de tres quarts)
		PieceView.New(tile, key, {
			size = UDim2.fromScale(0.86, 0.66),
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0.04),
			zIndex = tile.ZIndex + 1,
			angle = 25,
		})
	else
		Theme.Icon(tile, "❔", {
			Size = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			ZIndex = tile.ZIndex + 1,
			TextTransparency = 0.35,
		})
	end
	-- de quin animal és, sempre a la vista (el rètol flotant dona la resta)
	if owned and info then
		local def = Bones.ById[info.skeleton]
		Theme.Text(tile, string.upper(def and def.name or info.skeleton), {
			Size = UDim2.new(1, -6, 0.26, 0),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			ZIndex = tile.ZIndex + 2,
			StrokeThickness = 1.5,
		})
		local text, rar = Bones.Describe(key)
		Widgets.Tooltip(tile, text, `{string.upper(rar)} · {Bones.IncomeOf(key)}/min · sells {Bones.SellValue(key)} 💰`, Bones.RARITY_COLORS[rar])
	end
	if count > 1 then
		Theme.Text(tile, "x" .. count, {
			Size = UDim2.fromScale(0.5, 0.3),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 2, 0, -2),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = tile.ZIndex + 2,
		})
	end
	return tile
end

-- Cadenat petit a la cantonada de dalt a l'esquerra d'una rajola: fòssil
-- de recompensa, que no es pot comerciar.
function Widgets.LockMark(tile: GuiObject)
	Theme.Icon(tile, "🔒", {
		Name = "LockMark",
		Size = UDim2.fromScale(0.34, 0.34),
		Position = UDim2.fromOffset(3, 2),
		ZIndex = tile.ZIndex + 3,
	})
end

-- ─────────────────────────── FINESTRA ───────────────────────────

export type WindowProps = {
	Name: string,
	Title: string,
	Icon: string,
	Color: Color3,
	Size: Vector2,
}

export type Window = {
	gui: ScreenGui,
	frame: Frame,
	body: Frame,
	title: TextLabel,
	footer: TextLabel,
	onOpen: (() -> ())?,
}

function Widgets.Window(p: WindowProps): Window
	local gui = Theme.Screen("Window_" .. p.Name, 10)
	gui.Enabled = false

	-- Dos nivells: el de fora s'escala amb la pantalla, el de dins rebota.
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(p.Size.X, p.Size.Y)
	holder.Parent = gui
	Theme.AutoScale(holder, "menu")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = C.panel
	frame.Parent = holder
	Theme.Corner(frame, 22)
	Theme.Stroke(frame, 4.5)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 74)
	header.BackgroundColor3 = p.Color
	header.Parent = frame
	Theme.Corner(header, 22)
	gloss(header, 22)
	-- tapa les cantonades arrodonides de baix de la capçalera
	local patch = Instance.new("Frame")
	patch.Size = UDim2.new(1, 0, 0, 22)
	patch.Position = UDim2.new(0, 0, 1, -22)
	patch.BackgroundColor3 = p.Color
	patch.BorderSizePixel = 0
	patch.Parent = header
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 4)
	line.Position = UDim2.new(0, 0, 1, -2)
	line.BackgroundColor3 = C.ink
	line.BorderSizePixel = 0
	line.ZIndex = 3
	line.Parent = header

	Theme.Icon(header, p.Icon, {
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.fromOffset(18, 10),
		ZIndex = 3,
	})
	local title = Theme.Text(header, p.Title, {
		Size = UDim2.new(1, -170, 0, 48),
		Position = UDim2.fromOffset(84, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 3.5,
	})

	local close = Widgets.Button({
		Parent = frame,
		Size = UDim2.fromOffset(62, 62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -12, 0, 12),
		Color = C.red,
		Text = "X",
		Radius = 31,
		ZIndex = 8,
		OnClick = function()
			Windows.Close(p.Name)
		end,
	})
	close.button.ZIndex = 8

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(18, 90)
	body.Size = UDim2.new(1, -36, 1, -136)
	body.Parent = frame

	local footer = Theme.Text(frame, "", {
		Size = UDim2.new(1, -40, 0, 26),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		TextColor3 = C.muted,
		StrokeThickness = 2,
	})

	local window: Window = {
		gui = gui,
		frame = frame,
		body = body,
		title = title,
		footer = footer,
		onOpen = nil,
	}
	Windows.Register(p.Name, function()
		gui.Enabled = true
		Effects.PopIn(frame, 0.35)
		Theme.Play("open", 0.45)
		if window.onOpen then
			window.onOpen()
		end
	end, function()
		local s = Effects.ScaleOf(frame)
		Effects.Tween(s, 0.15, { Scale = 0.5 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.15, function()
			if not Windows.IsOpen(p.Name) then
				gui.Enabled = false
			end
		end)
	end)
	return window
end

-- Buida un contenidor excepte els modificadors d'UI (layouts, paddings,
-- cantonades, vores, escales...): només treu el contingut.
function Widgets.Clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- ScrollingFrame amb graella, ja preparat.
function Widgets.Grid(parent: Instance, cell: Vector2, size: UDim2, position: UDim2?, padding: number?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = size
	s.Position = position or UDim2.new()
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = C.muted
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(padding or 12, padding or 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = s
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = s
	return s
end

return Widgets
