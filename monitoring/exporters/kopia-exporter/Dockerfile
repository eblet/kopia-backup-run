FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod download && \
    CGO_ENABLED=0 GOOS=linux go build -o kopia-exporter .

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/kopia-exporter .

# Установка kopia из официального образа
COPY --from=kopia/kopia:latest /bin/kopia /usr/local/bin/kopia

# Установка необходимых зависимостей
RUN apk add --no-cache ca-certificates curl

EXPOSE 9091
ENTRYPOINT ["/app/kopia-exporter"]
