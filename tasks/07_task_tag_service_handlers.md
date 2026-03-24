### Task 7: Tag Service & Handlers

**Description**:
Implement tag management including listing all tags and admin-only tag creation.

```go
// internal/service/tag_service.go
func (s *TagService) ListAll(ctx context.Context) (*dto.TagListResponse, error) {
    tags, err := s.tagRepo.GetAll(ctx)
    if err != nil {
        return nil, err
    }
    
    responses := make([]dto.TagResponse, len(tags))
    for i, tag := range tags {
        responses[i] = dto.TagResponse{
            ID:    tag.ID,
            Title: tag.Title,
        }
    }
    
    return &dto.TagListResponse{Data: responses}, nil
}

func (s *TagService) Create(ctx context.Context, req *dto.CreateTagRequest) (*dto.TagResponse, error) {
    tag := &models.Tag{
        Title: req.Title,
    }
    
    if err := s.tagRepo.Create(ctx, tag); err != nil {
        if errors.Is(err, repository.ErrDuplicateTitle) {
            return nil, ErrTagAlreadyExists
        }
        return nil, err
    }
    
    return &dto.TagResponse{
        ID:    tag.ID,
        Title: tag.Title,
    }, nil
}
```

**Tag Handlers**:
```go
// internal/handler/tag_handler.go
func (h *TagHandler) RegisterRoutes(router fiber.Router) {
    tags := router.Group("/tags")
    tags.Get("/", h.List)
    tags.Post("/", middleware.AdminOnly(), h.Create)
}

// Admin middleware
func AdminOnly() fiber.Handler {
    return func(c *fiber.Ctx) error {
        role := c.Locals("userRole").(string)
        if role != "admin" {
            return response.Error(c, fiber.StatusForbidden, "FORBIDDEN", "Admin access required")
        }
        return c.Next()
    }
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC7.1 | List tags returns all non-deleted tags |
| TC7.2 | List tags returns empty array when no tags exist |
| TC7.3 | Create tag succeeds for admin |
| TC7.4 | Create tag fails for non-admin (FORBIDDEN) |
| TC7.5 | Create tag fails with duplicate title (CONFLICT) |
| TC7.6 | Create tag validates title length |

**Acceptance Criteria**:
- [ ] `/tags` GET returns all active tags
- [ ] `/tags` POST is restricted to admin users
- [ ] Tag creation prevents duplicates
- [ ] Non-existent tags in book creation are auto-created
