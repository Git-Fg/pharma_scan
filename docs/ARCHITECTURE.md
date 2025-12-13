# Architecture Documentation

**Version:** 1.0.0
**Status:** Source of Truth for Technical Architecture
**Context:** This document explains the technical skeleton of the application. Usable by any Flutter developer to understand the application structure.

For domain-specific business logic, see `docs/DOMAIN_LOGIC.md`. For maintenance procedures, see `docs/MAINTENANCE.md`.

---

# 2025 Audit Update (December)

- **Navigation:** `PopScope` for back-to-tab-0 removed from `MainScreen`. AutoRoute now manages back stack natively; use `context.router.popForced()` only if strict interception is needed. See section 'Navigation (AutoRoute v11)'.
- **Error Handling:** All Notifier mutations (writes) now use a private `_perform` helper that sets `state = AsyncError` on failure, ensuring robust UI feedback and preventing uncaught DB errors. See section 'Error Handling (Riverpod AsyncValue)'.
- **UI Components:** The main Scan/Stop button is now a dedicated `ScannerActionButton` widget, reducing build complexity and isolating animation/gradient logic.
- **Drift Optimization (2025):** SQL-first mapping using `**` syntax in queries.drift for automatic Drift mapping. Removed repetitive manual extensions in CatalogDao, reducing boilerplate code by over 50 lines.
- **Mappable Enums (2025):** Adopted `@MappableEnum` for `UpdateFrequency` and `SortingPreference` enums, eliminating manual mapping code and using native enum properties for persistence.
- **ScanResult Simplification:** Removed `@MappableClass` annotation to avoid Extension Type serialization issues and implemented manual equality comparison.

---

## High-Level Overview

This application follows an **offline-first architecture** using:

- **State Management:** Riverpod 3.0 with code generation
- **Database:** Drift (SQLite) with FTS5 search
- **UI Framework:** Shadcn UI (Flutter)
- **Navigation:** AutoRoute 11.0.0
- **Data Models:** Dart Mappable
- **Development Platform:** macOS Desktop with DevicePreview simulation
- **Component Testing:** Widgetbook for isolated widget development

The architecture prioritizes **simplicity**, **robustness**, and **performance** in a single-developer environment.

**Target Platforms:** iOS, Android (developed and tested on macOS Desktop)

> **Note:** See `docs/MACOS_DESKTOP_SETUP.md` for complete macOS Desktop development setup and workflow.

---

## Layer Strategy

### UI Layer (View)

**Framework:** Shadcn UI + Flutter Hooks

- **Widgets:** Use `ConsumerWidget` by default. `HookConsumerWidget` reserved for widgets requiring hooks (AnimationController, TextEditingController, FocusNode, `useAutomaticKeepAlive`, `useRef` for gesture state)
- **Components:** Shadcn UI components exclusively (no Material/Cupertino for new code)
- **Responsive:** `ShadResponsiveBuilder` for breakpoint-based layouts
- **Accessibility:** Trust Shadcn's built-in semantics by default
- **Layout:** `CustomScrollView` (Sliver Protocol) for all scrollable screens
- **Rendering:** Impeller rendering engine (standard on iOS/Android since Flutter 3.22+) provides excellent performance for Shadcn's visually rich components (shadows, blurs, gradients), validating the high-fidelity visual approach

**Key Patterns:**

- Forms use `ShadForm` with `GlobalKey<ShadFormState>` (no manual `TextEditingController` management)
- Keep-alive wrappers use `HookWidget` + `useAutomaticKeepAlive()` (no `StatefulWidget` + mixin)
- Gesture/local mutable counters use `useRef` when no rebuild is needed (e.g., swipe deltas)
- Lists use custom `Row` + `ShadTheme` styling (no `ListTile`)
- Status surfaces use native Shad primitives: `ShadAlert`/`ShadAlert.destructive` for banners/errors, `ShadCard` for neutral/empty states; progress lives inside the alert description.
- Large lists (>1k items, e.g., Explorer) use `SliverFixedExtentList` with a standardized item extent (72px) so jump-to-index math is O(1) and scroll layout stays stable.
- Sliver list items use `ShadButton.raw` with `variant: ghost` and `width: double.infinity` (no `LayoutBuilder`/`ConstrainedBox` hacks inside slivers).
- All user-facing strings come from `lib/core/utils/strings.dart`

