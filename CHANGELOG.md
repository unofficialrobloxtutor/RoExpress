# RoExpress Changelog

All notable changes to RoExpress are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.2.3] — 2026-06-07

### Fixed
- `wally.toml` — added missing `include` field (`wally.toml`, `init.luau`, `src/**`); source files were not being packaged on publish (fixes #6)
- v2.2.1 and v2.2.2 were failed attempts at the same fix

---

## [2.2.0] — 2026-05-30

### Added
- **TypeCoercer module** — shared type serialisation singleton available in both contexts
- `TypeCoercer.ToString(value)` — converts any supported Luau type to wire string
- `TypeCoercer.FromString(raw, typeName)` — manual coercion outside the router
- `TypeCoercer.RegisterInstanceRoot(name, root)` — register Instance search roots
- **Promise module** — lightweight chainable async API for Network
- `network:GetAsync(route, data?, timeout?)` — returns a chainable Promise
- `network:PostAsync(route, data, timeout?)` — returns a chainable Promise
- `promise:Then(fn)`, `promise:Catch(fn)`, `promise:Finally(fn)`, `promise:Cancel()`
- **Version module** — single writer of `shared.ROEXPRESS_VERSION`
- Auto silent version check on server start (pings roexpress.dev then GitHub fallback)
- `Version.Check()` — manual version check with formatted output and return value
- **New Router param types** via TypeCoercer delegation:
  - `int` — whole numbers only, rejects decimals
  - `Enum.TypeName` — e.g. `:state=Enum.HumanoidStateType`
  - `Instance` — e.g. `:target=Instance` (searches registered roots)
  - `cframe` — now supports full quaternion format `x,y,z,qX,qY,qZ,qW`
- Router type assertion now accepts `Enum.*` and `Instance` type names
- `network:Get` and `network:Post` now return `requestId` for cancellation
- Network callbacks are now optional — omit for fire-and-forget

### Changed
- Router delegates all coercion to TypeCoercer — single source of truth
- `shared.ROEXPRESS_VERSION` is now written exclusively by `Version.luau`
- init.luau requires Version.luau first to guarantee version is set before any module reads it

### Fixed
- Router `_match` function signature — removed invalid multi-return `?` annotation
- Orphaned `local module = {}` removed from Router.luau

---

## [2.1.0] — 2026-05-30

### Added
- **Stream module** — 60hz binary FPS streaming over raw Roblox buffers
  - Player state: 21 bytes (vs ~200 bytes JSON — 90% smaller)
  - Hit packets: 10 bytes with u16 timestamp for lag compensation
  - Projectile: 18 bytes with packed i16 XY velocity
  - Weapon state: 3 bytes
  - World broadcast batches all states into one buffer — one remote call total
  - `stream.EnableLagCompensation(settings)` — opt-in ring buffer + hit validation
  - `stream.BroadcastTo(players, states)` — zone-based streaming
  - Two dedicated remotes: `StreamState` (unreliable) + `StreamEvent` (reliable)
- **Port module** — named isolated request pipelines via `app:Listen()`
  - Each port owns its own RemoteEvent, Router, and TokenBucket
  - Global App middleware inherited automatically
  - Port-local middleware via `port:Use()`
  - Configurable TokenBucket settings per port
  - `app:GetPort(name)` — retrieve a port outside its callback
  - Client connects via `RoExpress("Network", "portName")`
- Network callbacks now optional — fire-and-forget without a callback

### Changed
- `app:Destroy()` now also destroys all registered ports

---

## [2.0.0] — 2026-05-30

### Added
- **Router module** — typed params, wildcards, globs, inline pattern constraints
  - Seven Luau types coerced at match time: `string`, `boolean`, `number`, `vector2`, `vector3`, `color3`, `cframe`
  - Wildcards (`*`) and globs (`**`) with `req.captures`
  - Inline pattern constraints `:id(\d+)`
  - Priority-sorted routes — most specific always wins regardless of declaration order
- **Server push** — `app:Push`, `app:PushAll`, `app:PushTo` over reliable remote
- **Codec module** — LZ77 buffer compression, opt-in per route via `{ compress = true }`
- **Bridge module** — shared singleton internal event bus
  - `bridge.Bind`, `bridge.Unbind`, `bridge.UnbindAll`, `bridge.Fire`, `bridge.Has`
  - `bridge.Wait`, `bridge.WaitUntil`, `bridge.WaitFirst` — yieldable coroutine variants
- **Tamper module** — passive exploit detection with 8 reason types across two tiers
  - Immediate: `VERSION_SPOOF`, `MALFORMED_PAYLOAD`, `INVALID_PARAM`, `UNKNOWN_ROUTE`
  - Pattern: `RATE_FLOOD`, `ROUTE_SCAN`, `PARAM_FLOOD`
  - `tamper.Strike()` for manual business-logic violations
  - `tamper.AutoKick(threshold, reason)` — opt-in auto-kick
  - `tamper.SetThresholds(config)` — configurable detection thresholds
- `app:OnParamError(fn)` — custom handler for typed param coercion failures
- `req.captures` — positional array for wildcard and glob matches
- `req.query` — parsed query string params

### Fixed
- Middleware returning `false` now blocks request with 403 (was a no-op in v1.6)
- Middleware crash now sends 500 and stops the request (previously continued silently)
- `TokenBucket` rewritten as instantiable class — App and Broadcast own independent instances
- TokenBucket now seeds buckets for players already in server on construction
- `shared.ROEXPRESS_VERSION` set once in init.luau — App and Network can never drift

### Changed
- `PushTo` argument order fixed — `(players, event, data)`
- `Module:Destroy()` declaration restored in App

---

## [1.6.0] — 2026-05-19

### Added
- Initial release
- `App` — GET/POST routing, global middleware, res:Send/Error/Status
- `Network` — client GET/POST with callbacks and timeout
- `Broadcast` — unreliable fire-and-forget with per-event and per-player rate limiting
- `Listener` — On/Once/Off for broadcast events
- `TokenBucket` — global rate limiter with Grant utilities
- `Base64` — shared encode/decode utility
- Single reliable remote + single unreliable remote architecture
- Version field on all payloads — 400 on mismatch
- `network:Cancel(requestId)` for client-side request abandonment
