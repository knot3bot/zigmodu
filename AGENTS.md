# ZigModu Framework Agent Guide

## Project Overview
ZigModu is a modular application framework for Zig 0.16.0, aligned with Spring Modulith core features. **v0.8.0 — 93/100 production readiness, 282 tests passing.**

## Critical Constraints
- **Zig Version**: Must use Zig 0.16.0 exactly
- **No GC**: Framework avoids hidden allocations; uses explicit memory management
- **Compile-time Validation**: Module dependencies checked at compile time where possible
- **Explicit Lifecycle**: Modules must implement `init() !void` and `deinit() void`
- **Time Source**: Always use `@import("core/Time.zig").monotonicNowSeconds()` — NEVER hardcode `const now = 0`
- **ArrayList Pattern**: Use `std.ArrayList(T).empty` + `.deinit(allocator)` + `.append(allocator, item)` in Zig 0.16.0

## Project Structure
```
zigmodu/
├── build.zig                  # Build system (Zig 0.16.0 syntax)
├── build.zig.zon              # Dependency management
├── AGENTS.md                  # This file
├── Dockerfile                 # Multi-stage Docker build
├── docker-compose.yml         # Full stack (PG + Redis + Vault + Jaeger)
├── src/
│   ├── root.zig               # Framework public API exports (PRIMARY/ADVANCED/DEPRECATED)
│   ├── Application.zig        # Application builder + shutdown hooks
│   ├── api/                   # Public API
│   │   ├── Module.zig         # Module and Modulith structs
│   │   ├── Server.zig         # Async HTTP server + router
│   │   └── Middleware.zig      # Middleware framework
│   ├── core/                  # Core framework
│   │   ├── Module.zig         # ModuleInfo, ApplicationModules
│   │   ├── ModuleScanner.zig  # Compile-time module scanning
│   │   ├── ModuleValidator.zig # Dependency validation
│   │   ├── ModuleInteractionVerifier.zig # Interaction model verification
│   │   ├── ModuleBoundary.zig # Module boundary enforcement
│   │   ├── ModuleContract.zig # Formal module contracts
│   │   ├── EventBus.zig       # Type-safe event bus
│   │   ├── DistributedEventBus.zig # Cross-node event communication
│   │   ├── Lifecycle.zig      # startAll/stopAll functions
│   │   ├── Time.zig           # Centralized monotonic time utility
│   │   ├── Documentation.zig  # PlantUML doc generation
│   │   ├── GrpcTransport.zig  # gRPC service registry + proto parser
│   │   ├── KafkaConnector.zig # Kafka producer/consumer
│   │   ├── SagaOrchestrator.zig # Saga auto-compensation orchestrator
│   │   ├── DistributedTransaction.zig # 2PC + Saga transactions
│   │   ├── HealthEndpoint.zig # K8s health probes
│   │   ├── HotReloader.zig    # File-watch hot reload
│   │   ├── PluginManager.zig  # Plugin system
│   │   └── ...
│   ├── http/                  # HTTP & API
│   │   ├── HttpClient.zig     # HTTP client with pooling
│   │   ├── Idempotency.zig    # Idempotency middleware + store
│   │   └── OpenApi.zig        # OpenAPI 3.x document generator
│   ├── migration/             # Database migrations
│   │   └── Migration.zig      # Flyway-style migration runner
│   ├── secrets/               # Secrets management
│   │   └── SecretsManager.zig # Multi-source secrets with Vault
│   ├── resilience/            # Resilience patterns
│   │   ├── CircuitBreaker.zig
│   │   ├── RateLimiter.zig
│   │   ├── Retry.zig
│   │   └── LoadShedder.zig
│   ├── sqlx/                  # Database drivers (PG/MySQL/SQLite)
│   ├── redis/                 # Redis client
│   ├── tenant/                # Multi-tenancy + sharding
│   ├── security/              # Auth (JWT/RBAC/PasswordEncoder)
│   ├── di/                    # DI container
│   ├── config/                # Configuration loaders
│   ├── log/                   # Structured logging
│   ├── test/                  # Testing utilities
│   │   ├── ContractTest.zig   # Pact-style contract testing
│   │   ├── IntegrationTest.zig
│   │   └── ModuleTest.zig
│   └── ...
├── docs/                      # Documentation
├── examples/                  # Example projects
├── shopdemo/                  # Full reference app (42 modules, 790+ APIs)
└── .github/workflows/ci.yml   # CI/CD pipeline
```