**Feedback utilisateur:**

- Utilisation de `HapticService` (smart service unique) qui observe `hapticSettingsProvider`. Les widgets/notifiers appellent directement `feedback.success()/warning()/error()/selection()` sans vérifier eux-mêmes les préférences.

**Interactions récentes (2025-12):**

- Scanner : le viseur est animé (idle/détection/succès) et flash vert sur succès en même temps que le haptique; scrim plus sombre autour de la fenêtre.
- Recherche : `HighlightText` met en gras/colorise les occurrences de la requête normalisée (diacritiques ignorés); une étiquette de fraîcheur au-dessus de la barre affiche la date de dernière synchro BDPM et avertit si >30j.
- Restock : le swipe supprime et propose un toast Undo; l’état vide est actionnable (“Commencer le scan”) et la FAB « retour haut » affiche le total scanné.
- Explorer : liste complète préchargée (limite 10k) et navigation A-Z via `AlphabetSidebar` + `SliverFixedExtentList` (72px fixes) et calcul d'offset O(1) (`index * 72`). Plus de pagination offset/limit, plus d'`AutoScrollController`.
- Navigation rapide : `quick_actions` enregistre les raccourcis « Scan to Restock » et « Search Database » qui ouvrent directement les onglets cibles et basculent le mode scanner en restock si besoin.

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

#### Navigation & Layout Structure

**Scaffold Strategy:**


**Hoisted Header Pattern (2025):**

- **MainScreen:** Now owns the single global `Scaffold` and `AppBar` (header) for the app. The AppBar is always present (except for immersive screens like Scanner) and is configured by child screens via a Riverpod provider and the `useAppHeader` hook.
- **Feature Screens:** No longer own a `Scaffold` or `AppBar`. Instead, each screen calls `useAppHeader(...)` at the top of its build method to emit its desired header config (title, actions, back button, visibility). The root widget is typically a `Column` or `CustomScrollView`.
- **Benefits:**
  - Eliminates header flicker and z-index issues during tab switches.
  - Ensures a single source of truth for header styling and logic.
  - Allows immersive/edge-case screens (e.g., Scanner) to hide the header by setting `isVisible: false`.
- **Implementation:**
  - See `lib/core/utils/app_bar_config.dart`, `lib/core/providers/app_bar_provider.dart`, and `lib/core/hooks/use_app_header.dart` for the pattern.
  - All navigation and back button logic is handled in the shell, not in feature screens.

Technical guardrails for UI components are defined in `.cursor/rules/`.

### Visual Identity (Charte Graphique)

L'application utilise une variation personnalisée du système **Shadcn Green** pour s'aligner avec l'esthétique pharmaceutique tout en restant moderne et sobre.

| Mode      | Couleur Primaire | Hex       | Rationale                                                                        |
| :-------- | :--------------- | :-------- | :------------------------------------------------------------------------------- |
| **Light** | **Teal 700**     | `#0F766E` | Évoque la croix de pharmacie et le sérieux médical sans être agressif.           |
| **Dark**  | **Teal 500**     | `#14B8A6` | Version éclaircie pour garantir un contraste suffisant (AA/AAA) sur fond `zinc`. |

**Principes :**

- **Sobriété :** Le vert n'est utilisé que pour les actions principales (Boutons) et les états actifs.
- **Neutralité :** Les fonds et surfaces restent dans les tons `Slate` ou `Zinc` (gris bleutés neutres) pour ne pas fatiguer l'œil.

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
- **Read-only rule:** If a Notifier only implements `build()` (no public mutator methods), implement it as a functional provider instead of a class, and place helpers at file scope.

### Scanner side-effects (ScannerNotifier)

