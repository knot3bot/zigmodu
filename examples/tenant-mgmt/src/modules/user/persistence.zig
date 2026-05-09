const std = @import("std");
const model = @import("model.zig");

pub fn UserPersistence(comptime Backend: type) type {
    return struct {
        const Self = @This();
        backend: Backend,

        pub fn init(backend: Backend) Self {
            return .{ .backend = backend };
        }

        pub fn findByTenant(self: *Self, tenant_id: i64) ![]model.User {
            _ = self; _ = tenant_id;
            return &[_]model.User{};
        }

        pub fn findById(self: *Self, tenant_id: i64, user_id: i64) !?model.User {
            _ = self; _ = tenant_id; _ = user_id;
            return null;
        }

        pub fn insert(self: *Self, user: model.User) !i64 {
            _ = self; _ = user; return 0;
        }

        pub fn countByTenant(self: *Self, tenant_id: i64) !usize {
            _ = self; _ = tenant_id; return 0;
        }
    };
}
