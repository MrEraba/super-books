### Task 8: User Service & Handlers

**Description**:
Implement user profile endpoints including preferences management.

```go
// internal/service/user_service.go
func (s *UserService) GetByID(ctx context.Context, id uuid.UUID) (*dto.UserResponse, error) {
    user, err := s.userRepo.GetByID(ctx, id)
    if err != nil {
        if errors.Is(err, repository.ErrNotFound) {
            return nil, ErrUserNotFound
        }
        return nil, err
    }
    
    prefs, _ := s.userRepo.GetPreferences(ctx, id)
    prefTitles := make([]string, len(prefs))
    for i, p := range prefs {
        prefTitles[i] = p.Tag.Title
    }
    
    return &dto.UserResponse{
        ID:          user.ID,
        Email:       user.Email,
        Role:        user.Role,
        LastLogin:   user.LastLogin,
        Preferences: prefTitles,
    }, nil
}

func (s *UserService) GetPreferences(ctx context.Context, userID uuid.UUID) (*dto.PreferencesResponse, error) {
    prefs, err := s.userRepo.GetPreferences(ctx, userID)
    if err != nil {
        return nil, err
    }
    
    titles := make([]string, len(prefs))
    for i, p := range prefs {
        titles[i] = p.Tag.Title
    }
    
    return &dto.PreferencesResponse{Preferences: titles}, nil
}

func (s *UserService) UpdatePreferences(ctx context.Context, userID uuid.UUID, req *dto.UpdatePreferencesRequest) error {
    // 1. Delete existing preferences
    if err := s.userRepo.DeletePreferences(ctx, userID); err != nil {
        return err
    }
    
    // 2. Get or create tags
    if len(req.Preferences) > 0 {
        tagIDs, err := s.getOrCreateTags(ctx, req.Preferences)
        if err != nil {
            return err
        }
        
        // 3. Create new preferences
        if err := s.userRepo.SetPreferences(ctx, userID, tagIDs); err != nil {
            return err
        }
    }
    
    return nil
}

func (s *UserService) GetMyRecommendations(ctx context.Context, userID uuid.UUID, page, limit int) (*dto.BookListResponse, error) {
    offset := (page - 1) * limit
    books, total, err := s.bookRepo.ListByOwner(ctx, userID, limit, offset)
    if err != nil {
        return nil, err
    }
    
    bookResponses := make([]dto.BookResponse, len(books))
    for i, book := range books {
        bookResponses[i] = s.bookService.ToBookResponse(book)
    }
    
    totalPages := int(math.Ceil(float64(total) / float64(limit)))
    
    return &dto.BookListResponse{
        Data: bookResponses,
        Pagination: dto.Pagination{
            Page:       page,
            Limit:      limit,
            Total:      total,
            TotalPages: totalPages,
        },
    }, nil
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC8.1 | Get user by ID returns user profile |
| TC8.2 | Get user by ID returns NOT_FOUND for non-existent user |
| TC8.3 | Get preferences returns user's preference tags |
| TC8.4 | Update preferences replaces existing preferences |
| TC8.5 | Update preferences with empty array clears all |
| TC8.6 | Update preferences creates new tags if needed |
| TC8.7 | Get my recommendations returns only user's books |
| TC8.8 | Get my recommendations excludes deleted books |
| TC8.9 | Get my recommendations respects pagination |

**Acceptance Criteria**:
- [ ] `/users/:id` returns user profile (without password)
- [ ] `/users/me/preferences` returns current user's preferences
- [ ] `/users/me/preferences` PUT updates preferences
- [ ] `/users/me/recommendations` returns paginated list
- [ ] User can only see their own preferences
