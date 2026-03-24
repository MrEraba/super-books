# Super Books - Books Recommendation API

A REST API for book recommendations where users can create, update, delete, search, and read book recommendations. The API uses JWT authentication and returns personalized book recommendations based on user preferences (tags).

## Features

- **User Authentication**: JWT-based authentication with access and refresh tokens
- **Book Recommendations**: Create, read, update, and delete book recommendations
- **Personalized Feed**: `/books` endpoint returns recommendations matching user's preference tags
- **Full-text Search**: Search books by title/content using PostgreSQL GIN indexes
- **Tag-based Filtering**: Filter recommendations by tags/genres
- **User Preferences**: Users can set their preferred book genres

## Tech Stack

- **Language**: Go 1.21+
- **Database**: PostgreSQL 16
- **Web Framework**: Standard library `net/http` (extensible to Fiber/Gin)
- **Authentication**: JWT with bcrypt password hashing
- **Migrations**: golang-migrate
- **Live Reload**: Air (development)
- **Containerization**: Docker & Docker Compose

## Prerequisites

| Tool | Version | Purpose | Install |
|------|---------|---------|--------|
| Docker | 24.x+ | Container runtime | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.x+ | Multi-container orchestration | [docs.docker.com](https://docs.docker.com/compose/install/) |
| Go | 1.21+ | Local development (optional) | [go.dev](https://go.dev/dl/) |
| golang-migrate | 4.x+ | Database migrations | `go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest` |
| Air | 1.91+ | Live reload for Go (optional) | `go install github.com/air-email/air@latest` |
| golangci-lint | 1.54+ | Code linting | [golangci-lint.run](https://golangci-lint.run/usage/install/) |

## Quick Start

### 1. Clone and Setup Environment

```bash
git clone <repository-url>
cd super-books
cp .env.example .env
```

### 2. Start with Docker (Recommended)

```bash
# Start PostgreSQL and run migrations
make setup

# Start the application with live reload
make docker-up
```

The API will be available at `http://localhost:8080`

### 3. Stop Services

```bash
make docker-down
```

## Local Development (Without Docker)

### 1. Start PostgreSQL

```bash
docker compose up -d postgres
```

### 2. Run Migrations

```bash
make migrate-up
```

### 3. Start the Server

```bash
# With live reload (requires Air)
air

# Or without live reload
make run
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make setup` | Start PostgreSQL, run migrations, and prepare for development |
| `make docker-up` | Start PostgreSQL and the API container with live reload |
| `make docker-down` | Stop and remove Docker containers |
| `make migrate-up` | Run all database migrations |
| `make migrate-down` | Rollback all database migrations |
| `make migrate-force VERSION=N` | Force migration to a specific version |
| `make test` | Run all tests with race detection |
| `make test/integration` | Run integration tests |
| `make lint` | Run linter (golangci-lint) |
| `make run` | Start the server without live reload |
| `make clean` | Remove containers, volumes, and temporary files |

## Environment Variables

Copy `.env.example` to `.env` and configure:

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `development` | Application environment |
| `APP_PORT` | `8080` | Server port |
| `DATABASE_URL` | (see example) | PostgreSQL connection string |
| `DB_MAX_CONNECTIONS` | `25` | Maximum database connections |
| `DB_MAX_IDLE_CONNECTIONS` | `5` | Maximum idle connections |
| `DB_CONN_MAX_LIFETIME` | `5m` | Connection max lifetime |
| `JWT_SECRET` | (required) | Secret key for JWT signing |
| `JWT_EXPIRY` | `1h` | Access token expiration |
| `REFRESH_TOKEN_EXPIRY` | `168h` | Refresh token expiration (7 days) |

## API Documentation

See [API.md](./API.md) for complete API reference including:

- All endpoints and their descriptions
- Request/response formats
- Authentication requirements
- Example cURL commands

### Key Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|--------------|
| POST | `/auth/register` | Register a new user | No |
| POST | `/auth/login` | Login and receive JWT | No |
| POST | `/auth/refresh` | Refresh access token | No |
| GET | `/auth/me` | Get current user profile | Yes |
| GET | `/books` | Get personalized recommendations | Yes |
| GET | `/books/search` | Search recommendations | Yes |
| GET | `/books/:id` | Get a recommendation by ID | Yes |
| POST | `/books` | Create a recommendation | Yes |
| PUT | `/books/:id` | Update a recommendation | Yes (owner) |
| DELETE | `/books/:id` | Delete a recommendation | Yes (owner) |
| GET | `/tags` | List all tags | Yes |
| POST | `/tags` | Create a tag | Yes (admin) |
| GET | `/users/me/preferences` | Get user preferences | Yes |
| PUT | `/users/me/preferences` | Update preferences | Yes |
| GET | `/users/me/recommendations` | Get user's recommendations | Yes |

### Example: Register and Login

```bash
# Register
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"SecurePass123","preferences":["sci-fi","fantasy"]}'

# Login
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"SecurePass123"}'

# Use the token for authenticated requests
TOKEN="your-jwt-token"
curl -X GET http://localhost:8080/books \
  -H "Authorization: Bearer $TOKEN"
```

## Database Schema

See [DATABASE.md](./DATABASE.md) for complete database documentation including:

- Entity relationship diagrams
- Table schemas
- Indexes and constraints
- Migration file structure

### Main Tables

- **users**: User accounts with email, hashed password, role, preferences
- **books**: Book recommendations with title, content, owner
- **tags**: Book genre/category tags
- **book_tags**: Many-to-many relationship between books and tags
- **user_preferences**: Many-to-many relationship between users and preferred tags
- **refresh_tokens**: Hashed refresh tokens for session management

## Project Structure

```
super-books/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── src/
│   ├── internal/
│   │   ├── config/              # Configuration loading
│   │   ├── database/            # Database connection & migrations
│   │   ├── models/              # Domain models
│   │   ├── repository/         # Data access layer
│   │   ├── service/            # Business logic
│   │   ├── handler/            # HTTP handlers
│   │   ├── middleware/         # Auth & error handling
│   │   ├── dto/                # Request/response DTOs
│   │   └── validator/          # Input validation
│   └── migrations/             # Database migrations
├── docker/
│   ├── Dockerfile              # Production build
│   └── Dockerfile.dev          # Development build
├── docker-compose.yaml         # Local development stack
├── Makefile                   # Build automation
├── .env.example               # Environment template
├── .golangci.yml              # Linter configuration
└── .air.toml                  # Live reload configuration
```

## Development Workflow

### Running Tests

```bash
# Unit tests
make test

# Integration tests (requires running database)
make test/integration

# With coverage report
go test -v -race -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### Linting

```bash
make lint
```

### Database Operations

```bash
# Create a new migration
migrate create -ext sql -dir src/migrations -seq create_example_table

# Check migration status
migrate -path src/migrations -database "postgres://..." status

# Rollback one step
make migrate-down

# Force to specific version (if needed)
make migrate-force VERSION=3
```

## Health Check

```bash
curl http://localhost:8080/health
# Response: {"status":"ok"}
```

## Production Deployment

### Build Docker Image

```bash
docker build -f docker/Dockerfile --target production -t super-books:latest .
```

### Run Production Container

```bash
docker run -p 8080:8080 \
  -e DATABASE_URL="postgres://..." \
  -e JWT_SECRET="production-secret" \
  super-books:latest
```

## Security Considerations

- Passwords are hashed with bcrypt (cost 12)
- Refresh tokens are hashed with SHA-256 before storage
- JWT tokens expire after 1 hour (configurable)
- Token rotation on refresh (old token revoked)
- SQL queries use parameterized statements
- Soft deletes preserve data for audit trails

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes and add tests
3. Ensure tests pass: `make test`
4. Ensure linting passes: `make lint`
5. Commit your changes: `git commit -am 'Add new feature'`
6. Push to the branch: `git push origin feature/your-feature`
7. Create a Pull Request

## License

MIT
