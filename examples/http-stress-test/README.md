# HTTP Stress Test

```bash
# Install wrk
brew install wrk

# Start server
zig build run

# Run stress test
wrk -t4 -c100 -d30s http://localhost:8080/health
```

Expected: <10ms p99 latency, 0 errors, 10K+ RPS on localhost.
