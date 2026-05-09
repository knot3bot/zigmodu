# ─────────────────────────────────────────────────
# ZigModu Production Docker Image
# Multi-stage build: compile in builder, minimal runtime
# ─────────────────────────────────────────────────

FROM --platform=$BUILDPLATFORM ziglang/zig:0.16.0 AS builder
WORKDIR /zigmodu

# Cache dependencies
COPY build.zig build.zig.zon ./
COPY src/ ./src/

# Build release
RUN zig build -Doptimize=ReleaseSafe

# ─────────────────────────────────────────────────
# Runtime stage — distroless-style minimal image
# ─────────────────────────────────────────────────
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -S zigmodu && adduser -S zigmodu -G zigmodu

COPY --from=builder /zigmodu/zig-out/bin/ /opt/zigmodu/bin/
COPY --from=builder /zigmodu/zig-out/lib/ /opt/zigmodu/lib/

# Default config directory
RUN mkdir -p /etc/zigmodu /var/log/zigmodu && \
    chown -R zigmodu:zigmodu /etc/zigmodu /var/log/zigmodu

USER zigmodu

EXPOSE 8080
EXPOSE 9091

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health/live || exit 1

ENTRYPOINT ["/opt/zigmodu/bin/zigmodu-example"]
