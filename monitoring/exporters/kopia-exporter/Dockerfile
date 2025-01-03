FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy go.mod and go.sum
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY main.go ./

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o kopia-exporter .

FROM alpine:3.19

WORKDIR /app
COPY --from=builder /app/kopia-exporter .

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

EXPOSE 9091
ENTRYPOINT ["/app/kopia-exporter"]
