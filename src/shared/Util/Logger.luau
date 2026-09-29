--!strict

-- Logger amb prefix per modul:
--   local log = Logger.new("DigService")
--   log:Info("os trobat", boneId)      --> [DigService] os trobat Femur01
--
-- DEBUG s'activa sol a Studio i queda apagat al joc publicat: els Info
-- desapareixen en produccio, els Warn i Error no (aquests sempre surten).

local RunService = game:GetService("RunService")

local DEBUG = RunService:IsStudio()

local Logger = {}
Logger.__index = Logger

export type Logger = typeof(setmetatable({} :: { _prefix: string }, Logger))

local function compose(prefix: string, ...: any): string
	local parts = table.create(select("#", ...))
	for index = 1, select("#", ...) do
		parts[index] = tostring((select(index, ...)))
	end
	return `[{prefix}] {table.concat(parts, " ")}`
end

function Logger.new(prefix: string): Logger
	return setmetatable({ _prefix = prefix }, Logger) :: any
end

-- Nomes surt amb DEBUG actiu.
function Logger.Info(self: Logger, ...: any)
	if not DEBUG then
		return
	end
	print(compose(self._prefix, ...))
end

function Logger.Warn(self: Logger, ...: any)
	warn(compose(self._prefix, ...))
end

-- No llenca l'error: registra i deixa que el codi decideixi que fa.
function Logger.Error(self: Logger, ...: any)
	warn(compose(self._prefix, "ERROR:", ...))
end

function Logger.IsDebugEnabled(): boolean
	return DEBUG
end

return Logger