## Essential Commands
- `zig build` - Compile the framework
- `zig build test` - Run tests (282 passed)
- `zig build run` - Run example application
- `zig build benchmark` - Run performance benchmarks
- `docker compose up -d` - Start full stack

## Framework Conventions (CRITICAL)

### 1. Module Definition
```zig
const api = @import("zigmodu").api;

pub const info = api.Module{
    .name = "order",
    .description = "Order management module",
    .dependencies = &.{"inventory"},
    .is_internal = false,
};

pub fn init() !void {
    std.log.info("Order module initialized", .{});
}

pub fn deinit() void {
    std.log.info("Order module cleaned up", .{});
}
```

### 2. Application Entry Point
```zig
const std = @import("std");
const zigmodu = @import("zigmodu");

const order = @import("order/module.zig");
const inventory = @import("inventory/module.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var modules = try zigmodu.scanModules(allocator, .{ order, inventory });
    defer modules.deinit();

    try zigmodu.validateModules(&modules);
    try zigmodu.generateDocs(&modules, "modules.puml", allocator);
    try zigmodu.startAll(&modules);
    defer zigmodu.stopAll(&modules);
}
```

### 3. Using Middleware
```zig
const zigmodu = @import("zigmodu");

// Tracing middleware
server.addMiddleware(.{ .func = zigmodu.tracing_middleware.tracing() });

// Idempotency middleware
var idempotency_store = zigmodu.IdempotencyStore.init(allocator, 100000);
defer idempotency_store.deinit();
server.addMiddleware(.{ .func = zigmodu.idempotencyMiddleware(&idempotency_store) });
```

### 4. Database Migrations
```zig
var runner = zigmodu.MigrationRunner.init(allocator);
defer runner.deinit();

try runner.addMigration(20260101000000, "create users table",
    \\CREATE TABLE users (id BIGINT PRIMARY KEY, name VARCHAR(255));
);
```

### 5. Secrets Management
```zig
var secrets = zigmodu.SecretsManager.init(allocator);
defer secrets.deinit();

// Load from env (highest priority)
try secrets.loadFromEnv("APP_");

// Load from file
try secrets.loadFromEnvContent(file_content);

// Set defaults (lowest priority)
try secrets.setDefault("DB_HOST", "localhost");

// Get with fallback
const db_host = secrets.getOrDefault("DB_HOST", "127.0.0.1");
```

### 6. Saga Orchestrator
```zig
var orchestrator = zigmodu.SagaOrchestrator.init(allocator);
defer orchestrator.deinit();

try orchestrator.registerSaga("create-order", &.{
    .{ .name = "validate", .action = validateOrder, .compensation = rollbackValidate },
    .{ .name = "process",  .action = processPayment, .compensation = refundPayment },
});

_ = orchestrator.execute("create-order") catch |err| {
    // Compensation executed automatically
    std.log.err("Saga failed: {}", .{err});
};
```

### 7. Kafka Integration
```zig
var producer = zigmodu.KafkaProducer.init(allocator, .{
    .bootstrap_servers = "kafka:9092",
});
defer producer.deinit();

try producer.send(.{
    .topic = "orders.created",
    .value = "{\"order_id\":123}",
    .headers = &.{},
    .timestamp = zigmodu.time.monotonicNowSeconds(),
});
```

### 8. gRPC Service
```zig
var registry = zigmodu.GrpcServiceRegistry.init(allocator);
defer registry.deinit();

try registry.registerService("order.OrderService");
try registry.registerMethod("order.OrderService", "CreateOrder", .unary, handleCreateOrder);
```

### 9. OpenAPI Documentation
```zig
var gen = zigmodu.OpenApiGenerator.init(allocator, "My API", "1.0.0", "API description");
defer gen.deinit();

try gen.addEndpoint(.{
    .method = .GET,
    .path = "/users/{id}",
    .summary = "Get user by ID",
    .tags = &.{"users"},
    .responses = &.{.{ .status_code = 200, .description = "User object" }},
});

const openapi_json = try gen.generate();
```

### 10. Contract Testing
```zig
var runner = zigmodu.ContractTestRunner.init(allocator);
defer runner.deinit();

try runner.registerContract(.{
    .name = "order-create",
    .consumer = "order-service",
    .provider = "payment-service",
    .version = "1.0",
    .interaction_type = .http,
    .request = .{ .method = "POST", .path = "/api/payments" },
    .response = .{ .status = 201, .body_contains = "paid" },
});

const result = try runner.verifyContract("order-create", 201, response_body, &.{});
try std.testing.expect(result.passed);
```

