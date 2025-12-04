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
- **Navigation:** AutoRoute 11.0.0
- **Data Models:** Dart Mappable

The architecture prioritizes **simplicity**, **robustness**, and **performance** in a single-developer environment.

---

## Layer Strategy

### UI Layer (View)

**Framework:** Shadcn UI + Flutter Hooks

- **Widgets:** Use `ConsumerWidget` by default. `HookConsumerWidget` reserved for widgets requiring hooks (AnimationController, TextEditingController, FocusNode)
- **Components:** Shadcn UI components exclusively (no Material/Cupertino for new code)
- **Responsive:** `ShadResponsiveBuilder` for breakpoint-based layouts
- **Accessibility:** Trust Shadcn's built-in semantics by default
- **Layout:** `CustomScrollView` (Sliver Protocol) for all scrollable screens
- **Rendering:** Impeller rendering engine (standard on iOS/Android since Flutter 3.22+) provides excellent performance for Shadcn's visually rich components (shadows, blurs, gradients), validating the high-fidelity visual approach

**Key Patterns:**

- Forms use `ShadForm` with `GlobalKey<ShadFormState>` (no manual `TextEditingController` management)
- Lists use custom `Row` + `ShadTheme` styling (no `ListTile`)
- All user-facing strings come from `lib/core/utils/strings.dart`

**Feedback Utilisateur :**

- Utilisation de `HapticService` pour les retours sensoriels (Succès, Erreur, Warning).
- Le feedback haptique est conditionné par les préférences utilisateur (`AppSettings`).

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
  - **Note (2025):** `@riverpod` + `build_runner` remains the standard due to the cancellation of Dart Macros
- **Widgets:** Use `ConsumerWidget` by default. `HookConsumerWidget` reserved for widgets requiring hooks (AnimationController, TextEditingController, FocusNode)
- **Async Data:** Prefer `Stream<T>` over `Future<T>` for UI data
- **Error Handling:**
  - **Reads:** `Future<T>` / `Stream<T>` (exceptions bubble up, `AsyncValue` handles errors)
  - **Writes:** `AsyncValue.guard` pattern (native error handling in Notifiers)

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

**Global Preferences:**

- `sortingPreferenceProvider`: Exposes the sorting strategy (Princeps vs Generic) affecting both Explorer and Restock List.
- `hapticSettingsProvider`: Controls system vibration permissions.

**Reference:** `.cursor/rules/flutter-architecture.mdc`

### Data Layer

**Framework:** Drift (SQLite) + Dart Mappable

- **Database:** Drift with SQLite FTS5 trigram tokenizer
- **Domain Model:** Extension Types (Dart 3) wrap Drift classes before UI consumption (zero-cost abstraction)
- **Mappers:** Only create mappers for significant transformations (e.g., ChartData)
- **Extensions:** Use Dart Extensions on Drift classes for computed properties

**Key Patterns:**

- **SQL-First Logic:** Use SQL Views instead of Dart loops for grouping/sorting/filtering
- **FTS5 Search:** Database-level normalization via `normalize_text` SQL function
- **Streams:** Prefer `watch()` for all UI data sources
- **Safety:** Use `watchSingleOrNull()` for detail views (handles concurrent deletions)
- **Extension Types:** All database rows must be wrapped in Extension Types before reaching the UI layer. This provides decoupling without runtime overhead and prepares the app for potential Server-Driven UI (SDUI) integration.

#### Zero-Cost Abstraction Strategy

**Core Principle:** Use Dart 3 Extension Types to create type-safe abstractions with zero runtime overhead.

**Why Extension Types?**

Extension Types are compile-time wrappers that provide:
- **Zero Runtime Cost:** No memory allocation or performance penalty
- **Type Safety:** Prevents mixing different ID types (e.g., `Cip13` vs `CisCode`)
- **Invariant Guarantees:** Semantic types (e.g., `NormalizedQuery`) ensure values meet specific requirements
- **Decoupling:** Database schema changes only require updating Extension Types, not UI widgets

**Three Use Cases:**

1. **ID Types:** Replace primitive `String` obsession with strongly-typed IDs (`Cip13`, `CisCode`, `GroupId`)
   - Prevents accidentally passing wrong ID type
   - Compile-time validation catches errors early
   - Example: `getProductByCip(Cip13 code)` cannot accept `CisCode` by mistake

2. **Semantic Types:** Enforce invariants at the type level (e.g., `NormalizedQuery`)
   - Factory constructor guarantees normalization happens once
   - Eliminates redundant normalization calls throughout codebase
   - Example: `searchMedicaments(NormalizedQuery query)` guarantees normalized input

