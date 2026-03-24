# Database Design - Books Recommendation API

## Overview

This document describes the PostgreSQL database schema for the Books Recommendation API.
It covers all tables, relationships, indexes, constraints, and migration strategy.

## Technology Choices

| Concern            | Choice                  | Rationale                                                                 |
|--------------------|-------------------------|---------------------------------------------------------------------------|
| Database           | PostgreSQL              | UUID support, full-text search (GIN), partial unique indexes, TIMESTAMPTZ |
| Primary Keys       | UUID v4                 | Non-sequential, safe for public exposure, generated via `gen_random_uuid()` |
| Timestamps         | TIMESTAMPTZ             | Timezone-aware, matches API's ISO 8601 UTC requirement                    |
| Deletion Strategy  | Soft deletes            | `deleted_at` column on main entities for audit trails and data recovery   |
| Migrations         | golang-migrate          | Plain SQL up/down files, widely adopted in Go ecosystem                   |
| Refresh Tokens     | Database-stored (hashed)| Enables token revocation, session management, and logout-all              |

---

## Entity Relationship Diagram

```text
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│    users      │       │ user_preferences │       │    tags       │
├──────────────┤       ├──────────────────┤       ├──────────────┤
│ id (PK)       │──┐   │ user_id (PK,FK)  │   ┌──│ id (PK)       │
│ email          │  └──>│ tag_id  (PK,FK)  │<──┘  │ title          │
│ password_hash  │      └──────────────────┘      │ created_at     │
│ role           │                                 │ updated_at     │
│ last_login     │      ┌──────────────────┐      │ deleted_at     │
│ created_at     │      │    book_tags      │      └───────────────┘
│ updated_at     │      ├──────────────────┤            ▲
│ deleted_at     │      │ book_id (PK,FK)  │            │
└───────┬───────┘      │ tag_id  (PK,FK)  │────────────┘
        │               └────────┬─────────┘
        │                        │
        │               ┌───────┴────────┐
        │               │     books       │
        │               ├────────────────┤
        └──────────────>│ id (PK)         │
         (owner_id FK)  │ title           │
                        │ content         │
                        │ owner_id (FK)   │
                        │ created_at      │
                        │ updated_at      │
                        │ deleted_at      │
                        └────────────────┘

┌────────────────────┐
│  refresh_tokens     │
├────────────────────┤
│ id (PK)             │
│ user_id (FK)────────┼──> users.id
│ token_hash          │
│ expires_at          │
│ revoked_at          │
│ created_at          │
└────────────────────┘
```

---

## Tables

### 1. `users`

Stores registered user accounts.

| Column          | Type           | Constraints                                            |
|-----------------|----------------|--------------------------------------------------------|
| `id`            | `UUID`         | PK, DEFAULT `gen_random_uuid()`                        |
| `email`         | `VARCHAR(255)` | NOT NULL                                               |
| `password_hash` | `VARCHAR(255)` | NOT NULL                                               |
| `role`          | `VARCHAR(20)`  | NOT NULL, DEFAULT `'user'`, CHECK (`'user'`, `'admin'`) |
| `last_login`    | `TIMESTAMPTZ`  | NULL                                                   |
| `created_at`    | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`                              |
| `updated_at`    | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`                              |
| `deleted_at`    | `TIMESTAMPTZ`  | NULL                                                   |

**Indexes:**
- `idx_users_email_unique` — `UNIQUE ON (email) WHERE deleted_at IS NULL` (partial unique; allows re-registration after soft delete)

**Notes:**
- Passwords are hashed with bcrypt before storage.
- The `role` column uses a CHECK constraint rather than a separate roles table, since there are only two roles.

---

### 2. `tags`

Stores book genre/category tags. Tags are created by admins only.

| Column       | Type           | Constraints                     |
|--------------|----------------|---------------------------------|
| `id`         | `UUID`         | PK, DEFAULT `gen_random_uuid()` |
| `title`      | `VARCHAR(100)` | NOT NULL                        |
| `created_at` | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`       |
| `updated_at` | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`       |
| `deleted_at` | `TIMESTAMPTZ`  | NULL                            |

**Indexes:**
- `idx_tags_title_unique` — `UNIQUE ON (title) WHERE deleted_at IS NULL` (prevents duplicate tag names among active tags)

---

### 3. `books`

Stores book recommendations created by users.

| Column       | Type           | Constraints                                  |
|--------------|----------------|----------------------------------------------|
| `id`         | `UUID`         | PK, DEFAULT `gen_random_uuid()`              |
| `title`      | `VARCHAR(500)` | NOT NULL                                     |
| `content`    | `TEXT`         | NOT NULL                                     |
| `owner_id`   | `UUID`         | NOT NULL, FK -> `users(id)` ON DELETE CASCADE |
| `created_at` | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`                    |
| `updated_at` | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`                    |
| `deleted_at` | `TIMESTAMPTZ`  | NULL                                         |

