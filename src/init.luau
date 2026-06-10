------------------------------------------------------------------------
--  <> Title:       RoExpress
--  <> Version:     2.2
--  <> Date:        30/05/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Root module for RoExpress
------------------------------------------------------------------------
-->> Services <<--
local RunService = game:GetService("RunService")
-->> Tables <<--
local RoExpress = {}
RoExpress.__index = RoExpress
-->> Variables <<--
local IS_SERVER          = RunService:IsServer()
local REMOTE_NAME        = "RoExpressRemote"
local UNRELIABLE_NAME    = "RoExpressUnreliable"

-- Version.luau is the only module that writes shared.ROEXPRESS_VERSION
-- Require it first so the value is set before any other module reads it
local _Version = require(script.Version)

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
local Base64      = require(script.Base64)
local Router      = require(script.Router)
local Codec       = require(script.Codec)
local Bridge      = require(script.Bridge)
local Tamper      = require(script.Tamper)
local TypeCoercer = require(script.TypeCoercer)
local Promise     = require(script.Promise)
local Harpy       = require(script.Harpy)

local _modules = if IS_SERVER
	then {
		App         = require(script.App),
		Broadcast   = require(script.Broadcast),
		Base64      = Base64,
		Bridge      = Bridge,
		Tamper      = Tamper,
		Port        = require(script.Port),
		Stream      = require(script.Stream),
		TypeCoercer = TypeCoercer,
		Version     = _Version,
	}
	else {
		Network     = require(script.Network),
		Listener    = require(script.Listener),
		Base64      = Base64,
		Bridge      = Bridge,
		Stream      = require(script.Stream),
		TypeCoercer = TypeCoercer,
		Promise     = Promise,
		Version     = _Version,
	}

-- Broadcast and Listener need the UnreliableRemote, everything else gets Remote
-- Listener also gets the reliable Remote so it can receive server push events
local function _getRemoteForModule(moduleName: string): any
	if moduleName == "Broadcast" then
		return UnreliableRemote
	end
	if moduleName == "Listener" then
		-- Listener.New(unreliable, reliable) — pass both
		return UnreliableRemote, Remote
	end
	return Remote
end

-->> Types <<--
export type Type = typeof(setmetatable({}, RoExpress)) & {
	_instances: { [string]: any },
}

type ServerModuleName = "App" | "Broadcast" | "Base64" | "Bridge" | "Tamper" | "Stream" | "TypeCoercer" | "Version"
type ClientModuleName = "Network" | "Listener" | "Base64" | "Bridge" | "Stream" | "TypeCoercer" | "Promise" | "Version"
type ModuleName = ServerModuleName | ClientModuleName
------------------------------------------------------------------------
--	PRIVATE
------------------------------------------------------------------------
local function _getInstance(self: Type, moduleName: ModuleName): any
	-- return cached instance if already created
	if self._instances[moduleName] then
		return self._instances[moduleName]
	end

	local m = _modules[moduleName]
	assert(m, "RoExpress: '" .. moduleName .. "' is not available in this context (" .. (IS_SERVER and "Server" or "Client") .. ")")

	-- Base64, Bridge, Tamper and Stream have no constructor — return directly.
	-- Listener takes two remotes — unpack accordingly.
	local instance
	if moduleName == "Listener" then
		local unreliable, reliable = _getRemoteForModule(moduleName)
		instance = m.New(unreliable, reliable)
	elseif m.New then
		instance = m.New(_getRemoteForModule(moduleName))
	else
		instance = m
	end
	self._instances[moduleName] = instance

	return instance
end
------------------------------------------------------------------------
--	CONSTRUCTORS
------------------------------------------------------------------------
local function _new(): Type
	local self = setmetatable({}, RoExpress) :: Type
	self._instances = {}
	return self
end

