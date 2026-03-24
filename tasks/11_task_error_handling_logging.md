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
