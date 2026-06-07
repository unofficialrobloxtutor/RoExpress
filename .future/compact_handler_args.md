---
name: compact-handler-args
description: Use debug.info param count to compact app:Get/Post handler from 4 args to 2 while preserving backwards compatibility
metadata:
  type: project
---

## Problem

Current handler signature for `app:Get` and `app:Post` takes four arguments:

```luau
app:Get("/route", function(Player, Payload, req, res)
    res:Send({ ok = true })
end)
```

`Player` and `Payload` are mostly noise — 90% of handlers only care about `req` and `res`. But dropping them would break every existing handler.

---

## Solution — debug.info param count dispatch

`debug.info(fn, "a")` returns the number of fixed parameters a function declares. Use that at call time to decide which calling convention to use:

```luau
local nparams = debug.info(handler, "a")
if nparams >= 4 then
    -- legacy: handler(Player, Payload, req, res)
    handler(Player, Payload, req, res)
else
    -- new compact: handler(req, res)
    -- req.player and req.raw available if needed
    handler(req, res)
end
```

No flag, no migration, no deprecation warning needed — the function's own signature selects the calling convention.

---

## What changes on the new (2-arg) path

`req` would need two extra fields so callers that need the player or raw payload can still get them without a fourth arg:

```luau
req.player  = Player   -- the firing player
req.raw     = Payload  -- the raw wire payload, if needed
```

`res` stays identical.

---

## Affected call sites

- `App.luau` — the `_dispatch` / route handler call inside the `OnServerEvent` listener
- `Port.luau` — mirrors the same dispatch logic for named ports

---

## Why deferred

- Needs a Luau runtime guarantee that `debug.info(fn, "a")` is stable across all Roblox executor contexts (server, client, Studio test). Worth verifying before shipping.
- Small but real overhead per-call. Acceptable at typical RPC rates; worth a note.
- `req.player` / `req.raw` field additions are a minor but non-zero API surface change on `Request`.
