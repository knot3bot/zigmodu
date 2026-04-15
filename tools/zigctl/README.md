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
```

## Features

- ✅ PascalCase/camelCase/snake_case sanitization
- ✅ Zig 0.15.2 compatible
- ✅ No external dependencies
- ✅ Fast code generation