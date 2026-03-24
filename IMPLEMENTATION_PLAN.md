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

---

## Part 2: Implementation Tasks

### Task 1: Project Initialization & Configuration

**Description**:
Set up the Go module, create the project structure, and implement configuration management. This is the foundation - all subsequent tasks depend on it.

**Recommended Libraries**:
```go
// go.mod dependencies
github.com/golang-migrate/migrate/v4           // Database migrations
github.com/lib/pq                                // PostgreSQL driver
github.com/jmoiron/sqlx                          // SQL extensions
github.com/golang-jwt/jwt/v5                    // JWT handling
github.com/google/uuid                           // UUID generation
golang.org/x/crypto                             // bcrypt
github.com/go-playground/validator/v10           // Input validation
github.com/joho/godotenv                         // .env file loading
github.com/rs/zerolog                           // Structured logging
```

**Pseudo Code - Configuration**:
```go
// internal/config/config.go
type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
    JWT      JWTConfig
}

type ServerConfig struct {
    Port string
    Env  string
}

type DatabaseConfig struct {
    URL            string
    MaxConns       int
    MaxIdleConns   int
    ConnMaxLifetime time.Duration
}

type JWTConfig struct {
    Secret           string
    Expiry           time.Duration
    RefreshExpiry    time.Duration
}

// Load priority: env vars > config.yaml > defaults
func Load(path string) (*Config, error) {
    // 1. Set defaults
    // 2. Load config.yaml if exists
    // 3. Override with environment variables
    // Return merged config
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC1.1 | Config loads with all environment variables set |
| TC1.2 | Config loads with partial env vars and defaults applied |
| TC1.3 | Config returns error when DATABASE_URL is missing |
| TC1.4 | Config returns error when JWT_SECRET is empty |
| TC1.5 | Duration parsing works for JWT_EXPIRY (e.g., "1h", "30m") |

**Acceptance Criteria**:
- [ ] `go mod init` creates proper module with v0.0.0 version
- [ ] All required directories are created
- [ ] Configuration struct can load from environment variables
- [ ] Application panics with helpful message if required config is missing
- [ ] `make lint` passes with no errors
- [ ] Unit tests for config loading pass

---

### Task 2: Database Migrations

**Description**:
Create all database migrations following the schema in DATABASE.md. Use golang-migrate with sequential numbering.

**File Structure to Create**:
```
migrations/
├── 000001_create_users_table.up.sql
├── 000001_create_users_table.down.sql
├── 000002_create_tags_table.up.sql
├── 000002_create_tags_table.down.sql
├── 000003_create_books_table.up.sql
├── 000003_create_books_table.down.sql
├── 000004_create_book_tags_table.up.sql
├── 000004_create_book_tags_table.down.sql
├── 000005_create_user_preferences_table.up.sql
├── 000005_create_user_preferences_table.down.sql
├── 000006_create_refresh_tokens_table.up.sql
└── 000006_create_refresh_tokens_table.down.sql
```

**Key SQL Patterns**:
```sql
-- Users table with partial unique index
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_users_email_unique ON users (email) WHERE deleted_at IS NULL;

-- updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Books with full-text search
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_books_full_text ON books 
    USING GIN (to_tsvector('english', title || ' ' || content));

-- Refresh tokens with hashed token
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Migration Runner**:
```go
// internal/database/migrations.go
func RunMigrations(db *sqlx.DB, migrationsPath string) error {
    m, err := migrate.New(
        "file://"+migrationsPath,
        db.Config.URL,
    )
    if err != nil {
        return fmt.Errorf("failed to create migrator: %w", err)
    }
    defer m.Close()
    
    if err := m.Up(); err != nil && err != migrate.ErrNoChange {
        return fmt.Errorf("failed to run migrations: %w", err)
    }
    return nil
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC2.1 | All migrations run successfully on clean database |
| TC2.2 | `migrate down` reverses all changes correctly |
| TC2.3 | Partial migration (migrate force) works when needed |
| TC2.4 | Partial unique index on users.email allows re-registration after soft delete |
| TC2.5 | Foreign key constraints are enforced |
| TC2.6 | GIN index is created on books table |
| TC2.7 | `migrate down` fails if dependent tables exist (correct order) |

**Acceptance Criteria**:
- [ ] All 6 migrations (up and down) are created
- [ ] `make migrate-up` completes without errors
- [ ] `make migrate-down` completes without errors
- [ ] Database schema matches DATABASE.md exactly
- [ ] Foreign key relationships are properly defined
- [ ] Indexes are created as specified

---

### Task 3: Database Connection & Repository Layer

**Description**:
Implement the PostgreSQL connection pool and create all repository interfaces. Each repository handles CRUD operations for its entity.

**Database Connection Pattern**:
```go
// internal/database/postgres.go
func NewPostgresDB(cfg config.DatabaseConfig) (*sqlx.DB, error) {
    db, err := sqlx.Connect("postgres", cfg.URL)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to db: %w", err)
    }
    
    db.SetMaxOpenConns(cfg.MaxConns)
    db.SetMaxIdleConns(cfg.MaxIdleConns)
    db.SetConnMaxLifetime(cfg.ConnMaxLifetime)
    
    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("failed to ping db: %w", err)
    }
    
    return db, nil
}
```

**Repository Interface Pattern**:
```go
// internal/repository/user_repository.go
type UserRepository interface {
    Create(ctx context.Context, user *models.User) error
    GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
    GetByEmail(ctx context.Context, email string) (*models.User, error)
    Update(ctx context.Context, user *models.User) error
    SoftDelete(ctx context.Context, id uuid.UUID) error
    UpdateLastLogin(ctx context.Context, id uuid.UUID) error
}

// internal/repository/book_repository.go
type BookRepository interface {
    Create(ctx context.Context, book *models.Book) error
    GetByID(ctx context.Context, id uuid.UUID) (*models.Book, error)
    Update(ctx context.Context, book *models.Book) error
    SoftDelete(ctx context.Context, id uuid.UUID) error
    ListByOwner(ctx context.Context, ownerID uuid.UUID, limit, offset int) ([]*models.Book, int, error)
    ListByTags(ctx context.Context, tagIDs []uuid.UUID, limit, offset int) ([]*models.Book, int, error)
    Search(ctx context.Context, query string, tagIDs []uuid.UUID, limit, offset int) ([]*models.Book, int, error)
    AddTags(ctx context.Context, bookID uuid.UUID, tagIDs []uuid.UUID) error
    RemoveTags(ctx context.Context, bookID uuid.UUID, tagIDs []uuid.UUID) error
}

