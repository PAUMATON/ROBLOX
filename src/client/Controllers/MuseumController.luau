--!strict

-- MuseumController — la finestra del museu: renda i les 10 vitrines.
-- A cada vitrina hi ha un fòssil o un esquelet muntat. Per posar-n'hi,
-- des de la motxilla (SHOW). Només demana coses: el servidor ho torna a
-- comprovar tot i calcula les monedes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bones = require(Config:WaitForChild("Bones"))
local Museum = require(Config:WaitForChild("Museum"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local PieceView = require(UI:WaitForChild("PieceView"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C

local MuseumController = {}

local window: Widgets.Window
local stats: Frame
local slotsGrid: Frame
local lastCoins: number? = nil

-- ─────────────────── MONEDES QUE SURTEN DE LES VITRINES ───────────────────
-- Cada cop que el museu cobra, cada cosa exposada "escup" les seves monedes.
-- Només decoració: la quantitat la calcula el servidor.

local function ownPlot(): Model?
	local folder = workspace:FindFirstChild("Museums")
	if not folder then
		return nil
	end
	for _, plot in folder:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function coinBurst(slot: BasePart, amount: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 50)
	bb.StudsOffset = Vector3.new(0, 9, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Adornee = slot
	bb.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = Theme.Text(bb, `+{Theme.Short(math.max(1, amount))} $`, { TextColor3 = C.yellow, StrokeThickness = 3 })
	Effects.PopIn(label, 0.3)
	Effects.Tween(bb, 1.3, { StudsOffset = Vector3.new(0, 13, 0) })
	task.delay(0.9, function()
		Effects.Tween(label, 0.4, { TextTransparency = 1 })
	end)
	task.delay(1.4, function()
		bb:Destroy()
	end)
end

local function onIncome(snapshot: ProfileController.Snapshot)
	local gained = if lastCoins then snapshot.coins > lastCoins else false
	lastCoins = snapshot.coins
	if not gained or snapshot.rate <= 0 then
		return
	end
	local plot = ownPlot()
	if not plot then
		return
	end
	for slot = 1, snapshot.slots do
		local item = snapshot.museum[tostring(slot)]
		local base = plot:FindFirstChild("Slot" .. slot)
		if item and base and base:IsA("BasePart") then
			task.delay(slot * 0.1, coinBurst, base, Bones.IncomeOf(item) * Museum.TICK * Museum.PUSH_EVERY / 60)
		end
	end
end

-- ─────────────────────────── FINESTRA ───────────────────────────

local function stat(parent: Instance, x: number, icon: string, text: string, color: Color3)
	local card = Widgets.Card(parent, {
		Size = UDim2.fromOffset(240, 58),
		Position = UDim2.fromOffset(x, 0),
	}, color, 16)
	Theme.Shade(card)
	Theme.Icon(card, icon, { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(10, 8) })
	Theme.Text(card, text, {
		Size = UDim2.new(1, -72, 0, 38),
		Position = UDim2.fromOffset(60, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	})
end

local function slotCard(slot: number, item: string?)
	local rarity = if item then Bones.RarityOf(item) else nil
	local card = Widgets.Card(slotsGrid, { LayoutOrder = slot }, if rarity then C.panelLight else Color3.fromRGB(36, 32, 52), 16)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke and rarity then
		stroke.Color = Bones.RARITY_COLORS[rarity]
		stroke.Thickness = 4
	end
	Theme.Text(card, `#{slot}`, {
		Size = UDim2.fromOffset(34, 20),
		Position = UDim2.fromOffset(8, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
	})
	if not item or not rarity then
		Theme.Text(card, "EMPTY", {
			Size = UDim2.new(1, -20, 0, 26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			TextColor3 = C.muted,
		})
		return
	end
	local info = Bones.PieceInfo[item]
	local def = Bones.ById[if info then info.skeleton else item]
	PieceView.New(card, item, {
		size = UDim2.fromOffset(74, 46),
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 18),
		zIndex = card.ZIndex + 1,
		angle = 25,
	})
	Theme.Text(card, if info then def.name .. " " .. Bones.PIECE_NAMES[def.kind][info.piece] else def.name .. " ✨", {
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.fromOffset(6, 66),
		TextColor3 = Bones.RARITY_COLORS[rarity],
	})
	Theme.Text(card, `+{Museum.PerSecondText(Bones.IncomeOf(item))} $/s`, {
		Size = UDim2.new(1, -12, 0, 18),
		Position = UDim2.fromOffset(6, 88),
		TextColor3 = C.green,
	})
	-- l'estat de la peça, o el bonus de conjunt de l'esquelet
	if info then
		Widgets.GradeBar(card, Bones.GradeOf(item))
	end
	Widgets.Tooltip(card, Bones.GradeText(item), `+{Museum.PerSecondText(Bones.IncomeOf(item))} $/s`, if info then Bones.GradeDef(Bones.GradeOf(item)).color else C.gold)
	-- treure'l de la vitrina (torna a la motxilla)
	Widgets.CloseButton({
		Parent = card,
		Size = 30,
		Inside = true,
		OnClick = function()
			Remotes.MuseumAction:FireServer("withdraw", slot)
		end,
	})
end

local function redraw()
	local snapshot = ProfileController.Get()
	if not snapshot or not Windows.IsOpen("Museum") then
		return
	end
	Widgets.Clear(stats)
	stat(stats, 0, "$", Theme.Short(snapshot.coins), C.gold)
	stat(stats, 256, "📈", `+{Museum.PerSecondText(snapshot.rate)} $/s`, C.green)
	stat(stats, 512, "🏆", `max {Museum.PerSecondText(snapshot.cap)} $/s`, C.purple)
	Widgets.Clear(slotsGrid)
	local used = 0
	for slot = 1, snapshot.slots do
		local item = snapshot.museum[tostring(slot)]
		if item then
			used += 1
		end
		slotCard(slot, item)
	end
	window.footer.Text = `{used}/{snapshot.slots} cases · a full skeleton earns x{Bones.SKELETON_BONUS} its bones`
end

function MuseumController.Start()
	window = Widgets.Window({
		Name = "Museum",
		Title = "MY MUSEUM",
		Icon = "🏛️",
		Color = C.blue,
		Size = Vector2.new(820, 600),
	})
	local body = window.body

	stats = Instance.new("Frame")
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, 0, 0, 60)
	stats.Position = UDim2.fromOffset(16, 0)
	stats.Parent = body

	slotsGrid = Instance.new("Frame")
	slotsGrid.BackgroundTransparency = 1
	slotsGrid.Position = UDim2.fromOffset(0, 74)
	slotsGrid.Size = UDim2.new(1, 0, 0, 250)
	slotsGrid.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(146, 114)
	grid.CellPadding = UDim2.fromOffset(9, 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = slotsGrid

	local add = Widgets.Button({
		Parent = body,
		Size = UDim2.fromOffset(420, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 348),
		Color = C.orange,
		Icon = "🎒",
		Text = "ADD FROM BACKPACK",
		OnClick = function()
			Windows.Open("Backpack")
		end,
	})
	Effects.Shine(add.button, 14, 2.4)

	window.onOpen = redraw
	ProfileController.Changed:Connect(redraw)
	ProfileController.Changed:Connect(onIncome)
end

return MuseumController
