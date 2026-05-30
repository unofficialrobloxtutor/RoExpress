--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       RoExpress.App
--  ◄► Version:     2.0
--  ◄► Date:        30/05/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: App module for RoExpress
--
--  v2.0 changes
--  ────────────────────────────────────────────────────────────────
--  • Route matching delegated to Router module
--  • Typed params, wildcards, globs, inline constraints
--  • Middleware can return false to block a request (→ 403)
--  • Middleware crash no longer silently continues (→ 500)
--  • app:OnParamError() registers a typed-param failure handler
--  • TokenBucket is now a proper instance (no shared global state)
--  • Version pulled from shared.ROEXPRESS_VERSION (set in init.luau)
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--► Tables       ◄--
local Module = {}
Module.__index = Module
--► Variables    ◄--
local Base64      = require(script.Parent.Base64)
local TokenBucket = require(script.Parent.TokenBucket)
local Router      = require(script.Parent.Router)
local Codec       = require(script.Parent.Codec)
local Tamper      = require(script.Parent.Tamper)
-- Version is set once in init.luau — no more drift between App and Network
local ROEXPRESS_VERSION = shared.ROEXPRESS_VERSION
--► Types        ◄--
export type Type = typeof(setmetatable({}, Module)) & {
	Remote       : RemoteEvent,
	TokenBucket  : typeof(TokenBucket),
	_router      : typeof(Router),
	_middleware  : { { id: string, fn: (Player: Player, Payload: Payload) -> (boolean?) } },
	_connection  : RBXScriptConnection,
}

type Payload = {
	version   : string,
	type      : "request" | "response" | "error",
	method    : "GET" | "POST",
	requestId : string,
	route     : string,
	data      : any,
}

type Request = {
	params   : { [string]: any },      -- coerced typed values
	captures : { any },                -- wildcard / glob positional captures
	query    : { [string]: string },
	data     : any,
}

type Response = {
	Send   : (self: Response, data: any) -> (),
	Error  : (self: Response, message: string) -> (),
	Status : (self: Response, code: number) -> Response,
}
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	PRIVATE
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _parseQuery(route: string): (string, { [string]: string })
	local path, queryString = route:match("^([^?]*)%??(.*)")
	local query = {}
	if queryString and queryString ~= "" then
		for key, value in queryString:gmatch("([^&=]+)=([^&=]+)") do
			query[key] = value
		end
	end
	return path, query
end

local function _validatePayload(Payload: Payload): boolean
	return type(Payload) == "table"
		and type(Payload.route) == "string"
		and type(Payload.requestId) == "string"
		and type(Payload.method) == "string"
		and Payload.type == "request"
end

local function _buildResponse(Remote: RemoteEvent, Player: Player, requestId: string, method: string, compress: boolean?): Response
	local res    = {}
	res._status  = 200
	res._sent    = false

	function res:Status(code: number): Response
		self._status = code
		return self
	end

	function res:Send(data: any)
		if self._sent then
			warn("RoExpress.App: res:Send() called more than once on requestId", requestId)
			return
		end
		self._sent = true

		local payload
		if compress then
			-- compress takes priority over plain base64 for POST
			payload = Codec.Compress(data)
		elseif method == "POST" then
			payload = Base64.EncodeTable(data)
		else
			payload = data
		end

		Remote:FireClient(Player, {
			version    = ROEXPRESS_VERSION,
			type       = "response",
			method     = method,
			requestId  = requestId,
			status     = self._status,
			data       = payload,
			compressed = compress == true,
		})
	end

	function res:Error(message: string)
		if self._sent then
			warn("RoExpress.App: res:Error() called more than once on requestId", requestId)
			return
		end
		self._sent = true

		Remote:FireClient(Player, {
			version   = ROEXPRESS_VERSION,
			type      = "error",
			method    = method,
			requestId = requestId,
			status    = self._status ~= 200 and self._status or 500,
			message   = message,
		})
	end

	return res
end