// internal/repository/tag_repository.go
type TagRepository interface {
    Create(ctx context.Context, tag *models.Tag) error
    GetByID(ctx context.Context, id uuid.UUID) (*models.Tag, error)
    GetByIDs(ctx context.Context, ids []uuid.UUID) ([]*models.Tag, error)
    GetAll(ctx context.Context) ([]*models.Tag, error)
    GetByTitles(ctx context.Context, titles []string) ([]*models.Tag, error)
}

// internal/repository/token_repository.go
type TokenRepository interface {
    Create(ctx context.Context, token *models.RefreshToken) error
    GetByHash(ctx context.Context, hash string) (*models.RefreshToken, error)
    Revoke(ctx context.Context, id uuid.UUID) error
    RevokeAllForUser(ctx context.Context, userID uuid.UUID) error
    DeleteExpired(ctx context.Context) (int64, error)
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC3.1 | Database connection succeeds with valid URL |
| TC3.2 | Database connection fails with invalid URL |
| TC3.3 | User repository creates user and returns generated ID |
| TC3.4 | User repository returns user by email |
| TC3.5 | Book repository creates book with tags |
| TC3.6 | Book repository lists books by owner with pagination |
| TC3.7 | Book repository searches with full-text query |
| TC3.8 | Tag repository returns all non-deleted tags |
| TC3.9 | Token repository creates and retrieves hashed token |
| TC3.10 | Token repository revokes token sets revoked_at |

**Acceptance Criteria**:
- [ ] Database connection pool is properly configured
- [ ] All repository interfaces are implemented
- [ ] SQL queries are parameterized (no SQL injection)
- [ ] Soft deletes work correctly (deleted_at is set, not hard delete)
- [ ] Pagination returns correct offset/limit
- [ ] Full-text search uses GIN index
- [ ] All tests pass with `go test ./internal/repository/...`

---

### Task 4: Models & DTOs

**Description**:
Define all domain models and create DTOs (Data Transfer Objects) for request/response handling. DTOs help separate internal models from API contracts.

**Model Definitions**:
```go
// internal/models/user.go
type User struct {
    ID           uuid.UUID  `db:"id" json:"id"`
    Email        string     `db:"email" json:"email"`
    PasswordHash string     `db:"password_hash" json:"-"`
    Role         string     `db:"role" json:"role"`
    LastLogin    *time.Time `db:"last_login" json:"last_login,omitempty"`
    CreatedAt    time.Time `db:"created_at" json:"created_at"`
    UpdatedAt    time.Time `db:"updated_at" json:"updated_at"`
    DeletedAt    *time.Time `db:"deleted_at" json:"-"`
}

// internal/models/book.go
type Book struct {
    ID        uuid.UUID `db:"id" json:"id"`
    Title     string    `db:"title" json:"title"`
    Content   string    `db:"content" json:"content"`
    OwnerID   uuid.UUID `db:"owner_id" json:"owner_id"`
    CreatedAt time.Time `db:"created_at" json:"created_at"`
    UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
    DeletedAt *time.Time `db:"deleted_at" json:"-"`
    Tags      []*Tag    `db:"-" json:"tags,omitempty"`
    Owner     *UserSummary `db:"-" json:"owner,omitempty"`
}

// internal/models/tag.go
type Tag struct {
    ID        uuid.UUID  `db:"id" json:"id"`
    Title     string     `db:"title" json:"title"`
    CreatedAt time.Time `db:"created_at" json:"created_at"`
    UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
    DeletedAt *time.Time `db:"deleted_at" json:"-"`
}

// internal/models/user_summary.go (embedded in book responses)
type UserSummary struct {
    ID    uuid.UUID `json:"id"`
    Email string    `json:"email"`
}

// internal/models/refresh_token.go
type RefreshToken struct {
    ID        uuid.UUID  `db:"id"`
    UserID    uuid.UUID  `db:"user_id"`
    TokenHash string     `db:"token_hash"`
    ExpiresAt time.Time  `db:"expires_at"`
    RevokedAt *time.Time `db:"revoked_at"`
    CreatedAt time.Time  `db:"created_at"`
}
```

**Request DTOs**:
```go
// internal/dto/request/auth.go
type RegisterRequest struct {
    Email       string   `json:"email" validate:"required,email"`
    Password    string   `json:"password" validate:"required,min=8,max=72"`
    Preferences []string `json:"preferences" validate:"dive,max=100"`
}

type LoginRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required"`
}

type RefreshTokenRequest struct {
    RefreshToken string `json:"refresh_token" validate:"required"`
}

// internal/dto/request/book.go
type CreateBookRequest struct {
    Title   string   `json:"title" validate:"required,min=1,max=500"`
    Content string   `json:"content" validate:"required,min=1"`
    Tags    []string `json:"tags" validate:"dive,max=100"`
}

type UpdateBookRequest struct {
    Title   *string  `json:"title" validate:"omitempty,min=1,max=500"`
    Content *string  `json:"content" validate:"omitempty,min=1"`
    Tags    []string `json:"tags" validate:"dive,max=100"`
}

// internal/dto/request/tag.go
type CreateTagRequest struct {
    Title string `json:"title" validate:"required,min=1,max=100"`
}

// internal/dto/request/user.go
type UpdatePreferencesRequest struct {
    Preferences []string `json:"preferences" validate:"dive,max=100"`
}
```

**Response DTOs**:
```go
// internal/dto/response/response.go
type ErrorResponse struct {
    Error ErrorDetail `json:"error"`
}

type ErrorDetail struct {
    Code    string `json:"code"`
    Message string `json:"message"`
}

// internal/dto/response/auth.go
type LoginResponse struct {
    Token        string `json:"token"`
    RefreshToken string `json:"refresh_token"`
    ExpiresIn    int64  `json:"expires_in"`
}

