FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod download && \
    CGO_ENABLED=0 GOOS=linux go build -o kopia-exporter .

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/kopia-exporter .
RUN apk add --no-cache ca-certificates
EXPOSE 9091
ENTRYPOINT ["/app/kopia-exporter"]
