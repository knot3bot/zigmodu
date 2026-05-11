const std = @import("std");

// ================================================================
// Module Lifecycle Contract
// ================================================================
//
// A ZigModu module is ANY struct that satisfies this contract:
//
//   pub const info: zigmodu.api.Module = .{
//       .name        = "my-module",          // required
//       .description = "What it does",        // required
//       .dependencies = &.{"other-module"},   // optional
//   };
//
//   pub fn init() !void { ... }              // called at startup (dep order)
//   pub fn deinit() void { ... }             // called at shutdown (reverse order)
//
// Lifecycle guarantee:
//   - `init()` is called AFTER all dependency modules have initialized
//   - `deinit()` is called BEFORE any dependency module is deinitialized
//   - If any `init()` returns an error, startup aborts and already-started
//     modules are stopped in reverse order (best-effort cleanup)
//   - `init()`/`deinit()` are called exactly once per Application instance
//
// Dependency resolution:
//   - Dependencies are specified by `info.dependencies` name list
//   - Circular dependencies are detected at validation time (compile error)
//   - Missing dependencies are detected at validation time (compile error)

/// Module metadata definition.
/// Annotate your module struct with `pub const info: Module = .{...};`
pub const Module = struct {
    name: []const u8,
    description: []const u8 = "",
    dependencies: []const []const u8 = &.{},
    is_internal: bool = false,
};

/// Application-level configuration
/// Defines the modular application structure
pub const Modulith = struct {
    name: []const u8,
    base_path: []const u8,
    validate: bool = true,
    generate_docs: bool = true,
};

/// Module trait - compile-time interface for modules
/// Any struct with these fields can be used as a module
pub fn ModuleTrait(comptime T: type) type {
    return struct {
        pub const has_info = @hasDecl(T, "info");
        pub const has_init = @hasDecl(T, "init");
        pub const has_deinit = @hasDecl(T, "deinit");
    };
}
