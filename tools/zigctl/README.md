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
├── model.zig        # Domain models mapped from SQL columns
├── persistence.zig  # ORM Repository layer (SqlxBackend)
├── service.zig      # Business service with CRUD methods
└── api.zig          # HTTP API handlers using api.Server.zig
```

#### Generated Architecture

- **model.zig** — Structs mapped from `CREATE TABLE` definitions.
- **persistence.zig** — `{Module}Persistence` struct that holds `SqlxBackend` and provides repository accessors.
- **service.zig** — `{Module}Service` struct that injects persistence and exposes `list*`, `get*`, `create*`, `update*`, `delete*` methods.
- **api.zig** — `{Module}Api` struct that injects the service into `Server.RouteGroup` handlers via `ctx.user_data`. Registers RESTful routes:
  - `GET    /{table}s`      → list
  - `GET    /{table}s/:id`  → get by id
  - `POST   /{table}s`      → create
  - `PUT    /{table}s/:id`  → update
  - `DELETE /{table}s/:id`  → delete
- **module.zig** — ZigModu module definition with `info`, `init()`, and `deinit()`.

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
    id BIGINT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL
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
│   ├── model.zig
│   ├── persistence.zig
│   ├── service.zig
│   └── api.zig
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
