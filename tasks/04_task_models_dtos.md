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