local function _handler(self: Type, Player: Player, Payload: Payload)
	-- version check
	if Payload.version ~= ROEXPRESS_VERSION then
		warn("RoExpress.App: Version mismatch from", Player.Name, "got", Payload.version, "expected", ROEXPRESS_VERSION)
		local res = _buildResponse(self.Remote, Player, Payload.requestId or "", Payload.method or "GET")
		res:Status(400):Error("Client version mismatch")
		Tamper.Signal("version_mismatch", Player, {
			route    = Payload.route,
			evidence = { got = Payload.version, expected = ROEXPRESS_VERSION },
		})
		return
	end

	-- rate limit check
	if not self.TokenBucket:Consume(Player, 1) then
		local res = _buildResponse(self.Remote, Player, Payload.requestId or "", Payload.method or "GET")
		res:Status(429):Error("Too many requests")
		Tamper.Signal("rate_limited", Player, { route = Payload.route })
		return
	end

	-- validate payload structure
	if not _validatePayload(Payload) then
		warn("RoExpress.App: Invalid payload from", Player.Name)
		Tamper.Signal("malformed", Player, { evidence = Payload })
		return
	end

	-- run global middleware — returning false blocks the request
	for _, entry in ipairs(self._middleware) do
		local ok, result = pcall(entry.fn, Player, Payload)
		if not ok then
			warn("RoExpress.App: Middleware '" .. entry.id .. "' error:", result)
			local res = _buildResponse(self.Remote, Player, Payload.requestId, Payload.method)
			res:Status(500):Error("Middleware error")
			return
		end
		if result == false then
			local res = _buildResponse(self.Remote, Player, Payload.requestId, Payload.method)
			if not res._sent then
				res:Status(403):Error("Blocked by middleware '" .. entry.id .. "'")
			end
			return
		end
	end

	local incomingPath, query = _parseQuery(Payload.route)

	-- match route — compress flag lives on the route entry
	local match = self._router:Match(Payload.method, incomingPath)

	if not match then
		local res = _buildResponse(self.Remote, Player, Payload.requestId, Payload.method, false)
		res:Status(404):Error("No handler for route '" .. Payload.route .. "'")
		Tamper.Signal("unknown_route", Player, {
			route    = Payload.route,
			evidence = { method = Payload.method },
		})
		return
	end

	-- handle typed param failures
	local typeFail = (match :: any)._typeFail
	if typeFail then
		local res = _buildResponse(self.Remote, Player, Payload.requestId, Payload.method, false)
		if self._router._paramError then
			self._router._paramError(Player, Payload, typeFail.name, typeFail.expectedType)
		else
			res:Status(400):Error(
				"Param '" .. typeFail.name .. "' expected type " .. typeFail.expectedType
			)
		end
		Tamper.Signal("param_fail", Player, {
			route    = Payload.route,
			evidence = { param = typeFail.name, expected = typeFail.expectedType },
		})
		return
	end

	local compress = (match.route :: any).compress == true
	local res = _buildResponse(self.Remote, Player, Payload.requestId, Payload.method, compress)

	local req: Request = {
		params   = match.params,
		captures = match.captures,
		query    = query,
		data     = Payload.data,
	}

	local ok, err = pcall(match.route.handler, Player, Payload, req, res)
	if not ok then
		warn("RoExpress.App: Handler error on '" .. Payload.route .. "':", err)
		if not res._sent then
			res:Status(500):Error("Internal server error")
		end
	end
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	CONSTRUCTORS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
function Module.New(Remote: RemoteEvent): Type
	local self       = setmetatable({}, Module) :: Type
	self.Remote      = Remote
	self.TokenBucket = TokenBucket.New({ Max = 10, Refill = 2 })
	self._router     = Router.New()
	self._middleware = {}

	self._connection = self.Remote.OnServerEvent:Connect(function(Player, Payload)
		_handler(self, Player, Payload)
	end)

	return self
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	FUNCTIONS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
function Module:Use(id: string, fn: (Player: Player, Payload: Payload) -> (boolean?))
	table.insert(self._middleware, { id = id, fn = fn })
end

function Module:Unuse(id: string)
	for i, entry in ipairs(self._middleware) do
		if entry.id == id then
			table.remove(self._middleware, i)
			return
		end
	end
	warn("RoExpress.App: No middleware found with id '" .. id .. "'")
end

function Module:Get(route: string, handler: (Player: Player, Payload: Payload, req: Request, res: Response) -> (), options: { compress: boolean? }?)
	self._router:Add("GET", route, handler, options)
end

function Module:Post(route: string, handler: (Player: Player, Payload: Payload, req: Request, res: Response) -> (), options: { compress: boolean? }?)
	self._router:Add("POST", route, handler, options)
end

--[[
	Push a reliable event to a specific player.
	The client receives it via listener:On(event, handler).

	Unlike Broadcast, this uses the reliable RemoteEvent — delivery is
	guaranteed but it consumes bandwidth from the reliable channel budget.

	app:Push(player, "inventoryUpdate", { item = "sword", qty = 1 })
]]
function Module:Push(player: Player, event: string, data: any)
	if player == nil or player.Parent == nil then
		warn("RoExpress.App: Push called with invalid player")
		return
	end
	self.Remote:FireClient(player, {
		type  = "push",
		event = event,
		data  = data,
	})
end

--[[
	Push a reliable event to all connected players.

	app:PushAll("roundEnd", { winner = "PlayerName", score = 500 })
]]
function Module:PushAll(event: string, data: any)
	local Players = game:GetService("Players")
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Parent ~= nil then
			self.Remote:FireClient(player, {
				type  = "push",
				event = event,
				data  = data,
			})
		end
	end
end

--[[
	Push a reliable event to a specific list of players.

	app:PushTo({ player1, player2 }, "zoneAlert", { zoneId = 3 })
]]
function Module:PushTo(players: { Player }, event: string, data: any)
	if not players or #players == 0 then
		warn("RoExpress.App: PushTo called with empty player list")
		return
	end
	for _, player in ipairs(players) do
		if player ~= nil and player.Parent ~= nil then
			self.Remote:FireClient(player, {
				type  = "push",
				event = event,
				data  = data,
			})
		end
	end
end

--[[
	Register a handler for typed param coercion failures.
	If not registered, failures return a plain 400.

	fn(Player, Payload, paramName, expectedType)
]]
function Module:OnParamError(fn: (Player: Player, Payload: Payload, paramName: string, expectedType: string) -> ())
	self._router:OnParamError(fn)
end

function Module:Destroy()
	self._connection:Disconnect()
	self._router:Destroy()
	table.clear(self._middleware)
	self.TokenBucket:Destroy()
end

return Module
