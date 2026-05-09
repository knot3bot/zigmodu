pub const Plan = struct {
    id: i64,
    name: []const u8,
    max_users: i32,
    max_storage: i64,
    price: f64,
    created_at: i64,
    pub const sql_table_name = "plans";
};

pub const Subscription = struct {
    id: i64,
    tenant_id: i64,
    plan_id: i64,
    status: []const u8,
    started_at: i64,
    expires_at: i64,
    created_at: i64,
    pub const sql_table_name = "subscriptions";
};
