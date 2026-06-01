------------------------------------------------------------------------
--  <> Title:       RoExpress.Bridge
--  <> Version:     1.1
--  <> Date:        30/05/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Shared internal event bus for RoExpress.
--
--  Bridge is a structured replacement for raw BindableEvents.
--  It runs in both server and client contexts as a shared singleton —
--  the same require() call gives you the same instance everywhere
--  within that context.
--
--  PHILOSOPHY
--  ────────────────────────────────────────────────────────────────
--  Raw BindableEvents scatter connection management across every
--  module that uses them. Bridge centralises it:
--
--    Without Bridge:
--      local KillEvent = Instance.new("BindableEvent")
--      KillEvent.Event:Connect(handler)   ← ModuleA
--      KillEvent:Fire(data)               ← ModuleB needs the ref
--
--    With Bridge:
--      bridge.Bind("kill", handler)       ← ModuleA
--      bridge.Fire("kill", data)          ← ModuleB, no ref needed
--
--  DESIGN
--  ────────────────────────────────────────────────────────────────
--  • Named channels — every event has a string name
--  • Multiple handlers per channel — all bound handlers fire
--  • bridge.Bind(name, handler)           register a handler
--  • bridge.Unbind(name, handler)         remove a specific handler
--  • bridge.UnbindAll(name?)              clear one channel or all
--  • bridge.Fire(name, data?)             fire to all handlers
--  • bridge.Has(name)                     check if handlers exist
--
--  YIELDABLE VARIANTS
--  ────────────────────────────────────────────────────────────────
--  • bridge.Wait(name, timeout?)
--      Yields until the channel fires once. Returns data, or nil
--      if the timeout expires.
--
--  • bridge.WaitUntil(name, predicate, timeout?)
--      Yields until the channel fires AND predicate(data) is true.
--      Non-matching fires are silently skipped. Returns data, or
--      nil on timeout.
--
--  • bridge.WaitFirst(names, timeout?)
--      Yields until any one of the listed channels fires. Returns
--      (channelName, data), or (nil, nil) on timeout.
--
--  All three yield safely using coroutine.wrap + task.delay.
--  A temporary internal handler is registered and always cleaned up
--  regardless of how the wait resolves — no coroutine leaks.
--
--  SINGLETON
--  ────────────────────────────────────────────────────────────────
--  Bridge has no New() constructor — requiring this module IS the
--  constructor. RoExpress("Bridge") always returns the same table
--  within a given Luau VM context.
------------------------------------------------------------------------

-->> Tables <<--
local Bridge = {}
Bridge.__index = Bridge

-->> Types <<--
export type Handler   = (data: any) -> ()
export type Predicate = (data: any) -> boolean
export type Channel   = { handlers: { Handler } }
export type Type      = typeof(Bridge) & {
	_channels : { [string]: Channel },
}

-->> State <<--
Bridge._channels = {}

-- Default timeout for all Wait variants when none is specified
local DEFAULT_TIMEOUT = 10

------------------------------------------------------------------------
--	PRIVATE
------------------------------------------------------------------------

local function _getOrCreate(name: string): Channel
	if not Bridge._channels[name] then
		Bridge._channels[name] = { handlers = {} }
	end
	return Bridge._channels[name]
end

-- Remove a handler reference from a channel by identity.
-- Does not warn if not found — used internally by Wait variants
-- where the handler may have already been removed by the timeout path.
local function _removeHandler(name: string, handler: Handler)
	local channel = Bridge._channels[name]
	if not channel then return end
	for i, h in ipairs(channel.handlers) do
		if h == handler then
			table.remove(channel.handlers, i)
			return
		end
	end
end

------------------------------------------------------------------------
--	FUNCTIONS
------------------------------------------------------------------------

