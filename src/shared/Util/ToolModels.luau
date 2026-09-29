--!strict

-- ToolModels — els models de les eines d'arqueòleg (Config/Tools.model).
-- El mateix codi fa l'eina que portes a la mà (Tool, amb soldadures) i la
-- que hi ha exposada a la botiga (Model ancorat): així són idèntiques.
--
-- Conveni: la peça "Handle" és el mànec, vertical, centrada a l'origen.

local Tools = require(script.Parent.Parent.Config.Tools)

local ToolModels = {}

local DARK = Color3.fromRGB(56, 54, 52)
local V = Vector3.new

type Spec = { name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType? }

-- Les peces de cada eina, relatives al mànec. El primer element és el mànec.
local function specsFor(def: Tools.ToolDef): ({ Spec }, Vector3)
	local metal, wood = def.blade, def.handle
	local M = Enum.Material
	if def.model == "trowel" then
		return {
			{ name = "Handle", size = V(0.34, 1.3, 0.34), pos = V(0, 0, 0), color = wood, material = M.Wood },
			{ name = "Ferrule", size = V(0.4, 0.3, 0.4), pos = V(0, -0.78, 0), color = DARK, material = M.Metal },
			{ name = "Neck", size = V(0.14, 0.5, 0.14), pos = V(0, -1.15, 0.12), color = metal, material = M.Metal },
			{ name = "Blade", size = V(0.9, 1.4, 0.08), pos = V(0, -2, 0.2), color = metal, material = M.Metal },
			{ name = "Tip", size = V(0.45, 0.4, 0.08), pos = V(0, -2.85, 0.2), color = metal, material = M.Metal },
		}, V(0, 0.45, 0) -- agafada per dalt: la fulla penja cap avall
	elseif def.model == "pickaxe" then
		return {
			{ name = "Handle", size = V(0.3, 3.2, 0.3), pos = V(0, 0, 0), color = wood, material = M.Wood },
			{ name = "Head", size = V(0.4, 0.45, 2.6), pos = V(0, 1.55, 0), color = metal, material = M.Metal },
			{ name = "PointA", size = V(0.26, 0.3, 0.7), pos = V(0, 1.45, 1.55), color = metal, material = M.Metal },
			{ name = "PointB", size = V(0.26, 0.3, 0.7), pos = V(0, 1.45, -1.55), color = metal, material = M.Metal },
			{ name = "Wedge", size = V(0.42, 0.3, 0.42), pos = V(0, 1.9, 0), color = DARK, material = M.Metal },
		}, V(0, -0.9, 0)
	elseif def.model == "brush" then
		return {
			{ name = "Handle", size = V(0.26, 1.8, 0.26), pos = V(0, 0, 0), color = wood, material = M.SmoothPlastic },
			{ name = "Ferrule", size = V(0.5, 0.45, 0.24), pos = V(0, -1.1, 0), color = Color3.fromRGB(200, 200, 204), material = M.Metal },
			{ name = "Bristles", size = V(0.9, 0.8, 0.26), pos = V(0, -1.7, 0), color = metal, material = M.Fabric },
			{ name = "Grip", size = V(0.34, 0.6, 0.34), pos = V(0, 0.6, 0), color = DARK, material = M.SmoothPlastic },
		}, V(0, 0.75, 0) -- agafat per dalt: les cerres cap avall
	elseif def.model == "drill" then
		return {
			{ name = "Handle", size = V(0.4, 1.4, 0.5), pos = V(0, 0, 0), color = wood, material = M.SmoothPlastic },
			{ name = "Body", size = V(0.7, 0.9, 1.8), pos = V(0, 0.95, -0.4), color = wood, material = M.SmoothPlastic },
			{ name = "Glow", size = V(0.74, 0.2, 1.4), pos = V(0, 1.2, -0.4), color = metal, material = M.Neon },
			{ name = "Chuck", size = V(0.5, 0.5, 0.5), pos = V(0, 0.95, 0.72), color = DARK, material = M.Metal },
			{ name = "Bit", size = V(0.16, 0.16, 1.5), pos = V(0, 0.95, 1.7), color = metal, material = M.Metal },
		}, V(0, -0.2, 0)
	end
	-- pala (per defecte)
	return {
		{ name = "Handle", size = V(0.28, 3.2, 0.28), pos = V(0, 0, 0), color = wood, material = M.WoodPlanks },
		{ name = "Collar", size = V(0.4, 0.35, 0.4), pos = V(0, -1.5, 0), color = DARK, material = M.Metal },
		{ name = "Blade", size = V(1.1, 1.2, 0.14), pos = V(0, -2.1, 0), color = metal, material = M.Metal },
		{ name = "Grip", size = V(0.9, 0.22, 0.22), pos = V(0, 1.55, 0), color = DARK, material = M.Metal },
	}, V(0, 1.45, 0) -- agafada per dalt del mànec: vertical, la fulla a baix
end

local function build(def: Tools.ToolDef, container: Instance, anchored: boolean, origin: CFrame): BasePart
	local specs = specsFor(def)
	local handle: BasePart? = nil
	for _, spec in specs do
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Size = spec.size
		p.CFrame = origin * CFrame.new(spec.pos)
		p.Color = spec.color
		p.Material = spec.material
		p.Anchored = anchored
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = container
		if not handle then
			handle = p
		end
	end
	local h = handle :: BasePart
	if not anchored then
		-- soldadures després de posar els CFrame: capturen la posició relativa
		for _, child in container:GetChildren() do
			if child:IsA("BasePart") and child ~= h then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = h
				weld.Part1 = child
				weld.Parent = h
			end
		end
	end
	-- les millors eines brillen una mica
	if def.price >= 40000 then
		local glow = Instance.new("PointLight")
		glow.Color = def.blade
		glow.Range = 6
		glow.Brightness = 0.8
		glow.Parent = h
	end
	return h
end

-- L'eina per portar a la mà. `attribute` marca que és l'eina de cavar.
function ToolModels.MakeTool(def: Tools.ToolDef, attribute: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = def.name
	local _, grip = specsFor(def)
	tool.GripPos = grip
	tool:SetAttribute(attribute, true)
	tool:SetAttribute("Tier", def.id)
	build(def, tool, false, CFrame.identity)
	return tool
end

-- L'eina exposada a la botiga, ancorada i col·locada a `cf`
function ToolModels.MakeDisplay(def: Tools.ToolDef, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Display_" .. def.id
	local h = build(def, model, true, cf)
	model.PrimaryPart = h
	return model
end

return ToolModels
