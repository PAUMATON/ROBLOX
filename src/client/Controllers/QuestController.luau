--!strict

-- QuestController — el "quest tracker": la missió en curs a dalt de la
-- pantalla (al lloc del tutorial, quan el tutorial ja s'ha acabat), amb una
-- barra de progrés, el premi i el botó CLAIM quan està complerta.
--
-- Només ensenya el que diu el servidor (QuestUpdate) i demana "claim". A més,
-- guia: el raig de llum (UI/Guide) apunta on s'ha d'anar per fer la missió,
-- o una rajola del HUD s'hi marca amb 👆.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Guide = require(UI:WaitForChild("Guide"))
local Widgets = require(UI:WaitForChild("Widgets"))
local HudController = require(script.Parent.HudController)
local TutorialController = require(script.Parent.TutorialController)

local C = Theme.C
local player = Players.LocalPlayer

local QuestController = {}

-- rajoles del HUD que es marquen quan la missió es fa des d'una finestra
local HUD_TILE: { [string]: string } = { backpack = "Backpack", trade = "Trade", store = "Store" }

local state: any = nil
local holder: Frame
local card: Frame
local counter: TextLabel
local label: TextLabel
local bar: Widgets.Bar
local rewardLabel: TextLabel
local claimButton: Widgets.Button
local markedTile: string? = nil
local lastClaim = 0

-- Es torna a posar a cada volta de guide() (cada mig segon): el HUD reescriu
-- les insígnies de Backpack i Trade cada cop que canvia el perfil, i si només
-- es posés quan canvia la rajola, el 👆 desapareixeria al primer refresc.
local function setTile(name: string?)
	if markedTile and markedTile ~= name then
		HudController.SetBadge(markedTile, nil)
	end
	markedTile = name
	if name then
		HudController.SetBadge(name, "👆", C.green)
	end
end

-- Cap on s'ha d'anar per fer la missió en curs
local function guide()
	if not state or state.done or not holder.Visible then
		Guide.Clear("quest")
		setTile(nil)
		return
	end
	local go = state.go
	if go == "construction" or go == "beach" then
		Guide.PointAt("quest", Guide.ZoneTarget(go))
		setTile(nil)
	elseif go == "shop" then
		Guide.PointAt("quest", Guide.Keeper("TalkShopkeeper") or Guide.TravelPoint("shop"))
		setTile(nil)
	elseif go == "seller" then
		Guide.PointAt("quest", Guide.Keeper("TalkSeller"))
		setTile(nil)
	else
		Guide.Clear("quest")
		setTile(HUD_TILE[go or ""])
	end
end

local function redraw(previous: any?)
	if not state then
		holder.Visible = false
		return
	end
	holder.Visible = not TutorialController.IsActive()
	local chain = tonumber(state.chain) or 0
	counter.Text = if state.index <= chain then `{state.index}/{chain}` else "★"
	label.Text = `📜 {state.text}`
	local target = math.max(1, tonumber(state.target) or 1)
	local progress = math.clamp(tonumber(state.progress) or 0, 0, target)
	bar.set(progress / target, if state.done then "✅ DONE!" else "", `{progress}/{target}`, if state.done then C.green else C.gold)
	rewardLabel.Text = tostring(state.reward or "")
	claimButton.button.Visible = state.done == true
	rewardLabel.Visible = not state.done
	card.BackgroundColor3 = if state.done then C.green else C.blue
	local isNew = not previous or previous.index ~= state.index
	if holder.Visible and (isNew or (state.done and not previous.done)) then
		Effects.PopIn(card, 0.35)
		if previous then
			Theme.Play(if state.done then "reward" else "pop", 0.5, if state.done then 1.1 else 1.2)
		end
	end
	guide()
end

function QuestController.Start()
	local gui = Theme.Screen("QuestGui", 4)
	holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 14)
	holder.Size = UDim2.fromOffset(580, 84)
	holder.Visible = false
	holder.Parent = gui
	Theme.AutoScale(holder)

	card = Widgets.Card(holder, { Size = UDim2.fromScale(1, 1) }, C.blue, 26)
	Theme.Shade(card)
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromOffset(70, 60)
	bubble.Position = UDim2.fromOffset(10, 12)
	bubble.BackgroundColor3 = C.ink
	bubble.Parent = card
	Theme.Corner(bubble, 22)
	counter = Theme.Text(bubble, "", {
		Size = UDim2.new(1, -12, 1, -18),
		Position = UDim2.fromOffset(6, 9),
		TextColor3 = C.yellow,
	})
	label = Theme.Text(card, "", {
		Size = UDim2.new(1, -250, 0, 32),
		Position = UDim2.fromOffset(92, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	})
	bar = Widgets.Bar(card, UDim2.new(1, -250, 0, 30), UDim2.fromOffset(92, 44))
	rewardLabel = Theme.Text(card, "", {
		Size = UDim2.fromOffset(136, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		TextColor3 = C.yellow,
		StrokeThickness = 3,
	})
	claimButton = Widgets.Button({
		Parent = card,
		Size = UDim2.fromOffset(140, 60),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Color = C.gold,
		Icon = "🎁",
		Text = "CLAIM",
		Sound = "reward",
		OnClick = function()
			local now = os.clock()
			if now - lastClaim < 1 then
				return
			end
			lastClaim = now
			Remotes.QuestRequest:FireServer("claim")
			Effects.Confetti(card, 40)
		end,
	})
	claimButton.button.Visible = false
	Effects.Shine(claimButton.button, 14, 1.2)
	Effects.Pulse(claimButton.button, 0.06, 0.9)

	Remotes.QuestUpdate.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		local previous = state
		state = data
		redraw(previous)
	end)
	-- el tutorial s'acaba, et mous: la guia i la visibilitat es revisen soles
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state then
				local visible = not TutorialController.IsActive()
				if holder.Visible ~= visible then
					holder.Visible = visible
					if visible then
						Effects.PopIn(card, 0.35)
					end
				end
				guide()
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		Guide.Clear("quest")
	end)
	Remotes.QuestRequest:FireServer("state")
end

return QuestController
