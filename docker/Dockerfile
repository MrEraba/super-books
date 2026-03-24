FROM golang:1.21-alpine AS base

RUN apk add --no-cache git ca-certificates tzdata

RUN adduser -D -g app app

WORKDIR /app

RUN go install github.com/air-email/air@latest

FROM base AS development

COPY go.mod go.sum ./
RUN go mod download

COPY . .

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]

FROM base AS production

RUN go mod download

COPY . .
RUN go build -ldflags="-w -s" -o /app/server ./cmd/server

FROM alpine:3.19 AS final

RUN apk add --no-cache ca-certificates tzdata

RUN adduser -D -g app app

COPY --from=production /app/server /app/server
COPY --from=production /app/migrations /app/migrations

USER app

EXPOSE 8080

CMD ["/app/server"]
