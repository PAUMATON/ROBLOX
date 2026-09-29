--!strict

-- Signal: events interns, servidor amb servidor o client amb client.
-- NO travessa la xarxa. Per parlar client<->servidor van els Remotes.
--
-- Els handlers s'executen en threads separats (task.spawn): un handler que
-- peta o que espera no atura els altres ni qui ha fet el Fire.

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable(
	{} :: {
		Connected: boolean,
		_signal: any,
		_handler: (...any) -> (),
	},
	Connection
))

export type Signal = typeof(setmetatable(
	{} :: {
		_connections: { Connection },
	},
	Signal
))

function Connection.Disconnect(self: Connection)
	if not self.Connected then
		return
	end
	self.Connected = false

	local connections = self._signal._connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

function Signal.new(): Signal
	return setmetatable({ _connections = {} }, Signal) :: any
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	local connection = setmetatable({
		Connected = true,
		_signal = self,
		_handler = handler,
	}, Connection) :: any

	table.insert(self._connections, connection)
	return connection
end

-- Es desconnecta tot sol despres del primer Fire.
function Signal.Once(self: Signal, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	-- Copia: un handler pot connectar o desconnectar durant el Fire.
	local snapshot = table.clone(self._connections)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.Destroy(self: Signal)
	for _, connection in ipairs(table.clone(self._connections)) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return Signal
