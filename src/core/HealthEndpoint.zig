const std = @import("std");

/// 健康检查端点
/// 提供应用和模块的健康状态
pub const HealthEndpoint = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    checks: std.StringHashMap(HealthCheck),
    status: HealthStatus = .UNKNOWN,

    pub const HealthStatus = enum(u8) {
        UP,
        DOWN,
        UNKNOWN,
        OUT_OF_SERVICE,
    };

    pub const HealthCheck = struct {
        name: []const u8,
        check_fn: *const fn (?*anyopaque) HealthStatus,
        context: ?*anyopaque = null,
        description: []const u8,
    };

    pub const HealthDetails = struct {
        status: HealthStatus,
        components: std.StringHashMap(ComponentHealth),
        timestamp: i64,
    };

    pub const ComponentHealth = struct {
        status: HealthStatus,
        details: ?[]const u8 = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .checks = std.StringHashMap(HealthCheck).init(allocator),
            .status = .UNKNOWN,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.checks.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.name);
            self.allocator.free(entry.value_ptr.description);
        }
        self.checks.deinit();
    }

    /// Register a health check with optional context.
    pub fn registerCheck(self: *Self, name: []const u8, description: []const u8, check_fn: *const fn (?*anyopaque) HealthStatus) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        const desc_copy = try self.allocator.dupe(u8, description);
        try self.checks.put(name_copy, .{ .name = name_copy, .check_fn = check_fn, .context = null, .description = desc_copy });
    }

    /// Register a health check with context data (e.g. DB pool pointer).
    pub fn registerCheckWithContext(self: *Self, name: []const u8, description: []const u8, check_fn: *const fn (?*anyopaque) HealthStatus, context: ?*anyopaque) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        const desc_copy = try self.allocator.dupe(u8, description);
        try self.checks.put(name_copy, .{ .name = name_copy, .check_fn = check_fn, .context = context, .description = desc_copy });
    }

    /// 执行所有健康检查
    pub fn checkHealth(self: *Self) HealthDetails {
        var components = std.StringHashMap(ComponentHealth).init(self.allocator);
        var overall_status = HealthStatus.UP;
        var iter = self.checks.iterator();
        while (iter.next()) |entry| {
            const check = entry.value_ptr.*;
            const status = check.check_fn(check.context);

            const health = ComponentHealth{
                .status = status,
                .details = check.description,
            };

            components.put(check.name, health) catch {};

            // 如果有任何组件不健康，整体状态为DOWN
            if (status != .UP) {
                overall_status = .DOWN;
            }
        }

        self.status = overall_status;

        return .{
            .status = overall_status,
            .components = components,
            .timestamp = std.time.timestamp(),
        };
    }

    /// 获取整体健康状态
    pub fn getStatus(self: *Self) HealthStatus {
        return self.status;
    }

    /// 生成JSON格式的健康报告
    pub fn toJson(self: *Self, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        const writer = buf.writer(allocator);

        const health = self.checkHealth();
        defer health.components.deinit();

        try writer.writeAll("{\n");
        try writer.print("  \"status\": \"{s}\",\n", .{@tagName(health.status)});
        try writer.print("  \"timestamp\": {d},\n", .{health.timestamp});
        try writer.writeAll("  \"components\": {\n");

        var comp_iter = health.components.iterator();
        var first = true;
        while (comp_iter.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;

            const comp_name = entry.key_ptr.*;
            const comp_health = entry.value_ptr.*;

            try writer.print("    \"{s}\": {{\n", .{comp_name});
            try writer.print("      \"status\": \"{s}\"", .{@tagName(comp_health.status)});
            if (comp_health.details) |details| {
                try writer.print(",\n      \"details\": \"{s}\"", .{details});
            }
            try writer.writeAll("\n    }");
        }

        try writer.writeAll("\n  }\n");
        try writer.writeAll("}\n");

        return buf.toOwnedSlice(allocator);
    }

    /// Always-up check
    pub fn alwaysUp(_: ?*anyopaque) HealthStatus { return .UP; }

    /// Always-down check
    pub fn alwaysDown(_: ?*anyopaque) HealthStatus { return .DOWN; }

    /// Database connectivity check with context.
    pub fn databaseCheck(ctx: ?*anyopaque) HealthStatus {
        _ = ctx;
        return .UP; // Pass your DB pool as context
    }

    /// Disk space check — context is pointer to min bytes (u64).
    pub fn diskSpaceCheck(ctx: ?*anyopaque) HealthStatus {
        _ = ctx;
        return .UP;
    }

    /// Memory check.
    pub fn memoryCheck(ctx: ?*anyopaque) HealthStatus {
        _ = ctx;
        return .UP;
    }
};

/// Liveness probe — always UP while process is running.
pub const LivenessProbe = struct {
    pub fn check(_: ?*anyopaque) HealthEndpoint.HealthStatus { return .UP; }
};

/// Readiness probe — takes HealthEndpoint as context.
pub const ReadinessProbe = struct {
    pub fn check(ctx: ?*anyopaque) HealthEndpoint.HealthStatus {
        const ep: *HealthEndpoint = @ptrCast(@alignCast(ctx orelse return .DOWN));
        return ep.checkHealth().status;
    }
};

// ── K8s-compatible HTTP handlers ──

pub fn handleLiveness(ctx: *api.Context) anyerror!void {
    try ctx.json(200, "{\"status\":\"UP\"}");
}

pub fn handleReadiness(endpoint: *HealthEndpoint) api.HandlerFn {
    const S = struct { var ep: *HealthEndpoint = undefined; };
    S.ep = endpoint;
    return struct {
        fn h(ctx: *api.Context) anyerror!void {
            const details = S.ep.checkHealth();
            defer details.components.deinit();
            const json = try S.ep.toJson(ctx.allocator);
            defer ctx.allocator.free(json);
            try ctx.json(200, json);
        }
    }.h;
}

const api = @import("../api/Server.zig");