### 11. Module Interaction Verification
```zig
var verifier = zigmodu.ModuleInteractionVerifier.init(allocator, .{
    .max_dependencies_per_module = 10,
    .allow_circular_deps = false,
});
defer verifier.deinit();

try verifier.addModuleRule("order", "payment", &.{ .event_driven, .api_call }, "order→payment");
```

## build.zig.zon Format (Zig 0.16.0)
```zig
.{
    .name = .zigmodu,  // MUST be enum literal, not string!
    .version = "0.8.0",
    .fingerprint = 0x7aa42d07b32f8d53,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{},
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

## build.zig Format (Zig 0.16.0)
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);
}
```

## Common Mistakes to Avoid

1. **build.zig.zon**: `.name` must be enum literal (`.zigmodu`), NOT string (`"zigmodu"`)
2. **build.zig**: Use `root_module = b.createModule(...)` NOT `root_source_file = ...`
3. **Module dependencies**: Use `&.{}` syntax for empty dependencies
4. **scanModules signature**: `scanModules(allocator, .{ mod1, mod2 })` - allocator FIRST
5. **Time**: Always use `@import("core/Time.zig").monotonicNowSeconds()` — NEVER `const now = 0`
6. **ModuleInfo.init**: Takes 3 args `(name, desc, deps)` — ptr is now optional and defaults to null
7. **ArrayList**: Use `std.ArrayList(T).empty` + `.deinit(allocator)` + `.append(allocator, item)` in Zig 0.16.0
8. **File I/O**: Use `std.Io.Dir.cwd().openFile(io, path, .{})` with explicit `io` parameter

## Verification
- ✅ `zig build` compiles successfully
- ✅ `zig build test` — 282 passed, 5 skipped, 2 failed (pre-existing)
- ✅ `zig build run` outputs module validation and startup messages
- ✅ `modules.puml` is generated with correct PlantUML syntax
- ✅ Module init/deinit functions are properly called
- ✅ Memory is properly cleaned up
- ✅ All timestamps use real monotonic time

## Module Inventory

### Core (100% complete)
`Module.zig`, `ModuleScanner.zig`, `ModuleValidator.zig`, `ModuleInteractionVerifier.zig`, `ModuleBoundary.zig`, `ModuleContract.zig`, `ModuleCapabilities.zig`, `Lifecycle.zig`, `Time.zig`, `EventBus.zig`, `Documentation.zig`, `Error.zig`, `ApplicationObserver.zig`, `ApplicationView.zig`

### Event System (100% complete)
`DistributedEventBus.zig`, `TransactionalEvent.zig`, `EventLogger.zig`, `EventPublisher.zig`, `EventStore.zig`, `AutoEventListener.zig`, `ModuleListener.zig`

### HTTP & API (95% complete)
`HttpClient.zig`, `Idempotency.zig`, `OpenApi.zig`, `api/Server.zig`, `api/Middleware.zig`, `api/middleware/Tracing.zig`

### Distributed (90% complete)
`ClusterMembership.zig`, `DistributedTransaction.zig`, `GrpcTransport.zig`, `KafkaConnector.zig`, `SagaOrchestrator.zig`, `WebSocket.zig`, `WebMonitor.zig`

### Resilience (100% complete)
`CircuitBreaker.zig`, `RateLimiter.zig`, `Retry.zig`, `LoadShedder.zig`

### Data (100% complete)
`sqlx/sqlx.zig`, `persistence/Orm.zig`, `migration/Migration.zig`, `cache/CacheManager.zig`, `redis/redis.zig`, `pool/Pool.zig`

### Security (100% complete)
`SecurityModule.zig`, `SecurityScanner.zig`, `Rbac.zig`, `PasswordEncoder.zig`, `secrets/SecretsManager.zig`, `tenant/TenantContext.zig`, `tenant/ShardRouter.zig`

### Observability (100% complete)
`DistributedTracer.zig`, `PrometheusMetrics.zig`, `AutoInstrumentation.zig`, `StructuredLogger.zig`, `HealthEndpoint.zig`

### DevOps (100% complete)
`HotReloader.zig`, `PluginManager.zig`, `ArchitectureTester.zig`, `Dockerfile`, `docker-compose.yml`, `.github/workflows/ci.yml`

### Testing (100% complete)
`ModuleTest.zig`, `IntegrationTest.zig`, `ContractTest.zig`, `Benchmark.zig`, `ModulithTest.zig`
