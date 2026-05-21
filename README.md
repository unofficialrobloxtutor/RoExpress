# RoExpress

A type-safe, rate-limited, Express.js-style RPC networking framework for Roblox.

> **Author:** DeathToTheStadium  
> **Version:** 1.6  
> **License:** MIT

---

## Overview

RoExpress replaces the scattered RemoteEvent approach most Roblox games use with a single structured pipeline. One reliable remote handles all request/response traffic. One unreliable remote handles all broadcast traffic. Every request is rate limited, versioned, and routed automatically.

```
Typical Roblox game:
    RemoteEvent1 → handler
    RemoteEvent2 → handler
    RemoteEvent3 → handler
    ... one remote per action, no structure, no rate limiting

RoExpress:
    One reliable remote   → full request/response pipeline
    One unreliable remote → full broadcast pipeline
```

---

## Module Tree

```
RoExpress
    ├── App          (server — request/response routing)
    │     └── TokenBucket  (rate limiter)
    ├── Network      (client — request/response)
    ├── Broadcast    (server — unreliable fire and forget)
    ├── Listener     (client — unreliable fire and forget)
    └── Base64       (shared — encode/decode utility)
```

---

## Installation

1. Place the `RoExpress` ModuleScript inside `game.ReplicatedStorage.Modules.Libraries`
2. Ensure the following children exist inside `RoExpress`:
   - `App` (ModuleScript)
   - `Network` (ModuleScript)
   - `Broadcast` (ModuleScript)
   - `Listener` (ModuleScript)
   - `Base64` (ModuleScript)
   - `TokenBucket` (ModuleScript)

RoExpress automatically creates its own `RemoteEvent` and `UnreliableRemoteEvent` on the server and waits for them on the client. You do not need to create any remotes manually.

---

## Quick Start

**Server (Script in ServerScriptService):**
```lua
local RoExpress = require(game.ReplicatedStorage.Modules.Libraries.RoExpress)
local app = RoExpress("App")

-- global middleware
app:Use("logger", function(Player, Payload)
    print(string.format("[%s] %s %s", Player.Name, Payload.method, Payload.route))
end)

-- GET route
app:Get("player/:userId", function(Player, Payload, req, res)
    res:Send({ userId = req.params.userId })
end)

-- POST route
app:Post("player/save", function(Player, Payload, req, res)
    if not req.data then
        res:Status(400):Error("Missing data")
        return
    end
    res:Send({ success = true })
end)
```

**Client (LocalScript in StarterPlayerScripts):**
```lua
local RoExpress = require(game.ReplicatedStorage.Modules.Libraries.RoExpress)
local network = RoExpress("Network")

-- GET request
network:Get("player/123", nil, function(res)
    if res.type == "error" then
        warn(res.status, res.message)
        return
    end
    print(res.data.userId)
end)

-- POST request
network:Post("player/save", { coins = 500 }, function(res)
    print(res.data.success)
end)
```

---

## API Reference

### RoExpress (Root)

```lua
local RoExpress = require(path.RoExpress)
```

The root module is callable. Calling it with a module name returns a singleton instance of that module for the current context.

| Call | Context | Returns |
|------|---------|---------|
| `RoExpress("App")` | Server only | App instance |
| `RoExpress("Network")` | Client only | Network instance |
| `RoExpress("Broadcast")` | Server only | Broadcast instance |
| `RoExpress("Listener")` | Client only | Listener instance |
| `RoExpress("Base64")` | Shared | Base64 utility |

Calling a server-only module on the client (or vice versa) will throw an assertion error with a clear context message.

---

### App (Server)

Handles incoming client requests, runs middleware, and routes to registered handlers.

#### `app:Use(id, fn)`
Register global middleware. Runs on every request before routing.

```lua
app:Use("logger", function(Player: Player, Payload: RoExpress.Payload)
    print(Player.Name, Payload.route)
end)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `string` | Unique identifier for this middleware |
| `fn` | `function` | Handler receiving `Player` and `Payload` |

#### `app:Unuse(id)`
Remove a registered middleware by id.

```lua
app:Unuse("logger")
```

#### `app:Get(route, handler)`
Register a GET route handler.

```lua
app:Get("player/:userId/coins", function(Player, Payload, req, res)
    res:Send({ coins = 100 })
end)
```

#### `app:Post(route, handler)`
Register a POST route handler. Response is automatically base64 encoded.

```lua
app:Post("player/save", function(Player, Payload, req, res)
    res:Send({ success = true })
end)
```

#### Route Handler Signature
```lua
function(Player: Player, Payload: RoExpress.Payload, req: RoExpress.Request, res: RoExpress.Response)
```

#### `req` Object

| Field | Type | Description |
|-------|------|-------------|
| `req.params` | `{ [string]: string }` | Route parameters e.g. `:userId` |
| `req.query` | `{ [string]: string }` | Query string params e.g. `?limit=5` |
| `req.data` | `any` | Raw payload data sent by the client |

#### `res` Object

| Method | Description |
|--------|-------------|
| `res:Send(data)` | Send a success response back to the client |
| `res:Error(message)` | Send an error response back to the client |
| `res:Status(code)` | Set the status code (chainable) |

```lua
res:Send({ coins = 100 })
res:Status(404):Error("Not found")
res:Status(200):Send({ ok = true })
```

`res:Send()` and `res:Error()` can only be called once per request. Subsequent calls will warn and no-op.

#### Route Params & Query Strings

```lua
-- route params
app:Get("player/:userId/item/:itemId", function(Player, Payload, req, res)
    print(req.params.userId)  -- "123"
    print(req.params.itemId)  -- "sword"
end)

