# API Migration Guide: Simplified API → Application API

ZigModu v0.8+ recommends `Application` as the primary API. The legacy `Simplified.zig`
(`App`, `Module`, `ModuleImpl`) is deprecated and will be removed in v1.0.

## Quick Comparison

| Feature | Simplified (deprecated) | Application (recommended) |
|---------|------------------------|---------------------------|
| Entry point | `App.init()` | `Application.init()` / `builder()` |
| Module type | `Module` (VTable) | `api.Module` (comptime) |
| Registration | `app.register(ModuleImpl(T).interface(&inst))` | `builder().build(.{T})` |
| Validation | Manual | `validate_on_start: true` (default) |
| Lifecycle | `app.start()` / `app.stop()` | `app.start()` / `app.stop()` + graceful drain |
| Shutdown hooks | Not supported | `app.onShutdown(hook)` |
| Health checks | Not supported | `HealthEndpoint` + K8s probes |
| Metrics | Not supported | `PrometheusMetrics` + `/metrics` |

## Migration Steps

### Before: Simplified API

```zig
const zmodu = @import("zigmodu");
const Simplified = zmodu.App;
const ModuleImpl = zmodu.ModuleImpl;

const UserModule = struct {
    pub fn name(_: *UserModule) []const u8 { return "user"; }
    pub fn init(self: *UserModule, _: *anyopaque) !void {
        std.log.info("user init", .{});
    }
    pub fn start(self: *UserModule) !void {}
    pub fn stop(self: *UserModule) void {}
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = App.init(allocator);
    defer app.deinit();

    var user_mod = UserModule{};
    try app.register(ModuleImpl(UserModule).interface(&user_mod));
    try app.start();
    defer app.stop();
}
```

### After: Application API

```zig
const zmodu = @import("zigmodu");

const UserModule = struct {
    pub const info = zmodu.api.Module{
        .name = "user",
        .description = "User management module",
        .dependencies = &.{},
    };
    pub fn init() !void {
        std.log.info("user init", .{});
    }
    pub fn deinit() void {}
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try zmodu.builder(allocator, std.testing.io)
        .withName("my-app")
        .build(.{UserModule});
    defer app.deinit();

    // app.run() handles signals + graceful drain (recommended for production)
    try app.start();
    defer app.stop();
}
```

## Key Changes

1. **Module definition**: Use `pub const info = zmodu.api.Module{...}` instead of VTable methods
2. **No instance needed**: `Application` calls `init()`/`deinit()` directly, no `self` pointer
3. **Compile-time safety**: `scanModules()` validates dependencies at compile time
4. **Graceful shutdown**: `app.run()` handles SIGINT/SIGTERM + drains in-flight requests
5. **No VTable**: Direct function calls instead of indirect VTable dispatch
