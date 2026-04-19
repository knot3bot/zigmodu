# ZigModu 安全评估报告

**项目**: ZigModu (Zig 模块化应用框架)  
**版本**: 0.6.0  
**审计日期**: 2025-04-19  
**审计范围**: 完整代码库 (src/ 目录下 87 个 Zig 源文件)  
**审计模式**: 静态代码分析 + 配置审查  

---

## 执行摘要

| 风险等级 | 数量 | 状态 |
|---------|------|------|
| **严重 (CRITICAL)** | 1 | 需立即修复 |
| **高 (HIGH)** | 1 | 需尽快修复 |
| **中 (MEDIUM)** | 5 | 建议修复 |
| **低 (LOW)** | 3 | 可选修复 |
| **信息 (INFO)** | 2 | 参考 |

**总体安全评分**: 6.2 / 10

---

## 严重风险 (CRITICAL)

### 1. SQL 注入漏洞 [CWE-89]

**位置**: `src/sqlx/sqlx.zig:647-671` (formatQuery 函数)

**描述**: MySQL 连接的查询构建函数 `formatQuery` 对字符串参数没有进行转义处理，直接将用户输入拼接到 SQL 语句中。

**漏洞代码**:
```zig
.string => |v| {
    try buf.append(allocator, '\'');
    try buf.appendSlice(allocator, v);  // 直接拼接，未转义
    try buf.append(allocator, '\'');
},
```

**影响**: 
- 攻击者可通过构造恶意输入执行任意 SQL 命令
- 可导致数据泄露、篡改或删除
- 可绕过身份验证

**修复建议**:
```zig
.string => |v| {
    try buf.appendSlice(allocator, "'");
    // 对单引号进行转义
    for (v) |char| {
        if (char == '\'') try buf.appendSlice(allocator, "''");
        else try buf.append(allocator, char);
    }
    try buf.appendSlice(allocator, "'");
},
```

**优先级**: 立即修复

---

## 高风险 (HIGH)

### 2. JWT 时间戳固定 [CWE-674]

**位置**: `src/security/SecurityModule.zig:60, 69-70, 169`

**描述**: JWT token 的 `iat` (签发时间) 和 `exp` (过期时间) 基于固定值 `now = 0` 计算，而非实际系统时间。

**漏洞代码**:
```zig
const now = 0;  // 固定时间戳
const exp = now + self.token_expiry_seconds;
```

**影响**:
- 所有 token 同时过期
- 无法验证 token 的发行时间
- 重放攻击风险
- 无法实施 token 刷新策略

**修复建议**:
```zig
const now = std.time.timestamp();  // 使用实际时间戳
const exp = now + self.token_expiry_seconds;
```

**优先级**: 尽快修复

---

## 中风险 (MEDIUM)

### 3. 密码哈希使用固定 Salt [CWE-760]

**位置**: `src/security/SecurityModule.zig:181`

**描述**: PBKDF2 密码哈希使用固定种子 `0x12345678` 生成 salt，导致所有用户的 salt 可预测。

**漏洞代码**:
```zig
var prng = std.Random.DefaultPrng.init(0x12345678);  // 固定种子
prng.random().bytes(&salt);
```

**影响**:
- 相同密码的用户产生相同的 hash
- 大幅降低彩虹表攻击成本
- 违反密码学最佳实践

**修复建议**:
```zig
var seed: [8]u8 = undefined;
try std.crypto.random.bytes(&seed);
var prng = std.Random.DefaultPrng.init(std.mem.readInt(u64, &seed, .little));
prng.random().bytes(&salt);
```

**优先级**: 建议修复

### 4. 缺少安全响应头

**位置**: `src/api/Server.zig`, `src/api/Middleware.zig`

**描述**: HTTP 响应缺少基本安全头：
- X-Frame-Options (点击劫持防护)
- X-Content-Type-Options (MIME 嗅探防护)
- X-XSS-Protection (XSS 防护)
- Content-Security-Policy (CSP)
- Strict-Transport-Security (HSTS)

**影响**:
- 增加 XSS、点击劫持等客户端攻击风险

**修复建议**: 在响应中添加安全头：
```zig
try ctx.setHeader("X-Frame-Options", "DENY");
try ctx.setHeader("X-Content-Type-Options", "nosniff");
try ctx.setHeader("X-XSS-Protection", "1; mode=block");
```

**优先级**: 建议修复

### 5. CORS 配置允许通配符

**位置**: `src/api/Middleware.zig:24`

**描述**: CORS 中间件默认允许 `*` 通配符来源，可能导致敏感信息泄露。

**影响**:
- 任何网站都可跨域访问 API
- 可能泄露认证信息

