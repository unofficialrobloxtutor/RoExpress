------------------------------------------------------------------------
--  <> Title:       RoExpress.Network
--  <> Version:     1.2
--  <> Date:        01/04/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Network module for RoExpress
------------------------------------------------------------------------
-->> Services <<--
-->> Tables <<--
local Module = {}
Module.__index = Module
-->> Variables <<--
local Base64            = require(script.Parent.Base64)
local Codec             = require(script.Parent.Codec)
local Promise           = require(script.Parent.Promise)
local _idCounter        = 0
local TIMEOUT           = 10
-- Version is set once in init.luau — matches App automatically
local ROEXPRESS_VERSION = shared.ROEXPRESS_VERSION
-->> Types <<--
export type Type = typeof(setmetatable({}, Module)) & {
	Remote     : RemoteEvent,
	_pending   : { [string]: { callback: (response: NetworkResponse) -> (), method: string } },
	_connection: RBXScriptConnection,
}

type NetworkPayload = {
	version   : string,
	type      : "request",
	method    : "GET" | "POST",
	requestId : string,
	route     : string,
	data      : any,
}

type NetworkResponse = {
	version   : string,
	type      : "response" | "error",
	method    : "GET" | "POST",
	requestId : string,
	status    : number,
	data      : any?,
	message   : string?,
}
------------------------------------------------------------------------
--	PRIVATE
------------------------------------------------------------------------
local function _generateId(): string
	_idCounter += 1
	return tostring(tick()) .. "_" .. tostring(_idCounter)
end

local function _timeout(self: Type, requestId: string, duration: number)
	task.delay(duration, function()
		local entry = self._pending[requestId]
		if entry then
			self._pending[requestId] = nil
			local errResponse = {
				version   = ROEXPRESS_VERSION,
				type      = "error",
				method    = entry.method,
				requestId = requestId,
				status    = 408,
				data      = nil,
				message   = "Request timed out after " .. duration .. "s",
			}
			if entry.promise then
				entry.promise:_reject(errResponse)
			elseif entry.callback then
				entry.callback(errResponse)
			end
		end
	end)
end

local function _onResponse(self: Type, response: NetworkResponse)
	if response.type ~= "response" and response.type ~= "error" then return end

	local entry = self._pending[response.requestId]
	if not entry then return end

	self._pending[response.requestId] = nil

	-- decode response data
	if response.type == "response" and response.data then
		if response.compressed then
			local ok, decoded = pcall(Codec.Decompress, response.data)
			if ok and decoded ~= nil then
				response.data = decoded
			else
				warn("RoExpress.Network: Failed to decompress response")
				response.data = nil
			end
		elseif entry.method == "POST" then
			local ok, decoded = pcall(Base64.DecodeTable, response.data)
			if ok then
				response.data = decoded
			else
				warn("RoExpress.Network: Failed to decode POST response")
				response.data = nil
			end
		end
	end

	-- resolve promise or call callback
	if entry.promise then
		if response.type == "error" then
			entry.promise:_reject(response)
		else
			entry.promise:_resolve(response)
		end
	elseif entry.callback then
		local ok, err = pcall(entry.callback, response)
		if not ok then
			warn("RoExpress.Network: Callback error:", err)
		end
	end
end
------------------------------------------------------------------------
--	CONSTRUCTORS
------------------------------------------------------------------------
function Module.New(Remote: RemoteEvent): Type
	local self   = setmetatable({}, Module) :: Type
	self.Remote  = Remote
	self._pending = {}

	self._connection = self.Remote.OnClientEvent:Connect(function(response: NetworkResponse)
		_onResponse(self, response)
	end)

	return self
end
------------------------------------------------------------------------
--	FUNCTIONS
------------------------------------------------------------------------
-- internal fire — shared by callback and promise paths
local function _fire(self: Type, method: string, route: string, data: any, entry: any, timeout: number?)
	local requestId = _generateId()
	entry.method    = method
	self._pending[requestId] = entry
	_timeout(self, requestId, timeout or TIMEOUT)
	self.Remote:FireServer({
		version   = ROEXPRESS_VERSION,
		type      = "request",
		method    = method,
		requestId = requestId,
		route     = route,
		data      = data,
	})
	return requestId
end

--[[
	Get(route, data?, callback?, timeout?) -> requestId
	Post(route, data, callback?, timeout?) -> requestId

	Callback-based API. callback is optional — omit for fire-and-forget.
]]
function Module:Get(route: string, data: any?, callback: ((response: NetworkResponse) -> ())?, timeout: number?)
	return _fire(self, "GET", route, data, { callback = callback or function() end }, timeout)
end

function Module:Post(route: string, data: any, callback: ((response: NetworkResponse) -> ())?, timeout: number?)
	return _fire(self, "POST", route, data, { callback = callback or function() end }, timeout)
end

--[[
	GetAsync(route, data?, timeout?) -> Promise
	PostAsync(route, data, timeout?) -> Promise

	Promise-based API. Returns a chainable Promise.

	network:GetAsync("player/123")
	    :Then(function(res) print(res.data) end)
	    :Catch(function(err) warn(err.message) end)
	    :Finally(function() UI:HideLoader() end)
]]
function Module:GetAsync(route: string, data: any?, timeout: number?)
	local promise = Promise.New()
	_fire(self, "GET", route, data, { promise = promise }, timeout)
	return promise
end

function Module:PostAsync(route: string, data: any, timeout: number?)
	local promise = Promise.New()
	_fire(self, "POST", route, data, { promise = promise }, timeout)
	return promise
end

function Module:Cancel(requestId: string)
	-- Stops client processing. Server still executes.
	local entry = self._pending[requestId]
	if entry then
		if entry.promise then entry.promise:Cancel() end
		self._pending[requestId] = nil
		return true
	end
	return false
end

function Module:Destroy()
	self._connection:Disconnect()
	table.clear(self._pending)
end

return Module