--[[
	Bind(name, handler)

	Register a persistent handler on a named channel.
	Multiple handlers can be bound to the same channel —
	all fire in registration order when bridge.Fire is called.

	bridge.Bind("kill", function(data)
	    print(data.killer, "→", data.victim)
	end)
]]
function Bridge.Bind(name: string, handler: Handler)
	assert(type(name)    == "string",   "RoExpress.Bridge: Bind — name must be a string")
	assert(type(handler) == "function", "RoExpress.Bridge: Bind — handler must be a function")
	local channel = _getOrCreate(name)
	table.insert(channel.handlers, handler)
end

--[[
	Unbind(name, handler)

	Remove a specific handler from a channel by reference.
	Logs a warning if the handler is not found.

	bridge.Unbind("kill", myHandler)
]]
function Bridge.Unbind(name: string, handler: Handler)
	assert(type(name)    == "string",   "RoExpress.Bridge: Unbind — name must be a string")
	assert(type(handler) == "function", "RoExpress.Bridge: Unbind — handler must be a function")

	local channel = Bridge._channels[name]
	if not channel then
		warn("RoExpress.Bridge: Unbind — no channel '" .. name .. "'")
		return
	end

	for i, h in ipairs(channel.handlers) do
		if h == handler then
			table.remove(channel.handlers, i)
			return
		end
	end

	warn("RoExpress.Bridge: Unbind — handler not found on '" .. name .. "'")
end

--[[
	UnbindAll(name?)

	Clear all handlers on one channel, or every channel.

	bridge.UnbindAll("kill")  -- just "kill"
	bridge.UnbindAll()        -- everything
]]
function Bridge.UnbindAll(name: string?)
	if name ~= nil then
		assert(type(name) == "string", "RoExpress.Bridge: UnbindAll — name must be a string")
		Bridge._channels[name] = nil
	else
		table.clear(Bridge._channels)
	end
end

--[[
	Fire(name, data?)

	Fire an event to all handlers on the named channel.
	Handlers are snapshot'd before iteration so Unbind calls
	inside a handler are safe. Each handler is pcall'd
	independently — a crash in one does not stop the rest.

	bridge.Fire("kill", { killer = "PlayerA", victim = "PlayerB" })
]]
function Bridge.Fire(name: string, data: any?)
	assert(type(name) == "string", "RoExpress.Bridge: Fire — name must be a string")

	local channel = Bridge._channels[name]
	if not channel or #channel.handlers == 0 then return end

	local snapshot = table.clone(channel.handlers)
	for _, handler in ipairs(snapshot) do
		local ok, err = pcall(handler, data)
		if not ok then
			warn("RoExpress.Bridge: Handler error on '" .. name .. "':", err)
		end
	end
end

--[[
	Has(name)

	Returns true if the channel has at least one bound handler.
	Useful to guard Fire calls in hot paths.

	if bridge.Has("kill") then
	    bridge.Fire("kill", data)
	end
]]
function Bridge.Has(name: string): boolean
	local channel = Bridge._channels[name]
	return channel ~= nil and #channel.handlers > 0
end

------------------------------------------------------------------------
--	YIELDABLE VARIANTS
------------------------------------------------------------------------

--[[
	Wait(name, timeout?) → data | nil

	Yields the current coroutine until the named channel fires once.
	Returns the data payload when it fires.
	Returns nil if the timeout expires before the channel fires.

	Default timeout: 10 seconds.

	-- block until a round starts (up to 30s)
	local data = bridge.Wait("round.start", 30)
	if data then
	    print("Round started with duration:", data.duration)
	else
	    print("Timed out waiting for round.start")
	end
]]
function Bridge.Wait(name: string, timeout: number?): any?
	assert(type(name) == "string", "RoExpress.Bridge: Wait — name must be a string")

	local thread   = coroutine.running()
	local resolved = false
	local handler: Handler

	handler = function(data: any)
		if resolved then return end
		resolved = true
		_removeHandler(name, handler)
		task.spawn(thread, data)
	end

	_getOrCreate(name)
	table.insert(Bridge._channels[name].handlers, handler)

	-- timeout path — resumes with nil if channel never fires
	task.delay(timeout or DEFAULT_TIMEOUT, function()
		if resolved then return end
		resolved = true
		_removeHandler(name, handler)
		task.spawn(thread, nil)
	end)

	return coroutine.yield()
