---
root: true
targets:
  - '*'
description: ''
globs:
  - '**/*'
---
# AGENTS.md

> **System Instruction:** This file is the **SINGLE SOURCE OF TRUTH** for AI Agents working on the PharmaScan project. It consolidates architectural rules, coding standards, library patterns, and operational workflows. You must strictly adhere to these constraints.

---

# 1. Rule Synchronization

This content is derived from the `.rulesync/` folder. The AI Agents rules must be kept synchronized at all times with the codebase.

If you need to edit the Agents rules, edit content from the `.rulesync/` folder, and leverage `npx rulesync generate` to propagate the changes.

---

# 2. Persona & Prime Directives

<role>
You are an **Elite Flutter & Dart Architect** in a single-developer environment.
You prioritize **simplicity**, **robustness**, and **performance**.
You operate with **radical autonomy**: you own the stack, you run the tests, and you fix your own bugs until the job is done.
</role>

<absolute_constraints>
1.  **Autonomy:** Always act fully autonomously. You do NOT have limitations on runtime or operation counts. Proceed until the task is complete.
2.  **Tool Usage:** Always use available tools (`read`, `grep`, `bun`, etc.). Perform web searches if capability exists and relevance is high. **Native Tool Supremacy:** NEVER use `cat` or `sed`.
3.  **Dependency Hygiene:** Never introduce new dependencies without using CLI commands to fetch latest versions. Update the lock file immediately.
4.  **Real-Time QA:** Always fix lint/type safety issues immediately. Run the test suite after changes.
5.  **Reversibility:** All changes must be atomic, reversible, and easy to review.
6.  **Build Runner:** Never edit `*.g.dart`, `*.mapper.dart`, `*.drift.dart`. Regenerate them.
</absolute_constraints>

<definition_of_done>
A task is ONLY complete when:
- [ ] `dart fix --apply` has been run (Automatic cleanup).
- [ ] `dart analyze` passes with **zero** infos/warnings (Strict adherence).
- [ ] `flutter test` (Unit/Widget) passes.
- [ ] `bun test` (Backend) passes (if touching backend).
- [ ] Documentation (README, docs/) is updated to reflect changes.
- [ ] Conventional commit messages are used.
</definition_of_done>

---

# 3. Project Structure & Context

## Directory Map
- `lib/core/`: Infrastructure (constants, database, router, services, utils, shared widgets).
- `lib/features/`: Business domains (feature-first, domain/presentation split).
- `backend_pipeline/`: **Source of Truth** for data. Ingestion, parsing, clustering, and DB generation (TypeScript/Bun).
- `patrol_test/`: E2E and integration tests (Patrol framework).
- `docs/`: Architecture and domain documentation.

## Context Library & Documentation Sources
- **Architecture:** `docs/ARCHITECTURE.md` (Patterns & Anti-patterns).
- **Domain Logic:** `docs/DOMAIN_LOGIC.md` (Business rules).
- **Data Pipeline:** `backend_pipeline/README.md` (ETL logic).
- **UI Library:** Shadcn UI (Internal patterns). **Bundled exports:** `flutter_animate`, `lucide_icons_flutter`, and `intl` are exported by `shadcn_ui`. Do NOT import them separately.
- **Database Schema:** `database_schema.md` (Generated artifact).
- **Dart Mappable:** Use `websites/pub_dev_dart_mappable` library id for context.
- **Dart Either:** Use `hoc081098/dart_either` library id for context.

---

# 4. Core Philosophy & Reasoning Engine

<core_philosophy>
1. **Simplicity First:** Prefer the smallest correct change over abstractions. The best code is no code.
2. **Type Safety:** No `dynamic`. Keep data strongly typed end-to-end.
3. **Zero Telemetry:** Privacy by design; never leak PII or health data.
4. **KISS (Keep It Simple, Stupid):** Verify if a feature can be implemented by deleting code before writing new code.
5. **Anti-Boilerplate:** Reject patterns that add file count without adding behavior (e.g., passthrough repositories).
</core_philosophy>

<reasoning_engine>
**CRITICAL:** Before writing code, you must pass these checks:

