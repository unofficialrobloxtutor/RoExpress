--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       RoExpress.App
--  ◄► Version:     1.6
--  ◄► Date:        05/19/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: App module for RoExpress
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--► Services     ◄--
--► Tables       ◄--
local Module = {}
Module.__index = Module
--► Variables    ◄--
local Base64      = require(script.Parent.Base64)
local TokenBucket = require(script.Parent.TokenBucket)
local ROEXPRESS_VERSION = "1.6"
--► Types        ◄--
export type Type = typeof(setmetatable({}, Module)) & {
	Remote      : RemoteEvent,
	TokenBucket : typeof(TokenBucket),
	_routes     : {
		{
			pattern  : string,
			segments : { string },
			method   : string,
			handler  : (Player: Player, Payload: Payload, req: Request, res: Response) -> ()
		}
	},
	_middleware    : { { id: string, fn: (Player: Player, Payload: Payload) -> () } },
	_connection    : RBXScriptConnection,
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
	params : { [string]: string },
	query  : { [string]: string },
	data   : any,
}

type Response = {
	Send   : (self: Response, data: any) -> (),
	Error  : (self: Response, message: string) -> (),
	Status : (self: Response, code: number) -> Response,
}
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	PRIVATE
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _splitSegments(path: string): { string }
	local segments = {}
	for segment in path:gmatch("[^/]+") do
		table.insert(segments, segment)
	end
	return segments
end

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

local function _matchRoute(incomingPath: string, segments: { string }): { [string]: string }?
	local incomingSegments = _splitSegments(incomingPath)
	if #incomingSegments ~= #segments then return nil end

	local params = {}
	for i, segment in ipairs(segments) do
		if segment:sub(1, 1) == ":" then
			params[segment:sub(2)] = incomingSegments[i]
		elseif segment ~= incomingSegments[i] then
			return nil
		end
	end

	return params
end

local function _validatePayload(Payload: Payload): boolean
	return type(Payload) == "table"
		and type(Payload.route) == "string"
		and type(Payload.requestId) == "string"
		and type(Payload.method) == "string"
		and Payload.type == "request"
end

local function _buildResponse(Remote: RemoteEvent, Player: Player, requestId: string, method: string): Response
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

		local payload = if method == "POST"
			then Base64.EncodeTable(data)
			else data

		Remote:FireClient(Player, {
			version   = ROEXPRESS_VERSION,
			type      = "response",
			method    = method,
			requestId = requestId,
			status    = self._status,
			data      = payload,
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
		return
	end

	-- rate limit check
	if not TokenBucket.Consume(Player, 1) then
		local res = _buildResponse(self.Remote, Player, Payload.requestId or "", Payload.method or "GET")
		res:Status(429):Error("Too many requests")
		return
	end

	-- validate payload structure
	if not _validatePayload(Payload) then
		warn("RoExpress.App: Invalid payload from", Player.Name)
		return
	end

	-- run global middleware
	for _, entry in ipairs(self._middleware) do
		entry.fn(Player, Payload)
	end

	-- strip query from incoming route
	local incomingPath = _parseQuery(Payload.route)

	local req: Request = {
		params = {},
		query  = select(2, _parseQuery(Payload.route)),
		data   = Payload.data,
	}

	local res = _buildResponse(self.Remote, Player, Payload.requestId, Payload.method)

	-- match route against method and pattern
	for _, entry in ipairs(self._routes) do
		if entry.method == Payload.method then
			local params = _matchRoute(incomingPath, entry.segments)
			if params then
				req.params = params
				local ok, err = pcall(entry.handler, Player, Payload, req, res)
				if not ok then
					warn("RoExpress.App: Handler error on '" .. Payload.route .. "':", err)
					if not res._sent then
						res:Status(500):Error("Internal server error")
					end
				end
				return
			end
		end
	end

	res:Status(404):Error("No handler for route '" .. Payload.route .. "'")
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	CONSTRUCTORS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
function Module.New(Remote: RemoteEvent): Type
	local self       = setmetatable({}, Module) :: Type
	self.Remote      = Remote
	self.TokenBucket = TokenBucket
	self._routes     = {}
	self._middleware = {}

	self._connection = self.Remote.OnServerEvent:Connect(function(Player, Payload)
		_handler(self, Player, Payload)
	end)

	return self
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	FUNCTIONS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _register(
	self    : Type,
	method  : string,
	route   : string,
	handler : (Player: Player, Payload: Payload, req: Request, res: Response) -> ()
)
	local path = _parseQuery(route)
	table.insert(self._routes, {
		pattern  = route,
		method   = method,
		segments = _splitSegments(path),
		handler  = handler,
	})
end

function Module:Use(id: string, fn: (Player: Player, Payload: Payload) -> ())
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

function Module:Get(route: string, handler: (Player: Player, Payload: Payload, req: Request, res: Response) -> ())
	_register(self, "GET", route, handler)
end

function Module:Post(route: string, handler: (Player: Player, Payload: Payload, req: Request, res: Response) -> ())
	_register(self, "POST", route, handler)
end

function Module:Destroy()
	self._connection:Disconnect()
	table.clear(self._routes)
	table.clear(self._middleware)
	TokenBucket.Destroy()
end

return Module
