# CLAUDE.md — ZigModu Framework for Claude Code

## Project
ZigModu v0.9.4 — modular app framework for Zig 0.16.0. 129 files, 420 tests, 92/100.

## Build & Test
```bash
zig build              # compile
zig build test         # run tests (417+)
zig build docs         # generate docs
```

## Architecture (5 domain files)
```
src/http.zig          → zmodu.http.{Server, Context, RouteGroup, Middleware}
src/data.zig          → zmodu.data.{sqlx, Repository, Client, orm, redis}
src/security.zig      → zmodu.security.{SecurityModule, PasswordEncoder, SecretsManager}
src/observability.zig → zmodu.observability.{PrometheusMetrics, DistributedTracer}
src/root.zig          → top-level: Application, EventBus, Container, HttpCode, HealthEndpoint
```

## Zig 0.16 Rules (top 5 mistakes to avoid)
1. `ArrayList(T).init(alloc)` → `ArrayList(T).empty`, pass alloc to each method
2. `std.Thread.Mutex` → `std.Io.Mutex`, needs `io`: `.lock(io)`, `.unlock(io)`
3. `std.time.milliTimestamp()` → `Time.monotonicNowMilliseconds()`
4. `file.writeAll(x)` → `file.writeStreamingAll(io, x)`
5. `std.os.getpid()` → `@intFromPtr(&seed)`

## Code Generation Rules
- Module: `pub const info = zmodu.api.Module{...}` + `init() !void` + `deinit() void`
- HTTP: `ctx.json(status, body)` NOT `sendSuccess/sendFail` (deprecated)
- DB: `data.Client.open(alloc, io, cfg)` one-step, NOT init+connect
- Router: `*` wildcard for catch-all, `{id}` for path params
- Logging: `std.log.err/warn/info` with `{s}/{d}` format, never emoji
- Secrets: never hardcode, use `zmodu.security.SecretsManager`
- CORS: `http_middleware.cors(.{ .allow_origins = &.{"*"} })` — runs before 404

## Common Bugs to Check
- `catch {}` — replace with `catch |err| std.log.err(...)`
- `bindJson` — deepCopy prevents UAF, strings are owned
- `parsed.deinit()` after `return parsed.value` — always deep-copy
- `ctx.headers.get("origin")` — already lowercase-normalized in parser
- `page_allocator.create()` — use module-level `var` instead

## Key Files
```
src/api/Server.zig      (1700L) — Context, Router, Server, connFiber
src/api/Middleware.zig   (350L) — cors, jwtAuth, csrf, requestId, recover
src/core/Error.zig       (330L) — ZigModuError, ErrorHandler, HttpCode, Result
src/core/EventBus.zig    (240L) — TypedEventBus, ThreadSafeEventBus, UnifiedEventBus
src/core/Time.zig         (90L) — monotonicNow, cachedNowSeconds, refreshCache
src/sqlx/sqlx.zig       (2900L) — Client, Conn, Transaction, ORM helpers
src/Application.zig      (540L) — builder, run(), lifecycle, graceful shutdown
```

## Examples
```
examples/shopdemo/      — 152-table e-commerce (42 modules)
examples/cluster-demo/   — 3-node docker compose
examples/http-stress-test/ — wrk benchmark
```
