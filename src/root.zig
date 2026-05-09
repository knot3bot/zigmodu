const std = @import("std");

// ============================================
// PRIMARY API - For most users
// ============================================

// Application (Primary entry point)
pub const Application = @import("Application.zig").Application;
pub const ApplicationBuilder = @import("Application.zig").ApplicationBuilder;
pub const builder = @import("Application.zig").builder;

// Module Definition
pub const api = @import("api/Module.zig");

// HTTP Server
pub const http_server = @import("api/Server.zig");
pub const RouteInfo = @import("api/Server.zig").RouteInfo;
pub const http_middleware = @import("api/Middleware.zig");
pub const tracing_middleware = @import("api/middleware/Tracing.zig");

// Error Handling
pub const ZigModuError = @import("core/Error.zig").ZigModuError;
pub const ErrorContext = @import("core/Error.zig").ErrorContext;
pub const ErrorHandler = @import("core/Error.zig").ErrorHandler;
pub const Result = @import("core/Error.zig").Result;

// Event System
pub const Event = @import("core/Event.zig").Event;
pub const EventBus = @import("core/EventBus.zig").EventBus;
pub const TypedEventBus = @import("core/EventBus.zig").TypedEventBus;

// Dependency Injection
pub const Container = @import("di/Container.zig").Container;

// Logging
pub const StructuredLogger = @import("log/StructuredLogger.zig").StructuredLogger;
pub const LogLevel = @import("log/StructuredLogger.zig").LogLevel;

// Configuration
pub const ExternalizedConfig = @import("config/ExternalizedConfig.zig").ExternalizedConfig;

// ============================================
// ADVANCED API - For power users
// ============================================

// Core Utilities (Time)
pub const time = @import("core/Time.zig");

// Core modules - Low-level access
pub const ModuleInfo = @import("core/Module.zig").ModuleInfo;
pub const ApplicationModules = @import("core/Module.zig").ApplicationModules;
pub const scanModules = @import("core/ModuleScanner.zig").scanModules;
pub const validateModules = @import("core/ModuleValidator.zig").validateModules;
pub const startAll = @import("core/Lifecycle.zig").startAll;
pub const stopAll = @import("core/Lifecycle.zig").stopAll;
pub const generateDocs = @import("core/Documentation.zig").generateDocs;
pub const Documentation = @import("core/Documentation.zig");

// Module Contracts
pub const ModuleContract = @import("core/ModuleContract.zig").ModuleContract;
pub const ContractRegistry = @import("core/ModuleContract.zig").ContractRegistry;

// Resilience Patterns
pub const CircuitBreaker = @import("resilience/CircuitBreaker.zig").CircuitBreaker;
pub const RateLimiter = @import("resilience/RateLimiter.zig").RateLimiter;

// Metrics
pub const PrometheusMetrics = @import("metrics/PrometheusMetrics.zig").PrometheusMetrics;

// Testing
pub const IntegrationTest = @import("test/IntegrationTest.zig").IntegrationTest;
pub const Benchmark = @import("test/Benchmark.zig").Benchmark;
pub const TestDataGenerator = @import("test/IntegrationTest.zig").TestDataGenerator;
pub const BenchmarkSuite = @import("test/Benchmark.zig").BenchmarkSuite;

// Tenant
pub const TenantContext = @import("tenant/TenantContext.zig").TenantContext;
pub const TenantInterceptor = @import("tenant/TenantInterceptor.zig").TenantInterceptor;
pub const DataPermissionContext = @import("datapermission/DataPermission.zig").DataPermissionContext;
pub const DataPermissionFilter = @import("datapermission/DataPermission.zig").DataPermissionFilter;
pub const Rbac = @import("security/Rbac.zig");
pub const PasswordEncoder = @import("security/PasswordEncoder.zig").PasswordEncoder;
// Messaging
pub const OutboxPublisher = @import("messaging/OutboxPublisher.zig").OutboxPublisher;
pub const OutboxPoller = @import("messaging/OutboxPublisher.zig").OutboxPoller;
pub const OutboxEntry = @import("messaging/OutboxPublisher.zig").OutboxEntry;
pub const OutboxConfig = @import("messaging/OutboxPublisher.zig").OutboxConfig;

// Sharding
pub const ShardRouter = @import("tenant/ShardRouter.zig").ShardRouter;
pub const ShardPool = @import("tenant/ShardRouter.zig").ShardPool;
pub const ShardConfig = @import("tenant/ShardRouter.zig").ShardConfig;
pub const datapermission = @import("datapermission/DataPermission.zig");
pub const auth = @import("security/AuthMiddleware.zig");
pub const SecurityScanner = @import("security/SecurityScanner.zig").SecurityScanner;
pub const DependencyScanner = @import("security/SecurityScanner.zig").DependencyScanner;
pub const SecurityConfigValidator = @import("security/SecurityScanner.zig").SecurityConfigValidator;

