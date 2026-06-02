# RoExpress — Library Comparison

A factual comparison of the main Roblox networking libraries.
Feature claims are sourced from each library's official README or documentation.

---

## At a Glance

| | RoExpress | BridgeNet2 | ByteNet | Zap | Red | Knit |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Maintained** | ✓ | ✓ | ✓ | ✓ (rewrite) | ✗ archived | ✗ archived |
| **Pure Luau** | ✓ | ✓ | ✓ | ✗ (Rust CLI) | ✓ | ✓ |
| **Zero dependencies** | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |
| **Wally** | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| **Single remote** | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **Request / response** | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ |
| **Typed route params** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Route middleware** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Named ports** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Server push** | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ |
| **LZ77 compression** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Binary protocol** | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| **Rate limiting** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Exploit detection** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Promise API** | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ |
| **FPS streaming** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Benchmarking** | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Build step required** | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |

---

## Library Summaries

### BridgeNet2
**Focus:** Bandwidth optimisation via a single remote and compact event identifiers.

BridgeNet2 reduces header overhead on RemoteEvent calls and lowers client-side packet processing time. Its API mirrors standard RemoteEvents (`Fire` / `Connect`) which makes adoption easy for existing codebases. It does not provide a request/response pattern, middleware, compression, rate limiting, or exploit detection. The BridgeNet2 author now recommends ByteNet for new projects.

**Strongest at:** Minimal migration from vanilla RemoteEvents.

---

### ByteNet
**Focus:** Maximum throughput via buffer-based binary serialisation.

ByteNet packs Luau data into `buffer` objects before transmission and unpacks on receipt. This gives it a raw performance advantage over libraries that send Luau tables directly. It enforces strict typing at the schema level. It does not provide routing, middleware, request/response, compression, rate limiting, or exploit detection — it is a transport layer, not an application framework.

**Strongest at:** High-frequency, fixed-schema data where raw bytes/frame matters most.

---

### Zap
**Focus:** Code-generated, zero-overhead binary networking from a typed schema.

Zap is not a Luau library — it is a Rust CLI tool and custom IDL (`.zap` files) that generates Luau client and server bindings at build time. Generated code packs data into buffers with no runtime overhead. Zap requires a build step and is not distributable via Wally. It is currently undergoing a significant rewrite.

**Strongest at:** Projects that want guaranteed type-safe bindings and can accept a build pipeline.

---

### Red *(archived December 2025)*
Red was a single-remote event library with bandwidth compression and full Luau type safety. It is no longer maintained. New projects should not depend on it.

---

### Knit *(archived July 2024)*
Knit was a service/controller framework that abstracted RemoteFunction and RemoteEvent creation. It is no longer maintained. New projects should not depend on it.

---

## Where RoExpress Wins

**Application-layer structure.** RoExpress is the only library in this space that brings Express.js-style routing to Roblox — typed path params (`:id=number`), wildcards, globs, middleware chains, and named ports. This makes server code organised, auditable, and testable in a way that event-based libraries cannot match.

**Security first.** Built-in rate limiting (TokenBucket), payload validation, version mismatch detection, and the Tamper module for exploit detection are part of the framework — not afterthoughts.

**Complete client API.** Network provides both callback and blocking request patterns, a full Promise chain (`GetAsync` / `PostAsync`), and cancellation by request ID. No other library in this group offers all three.

**No build step.** Pure Luau, zero external dependencies, installable via Wally in one line.

**Specialised modules.** LZ77 compression for large payloads, 60 hz binary FPS streaming for combat games, named ports for isolated route namespaces, and a built-in Benchmark module for profiling routes in production conditions.

---

## Where Others Win

**Raw byte performance.** ByteNet and Zap serialize into `buffer` objects which are faster and smaller than Luau table serialisation. If you are sending thousands of small fixed-schema packets per second, ByteNet or Zap will outperform RoExpress at the transport layer.

**Code-generated types.** Zap generates Luau bindings from a schema, giving compile-time type guarantees without manual annotations. RoExpress relies on the developer annotating types correctly.

**Simplest possible API.** BridgeNet2's `Fire` / `Connect` surface is familiar to anyone who has used vanilla RemoteEvents and requires almost no learning curve.

---

## When to Use Which

| Situation | Recommended |
|---|---|
| Structured server API with typed routes, middleware, and security | **RoExpress** |
| High-frequency fixed-schema data (combat state, physics) | **ByteNet** |
| Guaranteed type-safe bindings from a build pipeline | **Zap** |
| Minimal migration from vanilla RemoteEvents | **BridgeNet2** |
| Looking for a full service/controller framework | look for a maintained Knit alternative |
