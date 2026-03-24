### Task 6: Book Service & Handlers

**Description**:
Implement book/recommendation CRUD operations and the recommendation engine (filtering by user preferences).

**Recommendation Logic**:
The main `/books` endpoint should return books that match the authenticated user's preferences (tags).

```go
// internal/service/book_service.go
func (s *BookService) ListByPreferences(ctx context.Context, userID uuid.UUID, page, limit int) (*dto.BookListResponse, error) {
    // 1. Get user's preferences (tag IDs)
    prefs, err := s.userRepo.GetPreferences(ctx, userID)
    if err != nil {
        return nil, err
    }
    
    if len(prefs) == 0 {
        return &dto.BookListResponse{
            Data:       []dto.BookResponse{},
            Pagination: dto.Pagination{Page: page, Limit: limit, Total: 0, TotalPages: 0},
        }, nil
    }
    
    // 2. Get tag IDs
    tagIDs := make([]uuid.UUID, len(prefs))
    for i, p := range prefs {
        tagIDs[i] = p.TagID
    }
    
    // 3. List books with matching tags, ordered by created_at DESC
    offset := (page - 1) * limit
    books, total, err := s.bookRepo.ListByTags(ctx, tagIDs, limit, offset)
    if err != nil {
        return nil, err
    }
    
    // 4. Load owner info and tags for each book
    bookResponses := make([]dto.BookResponse, len(books))
    for i, book := range books {
        bookResponses[i] = s.toBookResponse(book)
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

func (s *BookService) Create(ctx context.Context, userID uuid.UUID, req *dto.CreateBookRequest) (*dto.BookResponse, error) {
    // 1. Create book
    book := &models.Book{
        Title:   req.Title,
        Content: req.Content,
        OwnerID: userID,
    }
    
    if err := s.bookRepo.Create(ctx, book); err != nil {
        return nil, err
    }
    
    // 2. Process tags
    if len(req.Tags) > 0 {
        // Get or create tags
        tagIDs, err := s.getOrCreateTags(ctx, req.Tags)
        if err != nil {
            return nil, err
        }
        
        if err := s.bookRepo.AddTags(ctx, book.ID, tagIDs); err != nil {
            return nil, err
        }
        
        book.Tags, _ = s.tagRepo.GetByIDs(ctx, tagIDs)
    }
    
    return s.toBookResponse(book), nil
}

func (s *BookService) Search(ctx context.Context, userID uuid.UUID, query string, tags []string, page, limit int) (*dto.BookListResponse, error) {
    offset := (page - 1) * limit
    
    var books []*models.Book
    var total int
    var err error
    
    tagIDs := []uuid.UUID{}
    if len(tags) > 0 {
        tagIDs, err = s.getOrCreateTags(ctx, tags)
        if err != nil {
            return nil, err
        }
    }
    
    if query != "" {
        // Full-text search
        books, total, err = s.bookRepo.Search(ctx, query, tagIDs, limit, offset)
    } else if len(tagIDs) > 0 {
        // Filter by tags only
        books, total, err = s.bookRepo.ListByTags(ctx, tagIDs, limit, offset)
    } else {
        // Return all books
        books, total, err = s.bookRepo.ListAll(ctx, limit, offset)
    }
    
    if err != nil {
        return nil, err
    }
    
    // Build response
    bookResponses := make([]dto.BookResponse, len(books))
    for i, book := range books {
        bookResponses[i] = s.toBookResponse(book)
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

**Book Handlers**:
```go
// internal/handler/book_handler.go
type BookHandler struct {
    bookService service.BookService
}

func (h *BookHandler) RegisterRoutes(router fiber.Router) {
    books := router.Group("/books")
    books.Get("/", h.List)
    books.Get("/search", h.Search)
    books.Get("/:id", h.Get)
    books.Post("/", h.Create)
    books.Put("/:id", h.Update)
    books.Delete("/:id", h.Delete)
}

func (h *BookHandler) List(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    page := c.QueryInt("page", 1)
    limit := c.QueryInt("limit", 10)
    
    if page < 1 {
        page = 1
    }
    if limit < 1 || limit > 100 {
        limit = 10
    }
    
    result, err := h.bookService.ListByPreferences(c.UserContext(), userID, page, limit)
    if err != nil {
        return err
    }
    
    return c.JSON(result)
}

