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
