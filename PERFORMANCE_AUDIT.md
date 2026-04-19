# ZigModu 性能评估报告

## 执行摘要

本次评估识别出 8 个性能瓶颈，按优先级排序如下。建议优先修复高优先级项（HTTP Server 并发模型、LRU Cache O(n) 瓶颈），这些对系统吞吐量和延迟影响最大。

---

## 1. HTTP Server: Thread-per-Connection C10K 问题 🔴 高优先级

**位置**: `src/api/Server.zig`

**问题**: 每个连接创建一个独立线程 (`std.Thread.spawn`)。在高并发下：
- 线程创建/销毁开销大
- 线程栈内存消耗（每个线程 ~8MB）
- 上下文切换开销
- 系统线程数上限限制并发连接数

**影响**: 并发连接数受限，高负载下延迟剧增

**建议**: 
1. 使用线程池 + 任务队列模型
2. 利用 `std.Io` 的异步 IO 能力（Zig 0.16.0）
3. 或者使用 `std.Thread.Pool` 作为中间方案

---

## 2. LRU Cache: O(n) 驱逐算法 🔴 高优先级

**位置**: `src/cache/Lru.zig`

**问题**: `updateAccessOrder()` 和 `removeInternal()` 使用线性扫描 `ArrayList`：
- 每次访问/插入/删除都是 O(n)
- 缓存热点项时性能急剧下降
- 大缓存时不可接受

**影响**: 缓存访问成为瓶颈，高频访问下 CPU 使用率过高

**建议**: 使用双向链表（`std.DoublyLinkedList`）+ `AutoHashMap` 存储节点指针，实现 O(1) 的 get/put/evict。

---

## 3. SQLx Query: 每行独立内存分配 🟡 中优先级

**位置**: `src/sqlx/sqlx.zig`

**问题**: `queryFn` 为每行数据独立分配 `columns` 和 `values` 数组：
- 无 Arena Allocator，产生大量小分配
- 内存碎片
- GC 压力（虽然 Zig 无 GC，但频繁分配/释放影响性能）

**影响**: 大数据集查询时内存分配成为瓶颈

**建议**: 
1. 使用 `std.heap.ArenaAllocator` 按查询生命周期分配
2. 或预分配固定大小的 Row 缓冲区

---

## 4. DI Container: 运行时字符串比较 🟡 中优先级

**位置**: `src/di/Container.zig`

**问题**: `get()` 方法在运行时遍历注册项进行字符串比较：
- 每次依赖解析都是 O(n) 字符串比较
- 无法利用 Zig 的编译时类型系统

**影响**: 依赖解析延迟，虽然单次开销小，但累积明显

**建议**: 使用 `@typeName(T)` 编译时生成类型标识符，配合 `AutoHashMap` 实现 O(1) 查找。

---

## 5. EventBus: HashMap 小数据量开销 🟡 中优先级

**位置**: `src/core/EventBus.zig`

**问题**: `ListenerSet` 使用 `AutoHashMap` 存储回调：
- 小数量监听器时，HashMap 桶分配和哈希计算开销大于收益
- 缓存局部性差

**影响**: 事件分发延迟，尤其是少量监听器场景

**建议**: 使用 `std.ArrayList` 作为 `ListenerSet` 底层存储，或实现混合结构（小数据量用 ArrayList，大数据量自动切换到 HashMap）。

---

## 6. Prometheus Metrics: 非原子计数器 🟡 中优先级

**位置**: `src/metrics/PrometheusMetrics.zig`

**问题**: `Counter.value += 1` 不是原子操作：
- 多线程环境下数据竞争
- 计数可能丢失

**影响**: 指标准确性，高并发下计数偏差

**建议**: 使用 `std.atomic.Value(u64)` 替代普通 `u64` 字段。

---

## 7. WebSocket: 每连接线程 + 广播 O(n) 🟡 中优先级

**位置**: `src/core/WebSocket.zig`

**问题**: 
- 每个 WebSocket 连接创建一个线程
- `broadcast()` 遍历所有客户端进行线性发送

**影响**: 同 HTTP Server 的 C10K 问题，广播消息延迟随客户端数线性增长

**建议**: 与 HTTP Server 统一使用线程池模型，广播使用锁保护的消息队列。

---

## 8. RequestParser: 多处 StringHashMap 分配 🟢 低优先级

**位置**: `src/api/RequestParser.zig`

**问题**: 每个请求创建多个 `StringHashMap`（headers, query_params），并复制所有数据。

**影响**: 内存分配频繁，但在现代 allocator 下影响相对可控

**建议**: 使用 Arena Allocator 按请求生命周期管理内存，或延迟解析（按需解析 query/header）。

---

## 优化路线图

### Phase 1 (立即执行)
1. LRU Cache O(1) 重构
2. HTTP Server 线程池模型

### Phase 2 (短期)
3. SQLx Arena Allocator
4. DI Container 编译时优化
5. Prometheus 原子计数器

### Phase 3 (中期)
6. EventBus 混合存储结构
7. WebSocket 统一线程池
8. RequestParser 内存优化

---

## 基准测试建议

优化后应运行以下基准：
1. **HTTP RPS 测试**: `wrk -t12 -c400 -d30s http://localhost:8080/`
2. **LRU 吞吐量**: 100K get/put 操作耗时
3. **内存分配计数**: 单次请求/查询的分配次数
4. **事件分发延迟**: 1K 监听器下的 publish 延迟

---

*报告生成时间: 2025-04-19*