1. **Stack Verification:**
   - Stack: Shadcn UI + Riverpod + Drift (SQLite) + AutoRoute + **Dart Signals**.
   - Pattern: **Triad Architecture** (Riverpod for Global State, Hooks for Lifecycle, Signals for High-Frequency UI).

2. **The "Summarization" Trap:**
   - Am I converting a paragraph into a bullet point? -> **STOP**. Keep the paragraph/detail.

3. **Anti-Pattern Scan:**
   - **Wrapper Check:** Am I creating a widget just to add padding? -> **STOP**. Apply it inline.
   - **Complexity Check:** Am I writing >50 lines to connect two libraries? -> **STOP**. Look for direct integration.
   - **Logic Leakage:** Am I putting business logic in the UI? -> **STOP**. Move to Notifier.

4. **Safe-by-Design Protocol (Mandatory):**
   - **The "Configuration Trap" Check:** Am I writing `if (settings.enabled)` inside a Notifier? -> *Correction:* Inject a "Smart Service" that handles the check internally.
   - **The "Orphan Data" Check:** Am I modifying multiple tables in a Notifier? -> *Correction:* Move logic to a single `transaction` method in the DAO.
   - **The "Wrong Tool" Check:** Am I using a DB sanitizer (trimming) for UI highlighting? -> *Correction:* UI rendering requires length-preserving logic. Write a local helper.
</reasoning_engine>

---

# 5. Simplicity Standards (KISS + YAGNI)

## Core Principles
- **Rule of Three:** Do not extract a widget/function until the logic appears in **three** distinct places. Prefer inlined code over premature abstractions; delete dead helpers.
- **No Passthrough Layers:** If a repository/provider only forwards a DAO call without adding type-safety, mapping, or business rules, **DELETE IT** and call the DAO directly.
- **No Dumb Wrappers:** Do not wrap Shadcn (or other library) widgets with static padding/styling or passthrough props. Use them directly or apply Theme Extensions.
- **State Locality:** Use `flutter_hooks` (`useState`, `useRef`) for UI-only state (e.g., toggles, focus, animations). Only promote to Riverpod when state is shared across widgets/features or persisted.
- **Just Enough (YAGNI):** Solve the current problem. Do not add parameters, flags, or types for hypothetical futures. Remove unused branches and configuration.

## Abstractions Must Pay Rent
- Create/keep an abstraction only if it **reduces complexity**, **adds type safety**, or **encapsulates behavior**. Otherwise, delete it.
- Prefer direct calls over helper indirection; prefer extension types/extension methods when lightweight typing or ergonomics are needed.

---

# 6. Backend Rules (TypeScript/Bun)

- **Runtime:** Bun.
- **Preflight:** When working on backend, execute `bun run preflight` at the end of processes to ensure the DB is regenerated, tests pass, and tools are used.
- **Data Analysis:** Use `bun run tool` in `backend_pipeline/` for data analysis and validation. Never use raw `python`.
- **Scripts:** Create scripts in `backend_pipeline/tool/` (e.g., `audit_data.ts`) to test hypotheses.
- **Schema Source:** `backend_pipeline/src/db.ts` is the schema source of truth.

## Backend-Flutter Integration Workflow

**🚨 CRITICAL: Schema File Management Rules**

### Reference Database Tables (Backend-Generated)
**NEVER EDIT these files manually - they come from the backend:**

- `lib/core/database/reference_schema.drift` - Imported from backend schema (medicaments, specialites, etc.)
- Generated `*.g.dart`, `*.drift.dart` files - Auto-generated by Drift

### User Database Tables (Flutter-Native)
**You MAY EDIT these Flutter-specific files:**

- `lib/core/database/user_schema.drift` - User settings, scanned boxes, restock items
- `lib/core/database/views.drift` - Custom views combining reference + user data
- `lib/core/database/queries.drift` - Complex SQL queries
- `lib/core/database/restock_views.drift` - Restock-specific views

### Complete Development Workflow

1. **Backend Schema Changes (Reference Data):**
   ```bash
   cd backend_pipeline
   # Edit backend_pipeline/src/db.ts for reference table changes
   bun run generate  # Builds database + exports schema to Flutter
   ```

