-- Multi-Tenant Management System — Database Schema
-- ZigModu v0.8.0 Best Practice Demo

CREATE TABLE IF NOT EXISTS tenants (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(255) NOT NULL,
    domain      VARCHAR(255) NOT NULL UNIQUE,
    status      TINYINT NOT NULL DEFAULT 1,  -- 1=active, 0=suspended
    tier        VARCHAR(20) NOT NULL DEFAULT 'free',  -- free, pro, enterprise
    created_at  BIGINT NOT NULL,
    updated_at  BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    tenant_id     BIGINT NOT NULL,
    username      VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'member',  -- admin, manager, member
    status        TINYINT NOT NULL DEFAULT 1,
    created_at    BIGINT NOT NULL,
    updated_at    BIGINT NOT NULL,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id),
    UNIQUE KEY uk_tenant_email (tenant_id, email)
);

CREATE TABLE IF NOT EXISTS plans (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    max_users   INT NOT NULL DEFAULT 5,
    max_storage BIGINT NOT NULL DEFAULT 1073741824,  -- 1GB
    price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    features    JSON,
    created_at  BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    tenant_id   BIGINT NOT NULL,
    plan_id     BIGINT NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'active',  -- active, cancelled, expired
    started_at  BIGINT NOT NULL,
    expires_at  BIGINT NOT NULL,
    created_at  BIGINT NOT NULL,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id),
    FOREIGN KEY (plan_id) REFERENCES plans(id)
);

-- Seed plans
INSERT INTO plans (id, name, max_users, max_storage, price, created_at) VALUES
    (1, 'Free', 5, 1073741824, 0.00, 0),
    (2, 'Pro', 50, 10737418240, 29.99, 0),
    (3, 'Enterprise', 500, 107374182400, 199.99, 0);

-- Seed demo tenants
INSERT INTO tenants (id, name, domain, status, tier, created_at, updated_at) VALUES
    (1, 'Acme Corp', 'acme.example.com', 1, 'enterprise', 0, 0),
    (2, 'Startup.io', 'startup.example.com', 1, 'pro', 0, 0);

-- Seed demo users
INSERT INTO users (id, tenant_id, username, email, password_hash, role, status, created_at, updated_at) VALUES
    (1, 1, 'admin', 'admin@acme.example.com', '$2a$10$hash', 'admin', 1, 0, 0),
    (2, 1, 'alice', 'alice@acme.example.com', '$2a$10$hash', 'manager', 1, 0, 0),
    (3, 2, 'bob', 'bob@startup.example.com', '$2a$10$hash', 'admin', 1, 0, 0);

-- Seed subscriptions
INSERT INTO subscriptions (id, tenant_id, plan_id, status, started_at, expires_at, created_at) VALUES
    (1, 1, 3, 'active', 0, 1893456000, 0),
    (2, 2, 2, 'active', 0, 1893456000, 0);
