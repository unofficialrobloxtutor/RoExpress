--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       RoExpress.Network
--  ◄► Version:     1.2
--  ◄► Date:        01/04/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: Network module for RoExpress
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--► Services     ◄--
--► Tables       ◄--
local Module = {}
Module.__index = Module
--► Variables    ◄--
local Base64            = require(script.Parent.Base64)
local Codec             = require(script.Parent.Codec)
local _idCounter        = 0
local TIMEOUT           = 10
-- Version is set once in init.luau — matches App automatically
local ROEXPRESS_VERSION = shared.ROEXPRESS_VERSION
--► Types        ◄--
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
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	PRIVATE
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _generateId(): string
	_idCounter += 1
	return tostring(tick()) .. "_" .. tostring(_idCounter)
end

local function _timeout(self: Type, requestId: string, duration: number)
	task.delay(duration, function()
		local entry = self._pending[requestId]
		if entry then
			self._pending[requestId] = nil
			entry.callback({
				version   = ROEXPRESS_VERSION,
				type      = "error",
				method    = entry.method,
				requestId = requestId,
				status    = 408,
				data      = nil,
				message   = "Request timed out after " .. duration .. "s",
			})
		end
	end)
end

local function _onResponse(self: Type, response: NetworkResponse)
	if response.type ~= "response" and response.type ~= "error" then return end

	local entry = self._pending[response.requestId]
	if not entry then return end

	self._pending[response.requestId] = nil

	-- decode response data based on encoding flags
	if response.type == "response" and response.data then
		if response.compressed then
			-- server used Codec.Compress — decompress with LZ77
			local ok, decoded = pcall(Codec.Decompress, response.data)
			if ok and decoded ~= nil then
				response.data = decoded
			else
				warn("RoExpress.Network: Failed to decompress response for requestId", response.requestId)
				response.data = nil
			end
		elseif entry.method == "POST" then
			-- plain base64 POST response (compress not enabled for this route)
			local ok, decoded = pcall(Base64.DecodeTable, response.data)
			if ok then
				response.data = decoded
			else
				warn("RoExpress.Network: Failed to decode POST response")
				response.data = nil
			end
		end
	end

	local ok, err = pcall(entry.callback, response)
	if not ok then
		warn("RoExpress.Network: Callback error:", err)
	end
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	CONSTRUCTORS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
function Module.New(Remote: RemoteEvent): Type
	local self   = setmetatable({}, Module) :: Type
	self.Remote  = Remote
	self._pending = {}

	self._connection = self.Remote.OnClientEvent:Connect(function(response: NetworkResponse)
		_onResponse(self, response)
	end)

	return self
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	FUNCTIONS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _fire(self: Type, method: string, route: string, data: any, callback: (response: NetworkResponse) -> (), timeout: number?)
	local requestId = _generateId()
	self._pending[requestId] = { callback = callback, method = method }
	_timeout(self, requestId, timeout or TIMEOUT)
	self.Remote:FireServer({
		version   = ROEXPRESS_VERSION,
		type      = "request",
		method    = method,
		requestId = requestId,
		route     = route,
		data      = data,
	})
end

function Module:Get(route: string, data: any?, callback: (response: NetworkResponse) -> (), timeout: number?)
	_fire(self, "GET", route, data, callback, timeout)
end

function Module:Post(route: string, data: any, callback: (response: NetworkResponse) -> (), timeout: number?)
	_fire(self, "POST", route, data, callback, timeout)
end

function Module:Cancel(requestId: string)
	-- Note: this only stops the client from processing the response.
	-- The server will still execute the handler and fire back into the void.
	-- There is no mechanism to signal the server to abort mid-flight.
	if self._pending[requestId] then
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