type UserResponse struct {
    ID          uuid.UUID `json:"id"`
    Email       string    `json:"email"`
    Role        string    `json:"role"`
    LastLogin   *time.Time `json:"last_login,omitempty"`
    Preferences []string  `json:"preferences,omitempty"`
}

// internal/dto/response/book.go
type BookResponse struct {
    ID        uuid.UUID       `json:"id"`
    Title     string          `json:"title"`
    Content   string          `json:"content"`
    Tags      []string        `json:"tags"`
    CreatedAt time.Time       `json:"created_at"`
    Owner     *UserSummary    `json:"owner,omitempty"`
}

type BookListResponse struct {
    Data       []BookResponse `json:"data"`
    Pagination Pagination     `json:"pagination"`
}

type Pagination struct {
    Page       int `json:"page"`
    Limit      int `json:"limit"`
    Total      int `json:"total"`
    TotalPages int `json:"total_pages"`
}

// internal/dto/response/tag.go
type TagResponse struct {
    ID    uuid.UUID `json:"id"`
    Title string   `json:"title"`
}

type TagListResponse struct {
    Data []TagResponse `json:"data"`
}

// internal/dto/response/user.go
type PreferencesResponse struct {
    Preferences []string `json:"preferences"`
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC4.1 | RegisterRequest validates email format |
| TC4.2 | RegisterRequest validates password length (8-72 chars) |
| TC4.3 | CreateBookRequest validates title length (1-500 chars) |
| TC4.4 | UpdateBookRequest allows partial updates |
| TC4.5 | ErrorResponse matches specified JSON structure |
| TC4.6 | BookListResponse includes pagination fields |
| TC4.7 | UserResponse excludes password_hash |
| TC4.8 | Empty preferences array is properly serialized |

**Acceptance Criteria**:
- [ ] All models have proper JSON/db tags
- [ ] Request DTOs use validator tags for input validation
- [ ] Response DTOs match API.md exactly
- [ ] Password hash is never exposed in JSON responses
- [ ] All timestamps use time.Time with proper serialization
- [ ] Validator integration works correctly

---

### Task 5: Authentication Service & JWT Handling

**Description**:
Implement authentication logic including user registration, login, JWT generation/validation, and token refresh. This is critical security code - pay attention to edge cases.

**Key Implementation Details**:

```go
// internal/service/auth_service.go
type AuthService struct {
    userRepo  repository.UserRepository
    tokenRepo repository.TokenRepository
    cfg       config.JWTConfig
}

func (s *AuthService) Register(ctx context.Context, req *dto.RegisterRequest) (*dto.UserResponse, error) {
    // 1. Check if email already exists
    existing, _ := s.userRepo.GetByEmail(ctx, req.Email)
    if existing != nil && existing.DeletedAt == nil {
        return nil, ErrEmailExists
    }
    
    // 2. Hash password with bcrypt (cost 12)
    hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
    if err != nil {
        return nil, fmt.Errorf("failed to hash password: %w", err)
    }
    
    // 3. Create user
    user := &models.User{
        Email:        req.Email,
        PasswordHash: string(hash),
        Role:         "user",
    }
    
    if err := s.userRepo.Create(ctx, user); err != nil {
        return nil, err
    }
    
    // 4. Set preferences (create tags if needed)
    if len(req.Preferences) > 0 {
        // Create tags and link to user
    }
    
    return toUserResponse(user, req.Preferences), nil
}

func (s *AuthService) Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error) {
    // 1. Find user by email
    user, err := s.userRepo.GetByEmail(ctx, req.Email)
    if err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 2. Verify password
    if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 3. Generate tokens
    accessToken, err := s.generateAccessToken(user)
    if err != nil {
        return nil, err
    }
    
    refreshToken, err := s.generateRefreshToken(user)
    if err != nil {
        return nil, err
    }
    
    // 4. Update last_login
    s.userRepo.UpdateLastLogin(ctx, user.ID)
    
    return &dto.LoginResponse{
        Token:        accessToken,
        RefreshToken: refreshToken,
        ExpiresIn:    int64(s.cfg.Expiry.Seconds()),
    }, nil
}

func (s *AuthService) generateAccessToken(user *models.User) (string, error) {
    claims := jwt.MapClaims{
        "sub":   user.ID.String(),
        "email": user.Email,
        "role":  user.Role,
        "exp":   time.Now().Add(s.cfg.Expiry).Unix(),
        "iat":   time.Now().Unix(),
    }
    
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(s.cfg.Secret))
}

func (s *AuthService) generateRefreshToken(user *models.User) (string, error) {
    rawToken := uuid.New().String() // Use crypto/rand in production
    
    hash := sha256.Sum256([]byte(rawToken))
    hashStr := hex.EncodeToString(hash[:])
    
    token := &models.RefreshToken{
        UserID:    user.ID,
        TokenHash: hashStr,
        ExpiresAt: time.Now().Add(s.cfg.RefreshExpiry),
    }
    
    if err := s.tokenRepo.Create(ctx, token); err != nil {
        return "", err
    }
    
    return rawToken, nil // Return raw token to client (only time)
}

func (s *AuthService) RefreshTokens(ctx context.Context, rawToken string) (*dto.LoginResponse, error) {
    // 1. Hash the token
    hash := sha256.Sum256([]byte(rawToken))
    hashStr := hex.EncodeToString(hash[:])
    
    // 2. Find token in DB
    token, err := s.tokenRepo.GetByHash(ctx, hashStr)
    if err != nil {
        return nil, ErrInvalidToken
    }
    
    // 3. Check if revoked
    if token.RevokedAt != nil {
        return nil, ErrTokenRevoked
    }
    
    // 4. Check if expired
    if time.Now().After(token.ExpiresAt) {
        return nil, ErrTokenExpired
    }
    
    // 5. Revoke old token (rotation)
    if err := s.tokenRepo.Revoke(ctx, token.ID); err != nil {
        return nil, err
    }
    
    // 6. Get user and generate new tokens
    user, err := s.userRepo.GetByID(ctx, token.UserID)
    if err != nil {
        return nil, err
    }
    
    return s.Login(ctx, &dto.LoginRequest{
        Email:    user.Email,
        Password: "", // Not needed for refresh
    })
}
```

**JWT Middleware**:
```go
// internal/middleware/auth.go
func JWTAuth(secret string) fiber.Handler {
    return func(c *fiber.Ctx) error {
        authHeader := c.Get("Authorization")
        if authHeader == "" {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Missing authorization header")
        }
        
        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Invalid authorization header format")
        }
        
        tokenString := parts[1]
        
        token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
            if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
            }
            return []byte(secret), nil
        })
        
        if err != nil || !token.Valid {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired token")
        }
        
        claims, ok := token.Claims.(jwt.MapClaims)
        if !ok {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Invalid token claims")
        }
        
        // Store user info in context
        c.Locals("userID", claims["sub"])
        c.Locals("userRole", claims["role"])
        c.Locals("userEmail", claims["email"])
        
        return c.Next()
    }
}

// Helper to get user from context
func GetUserID(c *fiber.Ctx) (uuid.UUID, error) {
    idStr := c.Locals("userID").(string)
    return uuid.Parse(idStr)
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC5.1 | Registration creates user with hashed password |
| TC5.2 | Registration fails with duplicate email |
| TC5.3 | Registration fails with weak password (< 8 chars) |
| TC5.4 | Login succeeds with valid credentials |
| TC5.5 | Login fails with invalid email |
| TC5.6 | Login fails with wrong password |
| TC5.7 | JWT token contains correct claims |
| TC5.8 | JWT middleware rejects expired token |
| TC5.9 | JWT middleware rejects malformed token |
| TC5.10 | Refresh token rotation works |
| TC5.11 | Refresh fails with revoked token |
| TC5.12 | Refresh fails with expired token |

**Acceptance Criteria**:
- [ ] Passwords are hashed with bcrypt (cost >= 10)
- [ ] JWT tokens contain user ID, email, role, expiry
- [ ] Refresh tokens are hashed with SHA-256 before storage
- [ ] Token rotation is implemented (old token revoked on refresh)
- [ ] Middleware correctly extracts and validates JWT
- [ ] User ID is accessible from context in handlers
- [ ] All authentication endpoints return correct error codes

---

### Task 6: Book Service & Handlers

**Description**:
Implement book/recommendation CRUD operations and the recommendation engine (filtering by user preferences).

**Recommendation Logic**:
The main `/books` endpoint should return books that match the authenticated user's preferences (tags).

```go
// internal/service/book_service.go
func (s *BookService) ListByPreferences(ctx context.Context, userID uuid.UUID, page, limit int) (*dto.BookListResponse, error) {
    // 1. Get user's preferences (tag IDs)
    prefs, err := s.userRepo.GetPreferences(ctx, userID)
    if err != nil {
        return nil, err
    }
    
    if len(prefs) == 0 {
        return &dto.BookListResponse{
            Data:       []dto.BookResponse{},
            Pagination: dto.Pagination{Page: page, Limit: limit, Total: 0, TotalPages: 0},
        }, nil
    }
    
    // 2. Get tag IDs
    tagIDs := make([]uuid.UUID, len(prefs))
    for i, p := range prefs {
        tagIDs[i] = p.TagID
    }
    
    // 3. List books with matching tags, ordered by created_at DESC
    offset := (page - 1) * limit
    books, total, err := s.bookRepo.ListByTags(ctx, tagIDs, limit, offset)
    if err != nil {
        return nil, err
    }
    
    // 4. Load owner info and tags for each book
    bookResponses := make([]dto.BookResponse, len(books))
    for i, book := range books {
        bookResponses[i] = s.toBookResponse(book)
    }
    
    totalPages := int(math.Ceil(float64(total) / float64(limit)))
    
    return &dto.BookListResponse{
        Data: bookResponses,
        Pagination: dto.Pagination{
            Page:       page,
            Limit:      limit,
            Total:      total,
            TotalPages: totalPages,
        },
    }, nil
}

func (s *BookService) Create(ctx context.Context, userID uuid.UUID, req *dto.CreateBookRequest) (*dto.BookResponse, error) {
    // 1. Create book
    book := &models.Book{
        Title:   req.Title,
        Content: req.Content,
        OwnerID: userID,
    }
    
    if err := s.bookRepo.Create(ctx, book); err != nil {
        return nil, err
    }
    
    // 2. Process tags
    if len(req.Tags) > 0 {
        // Get or create tags
        tagIDs, err := s.getOrCreateTags(ctx, req.Tags)
        if err != nil {
            return nil, err
        }
        
        if err := s.bookRepo.AddTags(ctx, book.ID, tagIDs); err != nil {
            return nil, err
        }
        
        book.Tags, _ = s.tagRepo.GetByIDs(ctx, tagIDs)
    }
    
    return s.toBookResponse(book), nil
}

func (s *BookService) Search(ctx context.Context, userID uuid.UUID, query string, tags []string, page, limit int) (*dto.BookListResponse, error) {
    offset := (page - 1) * limit
    
    var books []*models.Book
    var total int
    var err error
    
    tagIDs := []uuid.UUID{}
    if len(tags) > 0 {
        tagIDs, err = s.getOrCreateTags(ctx, tags)
        if err != nil {
            return nil, err
        }
    }
    
    if query != "" {
        // Full-text search
        books, total, err = s.bookRepo.Search(ctx, query, tagIDs, limit, offset)
    } else if len(tagIDs) > 0 {
        // Filter by tags only
        books, total, err = s.bookRepo.ListByTags(ctx, tagIDs, limit, offset)
    } else {
        // Return all books
        books, total, err = s.bookRepo.ListAll(ctx, limit, offset)
    }
    
    if err != nil {
        return nil, err
    }
    
    // Build response
    bookResponses := make([]dto.BookResponse, len(books))
    for i, book := range books {
        bookResponses[i] = s.toBookResponse(book)
    }
    
    totalPages := int(math.Ceil(float64(total) / float64(limit)))
    
    return &dto.BookListResponse{
        Data: bookResponses,
        Pagination: dto.Pagination{
            Page:       page,
            Limit:      limit,
            Total:      total,
            TotalPages: totalPages,
        },
    }, nil
}
```

**Book Handlers**:
```go
// internal/handler/book_handler.go
type BookHandler struct {
    bookService service.BookService
}

func (h *BookHandler) RegisterRoutes(router fiber.Router) {
    books := router.Group("/books")
    books.Get("/", h.List)
    books.Get("/search", h.Search)
    books.Get("/:id", h.Get)
    books.Post("/", h.Create)
    books.Put("/:id", h.Update)
    books.Delete("/:id", h.Delete)
}

func (h *BookHandler) List(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    page := c.QueryInt("page", 1)
    limit := c.QueryInt("limit", 10)
    
    if page < 1 {
        page = 1
    }
    if limit < 1 || limit > 100 {
        limit = 10
    }
    
    result, err := h.bookService.ListByPreferences(c.UserContext(), userID, page, limit)
    if err != nil {
        return err
    }
    
    return c.JSON(result)
}

func (h *BookHandler) Get(c *fiber.Ctx) error {
    bookID, err := uuid.Parse(c.Params("id"))
    if err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid book ID")
    }
    
    book, err := h.bookService.GetByID(c.UserContext(), bookID)
    if err != nil {
        if errors.Is(err, service.ErrNotFound) {
            return response.Error(c, fiber.StatusNotFound, "NOT_FOUND", "Book not found")
        }
        return err
    }
    
    return c.JSON(book)
}

