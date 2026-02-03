---
description: Execute comprehensive QA and fix loop for unit, widget, and integration tests
---

Execute Comprehensive QA & Fix Loop (Unit, Widget, Integration).

## Context

- Framework: Flutter, Riverpod, Drift (SQLite).
- Scope: `test/` (Unit/Widget) and `integration_test/` (E2E).
- Goal: Achieve 100% pass rate on all tests ensuring logical correctness.

## Phase 1: Unit & Widget Tests (Fast Feedback)

// turbo
1. Run `flutter test` to execute all unit and widget tests.
2. If failures occur:
   - **ANALYZE:** Is this a regression in logic or an outdated test?
   - **FIX CODE:** If the logic is broken, fix the implementation in `lib/`.
   - **UPDATE TEST:** Only update the test expectation if the business rule has legitimately changed.
   - **REPEAT:** Run the specific failing test file individually until it passes.

## Phase 2: Integration Tests (Critical Flows)

// turbo
1. Run `flutter test integration_test` (ensure emulator is running).
2. If failures occur:
   - **DIAGNOSE:** Check logs for database locks, navigation errors, or timeout issues.
   - **FIX:** Apply fixes to the app code or synchronization logic (pumpAndSettle).
   - **REPEAT:** Verify the fix by running the specific integration test file.

## Constraints

- **DO NOT** comment out failing tests (skip with TODO if strictly necessary and blocked).
- **DO NOT** blindly change assertions to match output.
// turbo
- Run `dart fix --apply` after significant changes.
- Assume the emulator is running.

## Verification Checklist

- [ ] `flutter test` runs with 0 failures.
- [ ] `flutter test integration_test` runs with 0 failures.
- [ ] No regression in business logic (Search, Grouping, Scanner).
- [ ] No `try-catch` blocks added purely to suppress test errors.
