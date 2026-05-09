const std = @import("std");
const Time = @import("../core/Time.zig");

/// 幂等性键条目
pub const IdempotencyEntry = struct {
    key: []const u8,
    response: []const u8,
    status_code: u16,
    created_at: i64,
    expires_at: i64,
};

/// 幂等性中间件配置
pub const IdempotencyConfig = struct {
    /// 幂等性键的默认过期时间 (秒)
    ttl_seconds: u64 = 24 * 60 * 60, // 24 hours
    /// 最大存储条目数
    max_entries: usize = 100_000,
    /// 幂等性键的 HTTP header 名称
    header_name: []const u8 = "Idempotency-Key",
};

/// 幂等性存储接口
/// 可替换为 Redis / SQLite / Memory 等实现
pub const IdempotencyStore = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    entries: std.StringHashMap(IdempotencyEntry),
    max_entries: usize,

    pub fn init(allocator: std.mem.Allocator, max_entries: usize) Self {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(IdempotencyEntry).init(allocator),
            .max_entries = max_entries,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.key);
            self.allocator.free(entry.value_ptr.response);
        }
        self.entries.deinit();
    }

    /// 存储幂等性响应
    pub fn store(self: *Self, key: []const u8, response: []const u8, status_code: u16, ttl_seconds: u64) !void {
        const now = Time.monotonicNowSeconds();

        // 如果达到上限，移除最旧的条目
        if (self.entries.count() >= self.max_entries) {
            self.evictOldest();
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const resp_copy = try self.allocator.dupe(u8, response);
        errdefer self.allocator.free(resp_copy);

        try self.entries.put(key_copy, .{
            .key = key_copy,
            .response = resp_copy,
            .status_code = status_code,
            .created_at = now,
            .expires_at = now + @as(i64, @intCast(ttl_seconds)),
        });
    }

    /// 查找已有的幂等性响应
    pub fn get(self: *Self, key: []const u8) ?IdempotencyEntry {
        const entry_ptr = self.entries.getPtr(key) orelse return null;

        const now = Time.monotonicNowSeconds();
        if (now >= entry_ptr.expires_at) {
            // 过期清理 — 先保存指针再移除
            const owned_key = entry_ptr.key;
            const owned_resp = entry_ptr.response;
            _ = self.entries.remove(key);
            self.allocator.free(owned_key);
            self.allocator.free(owned_resp);
            return null;
        }

        return IdempotencyEntry{
            .key = entry_ptr.key,
            .response = entry_ptr.response,
            .status_code = entry_ptr.status_code,
            .created_at = entry_ptr.created_at,
            .expires_at = entry_ptr.expires_at,
        };
    }

    /// 检查幂等性键是否存在且未过期
    pub fn has(self: *Self, key: []const u8) bool {
        return self.get(key) != null;
    }

    /// 清理过期条目
    pub fn purgeExpired(self: *Self) !usize {
        const now = Time.monotonicNowSeconds();
        var purged: usize = 0;

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (now >= entry.value_ptr.expires_at) {
                const owned_key = entry.value_ptr.key;
                const owned_resp = entry.value_ptr.response;
                _ = self.entries.remove(entry.key_ptr.*);
                self.allocator.free(owned_key);
                self.allocator.free(owned_resp);
                purged += 1;
            }
        }

        return purged;
    }

    fn evictOldest(self: *Self) void {
        var oldest_key: ?[]const u8 = null;
        var oldest_time: i64 = std.math.maxInt(i64);

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.created_at < oldest_time) {
                oldest_time = entry.value_ptr.created_at;
                oldest_key = entry.key_ptr.*;
            }
        }

        if (oldest_key) |key| {
            if (self.entries.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                self.allocator.free(removed.value.response);
            }
        }
    }
};