3. **Domain Wrappers:** Wrap database rows before UI consumption (e.g., `MedicamentEntity`)
   - Decouples UI from database schema
   - Enables future migration to different data sources (SDUI, remote APIs)
   - Example: Renaming a database column only requires updating the Extension Type

**Type Safety Benefits:**

- **Impossible to Mix IDs:** `Cip13` and `CisCode` are distinct types—compiler prevents mixing
- **Guaranteed Invariants:** `NormalizedQuery` type system ensures normalization
- **Self-Documenting APIs:** Method signatures clearly indicate expected types

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Modern Modeling with Extension Types section)

**Reference:** `.cursor/rules/flutter-data.mdc`

---

## Database Structure

### 6.1 Core Tables

#### `RestockItems`

* **PK:** `cip` (Text, 13 digits)
* Stores the temporary restock list.
* **Columns:** `quantity` (Int), `isChecked` (Bool), `addedAt` (DateTime).
* **Note:** This table is persistent but intended for temporary workflows.

---

## Key Patterns

### Zero-Boilerplate Mandate

1. **Passthrough Rule:** If a Class/Provider merely passes data from A to B without logic, **DELETE IT**.
2. **Extension Types for Zero-Cost Abstraction:** Use **Extension Types** (Dart 3) to wrap database rows before exposing to UI. This provides decoupling without runtime overhead. **FORBIDDEN:** Exposing raw Drift classes directly in UI. **FORBIDDEN:** Traditional DTOs/ViewModels (classes with allocation) that mirror database rows 1:1.
3. **Widget Default:** Use `ConsumerWidget` by default. `HookConsumerWidget` only when hooks are needed (controllers, animations).
4. **Code Deletion:** The highest value action is deleting code. Remove abstraction layers when possible.

### Error Handling (Native AsyncValue)

**Read Operations:**

- Protocol: Fail Fast
- Signature: `Future<T>` or `Stream<T>`
- Behavior: Let exceptions bubble up
- Handling: Riverpod's `AsyncValue` catches and renders error state

**Write/Logic Operations (2025 Standard):**

- Protocol: Native AsyncValue Error Handling
- Pattern: Use `AsyncValue.guard` in Notifiers for mutations
- Signature: `Future<void>` (or `Future<T>`) with `state = await AsyncValue.guard(...)`
- Behavior: `AsyncValue.guard` automatically catches exceptions and sets state to `AsyncError`
- UI Side-Effects: Use `ref.listen` in widgets to detect `AsyncError` and show SnackBars/Alerts

**Example:**

```dart
// In Notifier
Future<void> saveData(Data data) async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(() => repository.save(data));
}

// In Widget
ref.listen(myNotifierProvider, (prev, next) {
  if (next is AsyncError) {
    ShadToaster.of(context).show(
      ShadToast.destructive(
        title: Text(Strings.error),
        description: Text(next.error.toString()),
      ),
    );
  }
});
```

**Note:** Services ETL (parsing, retry logic) may still use `Either` for complex business logic, but Notifiers should use `AsyncValue.guard`.

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Error Handling section)

### Navigation (AutoRoute 11.0.0)

**Type Safety:** Always use generated `*Route` classes. Never use raw strings.

**Dependency Injection (2025 Standard):**

For business logic in Notifiers or Controllers, inject the router via Riverpod instead of using `context.router`. This decouples navigation from the widget tree and improves testability.

```dart
// In a Notifier/Controller
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  void build() {}

  void performAction() {
    final router = ref.read(appRouterProvider);
    router.push(const DetailRoute());
  }
}
```

For simple widget callbacks, `context.router` remains acceptable and convenient.

**Tab Navigation Patterns:**

- **Simple Cases:** Use `AutoTabsScaffold` when you only need tabs with a standard bottom navigation bar
- **Custom Cases:** Use `AutoTabsRouter` with builder pattern when you need:
  - Custom body structure (e.g., activity banner above tab content)
  - Conditional bottom navigation (e.g., hide when keyboard is open)
  - Custom AppBar with actions
  - PopScope logic for back button handling

**Pattern Example:**

```dart
AutoTabsRouter(
  routes: const [ScannerRoute(), ExplorerTabRoute()],
  builder: (context, child) {
    final tabsRouter = AutoTabsRouter.of(context);
    return Scaffold(
      body: child, // AutoRoute manages the page stack automatically
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabsRouter.activeIndex,
        onDestinationSelected: tabsRouter.setActiveIndex,
      ),
    );
  },
)
```

**Reactive Guards:**

Use `reevaluateListenable` in router configuration to make guards reactive to state changes (e.g., authentication):

```dart
routerConfig: appRouter.config(
  reevaluateListenable: ref.watch(authNotifierProvider),
),
```

