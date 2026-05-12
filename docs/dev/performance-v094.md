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
| ~~Response streaming~~ | ~~Full buffer before write~~ | `writeBody()` + chunked transfer | **DONE v0.9.5** |
| CacheManager eviction | O(n) HashMap scan | Evaluated TailQueue, rejected (see below) | Cold path only |

### P2 (est. +1 score)
| Item | Current | Target | Impact |
|------|---------|--------|:------:|
| `getQuantile()` | O(n log n) full sort | QuickSelect O(n) | Summary queries |
| ~~Router match() HashMap~~ | ~~Alloc per match~~ | Ownership transfer to ctx | **DONE v0.9.5** |
| ~~`Time.monotonicNow()`~~ | ~~Syscall per call~~ | `cachedNowSeconds()` 1s TTL | **DONE v0.9.5** |

## Per-Request Allocation Budget

| Operation | Allocations |
|-----------|:-----------:|
| Request parsing (path+headers) | ~4 |
| Context creation (3 HashMaps + response_body) | ~4 |
| Route matching | 0 (ownership transfer to ctx) |
| Middleware chain | 0 (pre-composed) |
| Response writing | 0 (direct socket write) |
| **Total** | **~8** |

Down from ~15 pre-optimization, ~11 in v0.9.4. Form HashMap is lazy (only for POST).

## Benchmark Notes
- Local wrk: ~10K+ RPS on M-series Mac
- SQLite: <1ms query latency with connection pooling
- No regression in keep-alive throughput vs v0.8.x

## v0.9.5 Optimizations (2026-05-12)

### Response Direct Socket Write
`writeResponse()` writes status line + headers + body directly to the stream
via small stack buffers. Eliminates intermediate `ArrayList(u8)` allocation + copy
per response. Also skips `Content-Length` header when `Transfer-Encoding: chunked`
is set (HTTP spec compliance).

### Cached Timestamp 1s TTL
`cachedNowSeconds()` auto-refreshes on 1-second boundary. First call within a
second hits `clock_gettime`; subsequent calls return the cached value. Used in:
- CacheManager.get() — single call serves TTL check + last_accessed
- RateLimiter.refill() — token bucket is inherently per-second
- SlidingWindowRateLimiter — window cleanup is per-second

### Params Ownership Transfer
Route match params HashMap ownership transferred directly to Context, avoiding
per-param key/value duplications. Same pattern already used for query/headers.
Saves 2 allocs per path parameter.

### Form Parsing Fix
Fixed use-after-transfer bug: form Content-Type check was reading from
`request.headers` after ownership had already been moved to `ctx.headers`,
silently breaking all form body parsing.

### TailQueue Eviction (Evaluated, Rejected)
`std.DoublyLinkedList`-based O(1) LRU eviction was prototyped but rejected:
intrusive list nodes require stable pointers, forcing heap allocation of every
`CacheEntry`. This adds 1 alloc/entry and degrades cache locality. The O(n)
scan is cold-path (cache-full only); callers should size caches appropriately.
Current `lru_counter` approach is simpler, more allocation-efficient, and the
right engineering trade-off for the common case.