**Indexes:**
- `idx_books_owner_id` — `ON (owner_id)` (lookup books by owner)
- `idx_books_created_at` — `ON (created_at DESC) WHERE deleted_at IS NULL` (paginated listing sorted by newest first)
- `idx_books_full_text` — `GIN ON to_tsvector('english', title || ' ' || content)` (full-text search for `/books/search?q=`)

**Notes:**
- The `ON DELETE CASCADE` on `owner_id` ensures that if a user is hard-deleted, their books are also removed. With soft deletes in normal operation, this acts as a safety net.

---

### 4. `book_tags` (Join Table)

Many-to-many relationship between books and tags.

| Column    | Type   | Constraints                                   |
|-----------|--------|-----------------------------------------------|
| `book_id` | `UUID` | NOT NULL, FK -> `books(id)` ON DELETE CASCADE |
| `tag_id`  | `UUID` | NOT NULL, FK -> `tags(id)` ON DELETE CASCADE  |

**Constraints:**
- `PRIMARY KEY (book_id, tag_id)` — composite PK, prevents duplicate assignments

**Indexes:**
- `idx_book_tags_tag_id` — `ON (tag_id)` (reverse lookup: find all books for a given tag)

---

### 5. `user_preferences` (Join Table)

Many-to-many relationship between users and their preferred tags.

| Column    | Type   | Constraints                                   |
|-----------|--------|-----------------------------------------------|
| `user_id` | `UUID` | NOT NULL, FK -> `users(id)` ON DELETE CASCADE |
| `tag_id`  | `UUID` | NOT NULL, FK -> `tags(id)` ON DELETE CASCADE  |

**Constraints:**
- `PRIMARY KEY (user_id, tag_id)` — composite PK, prevents duplicate preferences

**Indexes:**
- `idx_user_preferences_tag_id` — `ON (tag_id)` (reverse lookup)

---

### 6. `refresh_tokens`

Stores hashed refresh tokens for JWT session management.

| Column       | Type           | Constraints                                   |
|--------------|----------------|-----------------------------------------------|
| `id`         | `UUID`         | PK, DEFAULT `gen_random_uuid()`               |
| `user_id`    | `UUID`         | NOT NULL, FK -> `users(id)` ON DELETE CASCADE |
| `token_hash` | `VARCHAR(255)` | NOT NULL, UNIQUE                              |
| `expires_at` | `TIMESTAMPTZ`  | NOT NULL                                      |
| `revoked_at` | `TIMESTAMPTZ`  | NULL                                          |
| `created_at` | `TIMESTAMPTZ`  | NOT NULL, DEFAULT `NOW()`                     |

**Indexes:**
- `idx_refresh_tokens_user_id` — `ON (user_id)` (find all sessions for a user; enables "logout all")
- `idx_refresh_tokens_expires_at` — `ON (expires_at)` (periodic cleanup of expired tokens)

**Notes:**
- Refresh tokens are hashed with SHA-256 before storage (never stored in plaintext).
- A NULL `revoked_at` means the token is active. Setting `revoked_at = NOW()` revokes it.
- Token rotation: on each refresh, the old token is revoked and a new one is issued.

---

## Database Triggers

### `updated_at` Auto-Update Trigger

A reusable trigger function that automatically sets `updated_at = NOW()` on any row update.

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Applied to: `users`, `tags`, `books`.

---

## Migration File Structure

Using [golang-migrate](https://github.com/golang-migrate/migrate) with sequential numbering:

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
├── 000006_create_refresh_tokens_table.down.sql
```

Each `.up.sql` creates the table, indexes, triggers, and constraints.
Each `.down.sql` drops them in reverse order.

---

## Key Design Decisions

1. **Partial unique indexes** on `users.email` and `tags.title` — filtered by `WHERE deleted_at IS NULL` so soft-deleted records don't block new registrations or tag creation.

2. **Hashed refresh tokens** — `token_hash` stores SHA-256 of the raw token. The raw token is only returned to the client once and never persisted.

3. **GIN full-text search index** on books — avoids slow `LIKE '%query%'` patterns. Uses PostgreSQL's `to_tsvector` and `to_tsquery` for efficient search on the `/books/search?q=` endpoint.

4. **Composite primary keys** on join tables (`book_tags`, `user_preferences`) — no surrogate `id` column needed; the FK pair is the natural key and inherently prevents duplicates.

5. **CASCADE deletes on join tables** — when a parent row (book, user, or tag) is deleted, associated join rows are automatically cleaned up.

6. **`TIMESTAMPTZ` everywhere** — timezone-aware timestamps, matching the API's ISO 8601 UTC contract.

7. **`updated_at` trigger** — ensures consistency across application code; `updated_at` is always accurate even if the application layer forgets to set it.

8. **`VARCHAR` with sensible limits** — prevents unbounded data while allowing reasonable content (email: 255, book title: 500, tag title: 100).