func (h *BookHandler) Create(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    var req dto.CreateBookRequest
    if err := c.BodyParser(&req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
    }
    
    if err := validator.Validate.Struct(req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", err.Error())
    }
    
    book, err := h.bookService.Create(c.UserContext(), userID, &req)
    if err != nil {
        return err
    }
    
    return c.Status(fiber.StatusCreated).JSON(book)
}

func (h *BookHandler) Update(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    bookID, err := uuid.Parse(c.Params("id"))
    if err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid book ID")
    }
    
    var req dto.UpdateBookRequest
    if err := c.BodyParser(&req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
    }
    
    if err := validator.Validate.Struct(req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", err.Error())
    }
    
    err = h.bookService.Update(c.UserContext(), userID, bookID, &req)
    if err != nil {
        if errors.Is(err, service.ErrForbidden) {
            return response.Error(c, fiber.StatusForbidden, "FORBIDDEN", "You can only update your own books")
        }
        if errors.Is(err, service.ErrNotFound) {
            return response.Error(c, fiber.StatusNotFound, "NOT_FOUND", "Book not found")
        }
        return err
    }
    
    return c.SendStatus(fiber.StatusNoContent)
}

func (h *BookHandler) Delete(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    bookID, err := uuid.Parse(c.Params("id"))
    if err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid book ID")
    }
    
    err = h.bookService.Delete(c.UserContext(), userID, bookID)
    if err != nil {
        if errors.Is(err, service.ErrForbidden) {
            return response.Error(c, fiber.StatusForbidden, "FORBIDDEN", "You can only delete your own books")
        }
        if errors.Is(err, service.ErrNotFound) {
            return response.Error(c, fiber.StatusNotFound, "NOT_FOUND", "Book not found")
        }
        return err
    }
    
    return c.SendStatus(fiber.StatusNoContent)
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC6.1 | List books returns only books with matching user preferences |
| TC6.2 | List books with no preferences returns empty list |
| TC6.3 | List books respects pagination |
| TC6.4 | Search by full-text query returns matching books |
| TC6.5 | Search by tags returns books with those tags |
| TC6.6 | Search combines query and tags (AND logic) |
| TC6.7 | Create book succeeds with valid data |
| TC6.8 | Create book with new tags creates tags first |
| TC6.9 | Create book with existing tags reuses them |
| TC6.10 | Update book succeeds for owner |
| TC6.11 | Update book fails for non-owner (FORBIDDEN) |
| TC6.12 | Delete book succeeds for owner |
| TC6.13 | Delete book fails for non-owner (FORBIDDEN) |
| TC6.14 | Get book by ID returns book with owner info |
| TC6.15 | Get non-existent book returns NOT_FOUND |

