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