setmetatable(RoExpress, {
	__call = function(_, moduleName: ModuleName, portName: string?)
		if not RoExpress._root then
			RoExpress._root = _new()
		end

		-- if a portName is given, client wants a Network/Listener on a named port
		if portName and not IS_SERVER then
			local cacheKey = moduleName .. ":" .. portName
			if RoExpress._root._instances[cacheKey] then
				return RoExpress._root._instances[cacheKey]
			end

			-- find the port remote in ReplicatedStorage/RoExpressPorts
			local folder = game:GetService("ReplicatedStorage"):WaitForChild("RoExpressPorts", 10)
			assert(folder, "RoExpress: RoExpressPorts folder not found — did you call app:Listen() on the server?")
			local portRemote = folder:WaitForChild(portName, 10)
			assert(portRemote, "RoExpress: Port '" .. portName .. "' not found")

			local m = _modules[moduleName]
			assert(m, "RoExpress: '" .. moduleName .. "' is not available in this context")

			local instance
			if moduleName == "Listener" then
				-- Listener for a port: unreliable = main unreliable, reliable = port remote
				instance = m.New(UnreliableRemote, portRemote)
			elseif m.New then
				instance = m.New(portRemote)
			else
				instance = m
			end

			RoExpress._root._instances[cacheKey] = instance
			return instance
		end

		return _getInstance(RoExpress._root, moduleName)
	end,

	-- Property-style access: RoExpress.App, RoExpress.Network, etc.
	-- Returns the same cached instance as RoExpress("ModuleName").
	__index = function(_, key: string)
		local m = _modules[key]
		if not m then return nil end
		if not RoExpress._root then
			RoExpress._root = _new()
		end
		return _getInstance(RoExpress._root, key)
	end,
})
------------------------------------------------------------------------
--	Direct module references (no instantiation needed)
------------------------------------------------------------------------
RoExpress.Base64      = Base64
RoExpress.Codec       = Codec
RoExpress.Promise     = Promise
RoExpress.Bridge      = Bridge
RoExpress.TypeCoercer = TypeCoercer
RoExpress.Tamper      = Tamper
RoExpress.Harpy       = Harpy

------------------------------------------------------------------------
--	Typed accessors
--  Use these instead of RoExpress("ModuleName") when you want Luau to
--  infer the correct instance type without an explicit annotation.
--
--  Server:   local app = RoExpress.GetApp()
--  Client:   local net = RoExpress.GetNetwork()
------------------------------------------------------------------------
type _AppT = require(script.App).Type
type _NetT = require(script.Network).Type

function RoExpress.GetApp(): _AppT
	if not RoExpress._root then RoExpress._root = _new() end
	return _getInstance(RoExpress._root, "App") :: _AppT
end

function RoExpress.GetNetwork(): _NetT
	if not RoExpress._root then RoExpress._root = _new() end
	return _getInstance(RoExpress._root, "Network") :: _NetT
end

------------------------------------------------------------------------
--	TYPES
------------------------------------------------------------------------

-- Core envelope types forwarded from their source modules.
-- These always stay in sync because they reference the module directly.
export type Payload         = require(script.App).Payload
export type Request         = require(script.App).Request
export type Response        = require(script.App).Response
export type NetworkPayload  = require(script.Network).NetworkPayload
export type NetworkResponse = require(script.Network).NetworkResponse

export type BroadcastEnvelope = {
	event : string,
	data  : any,
}

-- Handler signatures forwarded from App
export type RouteHandlerCompact = require(script.App).RouteHandlerCompact
export type RouteHandlerLegacy  = require(script.App).RouteHandlerLegacy
export type RouteHandler        = require(script.App).RouteHandler
export type MiddlewareHandler   = require(script.App).MiddlewareHandler
export type BroadcastHandler    = (data: any) -> ()
export type ListenerMiddleware  = (event: string, data: any) -> ()
export type NetworkCallback     = (response: NetworkResponse) -> ()

-- Module instance types.
-- App, Network, Port use .Type (the instantiated shape from .New()).
-- Utility modules return their table directly and are typed as-is.
export type App         = require(script.App).Type
export type Network     = require(script.Network).Type
export type Port        = require(script.Port).Type
export type Broadcast   = typeof(require(script.Broadcast))
export type Listener    = typeof(require(script.Listener))
export type Base64      = typeof(require(script.Base64))
export type Router      = typeof(require(script.Router))
export type Codec       = typeof(require(script.Codec))
export type Bridge      = typeof(require(script.Bridge))
export type Tamper      = typeof(require(script.Tamper))
export type Promise     = typeof(require(script.Promise))
export type Stream      = typeof(require(script.Stream))
export type TokenBucket = typeof(require(script.TokenBucket))
export type Benchmark   = typeof(require(script.Benchmark))
export type Harpy       = typeof(require(script.Harpy))

-- Router sub-types
export type ParamType   = Router.ParamType
export type SegmentKind = Router.SegmentKind
export type MatchResult = Router.MatchResult



return RoExpress