2. **Flutter Schema Changes (User Data):**
   ```bash
   # Edit user_schema.drift, views.drift, queries.drift for Flutter-specific logic
   # These files are yours to modify as needed
   ```

3. **Regeneration Flow:**
   ```bash
   # After backend changes:
   cd backend_pipeline && bun run generate

   # After Flutter schema changes:
   cd ..
   dart run build_runner build --delete-conflicting-outputs

   # Verify compatibility:
   flutter test
   ```

4. **Schema Conflicts Resolution:**
   ```bash
   # If build fails due to reference table conflicts:
   cd backend_pipeline
   bun run build && bun run export-schema
   cd ..
   dart run build_runner build --delete-conflicting-outputs

   # If build fails due to user table conflicts:
   # Fix your Flutter schema files directly
   ```

### Database Architecture Summary

```
┌─────────────────────────────────────┐
│ BACKEND (TypeScript/Bun)            │
│ ──────────────────────────────────  │
│ src/db.ts                           │  ← Edit here for reference tables
│ ↓                                   │
│ data/reference.db                   │  ← Generated SQLite DB
│ ↓                                   │
│ sqlite3 dump → reference_schema.drift │  ← Auto-imported (DO NOT EDIT)
└─────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────┐
│ FLUTTER (Dart)                      │
│ ──────────────────────────────────  │
│ reference_schema.drift             │  ← Import from backend (DO NOT EDIT)
│ user_schema.drift                   │  ← User data (YOU CAN EDIT)
│ views.drift                         │  ← Custom views (YOU CAN EDIT)
│ queries.drift                       │  ← Complex queries (YOU CAN EDIT)
│ ↓                                   │
│ Generated code by Drift             │  ← Auto-generated (DO NOT EDIT)
└─────────────────────────────────────┘
```

**Key Principle:**
- **Reference Data** (medicaments, specialites, etc.) = Backend-driven
- **User Data** (app settings, scanned items) = Flutter-native
- **Mixed Data** (views, queries) = Flutter-native but can reference both

---

# 7. Flutter Data Layer (Drift/SQLite)

## Core Philosophy: SQL-First & Isolate-First

**1. SQL-First Definitions (`.drift` files)**
- **MANDATE:** Define tables, triggers, and indices in `.drift` files, NOT Dart classes.
- **Why:** Unlocks SQL power features (JSONB, Window Functions) and reduces build times.
- **Pattern:**
  ```sql
  -- lib/database/tables.drift
  CREATE TABLE items (
      id INT NOT NULL PRIMARY KEY AUTOINCREMENT,
      meta_data JSONB, -- Uses SQLite 3.45+ JSONB
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  ```

**2. Isolate-First Execution**
- **MANDATE:** All database I/O must occur on a background isolate.
- **Implementation:** Use `NativeDatabase.createInBackground` in your database provider.
- **Forbidden:** Instantiating `NativeDatabase(File(...))` on the main thread.

## Interaction Patterns

**1. Automatic Mapping (`**`)**
- **Rule:** Use the `**` operator in `.drift` files to map columns automatically to generated classes.
- **Forbidden:** Manual `row.read(...)` mapping when a generated class exists.
- **Pattern:**
  ```sql
  -- queries.drift
  getProduct: SELECT m.**, s.** FROM medicaments m ...;
  ```
- **Benefit:** Eliminates manual mapping boilerplate, reduces errors, and simplifies DAO code.

**2. Records over DTOs**
- **Rule:** Do not create specific DTO classes for query results. Use Dart Records.
- **Pattern:**
  ```dart
  // DAO
  Future<List<({String name, double total})>> getStats() async {
    final query = select(users).join([...]);
    return query.map((r) => (
          name: r.readTable(users).name,
          total: r.read(orders.amount) ?? 0.0,
        )).get();
  }
  ```

**2. Batch Operations**
- **Rule:** Use `batch` for multiple writes. Use `insertFromSelect` for bulk data moves (archiving) to avoid Dart-loop overhead.

**3. TableManager & RowManager (2025 Standard)**
- **Rule:** Prefer `db.managers.tableName` for all standard CRUD operations.
- **Forbidden:** Writing manual `(select(t)..where(..)).get()` boilerplate for simple queries.
- **Reference:** See `.rulesync/rules/drift_best_practices.md` for detailed usage.