// Validation
pub const Validator = @import("validation/ObjectValidator.zig").Validator;

// Scheduler
pub const ScheduledTask = @import("scheduler/ScheduledTask.zig").ScheduledTask;

// HTTP Client
pub const HttpClient = @import("http/HttpClient.zig").HttpClient;

// Auto Instrumentation
pub const AutoInstrumentation = @import("metrics/AutoInstrumentation.zig").AutoInstrumentation;
pub const InstrumentedLifecycleListener = @import("metrics/AutoInstrumentation.zig").InstrumentedLifecycleListener;
pub const InstrumentedEventListener = @import("metrics/AutoInstrumentation.zig").InstrumentedEventListener;

// Log Rotation
pub const LogRotator = @import("log/StructuredLogger.zig").LogRotator;

// Distributed Event Bus
pub const DistributedEventBus = @import("core/DistributedEventBus.zig").DistributedEventBus;
pub const ClusterConfig = @import("core/DistributedEventBus.zig").ClusterConfig;

// Web Monitor
pub const WebMonitor = @import("core/WebMonitor.zig").WebMonitor;

// WebSocket
pub const WebSocketServer = @import("core/WebSocket.zig").WebSocketServer;
pub const WebSocketClient = @import("core/WebSocket.zig").WebSocketClient;
pub const WebSocketMonitor = @import("core/WebSocket.zig").WebSocketMonitor;

// Plugin System
pub const PluginManager = @import("core/PluginManager.zig").PluginManager;
pub const PluginManifest = @import("core/PluginManager.zig").PluginManifest;

// Hot Reloading
pub const HotReloader = @import("core/HotReloader.zig").HotReloader;
pub const ReloadStrategy = @import("core/HotReloader.zig").ReloadStrategy;
pub const ModuleSnapshot = @import("core/HotReloader.zig").ModuleSnapshot;

// Cluster Membership
pub const ClusterMembership = @import("core/ClusterMembership.zig").ClusterMembership;

// Database Migrations (Flyway-style)
pub const MigrationRunner = @import("migration/Migration.zig").MigrationRunner;
pub const MigrationLoader = @import("migration/Migration.zig").MigrationLoader;
pub const MigrationEntry = @import("migration/Migration.zig").MigrationEntry;
pub const MigrationStatus = @import("migration/Migration.zig").MigrationStatus;
pub const AppliedMigration = @import("migration/Migration.zig").AppliedMigration;

// Module Interaction Verification
pub const ModuleInteractionVerifier = @import("core/ModuleInteractionVerifier.zig").ModuleInteractionVerifier;
pub const InteractionType = @import("core/ModuleInteractionVerifier.zig").ModuleInteractionVerifier.InteractionType;

// Idempotency
pub const IdempotencyStore = @import("http/Idempotency.zig").IdempotencyStore;
pub const idempotencyMiddleware = @import("http/Idempotency.zig").idempotencyMiddleware;

// OpenAPI Documentation
pub const OpenApiGenerator = @import("http/OpenApi.zig").OpenApiGenerator;

// RFC 7807 Problem Details
pub const ProblemDetails = @import("http/ProblemDetails.zig").ProblemDetails;
pub const ValidationProblem = @import("http/ProblemDetails.zig").ValidationProblem;

// Feature Flags
pub const FeatureFlagManager = @import("core/FeatureFlags.zig").FeatureFlagManager;
pub const FeatureFlag = @import("core/FeatureFlags.zig").FeatureFlag;

// HTTP Metrics
pub const HttpMetricsCollector = @import("http/HttpMetrics.zig").HttpMetricsCollector;
pub const httpMetricsMiddleware = @import("http/HttpMetrics.zig").httpMetricsMiddleware;

// Cache-Aside Pattern
pub const CacheAside = @import("cache/CacheAside.zig").CacheAside;

// Bulkhead Pattern
pub const Bulkhead = @import("resilience/Bulkhead.zig").Bulkhead;
pub const BulkheadRegistry = @import("resilience/Bulkhead.zig").BulkheadRegistry;

// API Key Authentication
pub const ApiKeyAuth = @import("security/ApiKeyAuth.zig").apiKeyAuth;
pub const ApiKeyAuthWithLoader = @import("security/ApiKeyAuth.zig").apiKeyAuthWithLoader;
pub const ApiKeyGenerator = @import("security/ApiKeyAuth.zig").ApiKeyGenerator;
pub const ApiKeyConfig = @import("security/ApiKeyAuth.zig").ApiKeyConfig;

// Validation Middleware
pub const validateRequest = @import("api/middleware/Validation.zig").validateRequest;
pub const validationMiddleware = @import("api/middleware/Validation.zig").validationMiddleware;

// Dashboard
pub const Dashboard = @import("http/Dashboard.zig");

