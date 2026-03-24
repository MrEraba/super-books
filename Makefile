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
