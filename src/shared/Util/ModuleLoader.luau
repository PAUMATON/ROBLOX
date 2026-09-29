--!strict

-- Logica compartida pels dos bootstraps (server i client): carrega tots els
-- ModuleScripts d'una carpeta i els executa en dues passades.
--   1) Init()  — cada modul prepara nomes el seu propi estat.
--   2) Start() — ara si pot fer servir altres moduls, perque tots ja han
--                fet Init(). Aixo evita bugs d'ordre-de-carrega.
-- Ordre alfabetic dins de cada passada perque sigui reproduible.

local Logger = require(script.Parent.Logger)

local ModuleLoader = {}

export type LoadedModule = {
	Init: ((any) -> ())?,
	Start: ((any) -> ())?,
}

-- Cerca `name` com a descendent de `context` o del seu Parent. La ubicacio
-- exacta depen de com Rojo resol l'init file al capdamunt d'un $path
-- (encara no verificat contra un Studio real), aixi que es cobreixen totes
-- dues possibilitats en lloc de donar per fet un dels dos casos.
function ModuleLoader.FindFolder(context: Instance, name: string): Instance
	local direct = context:FindFirstChild(name, true)
	if direct then
		return direct
	end

	local parent = context.Parent
	if parent then
		local viaParent = parent:FindFirstChild(name, true)
		if viaParent then
			return viaParent
		end
	end

	error(`[ModuleLoader] no s'ha trobat la carpeta "{name}"`, 0)
end

local function sortedNames(map: { [string]: any }): { string }
	local names = {}
	for name in map do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ModuleLoader.LoadAndStart(folder: Instance, loaderName: string)
	local log = Logger.new(loaderName)
	local modules: { [string]: LoadedModule } = {}

	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				modules[child.Name] = result :: LoadedModule
			else
				log:Error(`require({child.Name}) ha petat:`, result)
			end
		end
	end

	local names = sortedNames(modules)

	for _, phaseName in ipairs({ "Init", "Start" }) do
		for _, name in ipairs(names) do
			local moduleTable = modules[name]
			local phase = (moduleTable :: any)[phaseName]
			if phase then
				local ok, err = pcall(phase, moduleTable)
				if not ok then
					log:Error(`{name}.{phaseName}() ha petat:`, err)
				end
			end
		end
	end

	log:Info(`carregats {#names}: {table.concat(names, ", ")}`)
end

return ModuleLoader