- Purpose: `_sideEffects` uses `StreamController.broadcast(sync: true)` to emit UI-only events (toast, haptic, duplicate warnings) without perturbing the main `AsyncData` state or scan loop throughput.
- Emission rules: keep `_sideEffects` private and call `_emit` only from the notifier; avoid `await` between barcode detection and `_emit` to preserve ordering; payloads stay lightweight (no PII, no heavy objects).
- Safety constraints: cooldowns and `processingCips` already gate duplicate work; controller closes via `ref.onDispose`, and timers are cancelled in `ScannerRuntime.dispose()`, so avoid external controllers or manual closes.
- Consumption guidance: subscribe once per screen via `ref.listen(scannerNotifierProvider, ...)` or a dedicated `useEffect` that listens to `notifier.sideEffects`; let the hook/listener dispose with the widget—no global listeners. Handlers should remain fast (toast/haptic dispatch only) and avoid DB/network calls to keep the scan path jank-free.

**Key Patterns:**

- Expose DAOs directly (no Repository wrappers for 1:1 mappings)
- Use `ref.watch()` in `build()`, `ref.read()` in callbacks
- Never perform side effects (navigation, toasts) inside `build()`

**Global Preferences:**

- `sortingPreferenceProvider`: Exposes the sorting strategy (Princeps vs Generic) affecting both Explorer and Restock List.
- `hapticSettingsProvider`: Controls system vibration permissions.

Technical guardrails for state, modeling, and error handling live in `.cursor/rules/`.

### Data Layer

**Framework:** Drift (SQLite) + Dart Mappable

- **Database:** Drift with SQLite FTS5 (tokenizer/normalization defined in `docs/DOMAIN_LOGIC.md`)
- **Domain Model:** Extension Types (Dart 3) wrap Drift classes before UI consumption (zero-cost abstraction)
- **Mappers:** Only create mappers for significant transformations (e.g., ChartData)
- **Extensions:** Use Dart Extensions on Drift classes for computed properties

**Key Patterns:**

- **SQL-First Logic:** Use SQL Views instead of Dart loops for grouping/sorting/filtering
- **FTS5 Search:** Follow the domain doc for tokenizer/normalization (`docs/DOMAIN_LOGIC.md` Section 4); keep normalization single-source across SQL and Dart helpers
- **Streams:** Prefer `watch()` for all UI data sources
- **Safety:** Use `watchSingleOrNull()` for detail views (handles concurrent deletions)
- **Extension Types:** All database rows must be wrapped in Extension Types before reaching the UI layer. This provides decoupling without runtime overhead and prepares the app for potential Server-Driven UI (SDUI) integration.
- **Parser Strategy:** Use PetitParser for structured grammars (tokenized inputs, nested rules). Hand-written scanners are acceptable only for tiny, single-pass cases with measured perf gains (e.g., current GS1 AI loop); document the rationale when choosing manual parsing.
- **BDPM Ingestion IO:** All TSV inputs are read via `createBdpmRowStream(path)` using `Windows1252Decoder(allowInvalid: true)` piped into `CsvToListConverter(fieldDelimiter: '\t', shouldParseNumbers: false, eol: '\n')`. Parsers consume `Stream<List<dynamic>>` rows directly—no manual `split('\t')` or custom processors.

## Data Layer Architecture

### The "Thin Client" Pattern

PharmaScan operates as a **Thin Client** regarding pharmaceutical data. It does **not** perform ETL (Extract, Transform, Load), parsing, or complex aggregation on the device.

1. **Source of Truth:** The `backend_pipeline/` (TypeScript) parses ANSM files and generates a SQLite artifact (`reference.db`).
2. **Schema Definition:** The database schema is defined in the backend (`backend_pipeline/src/db.ts`).
3. **Synchronization:** The mobile app downloads the pre-computed `reference.db`.
4. **Schema Documentation:** Complete schema reference available in `database_schema.md` (generated artifact).

### Schema Management (`dbschema.drift`)

The file `lib/core/database/dbschema.drift` is a **read-only mirror** of the backend schema.

- **⚠️ DO NOT EDIT MANUALLY:** Changes to core tables (`medicament_summary`, `generique_groups`, etc.) must be made in the backend first.
- **Sync Process:**
  1. Run `bun run build:db` in `backend_pipeline`.
  2. Run the VS Code task `sync:backend`.
  3. Drift generates the Dart code matching the new schema.
