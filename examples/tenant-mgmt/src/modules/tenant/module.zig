const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "tenant",
    .description = "Multi-tenant management — tenant CRUD, tier management",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}