// Access Logging
pub const AccessLogger = @import("http/AccessLog.zig").AccessLogger;
pub const accessLogMiddleware = @import("http/AccessLog.zig").accessLogMiddleware;

// API Versioning
pub const ApiVersion = @import("http/ApiVersioning.zig").ApiVersion;
pub const ApiVersionExtractor = @import("http/ApiVersioning.zig").ApiVersionExtractor;
pub const ApiVersionRouter = @import("http/ApiVersioning.zig").ApiVersionRouter;
pub const apiVersionMiddleware = @import("http/ApiVersioning.zig").apiVersionMiddleware;
pub const ApiEndpoint = @import("http/OpenApi.zig").ApiEndpoint;
pub const ApiSchema = @import("http/OpenApi.zig").ApiSchema;
pub const HttpMethod = @import("http/OpenApi.zig").HttpMethod;

// Secrets Management
pub const SecretsManager = @import("secrets/SecretsManager.zig").SecretsManager;
pub const SecretEntry = @import("secrets/SecretsManager.zig").SecretsManager.SecretEntry;
pub const SecretsSourcePriority = @import("secrets/SecretsManager.zig").SecretsSourcePriority;

// gRPC Transport
pub const GrpcServiceRegistry = @import("core/GrpcTransport.zig").GrpcServiceRegistry;
pub const GrpcClient = @import("core/GrpcTransport.zig").GrpcClient;
pub const GrpcStatusCode = @import("core/GrpcTransport.zig").GrpcStatusCode;
pub const ProtoParser = @import("core/GrpcTransport.zig").ProtoParser;

// Kafka Connector
pub const KafkaProducer = @import("core/KafkaConnector.zig").KafkaProducer;
pub const KafkaConsumer = @import("core/KafkaConnector.zig").KafkaConsumer;
pub const KafkaEventBridge = @import("core/KafkaConnector.zig").KafkaEventBridge;
pub const KafkaMessage = @import("core/KafkaConnector.zig").KafkaMessage;

// Saga Orchestrator (auto-compensation)
pub const SagaOrchestrator = @import("core/SagaOrchestrator.zig").SagaOrchestrator;
pub const SagaLog = @import("core/SagaOrchestrator.zig").SagaLog;
pub const SagaStatus = @import("core/SagaOrchestrator.zig").SagaStatus;

// Contract Testing
pub const ContractTestRunner = @import("test/ContractTest.zig").ContractTestRunner;
pub const Contract = @import("test/ContractTest.zig").Contract;
pub const ContractVerificationResult = @import("test/ContractTest.zig").ContractVerificationResult;

// Distributed Transactions
pub const DistributedTransactionManager = @import("core/DistributedTransaction.zig").DistributedTransactionManager;
pub const TwoPhaseCommit = @import("core/DistributedTransaction.zig").TwoPhaseCommit;

// Transactions
pub const Transactional = @import("core/Transactional.zig").Transactional;

// Config Parsers
pub const YamlParser = @import("config/YamlToml.zig").YamlParser;
pub const TomlParser = @import("config/YamlToml.zig").TomlParser;

// SQLx
pub const sqlx = @import("sqlx/sqlx.zig");

// Redis
pub const redis = @import("redis/redis.zig");

// Pool
pub const pool = @import("pool/Pool.zig");

// Cache
pub const CacheManager = @import("cache/CacheManager.zig").CacheManager;
pub const cache = @import("cache/Lru.zig");

// Scheduler (Cron)
pub const cron = @import("scheduler/Cron.zig");

// Core Utilities
pub const fx = @import("core/Fx.zig");

// Retry / Load Shedder
pub const retry = @import("resilience/Retry.zig");
pub const load_shedder = @import("resilience/LoadShedder.zig");

// ORM
pub const orm = @import("persistence/Orm.zig");
pub const SqlxBackend = @import("persistence/backends/SqlxBackend.zig").SqlxBackend;
pub const util = @import("util.zig");

// Gozero Validator (legacy)
pub const gozero_validator = @import("validation/Validator.zig");

// Tracing
pub const DistributedTracer = @import("tracing/DistributedTracer.zig").DistributedTracer;

// ============================================
// DEPRECATED API - Will be removed in future
// ============================================

/// DEPRECATED: Use zigmodu.Application instead
/// This API will be removed in a future version.
/// Please use the Application API for better type safety and features.
pub const App = @import("api/Simplified.zig").App;

/// DEPRECATED: Use zigmodu.Application instead
pub const Module = @import("api/Simplified.zig").Module;

/// DEPRECATED: Use zigmodu.Application instead
pub const ModuleImpl = @import("api/Simplified.zig").ModuleImpl;

// Extensions namespace (backward compatibility)
pub const extensions = @import("extensions.zig");

// Tests
test {
    _ = @import("tests.zig");
}