**Acceptance Criteria**:
- [ ] `/books` filters by user's preference tags
- [ ] `/books` orders by created_at DESC (newest first)
- [ ] `/books/search` supports full-text search
- [ ] `/books/search` supports tag filtering
- [ ] Only owners can update/delete their books
- [ ] Pagination works correctly
- [ ] Books include owner summary (id, email)
- [ ] All timestamps are in ISO 8601 UTC format
- [ ] Proper HTTP status codes for all scenarios

---

### Task 7: Tag Service & Handlers

**Description**:
Implement tag management including listing all tags and admin-only tag creation.

```go
// internal/service/tag_service.go
func (s *TagService) ListAll(ctx context.Context) (*dto.TagListResponse, error) {
    tags, err := s.tagRepo.GetAll(ctx)
    if err != nil {
        return nil, err
    }
    
    responses := make([]dto.TagResponse, len(tags))
    for i, tag := range tags {
        responses[i] = dto.TagResponse{
            ID:    tag.ID,
            Title: tag.Title,
        }
    }
    
    return &dto.TagListResponse{Data: responses}, nil
}

func (s *TagService) Create(ctx context.Context, req *dto.CreateTagRequest) (*dto.TagResponse, error) {
    tag := &models.Tag{
        Title: req.Title,
    }
    
    if err := s.tagRepo.Create(ctx, tag); err != nil {
        if errors.Is(err, repository.ErrDuplicateTitle) {
            return nil, ErrTagAlreadyExists
        }
        return nil, err
    }
    
    return &dto.TagResponse{
        ID:    tag.ID,
        Title: tag.Title,
    }, nil
}
```