-- query strings
app:Get("leaderboard", function(Player, Payload, req, res)
    local limit = tonumber(req.query.limit) or 10
end)
-- client fires: network:Get("leaderboard?limit=5", ...)
```

#### `app:Destroy()`
Disconnects the remote connection, clears all routes and middleware, and destroys the TokenBucket.

#### `app.TokenBucket`
Direct reference to the TokenBucket utility. Use after round events to reward players.

```lua
app.TokenBucket.GrantAll(5)
app.TokenBucket.GrantExact(winnerPlayer, 10)
app.TokenBucket.Reset(player)
```

---

### Network (Client)

Fires requests to the server and resolves responses via callbacks.

#### `network:Get(route, data, callback, timeout?)`

```lua
network:Get("player/123", nil, function(res)
    if res.type == "error" then return end
    print(res.data)
end)

-- with custom timeout (seconds)
network:Get("ping", nil, function(res)
    print(res.data.message)
end, 5)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `route` | `string` | Route path, supports params and query strings |
| `data` | `any?` | Optional data to send |
| `callback` | `function` | Called with `NetworkResponse` when server responds |
| `timeout` | `number?` | Seconds before 408 fires (default: 10) |

#### `network:Post(route, data, callback, timeout?)`

Same as `Get` but sends heavier payloads. Response is automatically base64 decoded before your callback receives it.

#### `NetworkResponse` Object

| Field | Type | Description |
|-------|------|-------------|
| `res.type` | `"response" \| "error"` | Whether the request succeeded |
| `res.status` | `number` | HTTP-style status code |
| `res.data` | `any?` | Response data (nil on error) |
| `res.message` | `string?` | Error message (nil on success) |

#### Status Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `400` | Bad request (missing or invalid data) |
| `404` | No handler registered for this route |
| `408` | Request timed out |
| `429` | Rate limited |
| `500` | Internal server error |

#### `network:Cancel(requestId)`
Cancel a pending request by id. Returns `true` if found and cancelled.

#### `network:Destroy()`
Disconnects the remote connection and clears all pending requests.

---

### Broadcast (Server)

Fires unreliable fire-and-forget events to clients. Subject to both per-event and per-player rate limiting.

#### `broadcast:Emit(event, player, data)`
Fire to a single player.

```lua
broadcast:Emit("health", player, { hp = 75 })
```

#### `broadcast:EmitAll(event, data)`
Fire to all connected players. Players whose token bucket is empty are skipped individually.

```lua
broadcast:EmitAll("roundStart", { timeLimit = 60 })
```

#### `broadcast:EmitTo(event, targets, data)`
Fire to a specific list of players.

```lua
broadcast:EmitTo("zoneUpdate", { player1, player2 }, { zoneId = 3 })
```

#### Rate Limiting
- **Per event** — each event name has its own token bucket (`EVENT_MAX = 20`, `EVENT_REFILL = 10/s`)
- **Per player** — uses the shared TokenBucket, skips players whose bucket is empty
- **Data cap** — warns if payload exceeds 900 bytes (Roblox unreliable remote limit)
- **Event bucket TTL** — idle event buckets are cleared after 30 seconds
- **Max unique events** — capped at 64 event names to prevent memory abuse

#### `broadcast:Destroy()`
Cancels the cleanup thread and clears all event buckets.

---

### Listener (Client)

Subscribes to unreliable broadcast events fired by the server.

#### `listener:On(event, handler)`
Persistent subscription. Fires every time the event is received.

```lua
listener:On("health", function(data)
    print("hp:", data.hp)
end)
```

#### `listener:Once(event, handler)`
Fires once then automatically unsubscribes. Safe against race conditions — unsubscribes before the handler is called.

```lua
listener:Once("roundStart", function(data)
    print("round started:", data.timeLimit)
end)
```

