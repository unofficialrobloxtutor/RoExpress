------------------------------------------------------------------------
--  <> Title:       RoExpress.Types
--  <> Version:     1.0
--  <> Date:        15/06/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Explicit public-facing types for every RoExpress
--                  module. No private fields, no __index leakage.
--
--  USAGE
--  ---------------------------------------------------------------
--  Types are re-exported from the root module so you can annotate
--  variables directly after requiring RoExpress:
--
--    local RoExpress = require(game.ReplicatedStorage.RoExpress)
--    local app: RoExpress.App = RoExpress.GetApp()
--
--  Or require this module directly for sub-module annotation:
--
--    local T = require(game.ReplicatedStorage.RoExpress.Types)
--    type Handler = (data: any) -> ()
------------------------------------------------------------------------

-- ── Primitives ─────────────────────────────────────────────────────────

export type Method = "GET" | "POST" | "PUT" | "DELETE"

export type RouteOptions = {
	compress : boolean?,
	algo     : ("lz77" | "lzh")?,
}

-- ── App / Port ─────────────────────────────────────────────────────────

export type Payload = {
	version   : string,
	type      : "request" | "response" | "error",
	method    : Method,
	requestId : string,
	route     : string,
	data      : any,
}

export type Request = {
	params   : { [string]: any },
	captures : { any },
	query    : { [string]: string },
	data     : any,
	player   : Player?,
	raw      : Payload?,
}

export type Response = {
	Send     : (self: Response, data: any?) -> (),
	Error    : (self: Response, message: string) -> (),
	Status   : (self: Response, code: number) -> Response,
	Redirect : (self: Response, path: string) -> (),
}

export type RouteHandlerCompact = (req: Request, res: Response) -> ()
export type RouteHandlerLegacy  = (Player: Player, Payload: Payload, req: Request, res: Response) -> ()
export type RouteHandler        = RouteHandlerCompact | RouteHandlerLegacy
export type MiddlewareHandler   = (Player: Player, Payload: Payload) -> boolean?

export type ParamErrorHandler = (Player: Player, Payload: Payload, paramName: string, expectedType: string) -> ()

