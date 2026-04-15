// ZigCtl - Code generation tool for ZigModu
const std = @import("std");

const Command = enum {
    new,
    module,
    event,
    api,
    help,
    version,
};

const Config = struct {
    project_name: []const u8 = "",
    module_name: []const u8 = "",
    template_dir: []const u8 = "templates",
    output_dir: []const u8 = ".",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = parseCommand(args[1]) orelse {
        std.log.err("Unknown command: {s}", .{args[1]});
        printUsage();
        std.process.exit(1);
    };

    switch (command) {
        .new => try cmdNew(allocator, args[2..]),
        .module => try cmdModule(allocator, args[2..]),
        .event => try cmdEvent(allocator, args[2..]),
        .api => try cmdApi(allocator, args[2..]),
        .help => printUsage(),
        .version => printVersion(),
    }
}

fn toPascalCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try allocator.alloc(u8, input.len);
    var i: usize = 0;
    var j: usize = 0;
    var capitalize = true;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (c == '-' or c == '_') {
            capitalize = true;
        } else if (capitalize) {
            result[j] = std.ascii.toUpper(c);
            j += 1;
            capitalize = false;
        } else {
            result[j] = c;
            j += 1;
        }
    }
    return try allocator.realloc(result, j);
}

fn toCamelCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try allocator.alloc(u8, input.len);
    var i: usize = 0;
    var j: usize = 0;
    var capitalize = false;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (c == '-' or c == '_') {
            capitalize = true;
        } else if (capitalize) {
            result[j] = std.ascii.toUpper(c);
            j += 1;
            capitalize = false;
        } else {
            result[j] = c;
            j += 1;
        }
    }
    return try allocator.realloc(result, j);
}

fn toSnakeCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try allocator.alloc(u8, input.len);
    var j: usize = 0;
    for (input) |c| {
        if (c == '-') {
            result[j] = '_';
            j += 1;
        } else {
            result[j] = c;
            j += 1;
        }
    }
    return try allocator.realloc(result, j);
}

fn parseCommand(cmd: []const u8) ?Command {
    if (std.mem.eql(u8, cmd, "new")) return .new;
    if (std.mem.eql(u8, cmd, "module")) return .module;
    if (std.mem.eql(u8, cmd, "event")) return .event;
    if (std.mem.eql(u8, cmd, "api")) return .api;
    if (std.mem.eql(u8, cmd, "help")) return .help;
    if (std.mem.eql(u8, cmd, "version")) return .version;
    if (std.mem.eql(u8, cmd, "--help")) return .help;
    if (std.mem.eql(u8, cmd, "--version")) return .version;
    if (std.mem.eql(u8, cmd, "-h")) return .help;
    if (std.mem.eql(u8, cmd, "-v")) return .version;
    return null;
}

fn printUsage() void {
    const usage =
        \\ZigCtl - Code generation tool for ZigModu
        \\
        \\Usage:
        \\  zigctl <command> [options]
        \\
        \\Commands:
        \\  new <name>      Create new ZigModu project
        \\  module <name>   Generate module boilerplate
        \\  event <name>    Generate event handler
        \\  api <name>      Generate API endpoint
        \\  help            Show help
        \\  version         Show version
        \\
        \\Examples:
        \\  zigctl new myapp
        \\  zigctl module user
        \\  zigctl event order-created
        \\  zigctl api users
        \\
    ;
    std.log.info("{s}", .{usage});
}

fn printVersion() void {
    std.log.info("zigctl version 0.1.0", .{});
}

fn cmdNew(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.log.err("Usage: zigctl new <project-name>", .{});
        return;
    }

    const project_name = args[0];
    std.log.info("Creating new project: {s}", .{project_name});

    // Create project directory
    try std.fs.cwd().makePath(project_name);

    // Create subdirectories
    const dirs = [_][]const u8{
        "src",
        "src/modules",
        "src/events",
        "src/api",
        "tests",
    };

    for (dirs) |dir| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ project_name, dir });
        defer allocator.free(full_path);
        try std.fs.cwd().makePath(full_path);
    }

    // Generate build.zig
    const build_zig = try generateBuildZig(allocator, project_name);
    defer allocator.free(build_zig);

    const build_path = try std.fmt.allocPrint(allocator, "{s}/build.zig", .{project_name});
    defer allocator.free(build_path);

    try writeFile(build_path, build_zig);

    // Generate build.zig.zon
    const build_zon = try generateBuildZon(allocator, project_name);
    defer allocator.free(build_zon);

    const zon_path = try std.fmt.allocPrint(allocator, "{s}/build.zig.zon", .{project_name});
    defer allocator.free(zon_path);

    try writeFile(zon_path, build_zon);

    // Generate main.zig
    const main_zig = try generateMainZig(allocator, project_name);
    defer allocator.free(main_zig);

    const main_path = try std.fmt.allocPrint(allocator, "{s}/src/main.zig", .{project_name});
    defer allocator.free(main_path);

    try writeFile(main_path, main_zig);

    std.log.info("Project {s} created successfully!", .{project_name});
    std.log.info("  cd {s} && zig build run", .{project_name});
}

