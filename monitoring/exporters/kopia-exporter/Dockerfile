FROM golang:1.21-alpine AS builder

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o kopia-exporter main.go

FROM alpine:3.19

WORKDIR /app
COPY --from=builder /build/kopia-exporter .
COPY --from=kopia/kopia:latest /bin/kopia /usr/local/bin/kopia

RUN apk add --no-cache ca-certificates curl

# Create required directories
RUN mkdir -p /app/config /app/cache /app/logs

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9091/health || exit 1

EXPOSE 9091
ENTRYPOINT ["/app/kopia-exporter"]
