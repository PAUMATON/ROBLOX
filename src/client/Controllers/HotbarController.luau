--!strict

-- HotbarController — la barra d'eines de baix, en lloc de la de Roblox:
--   [1] la paleta (treure-la o guardar-la) · [2..5] les pocions (fer-les
--   servir, amb quantes en tens i el temps que queda) · [6] la motxilla
--   (els fòssils i esquelets, BackpackController).
-- Tecles 1..6 o clic. Només ensenya i demana: fer servir una poció ho
-- valida el servidor (PotionService); treure la paleta és de Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Dig = require(Config:WaitForChild("Dig"))
local Potions = require(Config:WaitForChild("Potions"))
local Tools = require(Config:WaitForChild("Tools"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C
local player = Players.LocalPlayer

local HotbarController = {}

local SLOT, GAP = 84, 10
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }

type Slot = { button: Widgets.Button, count: TextLabel, timer: TextLabel, stroke: UIStroke? }

local slots: { Slot } = {}
local actions: { () -> () } = {}
local snapshotAt = 0
local lastUse = 0

-- ─────────────────────────── LA PALETA ───────────────────────────

local function findTool(container: Instance?): Tool?
	if not container then
		return nil
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(Dig.TOOL_ATTRIBUTE) then
			return child
		end
	end
	return nil
end

local function toolInHand(): Tool?
	return findTool(player.Character)
end

local function toggleTool()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if toolInHand() then
		humanoid:UnequipTools()
		Theme.Play("click", 0.4, 0.9)
	else
		local tool = findTool(player:FindFirstChildOfClass("Backpack"))
		if tool then
			humanoid:EquipTool(tool)
			Theme.Play("click", 0.5, 1.2)
		end
	end
end

-- ─────────────────────────── REFRESC ───────────────────────────

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- segons que queden d'un boost (el servidor els diu en enviar el perfil)
local function leftOf(field: string): number
	local snapshot = ProfileController.Get() :: any
	if not snapshot then
		return 0
	end
	return (tonumber(snapshot[field]) or 0) - (os.clock() - snapshotAt)
end

local function refresh()
	local snapshot = ProfileController.Get()
	if not snapshot or #slots == 0 then
		return
	end
	-- [1] paleta
	local tool = Tools.Get(snapshot.equippedTool)
	local s1 = slots[1]
	s1.button.button.BackgroundColor3 = tool.blade:Lerp(C.panel, 0.35)
	s1.count.Text = string.upper((string.gsub(tool.name, " Trowel", "")))
	local inHand = toolInHand() ~= nil
	if s1.stroke then
		s1.stroke.Color = if inHand then C.yellow else C.ink
		s1.stroke.Thickness = if inHand then 5 else Theme.STROKE
	end
	s1.timer.Text = Tools.LuckText(tool.luck)
	-- [2..5] pocions
	local have = snapshot.potions or {}
	for i, def in Potions.LIST do
		local s = slots[i + 1]
		local n = have[def.id] or 0
		s.count.Text = if n > 0 then `x{n}` else ""
		s.button.button.BackgroundColor3 = if n > 0 then def.color else C.grey
		local left = if def.id == "luck" or def.id == "super" then leftOf("luckBoostLeft")
			elseif def.id == "money" then leftOf("boostLeft")
			else leftOf("hasteLeft")
		s.timer.Text = if left > 0 then clock(left) else ""
	end
	-- [6] motxilla
	local total = 0
	for _, n in snapshot.bones do
		total += n
	end
	slots[#slots].count.Text = if total > 0 then tostring(total) else ""
end

-- ─────────────────────────── CONSTRUCCIÓ ───────────────────────────

local function makeSlot(bar: Frame, i: number, icon: string, color: Color3, key: string, onClick: () -> ()): Slot
	local b = Widgets.Button({
		Parent = bar,
		Size = UDim2.fromOffset(SLOT, SLOT),
		Position = UDim2.fromOffset((i - 1) * (SLOT + GAP), 0),
		Color = color,
		Icon = icon,
		Layout = "tile",
		Radius = 18,
		OnClick = onClick,
	})
	-- la tecla, a dalt a l'esquerra
	Theme.Text(b.button, key, {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(5, 3),
		TextColor3 = C.cream,
		StrokeThickness = 2,
		ZIndex = b.button.ZIndex + 3,
	})
	-- quantes (o el nom de la paleta), a baix
	local count = Theme.Text(b.button, "", {
		Size = UDim2.new(1, -8, 0, 22),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		TextColor3 = C.white,
		StrokeThickness = 2.5,
		ZIndex = b.button.ZIndex + 3,
	})
	-- temps que queda del boost (o la sort de la paleta), a dalt a la dreta
	local timer = Theme.Text(b.button, "", {
		Size = UDim2.fromOffset(52, 20),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 3),
		TextColor3 = C.yellow,
		StrokeThickness = 2,
		ZIndex = b.button.ZIndex + 3,
	})
	actions[i] = onClick
	return { button = b, count = count, timer = timer, stroke = b.button:FindFirstChildOfClass("UIStroke") }
end

local function usePotion(def: Potions.PotionDef)
	local snapshot = ProfileController.Get()
	local n = snapshot and snapshot.potions and snapshot.potions[def.id] or 0
	if n < 1 then
		Effects.Toast(`{def.icon} No {def.name}s yet! Get them from rewards and digging`, C.grey, "error")
		return
	end
	local now = os.clock()
	if now - lastUse < 0.8 then
		return
	end
	lastUse = now
	Remotes.PotionRequest:FireServer("use", def.id)
	Effects.Pop(slots[table.find(Potions.LIST, def) :: number + 1].button.button, 0.4)
end

function HotbarController.Start()
	-- fora la barra de Roblox (la d'aquí la substitueix). Pot fallar si es
	-- crida massa d'hora: es torna a provar uns quants cops.
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
			if ok then
				break
			end
			task.wait(0.5)
		end
	end)

	local gui = Theme.Screen("HotbarGui", 2)
	local count = 2 + #Potions.LIST
	local bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -8)
	bar.Size = UDim2.fromOffset(count * SLOT + (count - 1) * GAP, SLOT)
	bar.Parent = gui
	Theme.AutoScale(bar)

	table.insert(slots, makeSlot(bar, 1, "⛏️", C.orange, "1", toggleTool))
	for i, def in Potions.LIST do
		table.insert(slots, makeSlot(bar, i + 1, def.icon, def.color, tostring(i + 1), function()
			usePotion(def)
		end))
	end
	table.insert(slots, makeSlot(bar, count, "🎒", C.orange, tostring(count), function()
		Windows.Toggle("Backpack")
	end))

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local i = table.find(KEYS, input.KeyCode)
		if i and actions[i] then
			actions[i]()
		end
	end)

	ProfileController.Changed:Connect(function()
		snapshotAt = os.clock()
		refresh()
	end)
	-- la paleta entra i surt de la mà, i els rellotges corren
	local function hookCharacter(character: Model)
		character.ChildAdded:Connect(refresh)
		character.ChildRemoved:Connect(refresh)
	end
	if player.Character then
		hookCharacter(player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
	refresh()
end

return HotbarController
