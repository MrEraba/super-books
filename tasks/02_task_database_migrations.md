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
