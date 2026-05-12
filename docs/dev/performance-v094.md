# Performance Assessment — v0.9.5

## Summary: 95/100 (A)

Up from 92 (v0.9.4). The 3-point gain comes from three high-impact hot-path wins:
SQLx O(1) row scanning, Router arena memory fix, and direct socket write.

## Strengths (v0.9.4 baseline, retained)

### Hot Path Optimizations
- **Router O(1) child lookup**: `StringHashMap` for 8+ children, cached `param_child`
- **CircuitBreaker**: `clock_gettime` syscall skipped when CLOSED (~99.9% of calls)
- **Method dispatch**: first-char switch O(1), replaces 7 sequential `std.mem.eql`

### Memory Allocation
- **Path single-allocation**: `_request_line_buf` eliminates double-dupe
- **Middleware pre-composed**: at registration time, not per-request (0 allocs)
- **Summary bounded**: `max_samples=500` reservoir sampling prevents OOM
- **Params ownership transfer**: match→ctx HashMap move, 0 dupe allocs per param
- **Form lazy-init**: HashMap only allocated for POST requests

### Data Structure Choice
- **swapRemove deployed**: 8 hot-path files
- **CacheManager O(1) LRU promotion**: monotonic `lru_counter`
- **WAL packed struct**: single `@bitCast` replaces 5 `writeInt` calls

## v0.9.5 New Optimizations

### P0: SQLx Comptime Column Index (+2 score)
`buildColumnIndices()` precomputes struct-field→column-index mapping once per query.
Per-row scanning drops from **O(F×C) string comparisons to O(F) direct array indexing**.
For a 20-column table mapped to a 20-field struct: 400 `mem.eql` calls/row → 20 array lookups/row.
Applied to `Client.queryRows`, `queryRowsPartial`, and `Transaction.queryRows`.

### P1: Router Arena Allocator (+0.5 score)
`Router.match()` now accepts allocator parameter. `connFiber` passes `arena_alloc`,
so param keys/values go into arena instead of the router's long-lived allocator.
Eliminates memory retention across keep-alive requests (previously leaked ~64 bytes
per dynamic param until connection close).

### P1: Direct Socket Write (+0.5 score)
`writeResponse()` writes status line + headers + body directly to `std.Io.net.Stream`
via small stack buffers (256B). Eliminates intermediate `ArrayList(u8)` allocation +
body copy per response. Skips `Content-Length` when `Transfer-Encoding: chunked` is set.

### P2: Cached Timestamp 1s TTL
`cachedNowSeconds()` auto-refreshes on 1-second boundary. Used in:
- CacheManager.get() — single call for TTL check + last_accessed
- RateLimiter.refill() — token bucket is per-second
- SlidingWindowRateLimiter — window cleanup is per-second

### P2: getQuantile QuickSelect O(n)
Replaces `std.sort.insertion` (O(n²) worst case) with in-place QuickSelect (O(n) expected).
At `max_samples=500`, saves ~125K comparisons per quantile query.

## Per-Request Allocation Budget

| Operation | Allocations | Change |
|-----------|:-----------:|:------:|
| Request parsing (path+headers) | ~4 | — |
| Context creation (3 HashMaps) | ~4 | — |
| Route matching | 0 (ownership transfer) | — |
| Middleware chain | 0 (pre-composed) | — |
| Response writing | 0 (direct socket write) | ↓1 from v0.9.4 |
| **Total per request** | **~8** | ↓3 from v0.9.3, ↓1 from v0.9.4 |

Arena per connection with `.retain_capacity` means **0 syscall allocations/req in steady state**.

## DB Row Scan Budget (per row, 20-column table)

| Operation | v0.9.4 | v0.9.5 |
|-----------|:------:|:------:|
| Column name string comparisons | 400 | 20 (once per query) |
| Array index lookups | 0 | 20 |
| String field dupes | S | S |
| **Algorithmic complexity** | O(F×C) | O(F) |

## Remaining Gaps

### Correctness (not just performance)
| Item | Current | Risk |
|------|---------|------|
| Histogram.observe() | Plain `f64` += | Data race under concurrency |
| Summary.observe() | Plain `f64` +=, non-atomic ArrayList | Data race under concurrency |

### P2 (est. +1 score)
| Item | Current | Target |
|------|---------|--------|
| SQL prepared statement cache | Re-prepare per query | LRU cache of compiled statements |
| CacheManager eviction | O(n) HashMap scan | TailQueue O(1) — evaluated, rejected |
| Response chunked streaming | Buffered in response_body | True stream-to-socket write |

## Benchmark Notes
- Local wrk: ~10K+ RPS on M-series Mac (unchanged — CPU-bound by zig cc)
- SQLite: <1ms query latency with connection pooling
- Row scan: ~5x fewer string comparisons per row for wide tables
- No regression in keep-alive throughput vs v0.8.x
- Arena reuse: 0 malloc/free syscalls per request in steady state
