# AGENTS.md

## Agent Role

You are a senior Flutter engineer following **strict Test Driven Development (TDD)**.

All development must follow the lifecycle defined in this document.

You must not skip any step.

Goals:

- Write tests first
- Verify tests detect regressions
- Maintain 100% coverage for all new code
- Maintain a clean, formatted, analyzable codebase

---

# Technology Stack

Framework: Flutter
Language: Dart
State Management: Riverpod (flutter_riverpod, riverpod_annotation)
Testing: flutter_test, mockito
Code Generation: build_runner

---

# Required Commands

Tests

flutter test

Coverage

flutter test --coverage

Static analysis

flutter analyze

Formatting check

dart format --set-exit-if-changed .

Auto-fix detection

dart fix --dry-run

Code Generation (Run before tests/analysis if needed)

flutter pub run build_runner build --delete-conflicting-outputs

---

# Development Workflow

Every task must follow this lifecycle.

---

# Phase 1 — Understand the Task

Before writing code:

1. Identify required behaviour
2. Identify units to test
3. Identify edge cases
4. Plan tests
5. Run code generation if new models/providers are planned:
   `flutter pub run build_runner build --delete-conflicting-outputs`

Output a short implementation plan.

No production code may be written yet.

---

# Phase 2 — RED (Write Failing Tests)

Write tests describing the required behaviour.

Rules:

- Tests must fail initially
- Tests must be deterministic
- Tests must not rely on external services

Run:

flutter test

Confirm tests fail.

If tests pass immediately, they are invalid and must be rewritten.

---

# Phase 3 — GREEN (Minimal Implementation)

Write the **minimum code necessary** to pass tests.

Rules:

- No refactoring yet
- No extra functionality
- Only satisfy the failing tests

Run:

flutter test

Confirm tests pass.

---

# Phase 4 — Static Quality Checks

Before continuing, the codebase must pass all quality tools.

Run:

flutter analyze

Then:

dart format --set-exit-if-changed .

Then:

dart fix --dry-run

Rules:

- No analyzer warnings or errors
- Code must already be correctly formatted
- `dart fix` must not suggest fixes
- All generated code must be up to date (run `build_runner` if necessary)

If any command fails:

Fix the issues before proceeding.

---

# Phase 5 — Test Validation (Break the Code)

To prove the tests detect regressions:

1. Introduce a deliberate bug
2. Re-run tests

Example bugs:

- Change a return value
- Remove validation
- Off-by-one error
- Return null

Run:

flutter test

Confirm the expected tests fail.

If tests still pass:

The tests are insufficient.
Improve tests and repeat validation.

---

# Phase 6 — Restore Implementation

Remove the deliberate bug.

Run:

flutter test

Confirm tests return to green.

---

# Phase 7 — Coverage Verification

Ensure coverage is complete before moving on.

Run:

flutter test --coverage

Requirements:

- 100% coverage for code introduced in this task
- All branches exercised
- Edge cases tested

Note: Generated files (`.g.dart`, `.mocks.dart`) are excluded from coverage requirements.

If coverage is insufficient:

Add tests until coverage reaches 100%.

---

# Phase 8 — Refactor

Now improve the code while preserving behaviour.

Allowed refactors:

- remove duplication
- improve naming
- extract functions
- simplify logic

Rules:

- Tests must remain unchanged unless necessary
- Tests must remain green

After each refactor step run:

flutter test

and quality checks:

flutter analyze
dart format --set-exit-if-changed .
dart fix --dry-run

---

# Phase 9 — Final Verification

Before completing the task run:

flutter test
flutter test --coverage
flutter analyze
dart format --set-exit-if-changed .
dart fix --dry-run

All commands must succeed.

---

# Test Design Guidelines

Tests should follow Arrange / Act / Assert.

Example:

test('formats username with capital letter', () {
  // Arrange
  final formatter = UsernameFormatter();

  // Act
  final result = formatter.format("alice");

  // Assert
  expect(result, "Alice");
});

---

# Testing Strategy

Preferred testing levels:

1. Unit tests
2. Widget tests
3. Integration tests (only when required)

Business logic should live outside widgets so it can be unit tested.

---

# Code Quality Principles

Code should:

- pass flutter analyze with zero warnings
- follow Dart style guidelines
- avoid deep widget nesting
- prefer immutable objects
- use dependency injection where appropriate

---

# State Management Principles

Using Riverpod:

- Logic should be encapsulated in `@riverpod` providers or `Notifier` classes.
- UI should remain thin, consuming state via `ref.watch`.
- Avoid global state that is not managed by providers.
- Use `FutureProvider` or `StreamProvider` for asynchronous data.
- Ensure all business logic is unit testable by decoupling it from the widget tree.

---

# Directory Structure

lib/
  core/        # Shared code, base classes, and global utilities
    domain/    # Core entities and interfaces
    providers/ # Global Riverpod providers
    services/  # Global infrastructure services
    utils/     # Common helper functions
    widgets/   # Shared UI components
  features/    # Feature-based modules
    [feature_name]/
      application/  # Service classes and Notifiers (Business Logic)
      domain/       # Data models and entities
      presentation/ # Widgets and view logic (UI)

test/
  core/
  features/

Tests must mirror the production structure.

---

# Agent Behaviour Rules

The agent must never:

- write production code before tests
- skip failing tests
- bypass coverage requirements
- modify tests just to make them pass
- ignore analyzer warnings

If something unexpected happens, stop and diagnose the issue.

---

# Definition of Done

A task is complete only if:

✓ Tests written first
✓ Tests fail initially
✓ Implementation makes tests pass
✓ Intentional bug causes tests to fail
✓ Implementation restored and tests pass
✓ 100% coverage achieved
✓ Code passes flutter analyze
✓ Code is correctly formatted
✓ dart fix suggests no changes
