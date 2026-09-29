--!strict

-- Bootstrap del client. Nomes orquestra: la logica de cada controlador viu
-- al seu propi modul dins Controllers/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModuleLoader = require(ReplicatedStorage.Shared.Util.ModuleLoader)

local controllersFolder = ModuleLoader.FindFolder(script, "Controllers")
ModuleLoader.LoadAndStart(controllersFolder, "ClientLoader")
