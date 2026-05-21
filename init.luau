--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       RoExpress
--  ◄► Version:     1.2
--  ◄► Date:        21/05/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: Root module for RoExpress
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--► Services     ◄--
local RunService = game:GetService("RunService")
--► Tables       ◄--
local RoExpress = {}
RoExpress.__index = RoExpress
--► Variables    ◄--
local IS_SERVER          = RunService:IsServer()
local REMOTE_NAME        = "RoExpressRemote"
local UNRELIABLE_NAME    = "RoExpressUnreliable"

-- server creates both remotes, client waits for them
local Remote;
local UnreliableRemote;
if IS_SERVER then
	Remote = Instance.new("RemoteEvent")
	Remote.Name = REMOTE_NAME
	Remote.Parent = script

	UnreliableRemote = Instance.new("UnreliableRemoteEvent")
	UnreliableRemote.Name = UNRELIABLE_NAME
	UnreliableRemote.Parent = script
else
	Remote           = script:WaitForChild(REMOTE_NAME)
	UnreliableRemote = script:WaitForChild(UNRELIABLE_NAME)
end

-- load only the modules valid for this context
local Base64 = require(script.Base64)

local _modules = if IS_SERVER
	then {
		App       = require(script.App),
		Broadcast = require(script.Broadcast),
		Base64    = Base64,
	}
	else {
		Network  = require(script.Network),
		Listener = require(script.Listener),
		Base64   = Base64,
	}

-- Broadcast and Listener need the UnreliableRemote, everything else gets Remote
local function _getRemoteForModule(moduleName: string): any
	if moduleName == "Broadcast" or moduleName == "Listener" then
		return UnreliableRemote
	end
	return Remote
end

--► Types        ◄--
export type Type = typeof(setmetatable({}, RoExpress)) & {
	_instances: { [string]: any },
}

type ServerModuleName = "App" | "Broadcast" | "Base64"
type ClientModuleName = "Network" | "Listener" | "Base64"
type ModuleName = ServerModuleName | ClientModuleName
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	PRIVATE
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _getInstance(self: Type, moduleName: ModuleName): any
	-- return cached instance if already created
	if self._instances[moduleName] then
		return self._instances[moduleName]
	end

	local m = _modules[moduleName]
	assert(m, "RoExpress: '" .. moduleName .. "' is not available in this context (" .. (IS_SERVER and "Server" or "Client") .. ")")

	-- Base64 has no constructor, return it directly
	local instance = if m.New then m.New(_getRemoteForModule(moduleName)) else m
	self._instances[moduleName] = instance

	return instance
end
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	CONSTRUCTORS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
local function _new(): Type
	local self = setmetatable({}, RoExpress) :: Type
	self._instances = {}
	return self
end

setmetatable(RoExpress, {
	__call = function(_, moduleName: ModuleName)
		if not RoExpress._root then
			RoExpress._root = _new()
		end
		return _getInstance(RoExpress._root, moduleName)
	end
})
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	FUNCTIONS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
RoExpress.Base64 = Base64


--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	TYPES
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

-- core envelope types
export type Payload = {
	version   : string,
	type      : "request" | "response" | "error",
	method    : "GET" | "POST",
	requestId : string,
	route     : string,
	data      : any,
}

export type Request = {
	params : { [string]: string },
	query  : { [string]: string },
	data   : any,
}

export type Response = {
	Send   : (self: Response, data: any) -> (),
	Error  : (self: Response, message: string) -> (),
	Status : (self: Response, code: number) -> Response,
}

export type NetworkResponse = {
	version   : string,
	type      : "response" | "error",
	method    : "GET" | "POST",
	requestId : string,
	status    : number,
	data      : any?,
	message   : string?,
}

export type BroadcastEnvelope = {
	event : string,
	data  : any,
}

-- handler signatures
export type RouteHandler     = (Player: Player, Payload: Payload, req: Request, res: Response) -> ()
export type MiddlewareHandler = (Player: Player, Payload: Payload) -> ()
export type BroadcastHandler  = (data: any) -> ()
export type ListenerMiddleware = (event: string, data: any) -> ()
export type NetworkCallback   = (response: NetworkResponse) -> ()

-- module instance types
export type App       = typeof(require(script.App))
export type Network   = typeof(require(script.Network))
export type Broadcast = typeof(require(script.Broadcast))
export type Listener  = typeof(require(script.Listener))
export type Base64    = typeof(require(script.Base64))



return RoExpress
