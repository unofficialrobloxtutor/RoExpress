# RoExpress v2.5 | Typed call form, lazy loading, Bridge v2, Maid, Debounce

RoExpress is an Express.js-style networking framework for Roblox. One RemoteEvent handles all request/response traffic: typed routes, middleware, rate limiting, server push, exploit detection, named ports, and now a more polished root API with standalone public types and lifecycle utilities.

v2.5 is a quality-of-life release that closes the gap on typed entry points, removes startup timing races, and adds two small but useful utility modules.

## Shipped in v2.5

### Full public typing

- `Types.luau` is now a standalone type module.
- All public RoExpress types are explicit and exported from the root module.
- `RoExpress("App")` now returns a typed `RoExpress.App` instance instead of `any`.
- Route handler signatures like `(req, res)` are fully inferred with no manual annotation needed.

### Lazy-loading root module

- RoExpress now loads submodules on first access using `__index` + `rawset` cache.
- Modules no longer require themselves at startup, which improves cold-load behavior and avoids unnecessary work for unused features.

### Pre-baked remotes

- `RemoteEvent` and `UnreliableRemoteEvent` are now installed as children of the RoExpress ModuleScript.
- This removes the server/client timing race and makes the installer more robust.

### Bridge v2 (breaking rename)

- `Bind` → `On`
- `BindOnce` → `Once`
- `Fire` → `Emit`
- `UnbindAll` → `Clear`
- `On` / `Once` now return a `BridgeConnection` object with `:Disconnect()`
- `Unbind` has been removed; use the returned connection instead.

### New Maid module

- `RoExpress("Maid")` returns a fresh cleanup helper every call.
- `Maid:Add(item)` returns the item unchanged so you can store and track in one expression.
- Supports cleanup for:
  - `RBXScriptConnection`
  - `BridgeConnection`
  - `:Destroy()` tables
  - threads
  - functions
- Nested Maids are supported: a child Maid added to a parent is cleaned up when the parent is destroyed.

### New Debounce module

- `Debounce.fn(fn, cooldown)` → global shared cooldown wrapper
- `Debounce.key(fn, cooldown)` → per-key cooldown wrapper
- Returns `true` when the call fires, `false` when it is blocked

### Installer updates

- `Maid`, `Debounce`, and `Types` are now included in the flat installer module list.
- Pre-baked remotes are created as children of the RoExpress ModuleScript.

## Migration notes

### Bridge rename

If you previously used:
- `bridge.Bind`
- `bridge.BindOnce`
- `bridge.Fire`
- `bridge.UnbindAll`

Update to:
- `bridge.On`
- `bridge.Once`
- `bridge.Emit`
- `bridge.Clear`

Use the returned connection object and call `:Disconnect()` when you need to remove a handler.

## Install / update

Wally:

```toml
[dependencies]
RoExpress = "unofficialrobloxtutor/roexpress@2.5.0"
```

Manual:

- Grab the latest release from GitHub
- Drop it into ReplicatedStorage
- Re-run the installer if needed

## Links

- Docs: https://roexpress.dev/
- GitHub: https://github.com/unofficialrobloxtutor/RoExpress
- Wally: https://wally.run/package/unofficialrobloxtutor/roexpress
- Discord: https://discord.gg/TszEHgEyV5
