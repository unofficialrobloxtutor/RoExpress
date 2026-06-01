# RoExpress

A type-safe, rate-limited, Express.js-style networking framework for Roblox.

> **Author:** DeathToTheStadium
> **Version:** 2.2.0
> **License:** MIT
> **Docs:** https://roexpress.dev

---

## Overview

RoExpress replaces scattered RemoteEvents with a single disciplined pipeline. One reliable RemoteEvent handles all request/response traffic. One UnreliableRemoteEvent handles all broadcasts. Every request is automatically versioned, rate-limited, routed, and optionally compressed.

```
Typical Roblox game:
    RemoteEvent1 → handler
    RemoteEvent2 → handler
    RemoteEvent3 → handler
    ... one remote per action, no structure, no rate limiting, no security

RoExpress:
    One reliable remote   → full request/response pipeline + server push
    One unreliable remote → full broadcast pipeline
    Named ports           → isolated pipelines for separate traffic domains
    Stream remotes        → dedicated 60hz binary FPS streaming
```

---

## Module Tree

```
RoExpress
├── App            server  — routing, middleware, server push
│   ├── Router             — typed params, wildcards, globs, constraints
│   └── TokenBucket        — per-instance rate limiter
├── Network        client  — request/response, Promise API
├── Broadcast      server  — unreliable fire-and-forget
├── Listener       client  — broadcast + reliable push
├── Bridge         shared  — internal event bus
├── Tamper         server  — exploit detection
├── Codec          shared  — LZ77 buffer compression
├── Port           server  — named isolated pipelines
├── Stream         shared  — 60hz binary FPS streaming
├── TypeCoercer    shared  — type serialisation utility
├── Promise        client  — chainable async Network API
├── TokenBucket    shared  — rate limiter (used internally)
└── Base64         shared  — encode/decode utility
```

---

## Installation

### Wally (recommended)

```toml
[dependencies]
RoExpress = "unofficialrobloxtutor/roexpress@2.2.0"
```

```bash
wally install
```

```lua
local RoExpress = require(game.ReplicatedStorage.Packages.RoExpress)
```

### Creator Store