**Tag Handlers**:
```go
// internal/handler/tag_handler.go
func (h *TagHandler) RegisterRoutes(router fiber.Router) {
    tags := router.Group("/tags")
    tags.Get("/", h.List)
    tags.Post("/", middleware.AdminOnly(), h.Create)
}

// Admin middleware
func AdminOnly() fiber.Handler {
    return func(c *fiber.Ctx) error {
        role := c.Locals("userRole").(string)
        if role != "admin" {
            return response.Error(c, fiber.StatusForbidden, "FORBIDDEN", "Admin access required")
        }
        return c.Next()
    }
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC7.1 | List tags returns all non-deleted tags |
| TC7.2 | List tags returns empty array when no tags exist |
| TC7.3 | Create tag succeeds for admin |
| TC7.4 | Create tag fails for non-admin (FORBIDDEN) |
| TC7.5 | Create tag fails with duplicate title (CONFLICT) |
| TC7.6 | Create tag validates title length |

**Acceptance Criteria**:
- [ ] `/tags` GET returns all active tags
- [ ] `/tags` POST is restricted to admin users
- [ ] Tag creation prevents duplicates
- [ ] Non-existent tags in book creation are auto-created

---

### Task 8: User Service & Handlers

**Description**:
Implement user profile endpoints including preferences management.

```go
// internal/service/user_service.go
func (s *UserService) GetByID(ctx context.Context, id uuid.UUID) (*dto.UserResponse, error) {
    user, err := s.userRepo.GetByID(ctx, id)
    if err != nil {
        if errors.Is(err, repository.ErrNotFound) {
            return nil, ErrUserNotFound
        }
        return nil, err
    }
    
    prefs, _ := s.userRepo.GetPreferences(ctx, id)
    prefTitles := make([]string, len(prefs))
    for i, p := range prefs {
        prefTitles[i] = p.Tag.Title
    }
    
    return &dto.UserResponse{
        ID:          user.ID,
        Email:       user.Email,
        Role:        user.Role,
        LastLogin:   user.LastLogin,
        Preferences: prefTitles,
    }, nil
}

func (s *UserService) GetPreferences(ctx context.Context, userID uuid.UUID) (*dto.PreferencesResponse, error) {
    prefs, err := s.userRepo.GetPreferences(ctx, userID)
    if err != nil {
        return nil, err
    }
    
    titles := make([]string, len(prefs))
    for i, p := range prefs {
        titles[i] = p.Tag.Title
    }
    
    return &dto.PreferencesResponse{Preferences: titles}, nil
}

func (s *UserService) UpdatePreferences(ctx context.Context, userID uuid.UUID, req *dto.UpdatePreferencesRequest) error {
    // 1. Delete existing preferences
    if err := s.userRepo.DeletePreferences(ctx, userID); err != nil {
        return err
    }
    
    // 2. Get or create tags
    if len(req.Preferences) > 0 {
        tagIDs, err := s.getOrCreateTags(ctx, req.Preferences)
        if err != nil {
            return err
        }
        
        // 3. Create new preferences
        if err := s.userRepo.SetPreferences(ctx, userID, tagIDs); err != nil {
            return err
        }
    }
    
    return nil
}

