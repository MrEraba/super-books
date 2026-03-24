### Task 10: Input Validation

**Description**:
Implement comprehensive input validation using go-playground/validator.

```go
// internal/validator/validator.go
var validate *validator.Validate

func Init() {
    validate = validator.New()
    
    // Register custom validation for password strength
    validate.RegisterValidation("password", func(fl validator.FieldLevel) bool {
        password := fl.Field().String()
        // At least 8 chars, 1 uppercase, 1 lowercase, 1 digit
        var hasUpper, hasLower, hasDigit bool
        for _, c := range password {
            switch {
            case c >= 'A' && c <= 'Z':
                hasUpper = true
            case c >= 'a' && c <= 'z':
                hasLower = true
            case c >= '0' && c <= '9':
                hasDigit = true
            }
        }
        return len(password) >= 8 && hasUpper && hasLower && hasDigit
    })
}

func Validate(s interface{}) error {
    return validate.Struct(s)
}

func ValidationErrors(err error) []string {
    var errors []string
    for _, e := range err.(validator.ValidationErrors) {
        errors = append(errors, fmt.Sprintf("field '%s' %s", e.Field(), e.Tag()))
    }
    return errors
}
```

**Validation Rules Summary**:
| Field | Rules |
|-------|-------|
| User.email | required, valid email format |
| User.password | required, min=8, max=72 |
| Book.title | required, min=1, max=500 |
| Book.content | required, min=1 |
| Tag.title | required, min=1, max=100 |
| Pagination.page | min=1 |
| Pagination.limit | min=1, max=100 |

**Test Cases**:
| ID | Description |
|----|-------------|
| TC10.1 | Empty email returns validation error |
| TC10.2 | Invalid email format returns validation error |
| TC10.3 | Password < 8 chars returns validation error |
| TC10.4 | Title > 500 chars returns validation error |
| TC10.5 | Valid registration passes validation |
| TC10.6 | Multiple validation errors are collected |

**Acceptance Criteria**:
- [ ] All request DTOs are validated
- [ ] Validation errors return 400 with details
- [ ] Custom password validation works
- [ ] Pagination limits are enforced
