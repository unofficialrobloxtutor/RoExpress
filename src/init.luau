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

-- All sub-modules required as locals so they can be referenced in type
-- positions below — the Luau LSP does not support require() in type expressions.
local Base64       = require(script.Base64)
local Router       = require(script.Router)
local Codec        = require(script.Codec)
local Bridge       = require(script.Bridge)
local Tamper       = require(script.Tamper)
local TypeCoercer  = require(script.TypeCoercer)
local Promise      = require(script.Promise)
local Harpy        = require(script.Harpy)
local App          = require(script.App)
local Network      = require(script.Network)
local Port         = require(script.Port)
local Broadcast    = require(script.Broadcast)
local Listener     = require(script.Listener)
local Stream       = require(script.Stream)
local Benchmark    = require(script.Benchmark)
local TokenBucket  = require(script.TokenBucket)

local _modules = if IS_SERVER
	then {
		App         = App,
		Broadcast   = Broadcast,
		Base64      = Base64,
		Bridge      = Bridge,
		Tamper      = Tamper,
		Stream      = Stream,
		TypeCoercer = TypeCoercer,
		Version     = _Version,
	}
	else {
		Network     = Network,
		Listener    = Listener,
		Benchmark   = Benchmark,
		Base64      = Base64,
		Bridge      = Bridge,
		Stream      = Stream,
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
export type Type = {
	_instances: { [string]: any },
}

type ServerModuleName = "App" | "Broadcast" | "Base64" | "Bridge" | "Tamper" | "Stream" | "TypeCoercer" | "Version"
type ClientModuleName = "Network" | "Listener" | "Benchmark" | "Base64" | "Bridge" | "Stream" | "TypeCoercer" | "Promise" | "Version"
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
	-- Benchmark takes a Network instance (not a remote) — wire after Network is resolved.
	local instance
	if moduleName == "Listener" then
		local unreliable, reliable = _getRemoteForModule(moduleName)
		instance = m.New(unreliable, reliable)
	elseif moduleName == "Benchmark" then
		local network = _getInstance(self, "Network")
		instance = m.New(network)
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
	local self = (setmetatable({}, RoExpress) :: any) :: Type
	self._instances = {}
	return self
end

-- Module-level root instance — avoids storing it on the RoExpress table,
-- which would otherwise force Luau to widen all property accesses to 'any'
-- via the __index metamethod.
local _root: Type

local function _getRoot(): Type
	if not _root then
		_root = _new()
	end
	return _root
end

setmetatable(RoExpress, {
	__call = function(_, moduleName: ModuleName, portName: string?)
		-- if a portName is given, client wants a Network/Listener on a named port
		if portName and not IS_SERVER then
			local root = _getRoot()
			local cacheKey = moduleName .. ":" .. portName
			if root._instances[cacheKey] then
				return root._instances[cacheKey]
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

			root._instances[cacheKey] = instance
			return instance
		end

		return _getInstance(_getRoot(), moduleName)
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
RoExpress.Router      = Router

------------------------------------------------------------------------
--	Typed accessors
--  Use these instead of RoExpress("ModuleName") when you want Luau to
--  infer the correct instance type without an explicit annotation.
--
--  Server:   local app = RoExpress.GetApp()
--  Client:   local net = RoExpress.GetNetwork()
------------------------------------------------------------------------
type _AppT = App.Type
type _NetT = Network.Type

function RoExpress.GetApp(): _AppT
	return _getInstance(_getRoot(), "App") :: _AppT
end

function RoExpress.GetNetwork(): _NetT
	return _getInstance(_getRoot(), "Network") :: _NetT
end

------------------------------------------------------------------------
--	TYPES
------------------------------------------------------------------------

-- Core envelope types forwarded from their source modules via pre-required
-- locals — the LSP does not support require() inside type expressions.
export type Payload         = App.Payload
export type Request         = App.Request
export type Response        = App.Response
export type NetworkPayload  = Network.NetworkPayload
export type NetworkResponse = Network.NetworkResponse

export type BroadcastEnvelope = {
	event : string,
	data  : any,
}

-- Handler signatures forwarded from App
export type RouteHandlerCompact = App.RouteHandlerCompact
export type RouteHandlerLegacy  = App.RouteHandlerLegacy
export type RouteHandler        = App.RouteHandler
export type MiddlewareHandler   = App.MiddlewareHandler
export type BroadcastHandler    = (data: any) -> ()
export type ListenerMiddleware  = (event: string, data: any) -> ()
export type NetworkCallback     = (response: NetworkResponse) -> ()

-- Module instance types.
-- App, Network, Port use .Type (the instantiated shape from .New()).
-- Utility modules are typed as their module table via typeof().
export type App         = App.Type
export type Network     = Network.Type
export type Port        = Port.Type
export type Broadcast   = typeof(Broadcast)
export type Listener    = typeof(Listener)
export type Base64      = typeof(Base64)
export type Router      = typeof(Router)
export type Codec       = typeof(Codec)
export type Bridge      = typeof(Bridge)
export type Tamper      = typeof(Tamper)
export type Promise     = typeof(Promise)
export type Stream      = typeof(Stream)
export type TokenBucket = typeof(TokenBucket)
export type Benchmark   = typeof(Benchmark)
export type Harpy       = typeof(Harpy)

-- Router sub-types
export type ParamType      = Router.ParamType
export type SegmentKind    = Router.SegmentKind
export type MatchResult    = Router.MatchResult
export type RouteBuilder<T> = Router.RouteBuilder<T>



return RoExpress