fn cmdModule(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.log.err("Usage: zigctl module <name>", .{});
        return;
    }

    const module_name = args[0];
    std.log.info("Generating module: {s}", .{module_name});

    // Generate module file
    const module_code = try generateModule(allocator, module_name);
    defer allocator.free(module_code);

    const module_path = try std.fmt.allocPrint(allocator, "src/modules/{s}.zig", .{module_name});
    defer allocator.free(module_path);

    try writeFile(module_path, module_code);

    std.log.info("Module {s} created at {s}", .{ module_name, module_path });
}

fn cmdEvent(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.log.err("Usage: zigctl event <name>", .{});
        return;
    }

    const event_name = args[0];
    std.log.info("Generating event: {s}", .{event_name});

    // Generate event file
    const event_code = try generateEvent(allocator, event_name);
    defer allocator.free(event_code);

    const event_path = try std.fmt.allocPrint(allocator, "src/events/{s}.zig", .{event_name});
    defer allocator.free(event_path);

    try writeFile(event_path, event_code);

    std.log.info("Event {s} created at {s}", .{ event_name, event_path });
}

fn cmdApi(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.log.err("Usage: zigctl api <name>", .{});
        return;
    }

    const api_name = args[0];
    std.log.info("Generating API: {s}", .{api_name});

    // Generate API file
    const api_code = try generateApi(allocator, api_name);
    defer allocator.free(api_code);

    const api_path = try std.fmt.allocPrint(allocator, "src/api/{s}.zig", .{api_name});
    defer allocator.free(api_path);

    try writeFile(api_path, api_code);

    std.log.info("API {s} created at {s}", .{ api_name, api_path });
}

// Template generators
fn generateBuildZig(allocator: std.mem.Allocator, project_name: []const u8) ![]const u8 {
    _ = project_name;
    return try allocator.dupe(u8,
        \\const std = @import("std");
        \\
        \\pub fn build(b: *std.Build) void {
        \\    const target = b.standardTargetOptions(.{});
        \\    const optimize = b.standardOptimizeOption(.{});
        \\
        \\    const exe = b.addExecutable(.{
        \\        .name = "app",
        \\        .root_module = b.createModule(.{
        \\            .root_source_file = b.path("src/main.zig"),
        \\            .target = target,
        \\            .optimize = optimize,
        \\        }),
        \\    });
        \\
        \\    b.installArtifact(exe);
        \\
        \\    const run_cmd = b.addRunArtifact(exe);
        \\    run_cmd.step.dependOn(b.getInstallStep());
        \\    if (b.args) |args| {
        \\        run_cmd.addArgs(args);
        \\    }
        \\
        \\    const run_step = b.step("run", "Run the app");
        \\    run_step.dependOn(&run_cmd.step);
        \\
        \\    const unit_tests = b.addTest(.{
        \\        .root_module = b.createModule(.{
        \\            .root_source_file = b.path("src/tests.zig"),
        \\            .target = target,
        \\            .optimize = optimize,
        \\        }),
        \\    });
        \\
        \\    const run_unit_tests = b.addRunArtifact(unit_tests);
        \\    const test_step = b.step("test", "Run unit tests");
        \\    test_step.dependOn(&run_unit_tests.step);
        \\}
        \\
    );
}

fn generateBuildZon(allocator: std.mem.Allocator, project_name: []const u8) ![]const u8 {
    _ = project_name;
    return try allocator.dupe(u8,
        \\.{
        \\    .name = .myapp,
        \\    .version = "0.1.0",
        \\    .fingerprint = 0x0000000000000000,
        \\    .minimum_zig_version = "0.15.2",
        \\    .dependencies = .{
        \\        .zigmodu = .{
        \\            .path = "../zigmodu",
        \\        },
        \\    },
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\    },
        \\}
        \\
    );
}

fn generateMainZig(allocator: std.mem.Allocator, project_name: []const u8) ![]const u8 {
    _ = project_name;
    return try allocator.dupe(u8,
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\    defer _ = gpa.deinit();
        \\    const allocator = gpa.allocator();
        \\
        \\    std.log.info("Application started!", .{});
        \\
        \\    // TODO: Add your modules here
        \\}
        \\
    );
}

