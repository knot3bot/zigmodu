const std = @import("std");
const model = @import("model.zig");

pub fn SubscriptionPersistence(comptime Backend: type) type {
    return struct {
        const Self = @This();
        backend: Backend,

        pub fn init(backend: Backend) Self {
            return .{ .backend = backend };
        }

        pub fn findByTenant(self: *Self, tenant_id: i64) !?model.Subscription {
            _ = self; _ = tenant_id; return null;
        }

        pub fn create(self: *Self, sub: model.Subscription) !i64 {
            _ = self; _ = sub; return 0;
        }

        pub fn updateStatus(self: *Self, id: i64, status: []const u8) !void {
            _ = self; _ = id; _ = status;
        }

        pub fn findAllPlans(self: *Self) ![]model.Plan {
            _ = self; return &[_]model.Plan{};
        }
    };
}