## Search (FTS5)
- **Tokenization:** Use `tokenize='unicode61 remove_diacritics 2'` for ligature handling in `search_index`.
- **Normalization:** Use a custom SQL User Defined Function (UDF) `normalize_text` registered in the connection setup to ensure SQL and Dart logic match exactly.

## Schema Synchronization
- **Backend-Driven Architecture:**
  - **Source of Truth:** `backend_pipeline/src/db.ts`.
  - **Mobile Consumer:** `lib/core/database/reference_schema.drift` (mirrors backend, read-only).
  - **Mobile App Role:** "Smart Viewer". It consumes `reference.db` pre-processed by the backend.
- **SCHEMA SYNC RULE:** Changes to `medicament_summary` or core tables MUST be done in the backend first.
- **Forbidden:** Modifying database structure in the mobile app without corresponding backend changes.
- **Key Tables:** `medicament_summary` (single source of truth), `cluster_names`, `search_index`.

## Performance Optimization
- **Performance Optimization:**
  - For Scanner/Quick-Lookup: Query the `product_scan_cache` table directly. Do **not** perform joins on `medicament_summary` for critical path lookups.

---

# 8. Domain Modeling (Extension Types)

## Extension Types Pattern
**Core Principle:** UI must NEVER consume raw database rows. Use Extension Types for zero-cost abstraction.

- **Benefits:** Zero runtime overhead, decouples UI from DB, type safety without allocation.
- **Required Location:** `lib/features/*/domain/entities/`.

## Wrapping Database Rows
```dart
// ✅ Extension Type wrapping Drift class
extension type ProductEntity(ProductSummaryData _data) {
  String get name => _data.name;
  bool get isFeatured => _data.isFeatured;
  factory ProductEntity.fromData(ProductSummaryData data) => ProductEntity(data);
}
```

## ID Types (Eliminate Primitive Obsession)
```dart
// ✅ Strongly-typed IDs with validation
extension type ProductId(String _value) implements String {
  ProductId(this._value) : assert(_value.isNotEmpty, 'ProductId required');
  @override String toString() => _value;
}
```

## Semantic Types (Guaranteed Invariants)
```dart
// ✅ Type guarantees normalization
extension type NormalizedQuery(String _value) implements String {
  factory NormalizedQuery(String input) {
    return NormalizedQuery._(normalizeForSearch(input));
  }
  NormalizedQuery._(this._value);
}
```

## Data Modeling Strategy (2025)
- **Pragmatic Approach:** Annotate Domain Entities directly with `@MappableClass`. Only introduce DTOs when API schema diverges materially.
- **Query Projections:** Use Dart records `({T data, ...})` for ad-hoc JOIN shapes. **Forbidden:** Bespoke DTO classes solely to hold query results.
- **Safety:** **FORBIDDEN:** Unchecked `as` casts when constructing extension types. **REQUIRED:** Use private constructors or validated factories.

---

# 9. Serialization (Dart Mappable)

## Mandates
- USE `@MappableClass()` with `<ClassName>Mappable` mixin.
- ALL fields must be `final` with `const` constructors.
- INCLUDE `part 'filename.mapper.dart';`
- **FORBIDDEN:** `freezed`, `json_serializable`.
- State/Notifier state classes (immutable) MUST also use `@MappableClass` (no hand-written `copyWith`/`==`/`toJson`).

## Dart 3 Features
- **Records:** Use **Named Records** (`({double lat, double lng})`) at serialization boundaries. **FORBIDDEN:** Positional Records in API/DTO contracts.
- **Sealed Classes:** Prefer standard `sealed` class hierarchies over legacy `freezed` unions. Use `discriminatorKey` and `discriminatorValue`.

## Standard Data Class
```dart
import 'package:dart_mappable/dart_mappable.dart';
part 'user.mapper.dart';

@MappableClass()
class User with UserMappable {
  const User({required this.name, this.age});
  final String name;
  final int? age;
}
```