**Pop Management:**

Avoid `PopScope` where possible due to conflicts with AutoRoute's internal stack. Use `context.router.popForced()` for interception if strictly necessary. See `.cursor/rules/flutter-navigation.mdc` section 11 for details.

**Other Patterns:**

- **Nested Stacks:** Use `AutoRouter` wrapper for tab history
- **Path Parameters:** `@PathParam('paramName')` for dynamic segments
- **Query Parameters:** `@QueryParam('paramName')` for optional query strings
- **Guards:** Use `redirectUntil` instead of `router.push()` for redirects

**Reference:** `.cursor/rules/flutter-navigation.mdc`

### Data Models (Dart Mappable)

**Standard:** Use standard Dart `class` (or `sealed class` for unions) with `@MappableClass()`.

**Forbidden:** `freezed`, `json_serializable`

**Patterns:**

- Immutable classes with `const` constructors
- `sealed class` for unions (use `switch` expressions, not `.map()`/`.when()`)
- Generated mixin provides `toMap()`, `toJson()`, `copyWith()`, etc.

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Data Models section)

### Scalability & Decoupling

**Extension Types Architecture (2025 Standard):**

The application uses **Extension Types** (Dart 3) to create zero-cost abstractions that decouple the UI layer from the database schema. This architectural choice provides several benefits:

- **Zero Runtime Overhead:** Extension Types are compile-time wrappers that add no memory allocation or performance cost
- **Schema Decoupling:** Renaming a database column only requires updating the Extension Type getter, not every UI widget
- **Future-Proof:** Enables migration to different data sources (Server-Driven UI, remote APIs) without changing UI code
- **Type Safety:** Prevents accidental access to internal database fields in the UI layer

**Example Pattern:**

```dart
// Domain Layer: Extension Type wraps Drift class
extension type MedicamentEntity(MedicamentSummaryData _data) {
  String get canonicalName => _data.nomCanonique;
  String get pharmaceuticalForm => _data.formePharmaceutique ?? '';
  bool get isPrinceps => _data.isPrinceps;
}

// UI Layer: Consumes only Extension Types
final List<MedicamentEntity> items = ref.watch(itemsProvider);
Text(items.first.canonicalName); // Decoupled from DB schema!
```

**Server-Driven UI (SDUI) Readiness:**

The Extension Types pattern prepares the application for potential Server-Driven UI integration. If the app needs to consume JSON-driven UI configurations from a server, the Extension Types can be extended to support both database-backed and API-backed data sources without changing the UI layer.

**Reference:** `.cursor/rules/flutter-architecture.mdc` (Domain Model section) and `.cursor/rules/flutter-data.mdc` (Extension Types Pattern section)

---

## Folder Structure

### Feature-First Organization

```text
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
      domain/              # Domain layer
        models/            # Domain entities (Dart Mappable)
        logic/             # Pure algorithms (Grouping, Sorting, Clustering)
      presentation/
        screens/           # Screen widgets
        widgets/           # Feature-specific widgets
        providers/         # Feature-specific providers
    explorer/              # Example: Data exploration feature
      domain/
        entities/          # Extension Types wrapping database models
        models/            # Domain entities (Dart Mappable)
        logic/             # Pure algorithms (e.g., ExplorerGroupingHelper)
      presentation/
        screens/
        widgets/
        providers/
  theme/                   # Theme configuration
```

**Principles:**

- Each feature is self-contained
- Core infrastructure is shared
- Avoid cross-feature dependencies

**Domain Logic:** The `domain/logic/` directory contains pure Dart algorithms independent of UI and database layers (e.g., `ExplorerGroupingHelper` for clustering logic). These are testable business logic functions that operate on domain models.

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
- `auto_route` (^11.0.0) - Type-safe navigation
- `dart_mappable` (latest) - Data serialization
- `dart_either` (^2.0.0) - Error handling for services ETL (optional, Notifiers use `AsyncValue.guard`)
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
6. **StatefulWidget:** Use `ConsumerWidget` or `HookConsumerWidget` instead
7. **String Paths:** Use generated Route classes, never raw strings for navigation

**Reference:** `.cursor/rules/flutter-architecture.mdc` and `.cursor/rules/flutter-ui.mdc` (Anti-Patterns sections)

---

## Additional Resources

- **Agent Manifesto:** `AGENTS.md` - Complete agent persona and workflow
- **Domain Logic:** `docs/DOMAIN_LOGIC.md` - Business logic and domain knowledge
- **Maintenance:** `docs/MAINTENANCE.md` - Setup, operations, and release procedures
- **Rule Files:** `.cursor/rules/*.mdc` - Detailed technical standards