#### `listener:Off(event)`
Manually unsubscribe both `On` and `Once` handlers for an event.

```lua
listener:Off("health")
```

#### `listener:Use(id, fn)`
Register middleware that runs before every handler.

```lua
listener:Use("logger", function(event, data)
    print("broadcast received:", event)
end)
```

#### `listener:Unuse(id)`
Remove middleware by id.

#### `listener:Destroy()`
Disconnects the remote connection and clears all handlers and middleware.

---

### Base64

Lightweight encoder/decoder. Used internally by RoExpress for POST responses. Available directly if needed.

```lua
local Base64 = RoExpress("Base64")

Base64.Encode("hello")           -- base64 string
Base64.Decode("aGVsbG8=")        -- "hello"
Base64.EncodeTable({ x = 1 })    -- JSONEncode then base64
Base64.DecodeTable("eyJ4IjoxfQ==") -- base64 then JSONDecode
```

---

### TokenBucket

Rate limiter used internally by App and Broadcast. Accessible via `app.TokenBucket`.

| Method | Description |
|--------|-------------|
| `TokenBucket.Consume(Player, Cost)` | Consume tokens. Returns false if insufficient. |
| `TokenBucket.HasTokens(Player)` | Returns true if player has any tokens |
| `TokenBucket.HasEnoughTokens(Player, Cost)` | Returns true if player has at least Cost tokens |
| `TokenBucket.Grant(Player, Amount)` | Add tokens up to Max |
| `TokenBucket.GrantAll(Amount)` | Add tokens to all players up to Max |
| `TokenBucket.GrantExact(Player, Amount)` | Add tokens ignoring Max |
| `TokenBucket.GrantAllExact(Amount)` | Add tokens to all players ignoring Max |
| `TokenBucket.Reset(Player)` | Refill player to Max immediately |
| `TokenBucket.Destroy()` | Disconnect events and clear all buckets |

Default settings: `Max = 10`, `Refill = 2 tokens/second`.

---

## Exported Types

All types are exported from the root module for autocomplete support.

```lua
local RoExpress = require(path.RoExpress)

-- envelope types
type Payload          = RoExpress.Payload
type Request          = RoExpress.Request
type Response         = RoExpress.Response
type NetworkResponse  = RoExpress.NetworkResponse
type BroadcastEnvelope = RoExpress.BroadcastEnvelope

-- handler signatures
type RouteHandler      = RoExpress.RouteHandler
type MiddlewareHandler = RoExpress.MiddlewareHandler
type BroadcastHandler  = RoExpress.BroadcastHandler
type ListenerMiddleware = RoExpress.ListenerMiddleware
type NetworkCallback   = RoExpress.NetworkCallback

-- module instance types
type App       = RoExpress.App
type Network   = RoExpress.Network
type Broadcast = RoExpress.Broadcast
type Listener  = RoExpress.Listener
type Base64    = RoExpress.Base64
```

---

## Request Pipeline

Every incoming request flows through this pipeline in order:

```
Client fires request
    │
    ├─ 1. Version check        → 400 if mismatch
    ├─ 2. TokenBucket.Consume  → 429 if empty
    ├─ 3. _validatePayload     → silent drop if malformed
    ├─ 4. Middleware chain      → logger, auth, etc
    ├─ 5. Route matching        → 404 if no match
    └─ 6. handler(req, res)     → business logic
```

Broadcast pipeline:

```
broadcast:Emit / EmitAll / EmitTo
    │
    ├─ 1. Data size check      → warn and drop if > 900 bytes
    ├─ 2. EventBucket.Consume  → drop if event rate limited
    ├─ 3. Per-player check     → skip individual players if rate limited
    └─ 4. FireClient
```

---

## GET vs POST

| | GET | POST |
|--|-----|------|
| Purpose | Fetch data | Send and persist data |
| Request data | Optional | Required |
| Response encoding | Plain table | Base64 encoded (auto decoded on client) |
| Use for | Leaderboards, player stats, lookups | Saves, purchases, mutations |

---

## Versioning

All payloads carry a `version` field matching `ROEXPRESS_VERSION`. If a client fires a request with a mismatched version the server rejects it with a `400` error. Update `ROEXPRESS_VERSION` in both `App` and `Network` together when making breaking changes.

---

## Limitations

- **Data cap** — reliable remote ~50kb per fire, unreliable remote ~900 bytes per fire
- **Player scale** — TokenBucket scales linearly with player count, suitable for standard Roblox servers (20-50 players)
- **Binary data** — all payloads are JSON encoded, raw binary is not supported
- **High frequency** — not optimized for 60fps position sync; use raw `UnreliableRemoteEvent` for that

---

## License

MIT — free to use, modify, and distribute.