func (s *UserService) GetMyRecommendations(ctx context.Context, userID uuid.UUID, page, limit int) (*dto.BookListResponse, error) {
    offset := (page - 1) * limit
    books, total, err := s.bookRepo.ListByOwner(ctx, userID, limit, offset)
    if err != nil {
        return nil, err
    }
    
    bookResponses := make([]dto.BookResponse, len(books))
    for i, book := range books {
        bookResponses[i] = s.bookService.ToBookResponse(book)
    }
    
    totalPages := int(math.Ceil(float64(total) / float64(limit)))
    
    return &dto.BookListResponse{
        Data: bookResponses,
        Pagination: dto.Pagination{
            Page:       page,
            Limit:      limit,
            Total:      total,
            TotalPages: totalPages,
        },
    }, nil
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC8.1 | Get user by ID returns user profile |
| TC8.2 | Get user by ID returns NOT_FOUND for non-existent user |
| TC8.3 | Get preferences returns user's preference tags |
| TC8.4 | Update preferences replaces existing preferences |
| TC8.5 | Update preferences with empty array clears all |
| TC8.6 | Update preferences creates new tags if needed |
| TC8.7 | Get my recommendations returns only user's books |
| TC8.8 | Get my recommendations excludes deleted books |
| TC8.9 | Get my recommendations respects pagination |

**Acceptance Criteria**:
- [ ] `/users/:id` returns user profile (without password)
- [ ] `/users/me/preferences` returns current user's preferences
- [ ] `/users/me/preferences` PUT updates preferences
- [ ] `/users/me/recommendations` returns paginated list
- [ ] User can only see their own preferences

---

### Task 9: HTTP Server & Routing Setup

**Description**:
Wire everything together in main.go, set up routing, error handling, and graceful shutdown.

```go
// cmd/server/main.go
func main() {
    // 1. Load configuration
    cfg, err := config.Load()
    if err != nil {
        log.Fatal().Err(err).Msg("Failed to load configuration")
    }
    
    // 2. Initialize database
    db, err := database.NewPostgresDB(cfg.Database)
    if err != nil {
        log.Fatal().Err(err).Msg("Failed to connect to database")
    }
    defer db.Close()
    
    // 3. Run migrations
    if err := database.RunMigrations(db, cfg.Database.URL, "./migrations"); err != nil {
        log.Fatal().Err(err).Msg("Failed to run migrations")
    }
    
    // 4. Initialize repositories
    userRepo := repository.NewUserRepository(db)
    bookRepo := repository.NewBookRepository(db)
    tagRepo := repository.NewTagRepository(db)
    tokenRepo := repository.NewTokenRepository(db)
    
    // 5. Initialize services
    authService := service.NewAuthService(userRepo, tokenRepo, cfg.JWT)
    bookService := service.NewBookService(bookRepo, tagRepo)
    tagService := service.NewTagService(tagRepo)
    userService := service.NewUserService(userRepo, bookRepo, tagRepo)
    
    // 6. Initialize handlers
    authHandler := handler.NewAuthHandler(authService)
    bookHandler := handler.NewBookHandler(bookService)
    tagHandler := handler.NewTagHandler(tagService)
    userHandler := handler.NewUserHandler(userService)
    
    // 7. Initialize Fiber app
    app := fiber.New(fiber.Config{
        AppName:      "Super Books API",
        ErrorHandler: middleware.ErrorHandler,
    })
    
    // 8. Setup routes
    setupRoutes(app, cfg, authHandler, bookHandler, tagHandler, userHandler)
    
    // 9. Start server
    go func() {
        addr := fmt.Sprintf(":%s", cfg.Server.Port)
        log.Info().Str("addr", addr).Msg("Starting server")
        if err := app.Listen(addr); err != nil {
            log.Fatal().Err(err).Msg("Server failed")
        }
    }()
    
    // 10. Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    log.Info().Msg("Shutting down server...")
    if err := app.Shutdown(); err != nil {
        log.Error().Err(err).Msg("Server forced to shutdown")
    }
}

func setupRoutes(
    app *fiber.App,
    cfg *config.Config,
    authHandler *handler.AuthHandler,
    bookHandler *handler.BookHandler,
    tagHandler *handler.TagHandler,
    userHandler *handler.UserHandler,
) {
    // Health check
    app.Get("/health", func(c *fiber.Ctx) error {
        return c.JSON(fiber.Map{"status": "ok"})
    })
    
    // Public routes
    auth := app.Group("/auth")
    auth.Post("/register", authHandler.Register)
    auth.Post("/login", authHandler.Login)
    auth.Post("/refresh", authHandler.Refresh)
    
    // Protected routes
    jwtAuth := middleware.JWTAuth(cfg.JWT.Secret)
    
    protected := app.Group("/", jwtAuth)
    
    // Auth
    protected.Get("/auth/me", authHandler.Me)
    
    // Books
    bookHandler.RegisterRoutes(protected)
    
    // Tags
    tagHandler.RegisterRoutes(protected)
    
    // Users
    protected.Get("/users/:id", userHandler.GetByID)
    protected.Get("/users/me/preferences", userHandler.GetPreferences)
    protected.Put("/users/me/preferences", userHandler.UpdatePreferences)
    protected.Get("/users/me/recommendations", userHandler.GetMyRecommendations)
}
```

**Error Handler Middleware**:
```go
// internal/middleware/error.go
func ErrorHandler(c *fiber.Ctx, err error) error {
    code := fiber.StatusInternalServerError
    errorCode := "INTERNAL_ERROR"
    message := "An unexpected error occurred"
    
    if e, ok := err.(*fiber.Error); ok {
        code = e.Code
        message = e.Message
    }
    
    return c.Status(code).JSON(dto.ErrorResponse{
        Error: dto.ErrorDetail{
            Code:    errorCode,
            Message: message,
        },
    })
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC9.1 | Server starts and listens on configured port |
| TC9.2 | Health check endpoint returns 200 |
| TC9.3 | Protected endpoints return 401 without token |
| TC9.4 | Graceful shutdown completes in-flight requests |
| TC9.5 | Unknown routes return 404 |
| TC9.6 | Server binds to all interfaces (0.0.0.0) |

**Acceptance Criteria**:
- [ ] Server starts without errors
- [ ] All routes are registered correctly
- [ ] Public routes don't require authentication
- [ ] Protected routes require valid JWT
- [ ] Graceful shutdown works on SIGTERM/SIGINT
- [ ] Application name appears in responses

---

### Task 10: Input Validation

**Description**:
Implement comprehensive input validation using go-playground/validator.

```go
// internal/validator/validator.go
var validate *validator.Validate

func Init() {
    validate = validator.New()
    
    // Register custom validation for password strength
    validate.RegisterValidation("password", func(fl validator.FieldLevel) bool {
        password := fl.Field().String()
        // At least 8 chars, 1 uppercase, 1 lowercase, 1 digit
        var hasUpper, hasLower, hasDigit bool
        for _, c := range password {
            switch {
            case c >= 'A' && c <= 'Z':
                hasUpper = true
            case c >= 'a' && c <= 'z':
                hasLower = true
            case c >= '0' && c <= '9':
                hasDigit = true
            }
        }
        return len(password) >= 8 && hasUpper && hasLower && hasDigit
    })
}

func Validate(s interface{}) error {
    return validate.Struct(s)
}

func ValidationErrors(err error) []string {
    var errors []string
    for _, e := range err.(validator.ValidationErrors) {
        errors = append(errors, fmt.Sprintf("field '%s' %s", e.Field(), e.Tag()))
    }
    return errors
}
```

**Validation Rules Summary**:
| Field | Rules |
|-------|-------|
| User.email | required, valid email format |
| User.password | required, min=8, max=72 |
| Book.title | required, min=1, max=500 |
| Book.content | required, min=1 |
| Tag.title | required, min=1, max=100 |
| Pagination.page | min=1 |
| Pagination.limit | min=1, max=100 |

**Test Cases**:
| ID | Description |
|----|-------------|
| TC10.1 | Empty email returns validation error |
| TC10.2 | Invalid email format returns validation error |
| TC10.3 | Password < 8 chars returns validation error |
| TC10.4 | Title > 500 chars returns validation error |
| TC10.5 | Valid registration passes validation |
| TC10.6 | Multiple validation errors are collected |

**Acceptance Criteria**:
- [ ] All request DTOs are validated
- [ ] Validation errors return 400 with details
- [ ] Custom password validation works
- [ ] Pagination limits are enforced

---

### Task 11: Error Handling & Logging

**Description**:
Implement consistent error handling throughout the application with structured logging.

```go
// internal/errors/errors.go
var (
    ErrNotFound       = errors.New("resource not found")
    ErrForbidden      = errors.New("access denied")
    ErrUnauthorized   = errors.New("unauthorized")
    ErrEmailExists    = errors.New("email already exists")
    ErrInvalidToken   = errors.New("invalid token")
    ErrTokenExpired   = errors.New("token expired")
    ErrTokenRevoked   = errors.New("token revoked")
    ErrInvalidCredentials = errors.New("invalid credentials")
)

// internal/service/errors.go
func (s *BookService) Update(...) error {
    book, err := s.bookRepo.GetByID(ctx, id)
    if err != nil {
        if errors.Is(err, repository.ErrNotFound) {
            return ErrNotFound
        }
        return err
    }
    
    if book.OwnerID != userID {
        return ErrForbidden
    }
    
    // ... update logic
}

// Logging setup with zerolog
func init() {
    zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
    log.Logger = zerolog.New(os.Stdout).With().Timestamp().Caller().Logger()
}
```

**Structured Logging**:
```go
// In services and handlers
func (s *BookService) Create(ctx context.Context, userID uuid.UUID, req *dto.CreateBookRequest) (*dto.BookResponse, error) {
    log.Info().
        Str("user_id", userID.String()).
        Str("title", req.Title).
        Msg("Creating new book")
    
    // ... implementation
    
    log.Info().
        Str("book_id", book.ID.String()).
        Str("user_id", userID.String()).
        Msg("Book created successfully")
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC11.1 | NOT_FOUND error maps to 404 HTTP status |
| TC11.2 | FORBIDDEN error maps to 403 HTTP status |
| TC11.3 | UNAUTHORIZED error maps to 401 HTTP status |
| TC11.4 | CONFLICT error maps to 409 HTTP status |
| TC11.5 | VALIDATION_ERROR maps to 400 HTTP status |
| TC11.6 | Logs are structured JSON |
| TC11.7 | Sensitive data is not logged |

**Acceptance Criteria**:
- [ ] All errors follow the API.md format
- [ ] Error codes match specification
- [ ] Logs include request context
- [ ] Passwords/tokens never appear in logs

---

### Task 12: Integration Tests

**Description**:
Write integration tests that test the full request/response cycle against a real database.

**Test Setup**:
```go
// internal/integration_test.go
func TestMain(m *testing.M) {
    // Setup test database
    os.Setenv("DATABASE_URL", "postgres://test:test@localhost:5432/test_db?sslmode=disable")
    
    db, err := database.NewPostgresDB(config.DatabaseConfig{
        URL: os.Getenv("DATABASE_URL"),
    })
    if err != nil {
        log.Fatal(err)
    }
    
    // Run migrations
    if err := database.RunMigrations(db, "./migrations"); err != nil {
        log.Fatal(err)
    }
    
    code := m.Run()
    
    // Teardown
    db.Close()
    os.Exit(code)
}

func TestAuthIntegration(t *testing.T) {
    app := fiber.New()
    // ... setup routes
    
    t.Run("Register and Login", func(t *testing.T) {
        // Register
        resp, err := http.Post("http://localhost:8080/auth/register", "application/json",
            strings.NewReader(`{"email":"test@example.com","password":"Password123"}`))
        
        require.NoError(t, err)
        assert.Equal(t, 201, resp.StatusCode)
        
        // Login
        resp, err = http.Post("http://localhost:8080/auth/login", "application/json",
            strings.NewReader(`{"email":"test@example.com","password":"Password123"}`))
        
        require.NoError(t, err)
        assert.Equal(t, 200, resp.StatusCode)
        
        var loginResp dto.LoginResponse
        json.NewDecoder(resp.Body).Decode(&loginResp)
        assert.NotEmpty(t, loginResp.Token)
    })
}
```

**Integration Test Scenarios**:
| ID | Description |
|----|-------------|
| TC12.1 | Full auth flow: register → login → access protected endpoint |
| TC12.2 | Create book and verify in database |
| TC12.3 | Update book as owner succeeds |
| TC12.4 | Update book as non-owner fails |
| TC12.5 | Search books with preferences |
| TC12.6 | Pagination works correctly |
| TC12.7 | Token refresh flow |
| TC12.8 | Admin can create tags |
| TC12.9 | Non-admin cannot create tags |
| TC12.10 | Concurrent requests don't corrupt data |

**Acceptance Criteria**:
- [ ] All integration tests pass
- [ ] Tests use isolated database transactions
- [ ] Tests clean up after themselves
- [ ] Tests can run in CI/CD pipeline

---

### Task 13: Code Quality & Polish

**Description**:
Final code quality improvements: linting, formatting, documentation, and final review.

**Lint Configuration (.golangci.yml)**:
```yaml
linters:
  enable:
    - gofmt
    - golint
    - govet
    - errcheck
    - staticcheck
    - unused
    - gosimple
    - structcheck
    - varcheck
    - ineffassign
    - deadcode
    - typecheck
    - gosec

linters-settings:
  gosec:
    excludes:
      - G104  # Unhandled errors
  govet:
    enable-all = true
  golint:
    min-confidence = 0

issues:
  exclude-use-default = false
  max-issues-per-linter = 0
  max-same-issues = 0
```

**Makefile Additions**:
```makefile
fmt:
	gofmt -s -w .
	
lint-full:
	golangci-lint run --new-from-rev=HEAD~1
	
check: fmt lint test
```

**Test Coverage Goal**:
```makefile
coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"
```

**Final Checklist**:
- [ ] `make fmt` passes
- [ ] `make lint` passes
- [ ] `make test` passes with >70% coverage
- [ ] `make test/integration` passes
- [ ] All endpoints respond correctly
- [ ] Error responses match API.md
- [ ] No hardcoded secrets/credentials
- [ ] README is updated with setup instructions

---

## Implementation Order

```
1. Task 1: Project Initialization & Configuration
   ↓
2. Task 2: Database Migrations
   ↓
3. Task 3: Database Connection & Repository Layer
   ↓
4. Task 4: Models & DTOs
   ↓
5. Task 5: Authentication Service & JWT Handling
   ↓
6. Task 6: Book Service & Handlers
   ↓
7. Task 7: Tag Service & Handlers
   ↓
8. Task 8: User Service & Handlers
   ↓
9. Task 10: Input Validation
   ↓
10. Task 11: Error Handling & Logging
   ↓
11. Task 9: HTTP Server & Routing Setup
   ↓
12. Task 12: Integration Tests
   ↓
13. Task 13: Code Quality & Polish
```

---

## Quick Start Commands

```bash
# First time setup
make setup

# Start development
make run

# Run tests
make test

# Run with live reload
docker compose up

# Stop everything
make clean
```

---

## API Quick Reference

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/register` | No | Register user |
| POST | `/auth/login` | No | Login, get JWT |
| POST | `/auth/refresh` | No | Refresh JWT |
| GET | `/auth/me` | Yes | Current user |
| GET | `/books` | Yes | List by preferences |
| GET | `/books/search` | Yes | Search books |
| GET | `/books/:id` | Yes | Get book |
| POST | `/books` | Yes | Create book |
| PUT | `/books/:id` | Yes | Update book (owner) |
| DELETE | `/books/:id` | Yes | Delete book (owner) |
| GET | `/tags` | Yes | List tags |
| POST | `/tags` | Yes (Admin) | Create tag |
| GET | `/users/:id` | Yes | Get user |
| GET | `/users/me/preferences` | Yes | Get preferences |
| PUT | `/users/me/preferences` | Yes | Update preferences |
| GET | `/users/me/recommendations` | Yes | My books |
