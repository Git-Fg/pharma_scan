# AGENTS.md

> **System Instruction:** This file is the **SINGLE SOURCE OF TRUTH** for AI Agents working on the PharmaScan project. It consolidates architectural rules, coding standards, library patterns, and operational workflows. You must strictly adhere to these constraints.

---

# 1. Rule Synchronization

This content is derived from the `.rulesync/` folder. The AI Agents rules must be kept synchronized at all times with the codebase.

If you need to edit the Agents rules, edit content from the `.rulesync/` folder, and leverage `npx rulesync generate --targets claudecode` & `npx rulesync generate --targets cursor` to propagate the changes.

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
   - Stack: Shadcn UI + Riverpod + Drift (SQLite) + AutoRoute.
   - Pattern: 2025 Standard (Hooks for UI state, Riverpod for App state).

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

**1. Records over DTOs**
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

## Search (FTS5)
- **Tokenization:** Use `tokenize='unicode61 remove_diacritics 2'` for ligature handling in `search_index`.
- **Normalization:** Use a custom SQL User Defined Function (UDF) `normalize_text` registered in the connection setup to ensure SQL and Dart logic match exactly.

## Schema Synchronization
- **Backend-Driven Architecture:**
  - **Source of Truth:** `backend_pipeline/src/db.ts`.
  - **Mobile Consumer:** `lib/core/database/dbschema.drift` (mirrors backend, read-only).
  - **Mobile App Role:** "Smart Viewer". It consumes `reference.db` pre-processed by the backend.
- **SCHEMA SYNC RULE:** Changes to `medicament_summary` or core tables MUST be done in the backend first.
- **Forbidden:** Modifying database structure in the mobile app without corresponding backend changes.
- **Key Tables:** `medicament_summary` (single source of truth), `cluster_names`, `search_index`.

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

# 12. UI Components & Shadcn (2025 Standard)

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

## Input & Query Safety
- Sanitize all untrusted input before storage or queries.
- For search/FTS flows, escape user strings via data-layer helpers.
- Validate form inputs; reject unexpected formats early.

## Storage
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
- **Location:** `patrol_test/`.
- **Execution:**
  - Run all: `patrol test`.
  - Run specific: `patrol test --target <file_path>`.

---

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
