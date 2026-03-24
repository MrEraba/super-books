# Books Recommendation API - Implementation Plan

## Tech Lead Review Summary

### API Design Review (API.md)
- **Strengths**: Clean REST API design, well-defined error codes, proper JWT authentication pattern with refresh tokens
- **Concerns**: 
  - Missing input validation details (password requirements, title/content length limits)
  - No rate limiting specified
  - No explicit content-type handling for refresh tokens endpoint (should it require auth?)

### Database Design Review (DATABASE.md)
- **Strengths**: Proper use of UUIDs, soft deletes, partial unique indexes, GIN full-text search, well-thought join tables
- **Concerns**: 
  - Refresh token hash algorithm (SHA-256) differs from API's bcrypt for passwords - this is intentional but worth noting
  - No explicit FK from books.owner_id to users - CASCADE is correct

---

## Part 1: Local Development Setup

### Prerequisites Checklist

| Tool | Version | Purpose | Install |
|------|---------|---------|---------|
| Docker | 24.x+ | Container runtime | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.x+ | Multi-container orchestration | [docs.docker.com](https://docs.docker.com/compose/install/) |
| Go | 1.21+ | Application runtime | [go.dev](https://go.dev/dl/) |
| golang-migrate | 4.x+ | Database migrations | `go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest` |
| PostgreSQL Client (psql) | 15.x | DB debugging/queries | `brew install postgresql` or `apt install postgresql-client` |
| Air | 1.91+ | Live reload for Go | `go install github.com/air-email/air@latest` |
| Make | 4.x+ | Task automation | Usually pre-installed |
| golangci-lint | 1.54+ | Code linting | `brew install golangci-lint` or `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` |

### Project Structure

```
super-books/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go            # Configuration loading (env vars, config.yaml)
│   ├── database/
│   │   ├── postgres.go         # PostgreSQL connection
│   │   └── migrations.go       # Migration runner
│   ├── models/
│   │   ├── user.go             # User model
│   │   ├── book.go             # Book/Recommendation model
│   │   ├── tag.go              # Tag model
│   │   └── refresh_token.go    # Refresh token model
│   ├── repository/
│   │   ├── user_repository.go  # User data access
│   │   ├── book_repository.go  # Book data access
│   │   ├── tag_repository.go   # Tag data access
│   │   └── token_repository.go # Refresh token data access
│   ├── service/
│   │   ├── auth_service.go    # Authentication logic
│   │   ├── book_service.go    # Book business logic
│   │   ├── tag_service.go     # Tag business logic
│   │   └── user_service.go    # User business logic
│   ├── handler/
│   │   ├── auth_handler.go     # Auth HTTP handlers
│   │   ├── book_handler.go     # Book HTTP handlers
│   │   ├── tag_handler.go      # Tag HTTP handlers
│   │   └── user_handler.go     # User HTTP handlers
│   ├── middleware/
│   │   ├── auth.go             # JWT authentication middleware
│   │   ├── admin.go            # Admin role check middleware
│   │   └── error.go            # Global error handler
│   ├── dto/
│   │   ├── request/            # Incoming request DTOs
│   │   └── response/           # Outgoing response DTOs
│   └── validator/
│       └── validator.go         # Input validation helpers
├── migrations/
│   ├── 000001_create_users_table.up.sql
│   ├── 000001_create_users_table.down.sql
│   └── ... (see DATABASE.md for full list)
├── docker/
│   └── Dockerfile              # Multi-stage build for production
├── docker-compose.yaml         # Local development stack
├── .env.example                # Environment variables template
├── .golangci.yml              # Linter configuration
├── Makefile                   # Build/test shortcuts
├── go.mod
└── go.sum
```

### Docker Compose Configuration

```yaml
# docker-compose.yaml
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    container_name: super-books-db
    environment:
      POSTGRES_USER: superbooks
      POSTGRES_PASSWORD: superbooks_dev_password
      POSTGRES_DB: superbooks_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U superbooks"]
      interval: 5s
      timeout: 5s
      retries: 5

  app:
    build:
      context: .
      dockerfile: docker/Dockerfile.dev
    container_name: super-books-api
    environment:
      DATABASE_URL: postgres://superbooks:superbooks_dev_password@postgres:5432/superbooks_dev?sslmode=disable
      JWT_SECRET: dev_jwt_secret_change_in_production
      JWT_EXPIRY: 1h
      REFRESH_TOKEN_EXPIRY: 168h  # 7 days
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - .:/app
      - /app/vendor  # Cache go modules
    command: air -c .air.toml

volumes:
  postgres_data:
```

### Development Workflow Commands (Makefile)

```makefile
# Makefile
.PHONY: setup migrate-up migrate-down test lint run clean docker-up docker-down

setup: docker-up migrate-up
	@echo "Setup complete. Run 'make run' to start the server"

docker-up:
	docker compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5

docker-down:
	docker compose down -v

migrate-up:
	migrate -path migrations -database "postgres://superbooks:superbooks_dev_password@localhost:5432/superbooks_dev?sslmode=disable" up

migrate-down:
	migrate -path migrations -database "postgres://superbooks:superbooks_dev_password@localhost:5432/superbooks_dev?sslmode=disable" down

migrate-force:
	migrate -path migrations -database "postgres://superbooks:superbooks_dev_password@localhost:5432/superbooks_dev?sslmode=disable" force ${VERSION}

test:
	go test -v -race -cover ./...

test/integration:
	go test -v -tags=integration ./...

lint:
	golangci-lint run ./...

run:
	go run ./cmd/server

clean:
	docker compose down -v --remove-orphans
	rm -rf .air.toml
```

### Air Configuration (Live Reload)

```toml
# .air.toml
root = "."
tmp_dir = "tmp"

[build]
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ./cmd/server"
  delay = 1000
  exclude_dir = ["assets", "tmp", "vendor", "migrations"]
  exclude_regex = ["_test.go"]
  exclude_unchanged = false
  follow_symlink = false
  include_ext = ["go", "tpl", "tmpl", "html"]
  kill_delay = "2s"
  log = "build-errors.log"
  send_interrupt = false
  stop_on_error = true

[log]
  time = false

[misc]
  clean_on_exit = true
```

### Environment Variables Template

```bash
# .env.example
# Application
APP_ENV=development
APP_PORT=8080

# Database
DATABASE_URL=postgres://superbooks:superbooks_dev_password@localhost:5432/superbooks_dev?sslmode=disable
DB_MAX_CONNECTIONS=25
DB_MAX_IDLE_CONNECTIONS=5
DB_CONN_MAX_LIFETIME=5m

# JWT
JWT_SECRET=change_this_to_a_long_random_secret_in_production
JWT_EXPIRY=1h
REFRESH_TOKEN_EXPIRY=168h

# Optional: External services
# REDIS_URL=redis://localhost:6379
# SENTRY_DSN=https://xxx@sentry.io/xxx
```
