--!strict

-- BackpackController — la motxilla: els fòssils i esquelets que TENS.
-- Tries un fòssil i el poses al museu (SHOW) o, si en tens les 5 peces,
-- muntes l'esquelet (BUILD, rendeix el doble). L'índex (el que has
-- descobert algun cop) és una altra finestra: IndexController.
-- Només ensenya i demana: el servidor ho valida tot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bones = require(Shared:WaitForChild("Config"):WaitForChild("Bones"))
local Museum = require(Shared:WaitForChild("Config"):WaitForChild("Museum"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local PieceView = require(UI:WaitForChild("PieceView"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C

local BackpackController = {}

local window: Widgets.Window
local scroll: ScrollingFrame
local detail: Frame
local selected: string? = nil -- peça ("Rat_Skull") o esquelet ("Rat")

local function section(text: string, order: number)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -16, 0, 32)
	f.LayoutOrder = order
	f.Parent = scroll
	Theme.Text(f, text, { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.yellow })
end

local function grid(order: number, cell: number): Frame
	local g = Instance.new("Frame")
	g.BackgroundTransparency = 1
	g.Size = UDim2.new(1, -16, 0, 0)
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.LayoutOrder = order
	g.Parent = scroll
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell, cell)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = g
	return g
end

local function sortedKeys(counts: { [string]: number }, isPiece: boolean): { string }
	local keys = {}
	for key, n in counts do
		if n > 0 and (if isPiece then Bones.IsPieceKey(key) else Bones.IsSkeletonId(key)) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local ra, rb = Bones.RARITY_ORDER[Bones.RarityOf(a)], Bones.RARITY_ORDER[Bones.RarityOf(b)]
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	return keys
end

-- ─────────────────────── BARRA DE DETALL (a baix) ───────────────────────

local function drawDetail(snapshot: ProfileController.Snapshot)
	Widgets.Clear(detail)
	local item = selected
	local owned = item and ((snapshot.bones[item] or 0) > 0 or (snapshot.skeletons[item] or 0) > 0)
	if not item or not owned then
		selected = nil
		Theme.Text(detail, "Tap a fossil to show it in your museum 🏛️", {
			Size = UDim2.new(1, -30, 0, 30),
			Position = UDim2.fromOffset(15, 26),
			TextColor3 = C.muted,
		})
		return
	end
	local rarity = Bones.RarityOf(item)
	local isPiece = Bones.IsPieceKey(item)
	local name = if isPiece then (Bones.Describe(item)) else Bones.ById[item].name .. " Skeleton"
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(130, 30)
	pill.Position = UDim2.fromOffset(14, 10)
	pill.BackgroundColor3 = Bones.RARITY_COLORS[rarity]
	pill.Parent = detail
	Theme.Corner(pill, 15)
	Theme.Stroke(pill, 2)
	Theme.Text(pill, string.upper(rarity), { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4) })
	local canBuild = isPiece and Bones.CanAssemble(snapshot.bones, Bones.PieceInfo[item].skeleton)
	-- espai que ocupen els botons de la dreta (SHOW, BUILD i SELL)
	local rightUsed = 204 + (if canBuild then 262 else 0) + (if isPiece then 172 else 0)
	Theme.Text(detail, name, {
		Size = UDim2.new(1, -(rightUsed + 160), 0, 30),
		Position = UDim2.fromOffset(154, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local locked = if isPiece then (snapshot.locked or {})[item] or 0 else 0
	local income = `+{Museum.PerSecondText(Bones.IncomeOf(item))} $/s in your museum`
	if locked > 0 then
		income ..= ` · 🔒 {locked} gift{if locked == 1 then "" else "s"}: can't trade`
	end
	Theme.Text(detail, income, {
		Size = UDim2.new(1, -(rightUsed + 20), 0, 24),
		Position = UDim2.fromOffset(16, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.green,
	})
	local show = Widgets.Button({
		Parent = detail,
		Size = UDim2.fromOffset(180, 60),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Color = C.green,
		Icon = "🏛️",
		Text = "SHOW",
		Sound = "reward",
		OnClick = function()
			Remotes.MuseumAction:FireServer("display", item)
			Effects.Toast(`🏛️ {name} is on display! +{Museum.PerSecondText(Bones.IncomeOf(item))} $/s`, C.green, "reward")
		end,
	})
	Effects.Shine(show.button, 14, 1.8)
	if isPiece then
		local info = Bones.PieceInfo[item]
		if Bones.CanAssemble(snapshot.bones, info.skeleton) then
			local def = Bones.ById[info.skeleton]
			local build = Widgets.Button({
				Parent = detail,
				Size = UDim2.fromOffset(250, 60),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -204, 0.5, 0),
				Color = C.gold,
				Icon = "🔨",
				Text = "BUILD x2 $",
				Sound = "reward",
				OnClick = function()
					Remotes.MuseumAction:FireServer("assemble", def.id)
					selected = def.id
					Effects.Toast(`🦴 {def.name} skeleton built! It earns double $`, C.gold, "reward")
				end,
			})
			Effects.Shine(build.button, 14, 1.2)
		end
		-- vendre-la a la Bonnie (el servidor mira que siguis a la parada)
		local value = Bones.SellValue(item)
		Widgets.Button({
			Parent = detail,
			Size = UDim2.fromOffset(160, 60),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(204 + (if canBuild then 262 else 0)), 0.5, 0),
			Color = C.orange,
			Text = `SELL {Theme.Short(value)} $`,
			OnClick = function()
				Remotes.SellRequest:FireServer("one", item)
			end,
		})
	end
end

-- ─────────────────────────── REDIBUIXA ───────────────────────────

local function redraw()
	local snapshot = ProfileController.Get()
	if not snapshot or not Windows.IsOpen("Backpack") then
		return
	end
	Widgets.Clear(scroll)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- esquelets que ja pots muntar
	local ready = {}
	for _, def in Bones.SKELETONS do
		if Bones.CanAssemble(snapshot.bones, def.id) then
			table.insert(ready, def)
		end
	end
	if #ready > 0 then
		section("🔨 READY TO BUILD (earns x2!)", nextOrder())
		local g = grid(nextOrder(), 84)
		for i, def in ready do
			local tile = Widgets.PieceTile(g, Bones.PieceKey(def.id, "Skull"), 1, 84, function()
				selected = Bones.PieceKey(def.id, "Skull")
				drawDetail(snapshot)
			end, i)
			Widgets.Badge(tile, 30).set("🔨", C.gold)
		end
	end

	local skeletons = sortedKeys(snapshot.skeletons, false)
	if #skeletons > 0 then
		section("🦴 SKELETONS", nextOrder())
		local g = grid(nextOrder(), 84)
		for i, id in skeletons do
			local def = Bones.ById[id]
			local b = Widgets.Button({
				Parent = g,
				Size = UDim2.fromOffset(84, 84),
				Color = Bones.RARITY_COLORS[def.rarity],
				Icon = def.icon,
				Text = if snapshot.skeletons[id] > 1 then "x" .. snapshot.skeletons[id] else def.name,
				Layout = "tile",
				LayoutOrder = i,
				OnClick = function()
					selected = id
					drawDetail(snapshot)
				end,
			})
			-- l'esquelet muntat de veritat en lloc de l'emoji
			if b.icon then
				b.icon.Visible = false
				PieceView.New(b.button, id, {
					size = UDim2.fromScale(0.92, 0.66),
					anchor = Vector2.new(0.5, 0),
					position = UDim2.fromScale(0.5, 0.02),
					zIndex = b.button.ZIndex + 2,
					angle = 30,
				})
			end
		end
	end

	local pieces = sortedKeys(snapshot.bones, true)
	section(`🦴 FOSSILS ({#pieces})`, nextOrder())
	if #pieces == 0 then
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, -16, 0, 40)
		f.LayoutOrder = nextOrder()
		f.Parent = scroll
		Theme.Text(f, "Your backpack is empty. Go dig at the 🏗️ Dig Site!", { TextColor3 = C.muted })
	else
		local g = grid(nextOrder(), 74)
		for i, key in pieces do
			local tile = Widgets.PieceTile(g, key, snapshot.bones[key], 74, function()
				selected = key
				drawDetail(snapshot)
			end, i)
			if ((snapshot.locked or {})[key] or 0) > 0 then
				Widgets.LockMark(tile)
			end
			if key == selected then
				local s = tile:FindFirstChildOfClass("UIStroke")
				if s then
					s.Color = C.yellow
					s.Thickness = 4
				end
			end
		end
	end
	drawDetail(snapshot)
	local total = 0
	for _, n in snapshot.bones do
		total += n
	end
	window.footer.Text = `{total} fossils · pieces of the same rarity are all equally rare`
end

function BackpackController.Start()
	window = Widgets.Window({
		Name = "Backpack",
		Title = "BACKPACK",
		Icon = "🎒",
		Color = C.orange,
		Size = Vector2.new(820, 600),
	})
	scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -92)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.Parent = window.body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = scroll

	detail = Widgets.Card(window.body, {
		Size = UDim2.new(1, 0, 0, 84),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
	}, Color3.fromRGB(36, 32, 52), 16)

	window.onOpen = redraw
	ProfileController.Changed:Connect(redraw)
end

return BackpackController
