--!strict

-- DialogController — parlar amb els botiguers de la plaça:
--   · en Rex (Dig & Co.): només xerra;
--   · la Bonnie (Fossil Buyer): et diu quant valen els teus fòssils i te'ls
--     compra (ho decideix el servidor: SellRequest).
-- Una bombolla a baix amb el que diu (lletra a lletra) i unes quantes opcions.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bones = require(Shared:WaitForChild("Config"):WaitForChild("Bones"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Effects = require(UI:WaitForChild("Effects"))
local Widgets = require(UI:WaitForChild("Widgets"))
local Windows = require(UI:WaitForChild("Windows"))
local ProfileController = require(script.Parent.ProfileController)

local C = Theme.C

local DialogController = {}

-- El text i les etiquetes poden ser funcions (per posar-hi números del moment)
type Option = { label: string | () -> string, go: string?, run: (() -> ())?, color: Color3? }
type Node = { text: string | () -> string, options: { Option } }

local NODES: { [string]: Node } = {
	hello = {
		text = "Hey, digger! I'm Rex. Welcome to Dig & Co., the best tools in town. Walk up to any tool out front and hold E to see it.",
		options = {
			{ label = "What do better tools do?", go = "tools" },
			{ label = "What's the rarest fossil?", go = "rare" },
			{ label = "How do I earn more coins?", go = "coins" },
			{ label = "Bye!" },
		},
	},
	tools = {
		text = "Better trowels give you way more LUCK: the Steel Trowel already gives +50%, and the Diamond Trowel TRIPLES it! Hitting PERFECT in the dig bar gives you more coins.",
		options = { { label = "Cool! Anything else?", go = "hello" }, { label = "Bye!" } },
	},
	rare = {
		text = "Rarity goes Common, Uncommon, Rare, Epic, Legendary, Mythic... and SECRET. Legend says a whole T-Rex is buried under the dig site. Only the luckiest ever find a piece!",
		options = { { label = "I'll find it!", go = "hello" }, { label = "Bye!" } },
	},
	coins = {
		text = "Put your fossils on display in your museum: the rarer, the more they earn. Find ALL the bones of one skeleton (5 to 8, the rarer the more) and BUILD it: a full skeleton earns x5! Cleaner bones earn more too (Pristine x6!), and better trowels dig them up cleaner.",
		options = { { label = "Thanks, Rex!", go = "hello" }, { label = "Bye!" } },
	},
}

-- ── la Bonnie ──
local function looseFossils(dupesOnly: boolean): (number, number)
	local snapshot = ProfileController.Get()
	local n, coins = 0, 0
	-- repetits: de cada peça en queda una, la de millor estat (igual que el servidor)
	local keep: { [string]: string } = {}
	for key in (if snapshot then snapshot.bones else {}) do
		local base = Bones.BaseOf(key)
		if not keep[base] or Bones.GradeOf(key) > Bones.GradeOf(keep[base]) then
			keep[base] = key
		end
	end
	for key, c in (if snapshot then snapshot.bones else {}) do
		local amount = if dupesOnly and keep[Bones.BaseOf(key)] == key then c - 1 else c
		if amount > 0 then
			n += amount
			coins += Bones.SellValue(key) * amount
		end
	end
	return n, coins
end

local function sellNow(action: string)
	Remotes.SellRequest:FireServer(action)
end

local BONNIE: { [string]: Node } = {
	hello = {
		text = function()
			local n, coins = looseFossils(false)
			if n == 0 then
				return "Hi, I'm Bonnie! I buy fossils. You don't have any loose fossils right now... go dig some up and come back!"
			end
			local d, dc = looseFossils(true)
			return `Hi, I'm Bonnie! I buy fossils. You have {n} loose fossils worth {Theme.Short(coins)} coins. {d} of them are duplicates, worth {Theme.Short(dc)} coins.`
		end,
		options = {
			{ label = function()
				local d, dc = looseFossils(true)
				return `🔁 Sell duplicates ({d}) · {Theme.Short(dc)} $`
			end, color = C.green, run = function()
				sellNow("dupes")
			end },
			{ label = function()
				local n, coins = looseFossils(false)
				return `$ Sell ALL ({n}) · {Theme.Short(coins)} $`
			end, go = "confirmAll", color = C.orange },
			{ label = "🎒 Sell just one...", go = "one" },
			{ label = "📋 What's each fossil worth?", go = "prices" },
		},
	},
	confirmAll = {
		text = function()
			local n, coins = looseFossils(false)
			return `Sure? You'll sell ALL {n} loose fossils for {Theme.Short(coins)} coins, even the rare ones! Fossils in your museum are safe.`
		end,
		options = {
			{ label = "✅ Yes, sell everything!", color = C.green, run = function()
				sellNow("all")
			end },
			{ label = "❌ No, wait!", go = "hello" },
		},
	},
	one = {
		text = "Open your 🎒 Backpack, tap the fossil you want to sell and press SELL. I'll pay right away!",
		options = {
			{ label = "🎒 Open my Backpack", color = C.orange, run = function()
				Windows.Open("Backpack")
			end },
			{ label = "Back", go = "hello" },
		},
	},
	prices = {
		text = function()
			local parts = {}
			for _, r in Bones.RARITIES do
				local any = nil
				for _, key in Bones.ALL_KEYS do
					if Bones.PieceInfo[key].rarity == r then
						any = key
						break
					end
				end
				if any then
					table.insert(parts, `{r} {Bones.SellValue(any)}`)
				end
			end
			return "I pay (Dusty): " .. table.concat(parts, " · ") .. ". Clean ones pay more, Pristine x6! Tip: in your museum a fossil earns that same amount every few minutes, so show your best ones!"
		end,
		options = { { label = "Got it!", go = "hello" }, { label = "Bye!" } },
	},
}

local CHARACTERS: { [string]: { tag: string, color: Color3, nodes: { [string]: Node } } } = {
	TalkShopkeeper = { tag = "🦖 REX · DIG & CO.", color = C.orange, nodes = NODES },
	TalkSeller = { tag = "🦴 BONNIE · FOSSIL BUYER", color = C.green, nodes = BONNIE },
}
local nodes: { [string]: Node } = NODES
local nameLabel: TextLabel
local nameTag: Frame

local gui: ScreenGui
local card: Frame
local speech: TextLabel
local options: Frame
local token = 0

local function close()
	token += 1
	Effects.Tween(Effects.ScaleOf(card), 0.15, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.16, function()
		gui.Enabled = false
	end)
end

local function show(id: string)
	local node = nodes[id]
	if not node then
		close()
		return
	end
	token += 1
	local mine = token
	gui.Enabled = true
	Widgets.Clear(options)
	local text = if type(node.text) == "function" then node.text() else node.text
	speech.Text = text
	speech.MaxVisibleGraphemes = 0
	-- lletra a lletra, com als jocs
	task.spawn(function()
		for i = 1, #text do
			if token ~= mine then
				return
			end
			speech.MaxVisibleGraphemes = i
			if i % 3 == 0 then
				task.wait()
			end
		end
		speech.MaxVisibleGraphemes = -1
	end)
	for i, opt in node.options do
		Widgets.Button({
			Parent = options,
			Size = UDim2.fromOffset(300, 46),
			Color = opt.color or (if opt.go then C.blue else C.grey),
			Text = if type(opt.label) == "function" then opt.label() else opt.label,
			LayoutOrder = i,
			OnClick = function()
				if opt.run then
					opt.run()
				end
				if opt.go then
					show(opt.go)
				else
					close()
				end
			end,
		})
	end
end

function DialogController.Start()
	gui = Theme.Screen("DialogGui", 12)
	gui.Enabled = false
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -40)
	holder.Size = UDim2.fromOffset(760, 300)
	holder.Parent = gui
	Theme.AutoScale(holder, "menu")

	card = Widgets.Card(holder, { Size = UDim2.fromScale(1, 1) }, C.panel, 22)
	nameTag = Widgets.Card(card, {
		Size = UDim2.fromOffset(300, 44),
		Position = UDim2.fromOffset(20, -22),
	}, C.orange, 22)
	Theme.Shade(nameTag)
	nameLabel = Theme.Text(nameTag, "", { Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6) })
	speech = Theme.Text(card, "", {
		Size = UDim2.new(1, -40, 0, 100),
		Position = UDim2.fromOffset(20, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 26,
	})
	-- ✕ petit per tancar sense haver de triar cap resposta
	Widgets.CloseButton({ Parent = card, Size = 52, ZIndex = 6, OnClick = close })
	options = Instance.new("Frame")
	options.BackgroundTransparency = 1
	options.Position = UDim2.fromOffset(20, 150)
	options.Size = UDim2.new(1, -40, 0, 130)
	options.Parent = card
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(350, 52)
	grid.CellPadding = UDim2.fromOffset(12, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = options

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local who = CHARACTERS[prompt.Name]
		if who then
			nodes = who.nodes
			nameLabel.Text = who.tag
			nameTag.BackgroundColor3 = who.color
			show("hello")
			Effects.PopIn(card, 0.3)
			Theme.Play("pop", 0.5)
		end
	end)
end

return DialogController
