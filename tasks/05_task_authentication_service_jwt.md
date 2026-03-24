### Task 5: Authentication Service & JWT Handling

**Description**:
Implement authentication logic including user registration, login, JWT generation/validation, and token refresh. This is critical security code - pay attention to edge cases.

**Key Implementation Details**:

```go
// internal/service/auth_service.go
type AuthService struct {
    userRepo  repository.UserRepository
    tokenRepo repository.TokenRepository
    cfg       config.JWTConfig
}

func (s *AuthService) Register(ctx context.Context, req *dto.RegisterRequest) (*dto.UserResponse, error) {
    // 1. Check if email already exists
    existing, _ := s.userRepo.GetByEmail(ctx, req.Email)
    if existing != nil && existing.DeletedAt == nil {
        return nil, ErrEmailExists
    }
    
    // 2. Hash password with bcrypt (cost 12)
    hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
    if err != nil {
        return nil, fmt.Errorf("failed to hash password: %w", err)
    }
    
    // 3. Create user
    user := &models.User{
        Email:        req.Email,
        PasswordHash: string(hash),
        Role:         "user",
    }
    
    if err := s.userRepo.Create(ctx, user); err != nil {
        return nil, err
    }
    
    // 4. Set preferences (create tags if needed)
    if len(req.Preferences) > 0 {
        // Create tags and link to user
    }
    
    return toUserResponse(user, req.Preferences), nil
}

func (s *AuthService) Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error) {
    // 1. Find user by email
    user, err := s.userRepo.GetByEmail(ctx, req.Email)
    if err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 2. Verify password
    if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
        return nil, ErrInvalidCredentials
    }
    
    // 3. Generate tokens
    accessToken, err := s.generateAccessToken(user)
    if err != nil {
        return nil, err
    }
    
    refreshToken, err := s.generateRefreshToken(user)
    if err != nil {
        return nil, err
    }
    
    // 4. Update last_login
    s.userRepo.UpdateLastLogin(ctx, user.ID)
    
    return &dto.LoginResponse{
        Token:        accessToken,
        RefreshToken: refreshToken,
        ExpiresIn:    int64(s.cfg.Expiry.Seconds()),
    }, nil
}

func (s *AuthService) generateAccessToken(user *models.User) (string, error) {
    claims := jwt.MapClaims{
        "sub":   user.ID.String(),
        "email": user.Email,
        "role":  user.Role,
        "exp":   time.Now().Add(s.cfg.Expiry).Unix(),
        "iat":   time.Now().Unix(),
    }
    
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(s.cfg.Secret))
}

func (s *AuthService) generateRefreshToken(user *models.User) (string, error) {
    rawToken := uuid.New().String() // Use crypto/rand in production
    
    hash := sha256.Sum256([]byte(rawToken))
    hashStr := hex.EncodeToString(hash[:])
    
    token := &models.RefreshToken{
        UserID:    user.ID,
        TokenHash: hashStr,
        ExpiresAt: time.Now().Add(s.cfg.RefreshExpiry),
    }
    
    if err := s.tokenRepo.Create(ctx, token); err != nil {
        return "", err
    }
    
    return rawToken, nil // Return raw token to client (only time)
}

func (s *AuthService) RefreshTokens(ctx context.Context, rawToken string) (*dto.LoginResponse, error) {
    // 1. Hash the token
    hash := sha256.Sum256([]byte(rawToken))
    hashStr := hex.EncodeToString(hash[:])
    
    // 2. Find token in DB
    token, err := s.tokenRepo.GetByHash(ctx, hashStr)
    if err != nil {
        return nil, ErrInvalidToken
    }
    
    // 3. Check if revoked
    if token.RevokedAt != nil {
        return nil, ErrTokenRevoked
    }
    
    // 4. Check if expired
    if time.Now().After(token.ExpiresAt) {
        return nil, ErrTokenExpired
    }
    
    // 5. Revoke old token (rotation)
    if err := s.tokenRepo.Revoke(ctx, token.ID); err != nil {
        return nil, err
    }
    
    // 6. Get user and generate new tokens
    user, err := s.userRepo.GetByID(ctx, token.UserID)
    if err != nil {
        return nil, err
    }
    
    return s.Login(ctx, &dto.LoginRequest{
        Email:    user.Email,
        Password: "", // Not needed for refresh
    })
}
```

**JWT Middleware**:
```go
// internal/middleware/auth.go
func JWTAuth(secret string) fiber.Handler {
    return func(c *fiber.Ctx) error {
        authHeader := c.Get("Authorization")
        if authHeader == "" {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Missing authorization header")
        }
        
        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Invalid authorization header format")
        }
        
        tokenString := parts[1]
        
        token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
            if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
            }
            return []byte(secret), nil
        })
        
        if err != nil || !token.Valid {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired token")
        }
        
        claims, ok := token.Claims.(jwt.MapClaims)
        if !ok {
            return response.Error(c, fiber.StatusUnauthorized, "UNAUTHORIZED", "Invalid token claims")
        }
        
        // Store user info in context
        c.Locals("userID", claims["sub"])
        c.Locals("userRole", claims["role"])
        c.Locals("userEmail", claims["email"])
        
        return c.Next()
    }
}

// Helper to get user from context
func GetUserID(c *fiber.Ctx) (uuid.UUID, error) {
    idStr := c.Locals("userID").(string)
    return uuid.Parse(idStr)
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC5.1 | Registration creates user with hashed password |
| TC5.2 | Registration fails with duplicate email |
| TC5.3 | Registration fails with weak password (< 8 chars) |
| TC5.4 | Login succeeds with valid credentials |
| TC5.5 | Login fails with invalid email |
| TC5.6 | Login fails with wrong password |
| TC5.7 | JWT token contains correct claims |
| TC5.8 | JWT middleware rejects expired token |
| TC5.9 | JWT middleware rejects malformed token |
| TC5.10 | Refresh token rotation works |
| TC5.11 | Refresh fails with revoked token |
| TC5.12 | Refresh fails with expired token |

**Acceptance Criteria**:
- [ ] Passwords are hashed with bcrypt (cost >= 10)
- [ ] JWT tokens contain user ID, email, role, expiry
- [ ] Refresh tokens are hashed with SHA-256 before storage
- [ ] Token rotation is implemented (old token revoked on refresh)
- [ ] Middleware correctly extracts and validates JWT
- [ ] User ID is accessible from context in handlers
- [ ] All authentication endpoints return correct error codes