Get it from the [Roblox Creator Store](https://create.roblox.com/store/asset/94926286357335) and drop the ModuleScript into `ReplicatedStorage`.

### Manual / GitHub

Clone or download from [GitHub](https://github.com/unofficialrobloxtutor/RoExpress) and place in `ReplicatedStorage`:

```
ReplicatedStorage
└── RoExpress          ← root ModuleScript (init.luau)
    ├── App
    ├── Network
    ├── Broadcast
    ├── Listener
    ├── Router
    ├── Codec
    ├── Bridge
    ├── Tamper
    ├── Port
    ├── Stream
    ├── TypeCoercer
    ├── Promise
    ├── TokenBucket
    ├── Version
    └── Base64
```

RoExpress creates its own RemoteEvents automatically — you don't touch them.

---

## Quick Start

### Server

```lua
local RoExpress = require(game.ReplicatedStorage.Modules.Libraries.RoExpress)
local app       = RoExpress("App")
local broadcast = RoExpress("Broadcast")
local bridge    = RoExpress("Bridge")

-- middleware — runs before every request
app:Use("logger", function(Player, Payload)
    print(Player.Name, Payload.method, Payload.route)
end)

-- typed param — req.params.userId is already a Lua number
app:Get("player/:userId=number", function(Player, Payload, req, res)
    res:Send({ userId = req.params.userId })
end)

-- compressed response — best on large tables (>2kb)
app:Get("feed/all", handler, { compress = true })

-- server push — reliable, no client request needed
app:PushAll("roundEnd", { winner = "PlayerName" })

-- internal bus — fire to other server modules
bridge.Fire("playerJoined", { player = Player })
```

### Client

```lua
local RoExpress = require(game.ReplicatedStorage.Modules.Libraries.RoExpress)
local network   = RoExpress("Network")
local listener  = RoExpress("Listener")

-- GET with callback
network:Get("player/123", nil, function(res)
    if res.type == "error" then return end
    print(res.data.userId)
end)

-- GET with Promise
network:GetAsync("player/123")
    :Then(function(res) print(res.data.userId) end)
    :Catch(function(err) warn(err.message) end)

-- listen to both reliable push and unreliable broadcast
listener:On("roundEnd", function(data)
    print("Winner:", data.winner)
end)
```

---

## Context Access

| Call | Context | Returns |
|------|---------|---------|
| `RoExpress("App")` | Server only | App instance |
| `RoExpress("Network")` | Client only | Network instance |
| `RoExpress("Broadcast")` | Server only | Broadcast instance |
| `RoExpress("Listener")` | Client only | Listener instance |
| `RoExpress("Bridge")` | Both | Shared singleton event bus |
| `RoExpress("Tamper")` | Server only | Exploit detection singleton |
| `RoExpress("Stream")` | Both | 60hz binary FPS streaming singleton |
| `RoExpress("TypeCoercer")` | Both | Type serialisation utility |
| `RoExpress("Promise")` | Client only | Promise factory |
| `RoExpress("Base64")` | Both | Base64 utility |

Calling a server-only module on the client (or vice versa) throws an assertion with a clear context message.

---

## API Reference

### App (Server)

```lua
local app = RoExpress("App")
```

#### Routing

```lua
app:Get(route, handler, options?)
app:Post(route, handler, options?)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `route` | `string` | Supports typed params, wildcards, globs, inline constraints |
| `handler` | `RouteHandler` | `(Player, Payload, req, res) → ()` |
| `options.compress` | `boolean?` | Enable LZ77 compression on the response |

#### Route Syntax

| Syntax | Example | Description |
|--------|---------|-------------|
| Literal | `player/coins` | Exact match |
| Plain param | `:name` | Any segment → string |
| Typed param | `:id=number` | Coerced to declared type |
| Constrained | `:id(\d+)` | Must match Lua pattern |
| Wildcard | `*` | One segment → `req.captures[n]` |
| Glob | `**` | Zero-or-more segments → `req.captures[n]` as table |

#### Supported Param Types

`string` · `number` · `int` · `boolean` · `vector2` · `vector3` · `color3` · `cframe` · `Enum.TypeName` · `Instance`

#### req Object

| Field | Type | Description |
|-------|------|-------------|
| `req.params` | `{[string]: any}` | Named params, coerced to declared type |
| `req.captures` | `{any}` | Positional wildcard/glob captures |
| `req.query` | `{[string]: string}` | Query string params e.g. `?limit=5` |
| `req.data` | `any` | Raw payload from client |

#### res Object

| Method | Description |
|--------|-------------|
| `res:Send(data)` | Send success response. Callable once. |
| `res:Error(message)` | Send error response. Callable once. |
| `res:Status(code)` | Set status code. Chainable. |

#### Middleware

```lua
app:Use(id, fn)   -- register — return false to block (403), throw for 500
app:Unuse(id)     -- remove by id
```

#### Server Push

```lua
app:Push(player, event, data)        -- reliable push to one player
app:PushAll(event, data)             -- reliable push to all players
app:PushTo(players, event, data)     -- reliable push to a list
```

Received on the client via `listener:On(event, handler)`.

#### Named Ports

```lua
app:Listen(name, callback, settings?)  -- create an isolated pipeline
app:GetPort(name)                      -- retrieve a port by name
```

```lua
app:Listen("combat", function(port)
    port:Post("gun/fire/:damage=number", handler)
end, { Max = 30, Refill = 10 })

-- client
local combat = RoExpress("Network", "combat")
```

#### Other

```lua
app:OnParamError(fn)   -- custom typed param failure handler
app.TokenBucket        -- direct access to the rate limiter
app:Destroy()
```

---

### Network (Client)

```lua
local network = RoExpress("Network")
```

#### Callbacks

```lua
network:Get(route, data?, callback?, timeout?)
network:Post(route, data, callback?, timeout?)
```

Callbacks and timeout are optional. Omit the callback for fire-and-forget. Both return a `requestId`.

#### Promises

```lua
network:GetAsync(route, data?, timeout?)   -- returns Promise
network:PostAsync(route, data, timeout?)   -- returns Promise
```

```lua
network:GetAsync("leaderboard/top")
    :Then(function(res) return res.data.entries end)
    :Then(function(entries) UI:Load(entries) end)
    :Catch(function(err) warn(err.message) end)
    :Finally(function() UI:HideLoader() end)
```

#### NetworkResponse

| Field | Type | Description |
|-------|------|-------------|
| `res.type` | `"response" \| "error"` | Whether the request succeeded |
| `res.status` | `number` | HTTP-style status code |
| `res.data` | `any?` | Payload — decompressed automatically if compressed |
| `res.message` | `string?` | Error message (nil on success) |

#### Other

```lua
network:Cancel(requestId)   -- cancel pending request, returns boolean
network:Destroy()
```

---

### Broadcast (Server)

```lua
local broadcast = RoExpress("Broadcast")

broadcast:Emit(event, player, data)
broadcast:EmitAll(event, data)
broadcast:EmitTo(event, targets, data)
broadcast:Destroy()
```

Uses `UnreliableRemoteEvent`. Subject to per-event and per-player rate limiting. Data cap: 900 bytes.

---

### Listener (Client)

```lua
local listener = RoExpress("Listener")

listener:On(event, handler)     -- persistent subscription
listener:Once(event, handler)   -- fires once then unsubscribes
listener:Off(event)             -- remove all handlers for event
listener:Use(id, fn)            -- middleware before every handler
listener:Unuse(id)
listener:Destroy()
```

Handles both unreliable broadcast and reliable server push through one API.

---

### Bridge (Shared)

```lua
local bridge = RoExpress("Bridge")  -- same instance everywhere in this context

bridge.Bind(name, handler)          -- register handler on channel
bridge.Unbind(name, handler)        -- remove specific handler
bridge.UnbindAll(name?)             -- clear one channel or all
bridge.Fire(name, data?)            -- fire to all handlers
bridge.Has(name)                    -- returns true if channel has handlers

-- yieldable variants
bridge.Wait(name, timeout?)                           -- yields until channel fires
bridge.WaitUntil(name, predicate, timeout?)           -- yields until predicate returns true
bridge.WaitFirst(names, timeout?)                     -- yields until any channel fires
```

Bridge is purely in-process — it does not cross the client/server boundary.

---

### Tamper (Server)

```lua
local tamper = RoExpress("Tamper")

tamper.On(handler)                              -- subscribe to detection reports
tamper.AutoKick(threshold, reason?)             -- opt-in auto-kick
tamper.Strike(player, reason?, route?, evidence?) -- manual strike
tamper.GetReport(player)                        -- full player record
tamper.GetStrikes(player)                       -- strike count
tamper.ClearStrikes(player)
tamper.ClearAll()
tamper.SetThresholds(config)
```

#### Detection Reasons

| Reason | Tier | Trigger |
|--------|------|---------|
| `VERSION_SPOOF` | immediate | Client version mismatch |
| `MALFORMED_PAYLOAD` | immediate | Payload fails validation |
| `INVALID_PARAM` | immediate | Typed param coercion fails |
| `UNKNOWN_ROUTE` | immediate | Route does not exist |
| `RATE_FLOOD` | pattern | Repeated 429s in window |
| `ROUTE_SCAN` | pattern | Many distinct unknown routes |
| `PARAM_FLOOD` | pattern | Repeated param failures on same route |
| `MANUAL` | immediate | Developer called `tamper.Strike()` |

---

### Codec (Shared)

```lua
local Codec = require(script.Parent.Codec)

Codec.Compress(data)       -- any → base64 string
Codec.Decompress(str)      -- base64 string → any
Codec.IsCompressed(str)    -- → boolean
```

LZ77 sliding-window compression over Roblox's native `buffer` type. Opt-in per route via `{ compress = true }`. Decompression is automatic on the client — transparent to your callback.

Typical savings: 30–60% on JSON. Compression adds overhead — measure before enabling on small payloads (<500 bytes).

---

### Stream (Shared)

```lua
local stream = RoExpress("Stream")
```

60hz binary state streaming over raw Roblox buffers. No JSON, no Base64.

| Packet | Size | vs JSON |
|--------|------|---------|
| Player state | 21 bytes | ~90% smaller |
| Projectile | 18 bytes | ~85% smaller |
| Hit | 10 bytes | ~87% smaller |
| Weapon state | 3 bytes | ~92% smaller |

#### Server

```lua
stream.EnableLagCompensation({ windowMs = 200, tickRate = 60 })
stream.OnState(fn)           -- receive player state updates
stream.OnHit(fn)             -- receive validated hit reports
stream.OnProjectile(fn)
stream.OnWeapon(fn)
stream.Broadcast(states)     -- push all states in one buffer
stream.BroadcastTo(players, states)
stream.ConfirmHit(player, hit)
```

#### Client

```lua
stream.SendState(state)
stream.SendHit(hit)
stream.SendProjectile(proj)
stream.SendWeapon(weapon)
stream.OnWorld(fn)
stream.OnHitConfirmed(fn)
```

---

### TypeCoercer (Shared)

```lua
local tc = RoExpress("TypeCoercer")

tc.ToString(value)                          -- any supported type → wire string
tc.FromString(raw, typeName)                -- wire string → Lua value, returns (ok, value)
tc.RegisterInstanceRoot(name, root)         -- register Instance search root
```

Powers all router param coercion. Use directly when building route URLs dynamically or validating data outside routes.

---

### TokenBucket (Shared)

Accessible via `app.TokenBucket`.

| Method | Description |
|--------|-------------|
| `tb:Consume(player, cost)` | Returns false if insufficient tokens |
| `tb:HasTokens(player)` | Returns true if any tokens remain |
| `tb:HasEnoughTokens(player, cost)` | Returns true if ≥ cost tokens remain |
| `tb:Grant(player, amount)` | Add tokens up to Max |
| `tb:GrantAll(amount)` | Add to all players up to Max |
| `tb:GrantExact(player, amount)` | Add tokens ignoring Max |
| `tb:GrantAllExact(amount)` | Add to all ignoring Max |
| `tb:Reset(player)` | Refill to Max immediately |
| `tb:Destroy()` | Disconnect events, clear all buckets |

Default: `Max = 10`, `Refill = 2 tokens/second`.

---

### Base64 (Shared)

```lua
local Base64 = RoExpress("Base64")

Base64.Encode("hello")
Base64.Decode("aGVsbG8=")
Base64.EncodeTable({ x = 1 })     -- JSONEncode then base64
Base64.DecodeTable("eyJ4IjoxfQ==") -- base64 then JSONDecode
```

---

## Request Pipeline

```
Client fires request
    │
    ├─ 1. Version check         → 400 if mismatch
    ├─ 2. TokenBucket.Consume   → 429 if empty
    ├─ 3. Payload validation    → silent drop if malformed
    ├─ 4. Middleware chain      → 403 if returns false · 500 if throws
    ├─ 5. Router.Match          → 404 if no match
    ├─ 6. Typed param coercion  → OnParamError / 400 on failure
    └─ 7. handler(req, res)     → your business logic
```

### Status Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `400` | Version mismatch or invalid typed param |
| `403` | Blocked by middleware returning false |
| `404` | No route matched |
| `408` | Client-side timeout |
| `429` | Rate limited |
| `500` | Handler threw / middleware crashed |

---

## Exported Types

```lua
local RoExpress = require(path.RoExpress)

type Payload           = RoExpress.Payload
type Request           = RoExpress.Request
type Response          = RoExpress.Response
type NetworkResponse   = RoExpress.NetworkResponse
type BroadcastEnvelope = RoExpress.BroadcastEnvelope

type RouteHandler      = RoExpress.RouteHandler
type MiddlewareHandler = RoExpress.MiddlewareHandler
type BroadcastHandler  = RoExpress.BroadcastHandler
type NetworkCallback   = RoExpress.NetworkCallback

type App       = RoExpress.App
type Network   = RoExpress.Network
type Broadcast = RoExpress.Broadcast
type Listener  = RoExpress.Listener
type Router    = RoExpress.Router
type Codec     = RoExpress.Codec
type Bridge    = RoExpress.Bridge
type Tamper    = RoExpress.Tamper

type ParamType   = RoExpress.ParamType
type SegmentKind = RoExpress.SegmentKind
type MatchResult = RoExpress.MatchResult
```

---

## Limitations

- **Reliable remote data cap** — ~50kb per fire
- **Unreliable remote data cap** — ~900 bytes per fire (Broadcast)
- **Codec threshold** — LZ77 adds overhead; not worth enabling under ~500 bytes
- **Stream interpolation** — Stream provides the data, interpolation is up to you
- **Push compression** — `app:Push` and `app:PushAll` do not go through Codec

---

## Links

- **Docs:** https://roexpress.dev
- **Discord:** https://discord.gg/TszEHgEyV5
- **DevForum:** https://devforum.roblox.com/t/roexpress/4646082
- **Wally:** https://wally.run/package/unofficialrobloxtutor/roexpress
- **Creator Store:** https://create.roblox.com/store/asset/94926286357335

---

## License

MIT — free to use, modify, and distribute.
