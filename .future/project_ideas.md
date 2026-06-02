---
name: roexpress-future-ideas
description: Future ideas and deferred features for RoExpress that were discussed but not yet implemented
metadata:
  type: project
---

## Adapter / Plugin System

**Idea:** A way to plug external functions into RoExpress route handlers without writing a full wrapper. Discussed two approaches:
1. A thin `adapt()` utility that wraps a plain `(player) -> data` function into a full route handler, auto-sending the return value
2. Handler chaining — pass multiple functions per route, each runs in sequence

**Why deferred:** Not the right time. Keeping RoExpress focused on networking first. Revisit once the core API is stable.

**How to apply:** If this comes up again, the two concrete directions are `adapt(fn)` utility or multi-function route chaining. Don't rebuild from scratch.