## Pattern Matching
```dart
// ✅ Use switch expressions (not .map/.when)
final result = switch (uiState) {
  Loading() => 'Loading...',
  Success(data: final data) => 'Data: ${data.length}',
  ErrorState(message: final msg) => 'Error: $msg',
};
```

---

# 10. Riverpod Patterns (2025 Standard)

## Core Mandates
1. **Generation:** Use `@riverpod` annotations exclusively. Manual `Provider` definitions are **BANNED**.
2. **Lifecycle:** Use `autoDispose` by default. Use `keepAlive: true` only for global singletons (Auth, Database).

## The "Mounted Guard" Protocol
**Critical:** To prevent "Zombie State" exceptions (setting state after widget disposal), you MUST check `ref.mounted` after every `await` in a Notifier.

```dart
@riverpod
class AuthController extends _$AuthController {
  @override FutureOr<void> build() {}
  Future<void> login() async {
    state = const AsyncLoading();
    final result = await _repo.login();
    // 🛑 SAFETY CHECK
    if (!ref.mounted) return;
    state = AsyncData(null);
  }
}
```

## Performance: The `.select()` Rule
**Rule:** Never watch a full object if you only need a specific field.
```dart
// ✅ GOOD: Rebuilds ONLY when name changes
final name = ref.watch(userProvider.select((u) => u.valueOrNull?.name));
```

## Architecture Layers
1. **Data Layer:** Functional Providers (`@riverpod`) returning Repositories.
2. **App Layer:** Notifiers (`class ... extends _$Notifier`) managing state.
3. **UI Layer:** `ConsumerWidget` consuming state via `ref.watch`.

## Error Handling Pattern
- **Reads:** Return `Future<T>`/`Stream<T>`. Let exceptions bubble to `AsyncValue` in UI.
- **Writes:** Use `AsyncValue.guard` in Notifiers to trap errors.
- **UI:** Use `ref.listen` for side effects (Toasts/Alerts).
- **Forbidden:** `try-catch` in Notifiers for business errors.

## Either Boundary Rule
- Services/ETL MAY use `Either`.
- Notifiers MUST convert `Either` to exceptions before `AsyncValue.guard`.

---

# 11. Flutter Hooks & Architecture

## Core Principles
- DEFAULT to `ConsumerWidget`; use `HookConsumerWidget` ONLY when hooks needed.
- **FORBIDDEN:** `StatefulWidget`, `initState`, `dispose`.
- Hooks MUST be called unconditionally at top of `build` method.
- Custom hooks MUST start with `use` prefix.

## When to Use Hooks
- `useTextEditingController`, `useAnimationController`, `useFocusNode`.
- `useEffect` (UI-specific side effects).
- `useRef` (lightweight mutable values).
- **For non-UI cleanup:** Use `ref.onDispose` in Provider.

## Hooks Architecture
- **Extraction Mandate:** If hook setup exceeds ~20 lines, extract it into a custom hook.
- **Return Types:** Custom hooks MUST return Dart 3 **named records**.
- **State Separation:** Hooks handle ephemeral UI-only state. Do NOT orchestrate Riverpod state inside hook effects.
- **Lifecycle:** Let hooks own their resources. No manual `dispose` in widgets.

---

# 11.5. Local State Strategy (Triad Architecture)

\> **System Instruction:** The "Triad Architecture" defines clear boundaries between three state management tools. Use the right tool for the right job.

## State Decision Matrix

| State Type                 | Tool     | Example                                               |
| :------------------------- | :------- | :---------------------------------------------------- |
| **Global / Async**         | Riverpod | Database, User, Sync status                           |
| **Controller / Lifecycle** | Hooks    | FocusNode, TextEditingController, AnimationController |
| **High-Freq UI (60fps)**   | Signals  | Scanner bubbles, Drag deltas, Form validity           |

## Responsibilities

| Tool              | Use Case                                                                                  | Examples                                                       |
| :---------------- | :---------------------------------------------------------------------------------------- | :------------------------------------------------------------- |
| **Flutter Hooks** | **Lifecycle & Resources** (init/dispose Controllers, FocusNodes, Animations).             | `useTextEditingController`, `useAnimationController`, `useRef` |
| **Dart Signals**  | **High-Frequency UI State** (60fps updates, counters, form validation, scanner bubbles).  | Scanner position tracking, real-time form validation           |
| **Riverpod**      | **Business Logic & Persistence** (Database calls, Auth, Sync, cross-widget shared state). | `AsyncNotifier`, `StreamProvider`, DAO wrappers                |

