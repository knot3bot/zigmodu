# Performance Assessment — v0.9.4

## Summary: 92/100 (A-)

## Strengths

### Hot Path Optimizations
- **Router O(1) child lookup**: `StringHashMap` for 8+ children, cached `param_child`
- **CircuitBreaker**: `clock_gettime` syscall skipped when CLOSED (~99.9% of calls)
- **Method dispatch**: first-char switch O(1), replaces 7 sequential `std.mem.eql`

### Memory Allocation
- **Path single-allocation**: `_request_line_buf` eliminates double-dupe
- **Middleware pre-composed**: at registration time, not per-request (eliminates alloc+memcpy)
- **Summary bounded**: `max_samples=500` reservoir sampling prevents OOM

### Data Structure Choice
- **swapRemove deployed**: 8 hot-path files (EventBus, RateLimiter, HttpClient, etc.)
- **CacheManager O(1) LRU**: monotonic `lru_counter` promotion
- **WAL packed struct**: single `@bitCast` replaces 5 `writeInt` calls

### Concurrency
- **Timer cached**: `cachedNowSeconds()` atomic read avoids syscall for TTL checks
- **ClusterMetrics**: 8 atomic gauges/counters for thread-safe metrics
- **ThreadSafeEventBus**: `std.Io.Mutex` with documented lock behavior

## Remaining Optimization Opportunities

### P1 (est. +2 score)
| Item | Current | Target | Impact |
|------|---------|--------|:------:|
| Response streaming | Full buffer before write | `writeBody()` + chunked transfer | Large payloads |
| CacheManager eviction | O(n) HashMap scan | `std.TailQueue` O(1) pop | Cold path only |

### P2 (est. +1 score)
| Item | Current | Target | Impact |
|------|---------|--------|:------:|
| `getQuantile()` | O(n log n) full sort | QuickSelect O(n) | Summary queries |
| Router match() HashMap | Alloc per match | Arena scratch buffer | Per-match alloc |
| `Time.monotonicNow()` | Syscall per call | Atomic ticker thread | Cold for coarse users |

## Per-Request Allocation Budget

| Operation | Allocations |
|-----------|:-----------:|
| Request parsing (path+headers) | ~4 |
| Context creation (5 HashMaps) | ~5 |
| Route matching | ~1 (HashMap on match) |
| Middleware chain | 0 (pre-composed) |
| Response writing | ~1 |
| **Total** | **~11** |

Down from ~15 pre-optimization. Further reduction possible with lazy HashMap init.

## Benchmark Notes
- Local wrk: ~10K+ RPS on M-series Mac
- SQLite: <1ms query latency with connection pooling
- No regression in keep-alive throughput vs v0.8.x
