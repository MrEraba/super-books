# Books Recommendation API - Proposal

## Overview

This document proposes a REST API design for a Books Recommendation system where users can create, update, delete, search, and read book recommendations. The API uses JWT for authentication.

---

## Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Register a new user |
| POST | `/auth/login` | Login and receive JWT token |
| POST | `/auth/refresh` | Refresh JWT token |
| GET | `/auth/me` | Get current user profile |

### Books (Recommendations)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/books` | Get paginated recommendations based on user preferences (tags), ordered by creation date |
| GET | `/books/:id` | Get a single recommendation by ID |
| GET | `/books/search` | Search recommendations by query/tags |
| POST | `/books` | Create a new recommendation |
| PUT | `/books/:id` | Update a recommendation (owner only) |
| DELETE | `/books/:id` | Delete a recommendation (owner only) |

### Tags

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/tags` | List all available tags |
| POST | `/tags` | Create a new tag (admin only) |

### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/:id` | Get user profile by ID |
| GET | `/users/me/preferences` | Get current user's preferences |
| PUT | `/users/me/preferences` | Update current user's preferences (owner only) |
| GET | `/users/me/recommendations` | Get all recommendations by current user |

---

## Data Models

### User
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "password": "hashed_password",
  "role": "user",
  "last_login": "2024-01-01T00:00:00Z",
  "preferences": ["sci-fi", "fantasy", "thriller"]
}
```
- `role`: `"user"` or `"admin"` (default: `"user"`)

### Recommendation (Book)
```json
{
  "id": "uuid",
  "title": "The Great Book",
  "content": "A detailed review...",
  "tags": ["sci-fi", "classic"],
  "created_at": "2024-01-01T00:00:00Z",
  "owner_id": "uuid"
}
```

### Tag
```json
{
  "id": "uuid",
  "title": "sci-fi"
}
```

---

## Authentication

All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

---

## API Examples (cURL)

### Register a new user
```bash
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123",
    "preferences": ["sci-fi", "fantasy"]
  }'
```

**Response:**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "role": "user",
  "preferences": ["sci-fi", "fantasy"]
}
```

---

### Login
```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123"
  }'
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600
}
```

---

### Get current user profile
```bash
curl -X GET http://localhost:8080/auth/me \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "role": "user",
  "last_login": "2024-01-01T00:00:00Z",
  "preferences": ["sci-fi", "fantasy"]
}
```

---

### Get books based on user preferences (main endpoint)
```bash
# Default: page=1, limit=10
curl -X GET "http://localhost:8080/books?page=1&limit=10" \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Dune",
      "content": "An amazing sci-fi epic...",
      "tags": ["sci-fi", "classic"],
      "created_at": "2024-01-01T00:00:00Z",
      "owner": {
        "id": "uuid",
        "email": "owner@example.com"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 50,
    "total_pages": 5
  }
}
```

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)

---

### Search recommendations by tags
```bash
curl -X GET "http://localhost:8080/books/search?tags=sci-fi,fantasy&page=1&limit=10" \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Dune",
      "content": "An amazing sci-fi epic...",
      "tags": ["sci-fi"],
      "created_at": "2024-01-01T00:00:00Z",
      "owner": {
        "id": "uuid",
        "email": "owner@example.com"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 5,
    "total_pages": 1
  }
}
```

**Query Parameters:**
- `tags` (optional): Comma-separated tags to filter by
- `q` (optional): Search query for title/content
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)

---

### Search recommendations by query
```bash
curl -X GET "http://localhost:8080/books/search?q=dune&page=1&limit=10" \
  -H "Authorization: Bearer <jwt_token>"
```

---

### Create a new recommendation
```bash
curl -X POST http://localhost:8080/books \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "The Hobbit",
    "content": "A wonderful adventure story...",
    "tags": ["fantasy", "adventure"]
  }'
```

**Response:**
```json
{
  "id": "uuid",
  "title": "The Hobbit",
  "content": "A wonderful adventure story...",
  "tags": ["fantasy", "adventure"],
  "created_at": "2024-01-01T00:00:00Z",
  "owner_id": "uuid"
}
```

---

### Get a single recommendation by ID
```bash
curl -X GET http://localhost:8080/books/:id \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "id": "uuid",
  "title": "The Hobbit",
  "content": "A wonderful adventure story...",
  "tags": ["fantasy", "adventure"],
  "created_at": "2024-01-01T00:00:00Z",
  "owner": {
    "id": "uuid",
    "email": "owner@example.com"
  }
}
```

---

### Update a recommendation (owner only)
```bash
curl -X PUT http://localhost:8080/books/:id \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "The Hobbit - Updated",
    "content": "An updated review...",
    "tags": ["fantasy", "classic"]
  }'
```

---

### Delete a recommendation (owner only)
```bash
curl -X DELETE http://localhost:8080/books/:id \
  -H "Authorization: Bearer <jwt_token>"
```

---

### Get current user's preferences
```bash
curl -X GET http://localhost:8080/users/me/preferences \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "preferences": ["sci-fi", "fantasy"]
}
```

---

### Update current user's preferences
```bash
curl -X PUT http://localhost:8080/users/me/preferences \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "preferences": ["sci-fi", "fantasy", "mystery"]
  }'
```

---

### Get current user's recommendations
```bash
curl -X GET http://localhost:8080/users/me/recommendations?page=1&limit=10 \
  -H "Authorization: Bearer <jwt_token>"
```

---

### Get all tags
```bash
curl -X GET http://localhost:8080/tags \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "data": [
    {"id": "uuid", "title": "sci-fi"},
    {"id": "uuid", "title": "fantasy"},
    {"id": "uuid", "title": "thriller"}
  ]
}
```

---

### Create a new tag (admin only)
```bash
curl -X POST http://localhost:8080/tags \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "horror"
  }'
```

**Note:** Requires user with `"role": "admin"`

---

### Refresh JWT token
```bash
curl -X POST http://localhost:8080/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

---

## Error Responses

All errors follow a consistent format:

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}
```

Common error codes:
- `UNAUTHORIZED` - Missing or invalid JWT token
- `FORBIDDEN` - User lacks permission (e.g., updating someone else's recommendation/preferences, or non-admin accessing admin endpoints)
- `NOT_FOUND` - Resource not found
- `VALIDATION_ERROR` - Invalid input data
- `CONFLICT` - Email already exists

---

## Notes

- The `/books` endpoint returns paginated recommendations based on the authenticated user's preferences (matching tags), ordered by creation date (newest first)
- Pagination: `page` (default: 1) and `limit` (default: 10) query parameters
- User preferences can only be updated by the owner via `/users/me/preferences`
- Tag creation (`POST /tags`) requires admin role (`"role": "admin"`)
- All timestamps are in ISO 8601 format (UTC)
- Passwords are hashed using bcrypt before storage
- JWT tokens expire after 1 hour (configurable)