- **Schema Reference:** For complete table structure, indexes, views, and relationships, consult `database_schema.md`.

This ensures the mobile app never drifts (pun intended) from the backend structure.

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

Technical guardrails for modeling and error handling live in `.cursor/rules/`.
Data-layer standards are defined in `.cursor/rules/`.

---

## Qualité & Tests (2025)

- **Strings uniques :** Toutes les chaînes exposées à l’utilisateur (et dans les tests) viennent de `lib/core/utils/strings.dart` ; pas de littéraux dans `find.text`.
- **Mocking :** `mocktail` uniquement. Dès qu’un `any()` cible un type non primitif, enregistrer un `registerFallbackValue` dédié.
- **Stubs plateforme :** Pour les tests Drift/sync, injecter `FakePathProviderPlatform` (voir `test/test_utils.dart`) avant d’appeler `DataInitializationService` afin d’éviter les `MissingPluginException`.
- **Mutations Riverpod :** Les écritures utilisent `AsyncValue.guard`; couvrir les états loading/data/error dans les tests.
- **FTS5 & recherche :** Utiliser `NormalizedQuery` et des données minimalistes pour valider ranking/typos/sanitisation, alignées avec `normalize_text` SQL.

## Database Structure

### Complete Schema Reference

**CRITICAL:** For complete database schema documentation (all tables, views, indexes, FTS5 configuration), consult `database_schema.md` (generated artifact).

### Mobile-Specific Tables

#### `restock_items`

- **PK:** `id` (INTEGER AUTOINCREMENT)
- Stores the temporary restock/inventory list.
- **Key Columns:** `cis_code`, `cip_code`, `nom_canonique`, `stock_count`, `expiry_date`, `location`, `notes`
- **Purpose:** Persistent but intended for temporary inventory workflows.
- **Indexes:** `idx_restock_items_cis_code`, `idx_restock_items_expiry_date`

#### `scanned_boxes`

- **PK:** `id` (INTEGER AUTOINCREMENT)
- **Columns:** `box_label`, `cis_code`, `cip_code`, `scan_timestamp`
- **Role:** Scan journal (one row per scan event). Stores scan history.
- **Indexes:** `idx_scanned_boxes_scan_timestamp`

---

## Key Patterns

### 3.1 Simplicity Principles

We prioritize maintainability through simplicity. Abstractions must pay rent: if a class does not reduce complexity or add type safety, it should not exist.

**Anti-Patterns to avoid:**

- Single-line helper functions that only forward parameters.
- “Manager” classes that manage nothing (no state, no orchestration).
- Passthrough repositories/providers over DAOs without transformations or rules.
- “Future-proof” branches/flags with no current caller or test.
- Wrapper widgets that only add padding/styling around library components (see `.cursor/rules/simplicity.mdc`).

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
- UI Side-Effects: Use `useAsyncFeedback(ref, provider, hapticSuccess: true/false)` in widgets to surface destructive toasts on `AsyncError` and haptics on first `AsyncData`. Avoid manual `ref.listen` boilerplate.

**Example:**

```dart
// In Notifier
Future<void> saveData(Data data) async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(() => repository.save(data));
}

// In Widget
final isSaving = useAsyncFeedback<void>(
  ref,
  myNotifierProvider,
  hapticSuccess: true,
    );
```

**Note:** Services ETL (parsing, retry logic) may still use `Either` for complex business logic, but Notifiers should use `AsyncValue.guard`.

Technical guardrails for error handling live in `.cursor/rules/`.

### Navigation (AutoRoute 11.0.0)

**Type Safety:** Always use generated `*Route` classes. Never use raw strings.

**Dependency Injection (2025 Standard):**

For business logic in Notifiers or Controllers, use `ref.router` (from `core/router/router_extensions.dart`) to avoid passing `BuildContext` and keep navigation testable.

```dart
// In a Notifier/Controller
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  void build() {}

  void performAction() {
    ref.router.push(const DetailRoute());
  }
}
```

For simple widget callbacks, `context.router` remains acceptable and convenient.