func (h *BookHandler) Get(c *fiber.Ctx) error {
    bookID, err := uuid.Parse(c.Params("id"))
    if err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid book ID")
    }
    
    book, err := h.bookService.GetByID(c.UserContext(), bookID)
    if err != nil {
        if errors.Is(err, service.ErrNotFound) {
            return response.Error(c, fiber.StatusNotFound, "NOT_FOUND", "Book not found")
        }
        return err
    }
    
    return c.JSON(book)
}

func (h *BookHandler) Create(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    var req dto.CreateBookRequest
    if err := c.BodyParser(&req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
    }
    
    if err := validator.Validate.Struct(req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", err.Error())
    }
    
    book, err := h.bookService.Create(c.UserContext(), userID, &req)
    if err != nil {
        return err
    }
    
    return c.Status(fiber.StatusCreated).JSON(book)
}

func (h *BookHandler) Update(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    bookID, err := uuid.Parse(c.Params("id"))
    if err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid book ID")
    }
    
    var req dto.UpdateBookRequest
    if err := c.BodyParser(&req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
    }
    
    if err := validator.Validate.Struct(req); err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", err.Error())
    }
    
    err = h.bookService.Update(c.UserContext(), userID, bookID, &req)
    if err != nil {
        if errors.Is(err, service.ErrForbidden) {
            return response.Error(c, fiber.StatusForbidden, "FORBIDDEN", "You can only update your own books")
        }
        if errors.Is(err, service.ErrNotFound) {
            return response.Error(c, fiber.StatusNotFound, "NOT_FOUND", "Book not found")
        }
        return err
    }
    
    return c.SendStatus(fiber.StatusNoContent)
}

func (h *BookHandler) Delete(c *fiber.Ctx) error {
    userID := middleware.GetUserID(c)
    
    bookID, err := uuid.Parse(c.Params("id"))
    if err != nil {
        return response.Error(c, fiber.StatusBadRequest, "VALIDATION_ERROR", "Invalid book ID")
    }
    
    err = h.bookService.Delete(c.UserContext(), userID, bookID)
    if err != nil {
        if errors.Is(err, service.ErrForbidden) {
            return response.Error(c, fiber.StatusForbidden, "FORBIDDEN", "You can only delete your own books")
        }
        if errors.Is(err, service.ErrNotFound) {
            return response.Error(c, fiber.StatusNotFound, "NOT_FOUND", "Book not found")
        }
        return err
    }
    
    return c.SendStatus(fiber.StatusNoContent)
}
```

**Test Cases**:
| ID | Description |
|----|-------------|
| TC6.1 | List books returns only books with matching user preferences |
| TC6.2 | List books with no preferences returns empty list |
| TC6.3 | List books respects pagination |
| TC6.4 | Search by full-text query returns matching books |
| TC6.5 | Search by tags returns books with those tags |
| TC6.6 | Search combines query and tags (AND logic) |
| TC6.7 | Create book succeeds with valid data |
| TC6.8 | Create book with new tags creates tags first |
| TC6.9 | Create book with existing tags reuses them |
| TC6.10 | Update book succeeds for owner |
| TC6.11 | Update book fails for non-owner (FORBIDDEN) |
| TC6.12 | Delete book succeeds for owner |
| TC6.13 | Delete book fails for non-owner (FORBIDDEN) |
| TC6.14 | Get book by ID returns book with owner info |
| TC6.15 | Get non-existent book returns NOT_FOUND |

**Acceptance Criteria**:
- [ ] `/books` filters by user's preference tags
- [ ] `/books` orders by created_at DESC (newest first)
- [ ] `/books/search` supports full-text search
- [ ] `/books/search` supports tag filtering
- [ ] Only owners can update/delete their books
- [ ] Pagination works correctly
- [ ] Books include owner summary (id, email)
- [ ] All timestamps are in ISO 8601 UTC format
- [ ] Proper HTTP status codes for all scenarios