export type Port = {
	Get          : (self: Port, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Post         : (self: Port, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Put          : (self: Port, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Delete       : (self: Port, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Use          : (self: Port, id: string, fn: MiddlewareHandler) -> (),
	Unuse        : (self: Port, id: string) -> (),
	Push         : (self: Port, player: Player, event: string, data: any) -> (),
	PushAll      : (self: Port, event: string, data: any) -> (),
	PushTo       : (self: Port, players: { Player }, event: string, data: any) -> (),
	OnParamError : (self: Port, fn: ParamErrorHandler) -> (),
	Destroy      : (self: Port) -> (),
}

export type App = {
	Get          : (self: App, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Post         : (self: App, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Put          : (self: App, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Delete       : (self: App, route: string, handler: (req: Request, res: Response) -> (), options: RouteOptions?) -> (),
	Use          : (self: App, id: string, fn: MiddlewareHandler) -> (),
	Unuse        : (self: App, id: string) -> (),
	Push         : (self: App, player: Player, event: string, data: any) -> (),
	PushAll      : (self: App, event: string, data: any) -> (),
	PushTo       : (self: App, players: { Player }, event: string, data: any) -> (),
	Listen       : (self: App, name: string, callback: (port: Port) -> (), settings: { Max: number?, Refill: number? }?) -> Port,
	GetPort      : (self: App, name: string) -> Port?,
	OnParamError : (self: App, fn: ParamErrorHandler) -> (),
	Destroy      : (self: App) -> (),
}

-- ── Network ────────────────────────────────────────────────────────────

export type NetworkPayload = {
	version   : string,
	type      : "request",
	method    : Method,
	requestId : string,
	route     : string,
	data      : any,
}

export type NetworkResponse = {
	version    : string,
	type       : "response" | "error",
	method     : Method,
	requestId  : string,
	status     : number,
	data       : any?,
	message    : string?,
	compressed : boolean?,
}

export type NetworkCallback = (response: NetworkResponse) -> ()

export type Network = {
	Configure   : (self: Network, config: { maxRetries: number?, backoff: number? }) -> (),
	Get         : (self: Network, route: string, data: any?, callback: NetworkCallback?, timeout: number?, retries: number?) -> string,
	Post        : (self: Network, route: string, data: any,  callback: NetworkCallback?, timeout: number?, retries: number?) -> string,
	Put         : (self: Network, route: string, data: any,  callback: NetworkCallback?, timeout: number?, retries: number?) -> string,
	Delete      : (self: Network, route: string, data: any?, callback: NetworkCallback?, timeout: number?, retries: number?) -> string,
	GetAsync    : (self: Network, route: string, data: any?, timeout: number?, retries: number?) -> (string, Promise),
	PostAsync   : (self: Network, route: string, data: any,  timeout: number?, retries: number?) -> (string, Promise),
	PutAsync    : (self: Network, route: string, data: any,  timeout: number?, retries: number?) -> (string, Promise),
	DeleteAsync : (self: Network, route: string, data: any?, timeout: number?, retries: number?) -> (string, Promise),
	Cancel      : (self: Network, id: string) -> boolean,
	Destroy     : (self: Network) -> (),
}

-- ── Promise ────────────────────────────────────────────────────────────

export type PromiseState = "pending" | "resolved" | "rejected"

export type Promise = {
	Then    : (self: Promise, fn: (value: any) -> any) -> Promise,
	Catch   : (self: Promise, fn: (err: any)   -> any) -> Promise,
	Finally : (self: Promise, fn: () -> ())            -> Promise,
	Cancel  : (self: Promise) -> (),
}

-- ── Broadcast ──────────────────────────────────────────────────────────

export type Broadcast = {
	Emit    : (self: Broadcast, event: string, player: Player,      data: any) -> (),
	EmitAll : (self: Broadcast, event: string,                      data: any) -> (),
	EmitTo  : (self: Broadcast, event: string, targets: { Player }, data: any) -> (),
	Destroy : (self: Broadcast) -> (),
}

-- ── Listener ───────────────────────────────────────────────────────────

export type Listener = {
	On      : (self: Listener, event: string, handler: (data: any) -> ()) -> (),
	Once    : (self: Listener, event: string, handler: (data: any) -> ()) -> (),
	Off     : (self: Listener, event: string) -> (),
	Use     : (self: Listener, id: string, fn: (event: string, data: any) -> ()) -> (),
	Unuse   : (self: Listener, id: string) -> (),
	Destroy : (self: Listener) -> (),
}

-- ── Bridge ─────────────────────────────────────────────────────────────

export type BridgeConnection = { Disconnect: (self: BridgeConnection) -> () }

export type Bridge = {
	On        : (name: string, handler: (data: any) -> ()) -> BridgeConnection,
	Once      : (name: string, handler: (data: any) -> ()) -> BridgeConnection,
	Emit      : (name: string, data: any?) -> (),
	Has       : (name: string) -> boolean,
	Clear     : (name: string?) -> (),
	Wait      : (name: string, timeout: number?) -> any?,
	WaitUntil : (name: string, predicate: (data: any) -> boolean, timeout: number?) -> any?,
	WaitFirst : (names: { string }, timeout: number?) -> (string?, any?),
	Destroy   : () -> (),
}

-- ── Hook ───────────────────────────────────────────────────────────────

-- Hook itself is callable: Hook(event, handler)
--                          Hook(event, priority, handler)
--                          Hook(event, { priority, id }, handler)
-- These static methods are accessed as Hook.Once, Hook.Off, etc.

export type HookPriority = number | "first" | "high" | "normal" | "low" | "last"

export type HookOptions = {
	priority : HookPriority?,
	id       : string?,
}

export type Hook = {
	Once  : (event: string, priorityOrHandler: HookPriority | ((...any) -> ()), handler: ((...any) -> ())?) -> (),
	Off   : (event: string, id: string) -> (),
	Clear : (event: string) -> (),
	Fire  : (event: string, ...any) -> (),
	Has   : (event: string) -> boolean,
}

-- ── TokenBucket ────────────────────────────────────────────────────────

export type TokenBucketSettings = {
	Max    : number,
	Refill : number,
}

export type TokenBucket = {
	Consume        : (self: TokenBucket, player: Player, cost: number) -> boolean,
	HasTokens      : (self: TokenBucket, player: Player) -> boolean,
	HasEnoughTokens: (self: TokenBucket, player: Player, cost: number) -> boolean,
	Grant          : (self: TokenBucket, player: Player, amount: number) -> (),
	GrantAll       : (self: TokenBucket, amount: number) -> (),
	GrantExact     : (self: TokenBucket, player: Player, amount: number) -> (),
	GrantAllExact  : (self: TokenBucket, amount: number) -> (),
	Reset          : (self: TokenBucket, player: Player) -> (),
	Destroy        : (self: TokenBucket) -> (),
}

-- ── Tamper ─────────────────────────────────────────────────────────────

export type TamperSeverity = "immediate" | "pattern"

export type TamperReason =
	"VERSION_SPOOF"     |
	"MALFORMED_PAYLOAD" |
	"INVALID_PARAM"     |
	"UNKNOWN_ROUTE"     |
	"RATE_FLOOD"        |
	"ROUTE_SCAN"        |
	"PARAM_FLOOD"       |
	"MANUAL"

export type TamperReport = {
	player    : Player,
	reason    : TamperReason,
	severity  : TamperSeverity,
	route     : string?,
	evidence  : any?,
	strikes   : number,
	firstSeen : number,
	lastSeen  : number,
}

export type TamperRecord = {
	strikes   : number,
	firstSeen : number,
	lastSeen  : number,
}

export type Tamper = {
	On        : (handler: (report: TamperReport) -> ()) -> (),
	AutoKick  : (threshold: number, reason: string?) -> (),
	Strike    : (player: Player, reason: string?, route: string?, evidence: any?) -> (),
	GetReport : (player: Player) -> TamperRecord?,
}

-- ── RTTP ───────────────────────────────────────────────────────────────

export type RTTPConfig = {
	base    : string?,
	headers : { [string]: string }?,
	retries : number?,
}

export type RTTPResponse = {
	ok      : boolean,
	status  : number,
	data    : any,
	headers : { [string]: string },
	raw     : string,
}

export type RTTPCallback = (res: RTTPResponse) -> ()

export type RTTPInstance = {
	SetBase      : (self: RTTPInstance, url: string) -> (),
	SetHeader    : (self: RTTPInstance, key: string, value: string) -> (),
	RemoveHeader : (self: RTTPInstance, key: string) -> (),
	SetRetries   : (self: RTTPInstance, n: number) -> (),
	Get          : (self: RTTPInstance, path: string, callback: RTTPCallback?) -> (),
	Post         : (self: RTTPInstance, path: string, body: any?, callback: RTTPCallback?) -> (),
	Put          : (self: RTTPInstance, path: string, body: any?, callback: RTTPCallback?) -> (),
	Delete       : (self: RTTPInstance, path: string, callback: RTTPCallback?) -> (),
	GetAsync     : (self: RTTPInstance, path: string) -> Promise,
	PostAsync    : (self: RTTPInstance, path: string, body: any?) -> Promise,
	PutAsync     : (self: RTTPInstance, path: string, body: any?) -> Promise,
	DeleteAsync  : (self: RTTPInstance, path: string) -> Promise,
}

-- RTTP is a factory — call RTTP.New(config?) to get an RTTPInstance
export type RTTP = {
	New : (config: RTTPConfig?) -> RTTPInstance,
}

-- ── Cross ──────────────────────────────────────────────────────────────

export type MsgContext = {
	serverId : string,
	time     : number,
}

export type ServerEntry = {
	id      : string,
	place   : number,
	players : number,
	meta    : { [string]: any },
	ts      : number,
}

export type CrossMemory = {
	Set    : (key: string, value: any, expiry: number?) -> (),
	Get    : (key: string) -> any,
	Remove : (key: string) -> (),
	Update : (key: string, transform: (current: any) -> any, expiry: number?) -> (),
}

export type Cross = {
	ServerId         : () -> string,
	Publish          : (topic: string, data: any) -> (),
	Subscribe        : (topic: string, handler: (data: any, ctx: MsgContext) -> ()) -> (),
	Once             : (topic: string, handler: (data: any, ctx: MsgContext) -> ()) -> (),
	Unsubscribe      : (topic: string) -> (),
	RegisterServer   : (meta: { [string]: any }?) -> (),
	GetServers       : () -> { ServerEntry },
	UnregisterServer : () -> (),
	Memory           : CrossMemory,
}

-- ── Maid ───────────────────────────────────────────────────────────────

export type Maid = {
	Add     : <T>(self: Maid, item: T) -> T,
	Remove  : (self: Maid, item: any) -> (),
	Clear   : (self: Maid) -> (),
	Destroy : (self: Maid) -> (),
}

-- ── Debounce ───────────────────────────────────────────────────────────

export type Debounce = {
	fn  : <T...>(fn: (T...) -> (), cooldown: number) -> (T...) -> boolean,
	key : <K, T...>(fn: (key: K, T...) -> (), cooldown: number) -> (key: K, T...) -> boolean,
}

-- ── BroadcastEnvelope (internal wire format) ───────────────────────────

export type BroadcastEnvelope = {
	event : string,
	data  : any,
}

-- ── RoExpress callable interface ───────────────────────────────────────
-- Typing for the RoExpress("ModuleName") and RoExpress("ModuleName", portName)
-- call syntax. The overload order matters — Luau picks the first match.

export type RoExpressCall =
	-- Constructed instances
	((name: "App")         -> App)         &
	((name: "Network")     -> Network)     &
	((name: "Broadcast")   -> Broadcast)   &
	((name: "Listener")    -> Listener)    &
	((name: "Benchmark")   -> any)         &
	((name: "Maid")        -> Maid)        &
	-- Named-port variants (client)
	((name: "Network",  portName: string)  -> Network)  &
	((name: "Listener", portName: string)  -> Listener) &
	-- Singleton / factory module references
	((name: "Base64")      -> any)         &
	((name: "Bridge")      -> Bridge)      &
	((name: "Codec")       -> any)         &
	((name: "Cross")       -> Cross)       &
	((name: "Hook")        -> Hook)        &
	((name: "Promise")     -> Promise)     &
	((name: "RTTP")        -> RTTP)        &
	((name: "Router")      -> any)         &
	((name: "Stream")      -> any)         &
	((name: "Tamper")      -> Tamper)      &
	((name: "TypeCoercer") -> any)         &
	((name: "Debounce")    -> Debounce)

return {}
