const std = @import("std");
const ModuleInfo = @import("Module.zig").ModuleInfo;

/// 模块交互验证器
/// 验证模块之间只通过允许的通道通信，防止架构腐化
/// 对标 Spring Modulith 的 `verify()` + ArchUnit
pub const ModuleInteractionVerifier = struct {
    const Self = @This();

    /// 模块间交互类型
    pub const InteractionType = enum {
        /// 直接依赖 (import / function call)
        direct_dependency,
        /// 事件驱动 (EventBus)
        event_driven,
        /// 共享数据 (同表/同缓存)
        shared_data,
        /// API 调用 (HTTP/gRPC)
        api_call,
    };

    /// 单个模块交互规则
    pub const InteractionRule = struct {
        /// 允许的交互类型
        allowed_types: []const InteractionType,
        /// 来源模块 (空 = 所有模块)
        from_module: ?[]const u8 = null,
        /// 目标模块 (空 = 所有模块)
        to_module: ?[]const u8 = null,
        /// 规则描述
        description: []const u8 = "",
    };

    /// 模块交互模型 (定义哪些模块如何通信)
    pub const InteractionModel = struct {
        module_name: []const u8,
        /// 允许的传出交互
        allowed_outgoing: std.StringHashMap([]const InteractionType),
        /// 允许的传入交互
        allowed_incoming: std.StringHashMap([]const InteractionType),
    };

    /// 验证违规
    pub const Violation = struct {
        from_module: []const u8,
        to_module: []const u8,
        interaction_type: InteractionType,
        message: []const u8,
    };

    /// 验证配置
    pub const Config = struct {
        /// 是否允许循环依赖
        allow_circular_deps: bool = false,
        /// 最大依赖深度
        max_dependency_depth: usize = 5,
        /// 每个模块的最大依赖数
        max_dependencies_per_module: usize = 10,
        /// 是否严格要求通过事件通信
        enforce_event_driven: bool = false,
    };

    allocator: std.mem.Allocator,
    config: Config,
    rules: std.ArrayList(InteractionRule),
    violations: std.ArrayList(Violation),

    pub fn init(allocator: std.mem.Allocator, config: Config) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .rules = std.ArrayList(InteractionRule).empty,
            .violations = std.ArrayList(Violation).empty,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.rules.items) |rule| {
            self.allocator.free(rule.allowed_types);
            self.allocator.free(rule.description);
        }
        self.rules.deinit(self.allocator);

        for (self.violations.items) |v| {
            self.allocator.free(v.from_module);
            self.allocator.free(v.to_module);
            self.allocator.free(v.message);
        }
        self.violations.deinit(self.allocator);
    }

    /// 注册交互规则
    pub fn addRule(self: *Self, allowed_types: []const InteractionType, description: []const u8) !void {
        const types_copy = try self.allocator.dupe(InteractionType, allowed_types);
        errdefer self.allocator.free(types_copy);

        const desc_copy = try self.allocator.dupe(u8, description);
        errdefer self.allocator.free(desc_copy);

        try self.rules.append(self.allocator, .{
            .allowed_types = types_copy,
            .description = desc_copy,
        });
    }

    /// 注册模块间特定交互规则
    pub fn addModuleRule(
        self: *Self,
        from_module: []const u8,
        to_module: []const u8,
        allowed_types: []const InteractionType,
        description: []const u8,
    ) !void {
        const types_copy = try self.allocator.dupe(InteractionType, allowed_types);
        errdefer self.allocator.free(types_copy);

        const desc_copy = try self.allocator.dupe(u8, description);
        errdefer self.allocator.free(desc_copy);

        try self.rules.append(self.allocator, .{
            .allowed_types = types_copy,
            .from_module = try self.allocator.dupe(u8, from_module),
            .to_module = try self.allocator.dupe(u8, to_module),
            .description = desc_copy,
        });
    }

    /// 验证单个模块的依赖是否合规
    /// 返回违规列表
    pub fn verifyModuleDependencies(
        self: *Self,
        comptime module_info: ModuleInfo,
        comptime all_modules: []const type,
    ) ![]Violation {
        var result = std.ArrayList(Violation).empty;

        // 1. 检查依赖深度
        if (module_info.dependencies.len > self.config.max_dependencies_per_module) {
            const msg = try std.fmt.allocPrint(self.allocator,
                "Module '{s}' has {d} dependencies, exceeding max of {d}",
                .{ module_info.name, module_info.dependencies.len, self.config.max_dependencies_per_module },
            );
            try result.append(self.allocator, .{
                .from_module = try self.allocator.dupe(u8, module_info.name),
                .to_module = try self.allocator.dupe(u8, "*"),
                .interaction_type = .direct_dependency,
                .message = msg,
            });
        }

        // 2. 检查循环依赖
        if (!self.config.allow_circular_deps) {
            for (module_info.dependencies) |dep_name| {
                inline for (all_modules) |mod| {
                    const mod_info = @field(mod, "info");
                    if (std.mem.eql(u8, mod_info.name, dep_name)) {
                        for (mod_info.dependencies) |transitive_dep| {
                            if (std.mem.eql(u8, transitive_dep, module_info.name)) {
                                const msg = try std.fmt.allocPrint(self.allocator,
                                    "Circular dependency: '{s}' ↔ '{s}'",
                                    .{ module_info.name, dep_name },
                                );
                                try result.append(self.allocator, .{
                                    .from_module = try self.allocator.dupe(u8, module_info.name),
                                    .to_module = try self.allocator.dupe(u8, dep_name),
                                    .interaction_type = .direct_dependency,
                                    .message = msg,
                                });
                                break;
                            }
                        }
                        break;
                    }
                }
            }
        }

        // 3. 检查是否有自依赖
        for (module_info.dependencies) |dep_name| {
            if (std.mem.eql(u8, dep_name, module_info.name)) {
                const msg = try std.fmt.allocPrint(self.allocator,
                    "Module '{s}' declares self-dependency",
                    .{module_info.name},
                );
                try result.append(self.allocator, .{
                    .from_module = try self.allocator.dupe(u8, module_info.name),
                    .to_module = try self.allocator.dupe(u8, module_info.name),
                    .interaction_type = .direct_dependency,
                    .message = msg,
                });
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// 验证所有模块的依赖拓扑
    pub fn verifyAllModules(
        self: *Self,
        comptime modules: anytype,
    ) ![]Violation {
        var result = std.ArrayList(Violation).empty;

        inline for (modules) |mod| {
            const info = @field(mod, "info");
            const mod_violations = try self.verifyModuleDependencies(
                info,
                modules,
            );
            defer self.allocator.free(mod_violations);

            for (mod_violations) |v| {
                try result.append(self.allocator, v);
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// 添加违规记录
    pub fn addViolation(
        self: *Self,
        from_module: []const u8,
        to_module: []const u8,
        interaction_type: InteractionType,
        message: []const u8,
    ) !void {
        try self.violations.append(self.allocator, .{
            .from_module = try self.allocator.dupe(u8, from_module),
            .to_module = try self.allocator.dupe(u8, to_module),
            .interaction_type = interaction_type,
            .message = try self.allocator.dupe(u8, message),
        });
    }

    /// 获取所有违规
    pub fn getViolations(self: *Self) []const Violation {
        return self.violations.items;
    }

    /// 是否有违规
    pub fn hasViolations(self: *Self) bool {
        return self.violations.items.len > 0;
    }

    /// 生成可读的违规报告
    pub fn generateReport(self: *Self) ![]const u8 {
        if (self.violations.items.len == 0) {
            return try self.allocator.dupe(u8, "✓ No architecture violations detected.\n");
        }

        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(self.allocator);

        try buf.appendSlice(self.allocator, "╔══════════════════════════════════════════╗\n");
        try buf.appendSlice(self.allocator, "║  Architecture Violations Report          ║\n");
        try buf.appendSlice(self.allocator, "╚══════════════════════════════════════════╝\n\n");

        for (self.violations.items, 0..) |v, i| {
            const line = try std.fmt.allocPrint(self.allocator,
                "[{d}] {s} → {s} ({s}): {s}\n",
                .{ i + 1, v.from_module, v.to_module, @tagName(v.interaction_type), v.message },
            );
            defer self.allocator.free(line);
            try buf.appendSlice(self.allocator, line);
        }

        const summary = try std.fmt.allocPrint(self.allocator,
            "\nTotal violations: {d}\n",
            .{self.violations.items.len},
        );
        defer self.allocator.free(summary);
        try buf.appendSlice(self.allocator, summary);

        return buf.toOwnedSlice(self.allocator);
    }
};

// ─────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────

test "ModuleInteractionVerifier init and add rule" {
    const allocator = std.testing.allocator;
    var verifier = ModuleInteractionVerifier.init(allocator, .{});
    defer verifier.deinit();

    try verifier.addRule(&.{ .direct_dependency, .event_driven }, "default interaction");
    try std.testing.expectEqual(@as(usize, 1), verifier.rules.items.len);
}

test "ModuleInteractionVerifier add violation" {
    const allocator = std.testing.allocator;
    var verifier = ModuleInteractionVerifier.init(allocator, .{});
    defer verifier.deinit();

    try verifier.addViolation("order", "inventory", .direct_dependency, "direct dep without event");
    try std.testing.expect(verifier.hasViolations());
    try std.testing.expectEqual(@as(usize, 1), verifier.getViolations().len);
}

test "ModuleInteractionVerifier generate report with violations" {
    const allocator = std.testing.allocator;
    var verifier = ModuleInteractionVerifier.init(allocator, .{});
    defer verifier.deinit();

    try verifier.addViolation("order", "inventory", .direct_dependency, "Forbidden direct access");

    const report = try verifier.generateReport();
    defer allocator.free(report);

    try std.testing.expect(std.mem.containsAtLeast(u8, report, 1, "order"));
    try std.testing.expect(std.mem.containsAtLeast(u8, report, 1, "inventory"));
    try std.testing.expect(std.mem.containsAtLeast(u8, report, 1, "Violations"));
}

test "ModuleInteractionVerifier generate report clean" {
    const allocator = std.testing.allocator;
    var verifier = ModuleInteractionVerifier.init(allocator, .{});
    defer verifier.deinit();

    const report = try verifier.generateReport();
    defer allocator.free(report);

    try std.testing.expect(std.mem.containsAtLeast(u8, report, 1, "No architecture violations"));
}

test "ModuleInteractionVerifier module rule" {
    const allocator = std.testing.allocator;
    var verifier = ModuleInteractionVerifier.init(allocator, .{});
    defer verifier.deinit();

    try verifier.addModuleRule("order", "payment", &.{ .event_driven, .api_call }, "order→payment");

    try std.testing.expectEqual(@as(usize, 1), verifier.rules.items.len);
    try std.testing.expectEqualStrings("order", verifier.rules.items[0].from_module.?);
    try std.testing.expectEqualStrings("payment", verifier.rules.items[0].to_module.?);
}

test "ModuleInteractionVerifier config constraints" {
    const allocator = std.testing.allocator;
    var verifier = ModuleInteractionVerifier.init(allocator, .{
        .max_dependencies_per_module = 3,
        .max_dependency_depth = 3,
    });
    defer verifier.deinit();

    try std.testing.expectEqual(@as(usize, 3), verifier.config.max_dependencies_per_module);
    try std.testing.expectEqual(@as(usize, 3), verifier.config.max_dependency_depth);
}