fn generateModule(allocator: std.mem.Allocator, module_name: []const u8) ![]const u8 {
    const template =
        \\const std = @import("std");
        \\const zigmodu = @import("zigmodu");
        \\
        \\const Self = @This();
        \\
        \\pub const info = zigmodu.api.Module{{
        \\    .name = "{s}",
        \\    .description = "{s} module",
        \\    .dependencies = &.{{}},
        \\}};
        \\
        \\allocator: std.mem.Allocator,
        \\
        \\pub fn init(allocator: std.mem.Allocator) !Self {{
        \\    std.log.info("{{s}} module initialized", .{{"{s}"}});
        \\    return Self{{ .allocator = allocator }};
        \\}}
        \\
        \\pub fn deinit(self: *Self) void {{
        \\    _ = self;
        \\    std.log.info("{{s}} module cleaned up", .{{"{s}"}});
        \\}}
        \\
    ;
    return try std.fmt.allocPrint(allocator, template, .{ module_name, module_name, module_name, module_name });
}

fn generateEvent(allocator: std.mem.Allocator, event_name: []const u8) ![]const u8 {
    const struct_name = try toPascalCase(allocator, event_name);
    defer allocator.free(struct_name);

    const part1 = "const std = @import(\"std\");\n\npub const ";
    const part2 = "Event = struct {\n    id: u64,\n    timestamp: i64,\n    data: []const u8,\n};\n\npub fn handle";
    const part3 = "(event: ";
    const part4 = "Event) void {\n    std.log.info(\"Handling ";
    const part5 = " event: id=\" ++ \"{}\", .{ event.id });\n    // TODO: Add event handling logic\n}\n";

    return try std.fmt.allocPrint(allocator, "{s}{s}{s}{s}{s}{s}{s}{s}{s}", .{ part1, struct_name, part2, struct_name, part3, struct_name, part4, event_name, part5 });
}

fn generateApi(allocator: std.mem.Allocator, api_name: []const u8) ![]const u8 {
    const struct_name = try toPascalCase(allocator, api_name);
    defer allocator.free(struct_name);
    const method_name = try toPascalCase(allocator, api_name);
    defer allocator.free(method_name);

    const pieces = [_][]const u8{
        "const std = @import(\"std\");\n" ++
            "const zigmodu = @import(\"zigmodu\");\n\n" ++
            "pub const ",
        struct_name,
        "Api = struct {\n" ++
            "    const Self = @This();\n\n" ++
            "    router: *zigmodu.api.Router,\n\n" ++
            "    pub fn init(router: *zigmodu.api.Router) !Self {\n" ++
            "        var self = Self{ .router = router };\n" ++
            "        try self.registerRoutes();\n" ++
            "        return self;\n" ++
            "    }\n\n" ++
            "    fn registerRoutes(self: *Self) !void {\n" ++
            "        try self.router.get(\"/",
        api_name,
        "\", &Self.get",
        method_name,
        ");\n" ++
            "        try self.router.post(\"/",
        api_name,
        "\", &Self.create",
        method_name,
        ");\n" ++
            "        try self.router.put(\"/",
        api_name,
        "/{id}\", &Self.update",
        method_name,
        ");\n" ++
            "        try self.router.delete(\"/",
        api_name,
        "/{id}\", &Self.delete",
        method_name,
        ");\n" ++
            "    }\n\n" ++
            "    fn get",
        method_name,
        "(req: zigmodu.api.Router.Request, res: *zigmodu.api.Router.Response) !void {\n" ++
            "        _ = req;\n" ++
            "        try res.json(.{ .message = \"GET ",
        api_name,
        "\" });\n" ++
            "    }\n\n" ++
            "    fn create",
        method_name,
        "(req: zigmodu.api.Router.Request, res: *zigmodu.api.Router.Response) !void {\n" ++
            "        _ = req;\n" ++
            "        try res.json(.{ .message = \"CREATE ",
        api_name,
        "\", .status = \"success\" });\n" ++
            "    }\n\n" ++
            "    fn update",
        method_name,
        "(req: zigmodu.api.Router.Request, res: *zigmodu.api.Router.Response) !void {\n" ++
            "        _ = req;\n" ++
            "        try res.json(.{ .message = \"UPDATE ",
        api_name,
        "\", .status = \"success\" });\n" ++
            "    }\n\n" ++
            "    fn delete",
        method_name,
        "(req: zigmodu.api.Router.Request, res: *zigmodu.api.Router.Response) !void {\n" ++
            "        _ = req;\n" ++
            "        try res.json(.{ .message = \"DELETE ",
        api_name,
        "\", .status = \"success\" });\n" ++
            "    }\n};\n",
    };

    var total_len: usize = 0;
    for (pieces) |p| total_len += p.len;

    var result = try allocator.alloc(u8, total_len);
    var offset: usize = 0;
    for (pieces) |p| {
        @memcpy(result[offset .. offset + p.len], p);
        offset += p.len;
    }
    return result;
}

fn writeFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}
