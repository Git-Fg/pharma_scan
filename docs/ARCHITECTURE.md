# Architecture Documentation

**Version:** 1.0.0  
**Status:** Source of Truth for Technical Architecture  
**Context:** This document explains the technical skeleton of the application. Usable by any Flutter developer to understand the application structure.

For domain-specific business logic, see `docs/DOMAIN_LOGIC.md`. For maintenance procedures, see `docs/MAINTENANCE.md`.

---

## High-Level Overview

This application follows an **offline-first architecture** using:

- **State Management:** Riverpod 3.0 with code generation
- **Database:** Drift (SQLite) with FTS5 search
- **UI Framework:** Shadcn UI (Flutter)
- **Navigation:** AutoRoute 10.3.0
- **Data Models:** Dart Mappable

The architecture prioritizes **simplicity**, **robustness**, and **performance** in a single-developer environment.

---

## Layer Strategy

### UI Layer (View)

**Framework:** Shadcn UI + Flutter Hooks

- **Widgets:** All widgets use `HookConsumerWidget` (never `StatefulWidget`)
- **Components:** Shadcn UI components exclusively (no Material/Cupertino for new code)
- **Responsive:** `ShadResponsiveBuilder` for breakpoint-based layouts
- **Accessibility:** Trust Shadcn's built-in semantics by default
- **Layout:** `CustomScrollView` (Sliver Protocol) for all scrollable screens

**Key Patterns:**

- Forms use `ShadForm` with `GlobalKey<ShadFormState>` (no manual `TextEditingController` management)
- Lists use custom `Row` + `ShadTheme` styling (no `ListTile`)
- All user-facing strings come from `lib/core/utils/strings.dart`

**Form State Management:**

- **Standard Forms:** Always use `ShadForm` with `ShadInputFormField` / `ShadSwitchFormField` for form submission. Access values via `formKey.currentState!.value` after `saveAndValidate()`.
- **Acceptable Exceptions:**
  - **Search Bars:** Use `useTextEditingController()` for search inputs requiring debouncing or real-time filtering (e.g., `ExplorerSearchBar`)
  - **Radio Groups:** Use `useState` for `ShadRadioGroup` selections (not form fields)
  - **Searchable Selects:** Use `useState` for internal search state within `ShadSelect.withSearch`

**Navigation Patterns:**

- **Simple Tab Navigation:** Use `AutoTabsScaffold` when you only need tabs with a bottom navigation bar
- **Custom Tab Navigation:** Use `AutoTabsRouter.pageView` when you need:
  - Swipeable tabs (PageView with custom physics)
  - Custom body structure (e.g., activity banner above tab content)
  - Conditional bottom navigation (e.g., hide when keyboard is open)
  - Custom AppBar with actions
  - PopScope logic for back button handling

**Reference:** `.cursor/rules/flutter-ui.mdc`

### State Layer (ViewModel)

**Framework:** Riverpod 3.0 with Code Generation

- **Providers:** Always use `@riverpod` / `@Riverpod` annotations
- **Widgets:** Always use `HookConsumerWidget` (never `ConsumerWidget`)
- **Async Data:** Prefer `Stream<T>` over `Future<T>` for UI data
- **Error Handling:**
  - **Reads:** `Future<T>` / `Stream<T>` (exceptions bubble up, `AsyncValue` handles errors)
  - **Writes:** `Future<Either<Failure, Success>>` (ROP - Railway Oriented Programming)

**Provider Types:**

- `Future<T>` for data fetching
- `Stream<T>` for real-time database updates
- `class ... extends _$Notifier` for complex logic
- `class ... extends _$AsyncNotifier` for async logic
- `@Riverpod(keepAlive: true)` for static config

**Key Patterns:**

- Expose DAOs directly (no Repository wrappers for 1:1 mappings)
- Use `ref.watch()` in `build()`, `ref.read()` in callbacks
- Never perform side effects (navigation, toasts) inside `build()`

**Reference:** `.cursor/rules/flutter-architecture.mdc`

### Data Layer

**Framework:** Drift (SQLite) + Dart Mappable

- **Database:** Drift with SQLite FTS5 trigram tokenizer
- **Domain Model:** Drift-generated classes used directly in UI (no DTOs/ViewModels)
- **Mappers:** Only create mappers for significant transformations (e.g., ChartData)
- **Extensions:** Use Dart Extensions on Drift classes for computed properties

**Key Patterns:**

- **SQL-First Logic:** Use SQL Views instead of Dart loops for grouping/sorting/filtering
- **FTS5 Search:** Database-level normalization via `normalize_text` SQL function
- **Streams:** Prefer `watch()` for all UI data sources
- **Safety:** Use `watchSingleOrNull()` for detail views (handles concurrent deletions)

**Reference:** `.cursor/rules/flutter-data.mdc`

---

## Key Patterns

### Zero-Boilerplate Mandate

1. **Passthrough Rule:** If a Class/Provider merely passes data from A to B without logic, **DELETE IT**.
2. **No DTOs/ViewModels:** Use Drift classes directly. Use Dart Extensions for computed properties.
3. **Hooks Over StatefulWidget:** All widgets requiring controllers/lifecycle use `HookConsumerWidget`.
4. **Code Deletion:** The highest value action is deleting code. Remove abstraction layers when possible.

### Error Handling (ROP - Railway Oriented Programming)

**Read Operations:**

- Protocol: Fail Fast
- Signature: `Future<T>` or `Stream<T>`
- Behavior: Let exceptions bubble up
- Handling: Riverpod's `AsyncValue` catches and renders error state

**Write/Logic Operations:**

