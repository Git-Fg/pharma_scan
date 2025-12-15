# 🦅 PharmaScan Lint Rules

> **Legislative Branch of PharmaScan Engineering**
> "Code is Law. Lints are the Enforcers."

This document outlines the strict rules enforced by `pharma_lints`. These are not suggestions; they are standard operating procedures.

---

## 🏗️ 1. Architecture Rules

### `enforce_architecture_layering`
**ERROR:** `❌ CORE VIOLATION` or `❌ FEATURE VIOLATION`
- **Why**: Prevents circular dependencies and spaghetti code. Keeps features independent.
- **Rule**:
    - `Core` layer can NEVER import from `Features` layer.
    - `Feature A` can NEVER import from `Feature B` (unless explicitly shared via Core).
- **For Agents**: If you hit this, you are trying to couple things that should be separate. Refactor the shared logic into `lib/core`.

### `enforce_ui_isolation`
**ERROR:** `❌ THIN CLIENT`
- **Why**: The UI should never speak SQL. It keeps the presentation layer "dumb" and testable.
- **Rule**: Files in `presentation/`, `screens/`, `widgets/` cannot import `drift` or `.drift.dart` files.
- **Fix**: Move the database call to a `Repository` or `DAO` in the `domain/` or `data/` layer.

### `enforce_hook_prefix`
**ERROR:** `❌ HOOK RULES`
- **Why**: Flutter Hooks rely on call order. Hiding them inside normal helper functions breaks this contract and causes crashes.
- **Rule**: Any function that calls a hook (e.g., `useState`) MUST be named starting with `use` (e.g., `useMyHelper`).

---

## 🎨 2. Design System Rules

### `avoid_direct_colors`
**ERROR:** `❌ FORBIDDEN`
- **Why**: Hardcoded colors (`Colors.red`) break Dark Mode and theming.
- **Rule**: Use semantic tokens only.
- **Fix**: `context.shadColors.destructive` instead of `Colors.red`.

### `avoid_print`
**ERROR:** `❌ OBSERVABILITY`
- **Why**: `print()` is swallowed in production and provides no log levels/context.
- **Rule**: Use the structured `LoggerService`.
- **Fix**: Use `ref.read(loggerProvider).info('message')`.

---

## 💾 3. Data Integrity Rules

### `enforce_dto_conversion`
**ERROR:** `❌ DATA MODEL`
- **Why**: Ensures a clean separation between raw Data Models (JSON/SQL) and Domain Entities.
- **Rule**: All classes ending in `Model` must implement `toEntity()`.

---

## 🤖 For AI Agents
If you encounter these errors, **read the Error Message carefully**. It tells you exactly what architecture pattern you violated.
**DO NOT** simply add `// ignore` unless explicitly instructed.
**DO** refactor the code to comply with the architecture.