end

--[[
	WaitUntil(name, predicate, timeout?) → data | nil

	Yields until the named channel fires AND predicate(data) returns
	true. Fires that don't satisfy the predicate are silently skipped
	and the coroutine remains yielded.
	Returns the matching data, or nil on timeout.

	-- wait for a kill where the victim is this player
	local data = bridge.WaitUntil("kill", function(d)
	    return d.victim == LocalPlayer.Name
	end, 60)

	if data then
	    print("You were killed by", data.killer)
	end
]]
function Bridge.WaitUntil(name: string, predicate: Predicate, timeout: number?): any?
	assert(type(name)      == "string",   "RoExpress.Bridge: WaitUntil — name must be a string")
	assert(type(predicate) == "function", "RoExpress.Bridge: WaitUntil — predicate must be a function")

	local thread   = coroutine.running()
	local resolved = false
	local handler: Handler

	handler = function(data: any)
		if resolved then return end

		-- test predicate — skip if it doesn't match
		local ok, result = pcall(predicate, data)
		if not ok then
			warn("RoExpress.Bridge: WaitUntil predicate error on '" .. name .. "':", result)
			return
		end
		if not result then return end  -- condition not met, keep waiting

		resolved = true
		_removeHandler(name, handler)
		task.spawn(thread, data)
	end

	_getOrCreate(name)
	table.insert(Bridge._channels[name].handlers, handler)

	task.delay(timeout or DEFAULT_TIMEOUT, function()
		if resolved then return end
		resolved = true
		_removeHandler(name, handler)
		task.spawn(thread, nil)
	end)

	return coroutine.yield()
end

--[[
	WaitFirst(names, timeout?) → (channelName | nil, data | nil)

	Yields until any one of the named channels fires first.
	Returns (channelName, data) for whichever fires first.
	Returns (nil, nil) if the timeout expires before any fire.

	All registered internal handlers are cleaned up after resolution
	regardless of which channel won.

	-- wait for either a round start or a server shutdown
	local event, data = bridge.WaitFirst({ "round.start", "server.shutdown" }, 60)
	if event == "round.start" then
	    print("Round starting, duration:", data.duration)
	elseif event == "server.shutdown" then
	    print("Server shutting down")
	else
	    print("Timed out")
	end
]]
function Bridge.WaitFirst(names: { string }, timeout: number?): (string?, any?)
	assert(type(names) == "table" and #names > 0,
		"RoExpress.Bridge: WaitFirst — names must be a non-empty array of strings")

	local thread   = coroutine.running()
	local resolved = false

	-- track all temporary handlers so we can clean them all up
	local handlers: { [string]: Handler } = {}

	local function cleanup()
		for _, name in ipairs(names) do
			if handlers[name] then
				_removeHandler(name, handlers[name])
			end
		end
	end

	for _, name in ipairs(names) do
		assert(type(name) == "string",
			"RoExpress.Bridge: WaitFirst — each name must be a string, got " .. type(name))

		local capturedName = name
		local handler: Handler

		handler = function(data: any)
			if resolved then return end
			resolved = true
			cleanup()
			task.spawn(thread, capturedName, data)
		end

		handlers[name] = handler
		_getOrCreate(name)
		table.insert(Bridge._channels[name].handlers, handler)
	end

	task.delay(timeout or DEFAULT_TIMEOUT, function()
		if resolved then return end
		resolved = true
		cleanup()
		task.spawn(thread, nil, nil)
	end)

	return coroutine.yield()
end

------------------------------------------------------------------------
--	DESTROY
------------------------------------------------------------------------

--[[
	Destroy()

	Clears all channels and handlers. Any coroutines currently
	yielded inside Wait, WaitUntil, or WaitFirst will NOT be
	resumed — call this only on full shutdown or test teardown.
]]
function Bridge.Destroy()
	table.clear(Bridge._channels)
end

return Bridge
