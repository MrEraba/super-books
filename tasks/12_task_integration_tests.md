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
