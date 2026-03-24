# Project Memory

## Task 00: Project Setup & Local Development
- Created directory structure: `cmd/server/`, `internal/{config,database,models,repository,service,handler,middleware,dto/request,dto/response,validator}`, `migrations/`, `docker/`
- Created Docker setup: `docker-compose.yaml`, `docker/Dockerfile`, `docker/Dockerfile.dev`
- Created configuration: `.env.example`, `.air.toml`, `.golangci.yml`, `Makefile`
- Created 6 SQL migrations following DATABASE.md schema (users, tags, books, book_tags, user_preferences, refresh_tokens)
- Created basic `cmd/server/main.go` entry point
- Go code compiles successfully

## Conventions
- Module name: `super-books`
- Database user/db: `superbooks`/`superbooks_dev`
- JWT expiry: 1h, Refresh token expiry: 168h (7 days)
- Uses golang-migrate for migrations
