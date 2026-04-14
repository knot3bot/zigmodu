const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for the modules directory
    const modules_mod = b.createModule(.{
        .root_source_file = b.path("modules/modules.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add ZigModu dependency to modules
    const zigmodu_dep = b.dependency("zigmodu", .{});
    modules_mod.addImport("zigmodu", zigmodu_dep.module("zigmodu"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("zigmodu", zigmodu_dep.module("zigmodu"));
    exe_mod.addImport("modules", modules_mod);

    const exe = b.addExecutable(.{
        .name = "metaverse-creative",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the metaverse creative economy demo");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const test_step = b.step("test", "Run module tests");

    const module_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("modules/modules.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    module_tests.root_module.addImport("zigmodu", zigmodu_dep.module("zigmodu"));

    const run_module_tests = b.addRunArtifact(module_tests);
    test_step.dependOn(&run_module_tests.step);
}
