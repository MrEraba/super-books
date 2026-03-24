### Task 9: HTTP Server & Routing Setup

**Description**:
Wire everything together in main.go, set up routing, error handling, and graceful shutdown.

```go
// cmd/server/main.go
func main() {
    // 1. Load configuration
    cfg, err := config.Load()
    if err != nil {
        log.Fatal().Err(err).Msg("Failed to load configuration")
    }
    
    // 2. Initialize database
    db, err := database.NewPostgresDB(cfg.Database)
    if err != nil {
        log.Fatal().Err(err).Msg("Failed to connect to database")
    }
    defer db.Close()
    
    // 3. Run migrations
    if err := database.RunMigrations(db, cfg.Database.URL, "./migrations"); err != nil {
        log.Fatal().Err(err).Msg("Failed to run migrations")
    }
    
    // 4. Initialize repositories
    userRepo := repository.NewUserRepository(db)
    bookRepo := repository.NewBookRepository(db)
    tagRepo := repository.NewTagRepository(db)
    tokenRepo := repository.NewTokenRepository(db)
    
    // 5. Initialize services
    authService := service.NewAuthService(userRepo, tokenRepo, cfg.JWT)
    bookService := service.NewBookService(bookRepo, tagRepo)
    tagService := service.NewTagService(tagRepo)
    userService := service.NewUserService(userRepo, bookRepo, tagRepo)
    
    // 6. Initialize handlers
    authHandler := handler.NewAuthHandler(authService)
    bookHandler := handler.NewBookHandler(bookService)
    tagHandler := handler.NewTagHandler(tagService)
    userHandler := handler.NewUserHandler(userService)
    
    // 7. Initialize Fiber app
    app := fiber.New(fiber.Config{
        AppName:      "Super Books API",
        ErrorHandler: middleware.ErrorHandler,
    })
    
    // 8. Setup routes
    setupRoutes(app, cfg, authHandler, bookHandler, tagHandler, userHandler)
    
    // 9. Start server
    go func() {
        addr := fmt.Sprintf(":%s", cfg.Server.Port)
        log.Info().Str("addr", addr).Msg("Starting server")
        if err := app.Listen(addr); err != nil {
            log.Fatal().Err(err).Msg("Server failed")
        }
    }()
    
    // 10. Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    log.Info().Msg("Shutting down server...")
    if err := app.Shutdown(); err != nil {
        log.Error().Err(err).Msg("Server forced to shutdown")
    }
}

func setupRoutes(
    app *fiber.App,
    cfg *config.Config,
    authHandler *handler.AuthHandler,
    bookHandler *handler.BookHandler,
    tagHandler *handler.TagHandler,
    userHandler *handler.UserHandler,
) {
    // Health check
    app.Get("/health", func(c *fiber.Ctx) error {
        return c.JSON(fiber.Map{"status": "ok"})
    })
    
    // Public routes
    auth := app.Group("/auth")
    auth.Post("/register", authHandler.Register)
    auth.Post("/login", authHandler.Login)
    auth.Post("/refresh", authHandler.Refresh)
    
    // Protected routes
    jwtAuth := middleware.JWTAuth(cfg.JWT.Secret)
    
    protected := app.Group("/", jwtAuth)
    
    // Auth
    protected.Get("/auth/me", authHandler.Me)
    
    // Books
    bookHandler.RegisterRoutes(protected)
    
    // Tags
    tagHandler.RegisterRoutes(protected)
    
    // Users
    protected.Get("/users/:id", userHandler.GetByID)
    protected.Get("/users/me/preferences", userHandler.GetPreferences)
    protected.Put("/users/me/preferences", userHandler.UpdatePreferences)
    protected.Get("/users/me/recommendations", userHandler.GetMyRecommendations)
}
```

**Error Handler Middleware**:
```go
// internal/middleware/error.go
func ErrorHandler(c *fiber.Ctx, err error) error {
    code := fiber.StatusInternalServerError
    errorCode := "INTERNAL_ERROR"
    message := "An unexpected error occurred"
    
    if e, ok := err.(*fiber.Error); ok {
        code = e.Code
        message = e.Message
    }
    
    return c.Status(code).JSON(dto.ErrorResponse{
        Error: dto.ErrorDetail{
            Code:    errorCode,
            Message: message,
        },
    })
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC9.1 | Server starts and listens on configured port |
| TC9.2 | Health check endpoint returns 200 |
| TC9.3 | Protected endpoints return 401 without token |
| TC9.4 | Graceful shutdown completes in-flight requests |
| TC9.5 | Unknown routes return 404 |
| TC9.6 | Server binds to all interfaces (0.0.0.0) |

**Acceptance Criteria**:
- [ ] Server starts without errors
- [ ] All routes are registered correctly
- [ ] Public routes don't require authentication
- [ ] Protected routes require valid JWT
- [ ] Graceful shutdown works on SIGTERM/SIGINT
- [ ] Application name appears in responses
