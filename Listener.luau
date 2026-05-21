--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       RoExpress.Listener
--  ◄► Version:     1.1
--  ◄► Date:        05/20/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: Listener module for RoExpress unreliable channel
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--► Services     ◄--
--► Tables       ◄--
local Module = {}
Module.__index = Module
--► Variables    ◄--
--► Types        ◄--
export type Type = typeof(setmetatable({}, Module)) & {
	Remote      : UnreliableRemoteEvent,
	_on         : { [string]: (data: any) -> () },
	_once       : { [string]: (data: any) -> () },
	_middleware : { { id: string, fn: (event: string, data: any) -> () } },
	_connection : RBXScriptConnection,
}
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	PRIVATE
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _dispatch(self: Type, envelope: { event: string, data: any })
	if type(envelope) ~= "table" or type(envelope.event) ~= "string" then
		warn("RoExpress.Listener: Invalid envelope received")
		return
	end

	local event = envelope.event
	local data  = envelope.data

	-- run middleware before handlers
	for _, entry in ipairs(self._middleware) do
		local ok, err = pcall(entry.fn, event, data)
		if not ok then
			warn("RoExpress.Listener: Middleware error on '" .. event .. "':", err)
		end
	end

	-- once handler fires first, unsubscribed before calling to avoid race
	local onceHandler = self._once[event]
	if onceHandler then
		self._once[event] = nil
		local ok, err = pcall(onceHandler, data)
		if not ok then
			warn("RoExpress.Listener: Once handler error on '" .. event .. "':", err)
		end
	end

	-- persistent handler
	local onHandler = self._on[event]
	if onHandler then
		local ok, err = pcall(onHandler, data)
		if not ok then
			warn("RoExpress.Listener: On handler error on '" .. event .. "':", err)
		end
	end
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	CONSTRUCTORS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
function Module.New(Remote: UnreliableRemoteEvent): Type
	local self       = setmetatable({}, Module) :: Type
	self.Remote      = Remote
	self._on         = {}
	self._once       = {}
	self._middleware = {}

	self._connection = self.Remote.OnClientEvent:Connect(function(envelope)
		_dispatch(self, envelope)
	end)

	return self
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	FUNCTIONS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
function Module:Use(id: string, fn: (event: string, data: any) -> ())
	table.insert(self._middleware, { id = id, fn = fn })
end

function Module:Unuse(id: string)
	for i, entry in ipairs(self._middleware) do
		if entry.id == id then
			table.remove(self._middleware, i)
			return
		end
	end
	warn("RoExpress.Listener: No middleware found with id '" .. id .. "'")
end

function Module:On(event: string, handler: (data: any) -> ())
	self._on[event] = handler
end

function Module:Once(event: string, handler: (data: any) -> ())
	self._once[event] = handler
end

function Module:Off(event: string)
	self._on[event]   = nil
	self._once[event] = nil
end

function Module:Destroy()
	self._connection:Disconnect()
	table.clear(self._on)
	table.clear(self._once)
	table.clear(self._middleware)
end

return Module
