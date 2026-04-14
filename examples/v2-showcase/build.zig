const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zigmodu_dep = b.dependency("zigmodu", .{});
    exe_mod.addImport("zigmodu", zigmodu_dep.module("zigmodu"));

    const exe = b.addExecutable(.{
        .name = "v2-showcase",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the v0.2.0 feature showcase");
    run_step.dependOn(&run_cmd.step);
    
    // Test step
    const test_step = b.step("test", "Run v0.2.0 feature tests");
    
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("zigmodu", zigmodu_dep.module("zigmodu"));
    
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
