# Testing Guidelines

This document defines the testing strategy and requirements for this project.

---

## Testing Pyramid

This project follows a comprehensive testing strategy with multiple layers:

```
        /\
       /  \  E2E Tests
      /----\
     /      \  Integration Tests
    /--------\
   /          \  Unit Tests
  /--------------\
```

### 1. Unit Tests (Foundation)
**What**: Test individual functions, classes, and business logic in isolation.
**Coverage Target**: 80% line coverage minimum

**Examples**:
- Business logic and service functions
- Data model serialization/deserialization
- Utility functions

### 2. Integration Tests (Components Working Together)
**What**: Test how modules, services, or layers interact with each other.
**Coverage Target**: 75% coverage minimum of integration points

**Examples**:
- Data persistence and repository operations
- API/service boundaries
- State management flows

### 3. End-to-End Tests (Full Flows)
**What**: Test complete user or system workflows across the entire application.
**Coverage Target**: All critical paths

**Examples**:
- Core user journeys from start to finish
- Error states and recovery
- Data persistence across sessions

---

## Test-Driven Development (TDD) - MANDATORY

**ALL code must follow TDD**:

1. ✅ Write failing test FIRST
2. ✅ Run test → verify FAIL
3. ✅ Implement minimum code to pass
4. ✅ Run test → verify PASS
5. ✅ Refactor if needed
6. ✅ Run test → verify still PASS
7. ✅ Commit

**No exceptions**: Every line of production code must be test-driven.

---

## Test Organization

### Directory Structure
```
test/ (or the equivalent for the chosen stack)
├── unit/                    # Unit tests
├── integration/             # Integration tests
└── e2e/                     # End-to-end tests
```

### Naming Conventions

Follow the idiomatic test naming convention for the language/framework in use
(e.g. `{component_name}_test.*` or `{ComponentName}.test.*`). Keep test names
descriptive of the behavior under test, not the implementation.

---

## Test Coverage Requirements

### Critical Paths (100% Coverage Required)
- Data persistence
- Core business logic
- Anything touching money, auth, or user data

### High Priority (≥90% Coverage)
- Primary application flows
- Scheduling/calculation logic

### Standard Priority (≥80% Coverage)
- UI screens and components
- Navigation flows
- Form validation

---

## Test Quality Standards

### Good Test Characteristics

✅ **Fast**: Unit tests run in milliseconds, integration tests in seconds
✅ **Isolated**: Each test is independent, no shared state
✅ **Repeatable**: Same result every time
✅ **Readable**: Clear test names and well-structured arrange-act-assert
✅ **Maintainable**: Easy to update when requirements change

### Anti-Patterns to Avoid

❌ **Testing implementation details**: Test behavior, not internal structure
❌ **Brittle tests**: Don't break from minor UI changes
❌ **Slow tests**: Keep unit tests under 100ms, integration tests under 1s
❌ **Flaky tests**: No random timeouts or race conditions
❌ **Testing mocked behavior**: Test real logic, not mock returns

---

## Continuous Integration

### Pre-Commit Checklist
- [ ] All new code has tests
- [ ] The full test suite passes locally
- [ ] Coverage meets minimum thresholds
- [ ] No skipped or disabled tests

### CI Pipeline (Future)
1. Run the test suite on all commits
2. Run E2E tests on the main branch
3. Generate coverage reports
4. Block merges if tests fail or coverage drops

---

## Test Data Management

### Isolated Test Environments
- Unit and integration tests should use an isolated/in-memory environment where possible
- Each test gets a clean state via setup/teardown hooks

### Test Fixtures
- Create reusable test data factories
- Keep test data minimal but representative

### Mocks and Fakes
- Use mocks/fakes only where a real dependency is impractical in the test (e.g. an external network call)
- Avoid testing mocked behavior — the assertions should verify real logic, not that a mock returned what it was told to return

---

**Remember**: Tests are not just verification — they're documentation, design tools, and safety nets. Write them first, write them well, and your code will thank you!