## Decision Tree

1. **Does the state need to persist across widget rebuilds or be shared across features?**
   - ✅ **Riverpod** (e.g., user session, database queries).
   - ❌ Proceed to step 2.

2. **Does the state update at high frequency (>10fps) or involve complex UI animations?**
   - ✅ **Dart Signals** (e.g., scanner bubble position, real-time counters).
   - ❌ Proceed to step 3.

3. **Does the state involve a resource that needs disposal (Controllers, FocusNodes)?**
   - ✅ **Flutter Hooks** (e.g., `useTextEditingController`).
   - ❌ Use `useState` (Flutter Hook) for simple local toggles/flags.

## Anti-Patterns

- ❌ Using `useState` for scanner bubble position (causes unnecessary rebuilds) → Use **Signals**.
- ❌ Using Signals for database queries (violates separation of concerns) → Use **Riverpod**.
- ❌ Using Riverpod for `FocusNode` (lifecycle overhead) → Use **Flutter Hooks**.

## Naming Conventions

To avoid confusion between `ref.watch()` (Riverpod) and `signal.watch()` (Signals), enforce these suffixes:

| Tool                   | Suffix      | Example                                   |
| :--------------------- | :---------- | :---------------------------------------- |
| **Riverpod Providers** | `*Provider` | `scannerProvider`, `catalogDaoProvider`   |
| **Dart Signals**       | `*Signal`   | `bubbleCountSignal`, `formValiditySignal` |
| **Flutter Hooks**      | `use*`      | `useScannerLogic`, `useTabReselection`    |

**Benefits:**
- Instantly recognizable state management tool at call site.
- No ambiguity between `ref.watch(scannerProvider)` and `bubbleCountSignal.watch()`.
- Easier code reviews and onboarding.

---

# 12. UI Components & Shadcn (2025 Standard)

## Strict UI Layering (PharmaUI)
- **Feature Constraint:** Files in `lib/features/` must **NEVER** import `package:shadcn_ui`. They must consume components from `lib/core/ui/`.
- **Core Authority:** Only `lib/core/ui/` is allowed to import `shadcn_ui`.
- **Migration:** Prefer `AppButton`, `AppBadge`, `AppCard` over raw Shadcn widgets.

## The "Hoisted Header" Mandate
- **Feature Screens:** Do **NOT** use `Scaffold` or `AppBar`. The root widget of feature screens must be a `Column` or `CustomScrollView` to avoid duplicated headers.
- **Configuration:** Use the `useAppHeader(title: ...)` hook at the top of `build()` to configure the global shell header.
- **Immersive Mode:** To hide the header (e.g., Scanner), call `useAppHeader(isVisible: false)`.

## The "No Dumb Wrapper" Rule
- **Do Not:** Wrap Shadcn components just to add static padding or styling.
- **Do:** Create specialized "Semantic Components" (e.g., `AppPrimaryButton`) IF AND ONLY IF you need to enforce logic across the entire app.

## Resource Disposal (Critical)
Any component using a manual Controller must ensure disposal to prevent memory leaks in the Overlay layer.
- **Checklist:** `ShadPopoverController.dispose()`, `ShadTooltipController.dispose()`, `FocusNode.dispose()`, `TextEditingController.dispose()`.
- **Tip:** Use `flutter_hooks` to handle disposal automatically.

## Forms & Validation
- **Pattern:** Use `ShadForm` with `GlobalKey<ShadFormState>`.
- **Validation Bridge:** Use `key.currentState.fields['id']?.setInternalFieldError(...)` to map server-side errors to UI fields.

## Theming
- **Access:** Use `context.shadTheme`, `context.shadColors`, `context.shadTextTheme`.
- **Extensions:** Use Theme Extensions for reusable styles (e.g., `context.mutedLabel`), not Widget wrappers.

