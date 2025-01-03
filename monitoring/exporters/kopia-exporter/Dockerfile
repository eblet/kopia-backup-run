FROM golang:1.21-alpine AS builder

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY cmd/exporter/main.go cmd/exporter/
RUN CGO_ENABLED=0 GOOS=linux go build -o kopia-exporter cmd/exporter/main.go

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /build/kopia-exporter .
COPY --from=kopia/kopia:latest /bin/kopia /usr/local/bin/kopia

RUN apk add --no-cache ca-certificates curl

EXPOSE 9091
ENTRYPOINT ["/app/kopia-exporter"]