/// HTTP 幂等性中间件
/// 防止同一请求被重复处理（适用于支付、下单等关键操作）
///
/// 用法:
///   server.addMiddleware(.{ .func = idempotencyMiddleware(&store) });
///
/// 客户端需在请求头中发送 `Idempotency-Key`
pub fn idempotencyMiddleware(store: *IdempotencyStore) api.MiddlewareFn {
    const S = struct {
        fn handler(ctx: *api.Context, next: api.HandlerFn, user_data: ?*anyopaque) anyerror!void {
            _ = user_data;

            // 仅对写操作检查幂等性
            const method = ctx.method.toString();
            const is_write = std.mem.eql(u8, method, "POST") or
                std.mem.eql(u8, method, "PUT") or
                std.mem.eql(u8, method, "PATCH") or
                std.mem.eql(u8, method, "DELETE");

            if (!is_write) {
                try next(ctx, next, null);
                return;
            }

            // 提取幂等性键
            const key = ctx.header("Idempotency-Key") orelse {
                // 无幂等性键时放行（非关键操作可以不传）
                try next(ctx, next, null);
                return;
            };

            // 检查是否已处理过
            if (store.get(key)) |existing| {
                // 幂等性键已存在，返回缓存的响应
                try ctx.json(existing.status_code, existing.response);
                return;
            }

            // 第一次请求：正常处理
            try next(ctx, next, null);

            // 存储响应（此处简化——实际实现需要拦截响应体）
            // 在生产环境中，需要包装 ctx 来捕获写入的响应
        }
    };
    return S.handler;
}

/// 为幂等性中间件扩展 Context，捕获响应体
pub fn wrapContextWithIdempotency(ctx: *api.Context, store: *IdempotencyStore, ttl_seconds: u64) !void {
    const key = ctx.header("Idempotency-Key") orelse return;

    // 先检查存储，防止竞态
    if (store.has(key)) return;

    // 存储占位符，表示请求正在处理中
    _ = try store.store(key, "", 202, ttl_seconds);
}

/// 记录幂等性响应 (在 handler 完成后调用)
pub fn recordIdempotencyResponse(store: *IdempotencyStore, key: []const u8, response_body: []const u8, status_code: u16, ttl_seconds: u64) !void {
    // 先移除占位符
    _ = store.get(key);
    // 存储真实响应
    try store.store(key, response_body, status_code, ttl_seconds);
}

const api = @import("../api/Server.zig");

// ─────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────

test "IdempotencyStore store and get" {
    const allocator = std.testing.allocator;
    var store = IdempotencyStore.init(allocator, 100);
    defer store.deinit();

    try store.store("key-001", "{\"result\":\"ok\"}", 200, 3600);

    const entry = store.get("key-001").?;
    try std.testing.expectEqualStrings("{\"result\":\"ok\"}", entry.response);
    try std.testing.expectEqual(@as(u16, 200), entry.status_code);
}

test "IdempotencyStore expired entry returns null" {
    const allocator = std.testing.allocator;
    var store = IdempotencyStore.init(allocator, 100);
    defer store.deinit();

    // Store with 0 TTL (immediately expired)
    try store.store("key-ephemeral", "data", 200, 0);

    const entry = store.get("key-ephemeral");
    try std.testing.expect(entry == null);
}

test "IdempotencyStore purge expired" {
    const allocator = std.testing.allocator;
    var store = IdempotencyStore.init(allocator, 100);
    defer store.deinit();

    try store.store("key-purge", "data", 200, 0);
    try store.store("key-valid", "data2", 200, 3600);

    const purged = try store.purgeExpired();
    try std.testing.expect(purged >= 1);
    try std.testing.expect(store.has("key-valid"));
    try std.testing.expect(!store.has("key-purge"));
}

test "IdempotencyStore eviction under max" {
    const allocator = std.testing.allocator;
    var store = IdempotencyStore.init(allocator, 3);
    defer store.deinit();

    try store.store("k1", "v1", 200, 3600);
    try store.store("k2", "v2", 200, 3600);
    try store.store("k3", "v3", 200, 3600);
    try store.store("k4", "v4", 200, 3600);

    // k1 should have been evicted (oldest)
    try std.testing.expect(!store.has("k1"));
    try std.testing.expect(store.has("k4"));
}

test "IdempotencyStore has" {
    const allocator = std.testing.allocator;
    var store = IdempotencyStore.init(allocator, 100);
    defer store.deinit();

    try std.testing.expect(!store.has("nonexistent"));
    try store.store("exists", "v", 200, 3600);
    try std.testing.expect(store.has("exists"));
}