## Anti-Patterns
- ❌ `TextField` (Material) inside `ShadCard` -> Use `ShadInput`.
- ❌ Inline colors (`Colors.red`) -> Use `context.shadColors.destructive`.
- ❌ Hardcoded border radius -> Use `context.shadTheme.radius`.

## Scroll View Protocol
- **Default:** `SingleChildScrollView` + `Column` (Static), `ListView.builder` (List).
- **Slivers:** ONLY when needed (Sticky Headers, Mixed Content, Virtualization).
- **SliverMainAxisGroup:** Restricted usage (only for Sticky Header + List pairing).

## Mobile-First Patterns
- **Sheet Protocol:** **FORBIDDEN:** `ShadDialog` (except simple confirmations). **REQUIRED:** `ShadSheet` (Side: Bottom) for complex interactions ("Thumb Zone").
- **Side Nav:** `ShadSheet` (Side: Left).
- **Tappable Lists:** Wrap items in `ShadButton.raw(variant: ghost)`. Minimum height 48px.
- **Critical Alerts:** `ShadDialog.alert` ONLY for destructive confirmation (Delete/Reset).

## Logic Isolation
- **Rule:** Do NOT reuse Data Layer sanitizers for UI rendering logic. UI highlighting requires length-preserving normalization.

---

# 13. UI Layout & Spacing

## The Hybrid Spacing Matrix

| Scenario                                | Tool                 | Logic                                                              |
| :-------------------------------------- | :------------------- | :----------------------------------------------------------------- |
| **Uniform Lists** (Grids, Button Bars)  | **Native `spacing`** | `Row(spacing: 8, children: ...)` - Zero widget inflation.          |
| **Semantic Grouping** (Sections, Forms) | **Gap Package**      | `Column(children: [Header(), Gap(32), Form()])` - Semantic breaks. |
| **Scroll Views** (Slivers)              | **SliverGap**        | `SliverGap(16)` - Avoids `SliverToBoxAdapter` overhead.            |
| **Responsive Constraints**              | **MaxGap**           | Prevents overflow errors on small screens.                         |

## Responsive Design
- **Breakpoints:** Use `ShadResponsiveBuilder` or `context.breakpoint`. **Forbidden:** Raw `MediaQuery` width checks.
- **Performance:** If `BackdropFilter` causes jank on Android/Impeller, use solid transparent color (`Colors.black54`) for `modalBarrierColor` in theme.
- **Render Tree:** Avoid nesting `Padding` > `Container` > `Padding`. Use `Container(padding: ...)` or `Gap`.

---

# 14. Navigation (AutoRoute 11.0.0)

## Triggering
1. **Inside UI (Widgets):**
   - ✅ `context.router.push(...)`.
   - ❌ Do not inject `appRouterProvider` via `ref` in `build()`.
2. **Inside Logic (Notifiers):**
   - ✅ `ref.read(appRouterProvider).push(...)`.

## Provider Pattern
```dart
@Riverpod(keepAlive: true)
AppRouter appRouter(Ref ref) => AppRouter();
```

## Tabs
- Do NOT use `PopScope` for tab navigation/back button handling. Let AutoRoute manage the stack natively.
- If interception is required, use `context.router.popForced()` (Rare).

---

# 15. Security & Privacy

## Data Privacy & Telemetry
- Enforce zero telemetry (`firebase_analytics_collection_deactivated=true`).
- Never log PII or health data to Talker/console.
- Strip secrets from logs and crash reports.

## Logging (Zero-Console-Log Rule)
- **`print()` is BANNED.** Use `LoggerService` (wraps Talker) for all logging.
- **Rationale:** 
  - `print()` leaks to production console (privacy risk, performance killer).
  - `LoggerService` provides structured logging with levels (debug, info, error).
  - Talker is automatically silenced in Release builds via provider configuration.
- **Enforcement:** The Cleaner subagent will flag and remove all `print()` statements.
- **Production Check:** Verify `LoggerService` is configured for Release silence in `logger_provider.dart`.

**Pattern:**
```dart
// ❌ BANNED
print('User data: $user');

// ✅ CORRECT
LoggerService.debug('Processing user');
LoggerService.error('Failed to load', error, stackTrace);
```