**修复建议**: 验证来源白名单，拒绝未授权来源。

**优先级**: 建议修复

### 6. WebSocket 缺少 Origin 验证

**位置**: `src/core/WebSocket.zig`

**描述**: WebSocket 握手不验证 `Origin` 头，允许任意网站建立 WebSocket 连接。

**影响**:
- CSWSH (Cross-Site WebSocket Hijacking) 攻击
- 攻击者可通过恶意网站建立 WebSocket 连接

**修复建议**: 在握手时验证 `Origin` 头。

**优先级**: 建议修复

### 7. 信息泄露风险

**位置**: 多处 `std.log.err` 调用

**描述**: 错误日志可能泄露内部实现细节（如文件路径、数据库错误等）。

**影响**:
- 帮助攻击者了解系统架构
- 可能泄露敏感路径信息

**修复建议**: 区分内部错误日志和对外错误消息。

**优先级**: 建议修复

---

## 低风险 (LOW)

### 8. GitHub Actions 未固定 SHA

**位置**: `.github/workflows/ci.yml`

**描述**: 使用版本标签而非 SHA 固定第三方 action：
- `actions/checkout@v4`
- `goto-bus-stop/setup-zig@v2`
- `actions/cache@v3`

**影响**:
- 供应链攻击风险（action 被篡改）

**修复建议**: 使用 SHA 固定：
```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4
```

**优先级**: 可选修复

### 9. .env 文件未在 .gitignore 中

**描述**: `.env` 文件未被 `.gitignore` 排除，可能意外提交敏感配置。

**修复建议**: 添加 `.env*` 到 `.gitignore`。

**优先级**: 可选修复

### 10. CI 使用旧版本 Zig

**位置**: `.github/workflows/ci.yml:9`

**描述**: CI 配置使用 Zig 0.15.2，但项目要求 0.16.0。

**影响**:
- 构建不一致
- 可能使用有已知漏洞的编译器版本

**修复建议**: 更新 `ZIG_VERSION` 为 `0.16.0`。

**优先级**: 可选修复

---

## 信息 (INFO)

### 11. 零外部依赖

**描述**: `build.zig.zon` 中 `dependencies` 为空，供应链攻击面极小。

**评价**: 正面 - 降低依赖风险

### 12. 使用 PBKDF2 而非 bcrypt/argon2

**描述**: 密码哈希使用 PBKDF2-HMAC-SHA256 (10,000 迭代)。

**评价**: 建议使用 Argon2id 或 bcrypt 替代 PBKDF2

---

## OWASP Top 10 评估

| 类别 | 状态 | 说明 |
|------|------|------|
| A01: 访问控制失效 | 中 | 无 RBAC 实现，依赖 JWT 签名验证 |
| A02: 加密失败 | 高 | 固定 salt，弱时间戳 |
| A03: 注入 | 严重 | MySQL SQL 注入 |
| A04: 不安全设计 | 中 | 缺少安全头，无速率限制 |
| A05: 安全配置错误 | 中 | CORS 通配符，缺少安全头 |
| A06: 漏洞组件 | 低 | 零外部依赖 |
| A07: 身份验证失效 | 高 | JWT 时间戳问题 |
| A08: 完整性失效 | 低 | 无反序列化风险 |
| A09: 日志监控不足 | 中 | 错误日志可能泄露信息 |
| A10: SSRF | 低 | 无用户控制 URL 请求 |

---

## 修复优先级建议

### 立即修复 (本周内)
1. 修复 SQL 注入漏洞 (formatQuery 函数转义)
2. 修复 JWT 时间戳 (使用 std.time.timestamp())

### 尽快修复 (本月内)
3. 修复密码哈希 salt 生成 (使用随机种子)
4. 添加安全响应头
5. 修复 CORS 配置

### 计划修复 (下个版本)
6. 添加 WebSocket Origin 验证
7. 区分内部/外部错误信息
8. 固定 GitHub Actions SHA
9. 更新 CI Zig 版本
10. 添加 .env 到 .gitignore

---

## 附录: 检查清单

- [x] 密钥考古学 (无硬编码密钥)
- [x] SQL 注入检查 (发现漏洞)
- [x] XSS 防护检查 (缺少 CSP)
- [x] CSRF 防护检查 (无相关实现)
- [x] 访问控制检查 (基础 JWT 实现)
- [x] 加密实现检查 (发现问题)
- [x] 依赖供应链检查 (零依赖)
- [x] CI/CD 安全检查 (发现配置问题)
- [x] 信息泄露检查 (发现日志问题)
- [x] 内存安全检查 (无明显漏洞)

---

*报告生成时间: 2025-04-19*  
*审计工具: 静态代码分析 + 手动审查*
