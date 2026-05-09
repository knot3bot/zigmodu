/// 业务枚举 — 多租户管理系统
pub const TenantStatus = enum(i32) {
    active = 1,
    suspended = 0,
};

pub const TenantTier = enum {
    free,
    pro,
    enterprise,

    pub fn fromString(s: []const u8) TenantTier {
        if (std.mem.eql(u8, s, "pro")) return .pro;
        if (std.mem.eql(u8, s, "enterprise")) return .enterprise;
        return .free;
    }

    pub fn toString(self: TenantTier) []const u8 {
        return switch (self) {
            .free => "free",
            .pro => "pro",
            .enterprise => "enterprise",
        };
    }
};

pub const UserRole = enum {
    admin,
    manager,
    member,

    pub fn fromString(s: []const u8) UserRole {
        if (std.mem.eql(u8, s, "admin")) return .admin;
        if (std.mem.eql(u8, s, "manager")) return .manager;
        return .member;
    }

    pub fn toString(self: UserRole) []const u8 {
        return switch (self) {
            .admin => "admin",
            .manager => "manager",
            .member => "member",
        };
    }
};

pub const SubscriptionStatus = enum {
    active,
    cancelled,
    expired,

    pub fn fromString(s: []const u8) SubscriptionStatus {
        if (std.mem.eql(u8, s, "cancelled")) return .cancelled;
        if (std.mem.eql(u8, s, "expired")) return .expired;
        return .active;
    }

    pub fn toString(self: SubscriptionStatus) []const u8 {
        return switch (self) {
            .active => "active",
            .cancelled => "cancelled",
            .expired => "expired",
        };
    }
};

const std = @import("std");