- Protocol: Functional Safety (ROP)
- Library: `dart_either` (^2.0.0)
- Signature: `Future<Either<Failure, Success>>`
- Behavior: Catch exceptions and map to `Failure`
- Reason: Writes need explicit recovery logic (retry, rollback, user alerts)

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Error Handling section)

### Navigation (AutoRoute 10.3.0)

**Type Safety:** Always use generated `*Route` classes. Never use raw strings.

**Tab Navigation Patterns:**

- **Simple Cases:** Use `AutoTabsScaffold` when you only need tabs with a standard bottom navigation bar
- **Custom Cases:** Use `AutoTabsRouter.pageView` when you need:
  - Swipeable tabs (PageView with custom physics)
  - Custom body structure (e.g., activity banner above tab content)
  - Conditional bottom navigation (e.g., hide when keyboard is open)
  - Custom AppBar with actions
  - PopScope logic for back button handling

**Other Patterns:**

- **Nested Stacks:** Use `AutoRouter` wrapper for tab history
- **Path Parameters:** `@PathParam('paramName')` for dynamic segments
- **Query Parameters:** `@QueryParam('paramName')` for optional query strings

**Reference:** `.cursor/rules/flutter-navigation.mdc`

### Data Models (Dart Mappable)

**Standard:** Use standard Dart `class` (or `sealed class` for unions) with `@MappableClass()`.

**Forbidden:** `freezed`, `json_serializable`

**Patterns:**

- Immutable classes with `const` constructors
- `sealed class` for unions (use `switch` expressions, not `.map()`/`.when()`)
- Generated mixin provides `toMap()`, `toJson()`, `copyWith()`, etc.

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Data Models section)

---

## Folder Structure

### Feature-First Organization

```
lib/
  core/                    # Infrastructure (shared across features)
    constants/             # App-wide constants
    database/              # Drift database, DAOs, views
    router/                # AutoRoute configuration
    services/              # Business services (logging, download, etc.)
    utils/                 # Utilities (strings, hooks, etc.)
    widgets/               # Shared UI components
  features/                # Business domains
    auth/                  # Example: Authentication feature
      domain/              # Domain models (Dart Mappable)
      presentation/
        screens/           # Screen widgets
        widgets/           # Feature-specific widgets
        providers/         # Feature-specific providers
    explorer/              # Example: Data exploration feature
      ...
  theme/                   # Theme configuration
```

**Principles:**

- Each feature is self-contained
- Core infrastructure is shared
- Avoid cross-feature dependencies

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Folder Structure section)

---

## Testing Strategy

### Unit Tests

- Focus on logic in `lib/core/`
- Test business logic, parsers, and utilities in isolation

### Widget Tests

- Test UI components with mocked providers
- Use `ShadApp.custom` in test helpers
- Test all `AsyncValue` states (Loading, Data, Error)

### Integration Tests

- Validate flows using real DB logic (Drift in-memory)
- Test complete user flows and data pipelines
- Use Robot pattern for complex, reusable flows

**Reference:** `.cursor/rules/flutter-qa.mdc`

---

## Quality Gate

Before committing, run this sequence (stop if any step fails):

```bash
dart run build_runner build --delete-conflicting-outputs
dart fix --apply  # Repeat up to 3 times
dart analyze --fatal-infos --fatal-warnings
flutter test
```

**Reference:** `.cursor/rules/flutter-qa.mdc` (Quality Gate section)

---

## Dependencies

### Core Stack

- `riverpod` (^3.0.0) - State management with code generation
- `drift` (latest) - SQLite database
- `shadcn_ui` (latest) - UI components (bundles `flutter_animate`, `lucide_icons_flutter`, `intl`)
- `auto_route` (^10.3.0) - Type-safe navigation
- `dart_mappable` (latest) - Data serialization
- `dart_either` (^2.0.0) - Error handling (ROP)
- `flutter_hooks` (latest) - Widget lifecycle management

### Linting

- `very_good_analysis` - Strict linting rules

**Reference:** `pubspec.yaml`

---

## Development Workflow

1. **Plan:** Analyze requirements and verify documentation
2. **Implement:** Write code following architecture patterns
3. **Audit:**
   - Check for hardcoded strings (move to `Strings.dart`)
   - Check for prohibited widgets (`Scaffold` in sub-views)
4. **Quality Gate:** Run build, fix, analyze, and test commands

**App Lifecycle:** `bash tool/run_session.sh` and `bash tool/run_session.sh stop` are the **ONLY** permitted ways to run the Flutter app for testing.

**Reference:** `AGENTS.md` (Workflow Phases section)

---

## Anti-Patterns (Forbidden)

1. **Premature Abstraction:** Don't extract logic until duplicated in **three** distinct places
2. **Pseudo-Domain:** Don't create DTOs that mirror database rows 1:1 without behavior
3. **Smart Wrapper:** Don't wrap library widgets just to apply padding/scrolling
4. **Layout Manager:** Don't calculate padding in parent widgets—let children handle layout
5. **Manual Form State:** Don't use `TextEditingController` for standard forms—use `ShadForm`
6. **StatefulWidget:** Use `HookConsumerWidget` instead
7. **String Paths:** Use generated Route classes, never raw strings for navigation

**Reference:** `.cursor/rules/flutter-architecture.mdc` and `.cursor/rules/flutter-ui.mdc` (Anti-Patterns sections)

---

## Additional Resources

- **Agent Manifesto:** `AGENTS.md` - Complete agent persona and workflow
- **Domain Logic:** `docs/DOMAIN_LOGIC.md` - Business logic and domain knowledge
- **Maintenance:** `docs/MAINTENANCE.md` - Setup, operations, and release procedures
- **Rule Files:** `.cursor/rules/*.mdc` - Detailed technical standards
