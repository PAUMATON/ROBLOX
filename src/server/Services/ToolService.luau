--!strict

-- ToolService — l'eina de cavar. Es fa per codi (Util/ToolModels) perquè
-- Rojo en sigui l'amo, i es dona sola en entrar i en reaparèixer.
--
-- L'eina NO porta cap valor: és només el permís per cavar i el seu aspecte.
-- Quina eina tens (i què fa) viu al perfil: `equippedTool` / Config/Tools.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Dig = require(Config:WaitForChild("Dig"))
local Tools = require(Config:WaitForChild("Tools"))
local ToolModels = require(Shared:WaitForChild("Util"):WaitForChild("ToolModels"))

local DataService = require(script.Parent.DataService)

local ToolService = {}

local function currentDef(player: Player): Tools.ToolDef
	local profile = DataService.Get(player)
	return Tools.Get(profile and profile.equippedTool)
end

local function findIn(container: Instance?): Tool?
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

local function findTool(player: Player): Tool?
	return findIn(player:FindFirstChildOfClass("Backpack")) or findIn(player.Character)
end

function ToolService.HasShovel(player: Player): boolean
	return findTool(player) ~= nil
end

function ToolService.IsShovelEquipped(player: Player): boolean
	return findIn(player.Character) ~= nil
end

-- Posa l'eina a la mà si la té a la motxilla. Serveix perquè el botó
-- "Dig" del munt (mòbil) funcioni sense haver d'equipar-la abans.
function ToolService.EquipShovel(player: Player): boolean
	if ToolService.IsShovelEquipped(player) then
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = findIn(player:FindFirstChildOfClass("Backpack"))
	if not humanoid or not tool or humanoid.Health <= 0 then
		return false
	end
	humanoid:EquipTool(tool)
	return ToolService.IsShovelEquipped(player)
end

function ToolService.GiveShovel(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or ToolService.HasShovel(player) then
		return
	end
	ToolModels.MakeTool(currentDef(player), Dig.TOOL_ATTRIBUTE).Parent = backpack
end

-- Canvia l'eina per l'equipada (després de comprar-ne o equipar-ne una).
-- Si la portava a la mà, la nova també hi va.
function ToolService.RefreshShovel(player: Player)
	local old = findTool(player)
	local wasEquipped = ToolService.IsShovelEquipped(player)
	local def = currentDef(player)
	if old and old:GetAttribute("Tier") == def.id then
		return
	end
	if old then
		old:Destroy()
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	ToolModels.MakeTool(def, Dig.TOOL_ATTRIBUTE).Parent = backpack
	if wasEquipped then
		ToolService.EquipShovel(player)
	end
end

function ToolService.Init()
	-- En carregar el perfil, l'eina ha de ser la que toca (en entrar encara
	-- no se sabia i s'ha donat la de defecte).
	DataService.ProfileLoaded:Connect(function(player: Player)
		ToolService.RefreshShovel(player)
	end)
end

function ToolService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- La motxilla es refà amb el personatge; cal esperar que hi sigui.
			player:WaitForChild("Backpack", 10)
			ToolService.GiveShovel(player)
		end)
		if player.Character then
			ToolService.GiveShovel(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return ToolService
