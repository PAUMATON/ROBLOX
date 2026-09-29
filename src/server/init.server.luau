--!strict

-- Bootstrap del servidor. Nomes orquestra: la logica de cada servei viu al
-- seu propi modul dins Services/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModuleLoader = require(ReplicatedStorage.Shared.Util.ModuleLoader)

local servicesFolder = ModuleLoader.FindFolder(script, "Services")
ModuleLoader.LoadAndStart(servicesFolder, "ServerLoader")