**Tab Navigation Patterns:**

- **Simple Cases:** Use `AutoTabsScaffold` when you only need tabs with a standard bottom navigation bar
- **Custom Cases:** Use `AutoTabsRouter` with builder pattern when you need:
  - Custom body structure (e.g., activity banner above tab content)
  - Conditional bottom navigation (e.g., hide when keyboard is open)
  - Hoisted AppBar with actions (see Hoisted Header Pattern)
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

Avoid `PopScope` where possible due to conflicts with AutoRoute's internal stack. Use `context.router.popForced()` for interception if strictly necessary, following the navigation guardrails.

**Other Patterns:**

- **Nested Stacks:** Use `AutoRouter` wrapper for tab history
- **Path Parameters:** `@PathParam('paramName')` for dynamic segments
- **Query Parameters:** `@QueryParam('paramName')` for optional query strings
- **Guards:** Use `redirectUntil` instead of `router.push()` for redirects

Navigation guardrails live in `.cursor/rules/`.

### Data Models (Dart Mappable)

**Standard:** Use standard Dart `class` (or `sealed class` for unions) with `@MappableClass()`.

**Forbidden:** `freezed`, `json_serializable`

**Patterns:**

- Immutable classes with `const` constructors
- `sealed class` for unions (use `switch` expressions, not `.map()`/`.when()`)
- Generated mixin provides `toMap()`, `toJson()`, `copyWith()`, etc.

Technical guardrails for data models live in `.cursor/rules/`.

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

Technical guardrails for modeling and data live in `.cursor/rules/`.

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
        logic/             # Pure algorithms (e.g., grouping_algorithms.dart)
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

**Domain Logic:** The `domain/logic/` directory contains pure Dart algorithms independent of UI and database layers (e.g., `grouping_algorithms.dart` for clustering logic). These are testable business logic functions that operate on domain models.

Technical guardrails for folder structure and layering live in `.cursor/rules/`.

---

## Quality Gate

Before committing, run this sequence (stop if any step fails):

```bash
dart run build_runner build --delete-conflicting-outputs
dart fix --apply  # Repeat up to 3 times
dart analyze --fatal-infos --fatal-warnings
flutter test
```

Quality gate guardrails live in `.cursor/rules/`.

---

## Dependencies

### Core Stack

- `riverpod` (^3.0.0) - State management with code generation
- `drift` (latest) - SQLite database
- `shadcn_ui` (latest) - UI components (bundles `flutter_animate`, `lucide_icons_flutter`, `intl`)
- `auto_route` (^11.0.0) - Type-safe navigation
- `dart_mappable` (latest) - Data + state serialization (all immutable DTO/state classes use generated copy/equals/json; manual `copyWith` forbidden)
- `dart_either` (^2.0.0) - Error handling for services ETL (optional, Notifiers use `AsyncValue.guard`)
- `flutter_hooks` (latest) - Widget lifecycle management
- `azlistview` (latest) - Alphabetical navigation with sticky headers in Explorer (Shadcn-styled index bar)

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

Workflow phases are summarized in `AGENTS.md`.

---

## Anti-Patterns (Forbidden)

1. **Premature Abstraction:** Don't extract logic until duplicated in **three** distinct places
2. **Pseudo-Domain:** Don't create DTOs that mirror database rows 1:1 without behavior
3. **Smart Wrapper:** Don't wrap library widgets just to apply padding/scrolling
4. **Layout Manager:** Don't calculate padding in parent widgets—let children handle layout
5. **Manual Form State:** Don't use `TextEditingController` for standard forms—use `ShadForm`
6. **StatefulWidget:** Use `ConsumerWidget` or `HookConsumerWidget` instead
7. **String Paths:** Use generated Route classes, never raw strings for navigation

Anti-pattern guardrails live in `.cursor/rules/`.

---

## Additional Resources

- **Agent Manifesto:** `AGENTS.md` - Complete agent persona and workflow
- **Domain Logic:** `docs/DOMAIN_LOGIC.md` - Business logic and domain knowledge
- **Rule Files:** `.cursor/rules/` - Detailed technical standards