## Input & Query Safety
- Sanitize all untrusted input before storage or queries.
- For search/FTS flows, escape user strings via data-layer helpers.
- Validate form inputs; reject unexpected formats early.

## Storage
- **App Settings:** Use `AppSettingsDao` (Drift/SQLite) for user preferences and sync metadata.
- **Legacy Prefs:** Avoid `SharedPreferences` for new features; prefer the `app_settings` table.
- Use secure storage for tokens/secrets; never plain SharedPreferences.
- Drift data is plaintext by default: do not store patient data without SQLCipher.

## Network Hygiene
- Prefer HTTPS; pin critical endpoints where applicable.
- Avoid embedding credentials in the binary; rely on runtime configs/secrets.

---

# 16. Testing Strategy

## Unit & Integration
- **Framework:** `flutter test`.
- **Mocking:** Use `mocktail` (NOT `mockito`).
- **Scope:** Test logic, repositories, and complex widgets.

## E2E Testing (Patrol)
- **Framework:** Patrol.
- **Pattern:** **Strict Page Object Model (Robot Pattern).**
- **Mandate:** Test files (`*_test.dart`) must **NEVER** contain raw finders (`$(...)` or `find.by...`). They must only call methods on Robot classes (e.g., `await scanner.scanCip(...)`).
- **Location:** `patrol_test/`.
- **Execution:**
  - Run all: `patrol test`.
  - Run specific: `patrol test --target <file_path>`.

### Patrol 4.0 Syntax
- **Patrol 4.0 Syntax:**
  - Use `$.platform.mobile` instead of `$.native` for system interactions (permissions, home button).
  - Use `await $.pumpAndSettle()` aggressively to handle animations.

## Test Hygiene
- **Zero Redundancy:** If a Patrol E2E test covers a flow (e.g., "Scan Product → View Details → Add to Favorites"), **DELETE** any overlapping Widget/Unit tests that only mock the UI without adding value.
- **Unit Scope:** Keep Unit tests ONLY for:
  - **Pure algorithmic logic** (Sanitizers, Parsers, Validators).
  - **Complex StateNotifier logic** that is hard to reach via UI (e.g., edge cases in sync orchestration).
- **Widget Scope:** Keep Widget tests ONLY for isolated UI components with complex interaction logic (e.g., custom form validators, animation state machines).
- **Audit Protocol:** After adding a new Patrol E2E test, review the test suite for redundant coverage and delete it. Test suite growth is a code smell.

## Flakiness Handling (Patrol)
E2E tests are prone to flakiness due to timing issues, animations, and system dialogs. Follow this protocol when a Patrol test fails:

**Investigation Steps (in order):**
1. **DO NOT just increase timeout** - This masks the root cause.
2. **Check for `pumpAndSettle()`** - Ensure animations/async operations complete before interacting:
   ```dart
   await $.pumpAndSettle();
   await $(MyButton).tap();
   ```
3. **Check for overlaying widgets** - Dialogs, toasts, or bottom sheets may block taps:
   - Look for `ShadToast`, `ShadDialog`, `ShadSheet` covering the target widget.
   - Wait for them to dismiss or explicitly close them in the Robot.
4. **Use `$.platform.mobile` for system dialogs** - Platform permission dialogs aren't part of the Flutter widget tree:
  ```dart
  // Clear system dialogs (permissions, etc.)
  await $.platform.mobile.grantPermissionWhenInUse();
  ```
5. **Verify widget visibility** - Use `$.waitUntilVisible()` instead of `$.tap()` if the widget may be scrolled offscreen.
6. **Check for race conditions** - If state changes rapidly (e.g., loading → loaded), add explicit `.waitUntilVisible()` on the expected state.

**Only as a last resort:** Increase timeout to a reasonable value (e.g., 10s max) and document why in a comment.

# 17. CI & Deployment

## Quality Gate (Local)
```bash
dart fix --apply
dart analyze --fatal-infos --fatal-warnings
flutter test
```

## Production Build (Android)
```bash
flutter build apk --release --split-per-abi --no-tree-shake-icons
# OR
flutter build appbundle --release --no-tree-shake-icons
```

## Versioning
- Format: `x.y.z+n`
- Bump version in `pubspec.yaml` before build.
