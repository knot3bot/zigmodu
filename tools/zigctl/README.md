# ZigCtl

Code generation tool for ZigModu framework.

## Installation

```bash
cd tools/zigctl
zig build install-zigctl
```

Or run directly:
```bash
cd tools/zigctl
zig build run -- <command>
```

## Commands

### `new <name>`
Create a new ZigModu project.

```bash
zigctl new myapp
cd myapp
zig build run
```

### `module <name>`
Generate a module boilerplate.

```bash
zigctl module user
```

Creates `src/modules/user.zig` with module metadata and lifecycle hooks.

### `event <name>`
Generate an event handler.

```bash
zigctl event order-created
```

Creates `src/events/order-created.zig` with event struct and handler function.

### `api <name>`
Generate an API endpoint with CRUD routes.

```bash
zigctl api users
```

Creates `src/api/users.zig` with GET/POST/PUT/DELETE handlers.

### `orm`
Generate ORM models, repositories, services, and API handlers from SQL DDL. The output follows the **Spring Modulith** package-by-module pattern.

```bash
# Auto-partition by table prefix (user_profile → user module)
zigctl orm --sql schema.sql --out src/modules

# Force all tables into a single module
zigctl orm --sql schema.sql --module user --out src/modules
```

Creates a complete module directory for each inferred module:

```
src/modules/{module}/
├── module.zig       # ZigModu module metadata (init/deinit)
├── model.zig        # Domain models with JSON serialization
├── persistence.zig  # ORM Repository layer (SqlxBackend)
├── service.zig      # Business service with paginated CRUD
└── api.zig          # HTTP API handlers using api.Server.zig
```

#### Generated Architecture

- **model.zig** — Structs mapped from `CREATE TABLE` definitions with:
  - `jsonStringify()` method using original SQL field names for API stability
  - Support for SQL COMMENT extraction (stored for documentation)
- **persistence.zig** — `{Module}Persistence` struct that holds `SqlxBackend` and provides repository accessors
- **service.zig** — `{Module}Service` struct that injects persistence and exposes:
  - `list*{s}(page, size)` — Paginated list returning `PageResult(T)`
  - `get*{s}(id)` — Get by ID
  - `create*{s}(entity)` — Create
  - `update*{s}(entity)` — Update
  - `delete*{s}(id)` — Delete
- **api.zig** — `{Module}Api` struct that injects the service into `Server.RouteGroup` handlers via `ctx.user_data`. Registers RESTful routes:
  - `GET    /{table}s?page=0&size=10`  → paginated list
  - `GET    /{table}s/:id`  → get by id
  - `POST   /{table}s`      → create
  - `PUT    /{table}s/:id`  → update
  - `DELETE /{table}s/:id`  → delete
- **module.zig** — ZigModu module definition with `info`, `init()`, and `deinit()`.

#### Pagination

List endpoints support pagination via query parameters:
- `page` — Page number starting from 0 (default: 0)
- `size` — Items per page (default: 10)

Response format:
```json
{
  "items": [...],
  "page": 0,
  "size": 10,
  "total": 100
}
```

#### JSON Field Names

Generated models use `jsonStringify()` to ensure API stability:
- JSON field names match original SQL column names (e.g., `user_name` not `userName`)
- This prevents breaking API clients when refactoring database schema

## Examples

```bash
# Create new project
zigctl new ecommerce-app
cd ecommerce-app

# Generate modules
zigctl module user
zigctl module order
zigctl module payment

# Generate events
zigctl event order-placed
zigctl event payment-completed

# Generate APIs
zigctl api users
zigctl api orders

# Generate ORM from schema
zigctl orm --sql schema.sql --out src/modules
```

### Example SQL Schema

```sql
CREATE TABLE user_profile (
    id BIGINT PRIMARY KEY COMMENT 'ID',
    user_name VARCHAR(255) NOT NULL COMMENT '用户名',
    email VARCHAR(255) NOT NULL COMMENT '邮箱',
    created_at TIMESTAMP COMMENT '创建时间'
);

CREATE TABLE order_item (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    total DECIMAL(10,2) NOT NULL
);
```

Running `zigctl orm --sql schema.sql --out src/modules` will produce:

```
src/modules/
├── user/
│   ├── module.zig
│   ├── model.zig          # UserProfile/UserAddress with jsonStringify
│   ├── persistence.zig
│   ├── service.zig        # Paginated CRUD methods
│   └── api.zig            # /user_profiles?page=0&size=10
└── order/
    ├── module.zig
    ├── model.zig
    ├── persistence.zig
    ├── service.zig
    └── api.zig
```

## SQL to Zig type mapping

| SQL type | Zig type |
|---|---|
| INT, INTEGER, BIGINT, SMALLINT, TINYINT, SERIAL | `i64` |
| VARCHAR, TEXT, CHAR, NVARCHAR, JSON, JSONB, UUID | `[]const u8` |
| BOOLEAN, BOOL | `bool` |
| FLOAT, DOUBLE, REAL, NUMERIC, DECIMAL | `f64` |
| DATETIME, TIMESTAMP, DATE, TIME | `[]const u8` |

## Features

- ✅ PascalCase/camelCase/snake_case sanitization
- ✅ Zig 0.15.2 compatible
- ✅ No external dependencies
- ✅ Fast code generation
- ✅ Spring Modulith package-by-module structure
- ✅ Service + API scaffolding with DI via `ctx.user_data`
- ✅ Pagination support with PageResult
- ✅ Stable JSON field names via jsonStringify
