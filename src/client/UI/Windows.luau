--!strict

-- Windows — les finestres (Inventari, Museu, Intercanvi...). Nomes n'hi ha
-- una d'oberta alhora: obrir-ne una tanca la que hi hagi.

local Windows = {}

type Entry = {
	open: () -> (),
	close: () -> (),
}

local registry: { [string]: Entry } = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}

function Windows.Register(name: string, open: () -> (), close: () -> ())
	registry[name] = { open = open, close = close }
end

local function notify()
	for _, fn in listeners do
		task.spawn(fn, current)
	end
end

function Windows.Close(name: string?)
	local target = name or current
	if target and current == target then
		local entry = registry[target]
		current = nil
		if entry then
			entry.close()
		end
		notify()
	end
end

function Windows.Open(name: string)
	if current == name then
		return
	end
	Windows.Close()
	local entry = registry[name]
	if entry then
		current = name
		entry.open()
		notify()
	end
end

function Windows.Toggle(name: string)
	if current == name then
		Windows.Close(name)
	else
		Windows.Open(name)
	end
end

function Windows.IsOpen(name: string): boolean
	return current == name
end

-- (nom de la finestra oberta o nil)
function Windows.OnChanged(fn: (string?) -> ())
	table.insert(listeners, fn)
end

return Windows
