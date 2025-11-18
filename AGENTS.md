# PharmaScan - Development Manifest

Your primary mission is to contribute to the development of the **PharmaScan** application. This document is the single source of truth for all development principles, quality standards, and project architecture.

**Core Philosophy:** Prioritize **simplicity**, **robustness**, and **performance**. The application must be instantly responsive, even on low-end devices, as it is a professional tool intended for rapid, repetitive use. The code is the ultimate authority; your contributions must be clear, self-documenting, and rigorously tested.

---

## 1. Core Protocols & Workflow

### **Workflow A: Code Development (Features & Fixes)**

This workflow applies to any code written or modified within the `lib/` directory.

1. **Understand:** Analyze the existing code and task objectives to align with the current architecture. The goal is to maintain a lightweight and coherent codebase.

2. **Implement:** Write clean, performant code, strictly adhering to the technical best practices defined in this document.

    * **Update Tests Concurrently:** If your changes affect existing business logic, you **MUST** update the corresponding unit or integration tests in the same scope of work. Tests are not an afterthought; they are an integral part of the implementation.

3. **Generate Code:** If you modify any data models (files annotated with `@freezed` or `@DriftDatabase`), you **MUST** run the code generator to apply your changes.

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

4. **Verify (The Quality Gate):** Before finalizing your changes, you are responsible for validating your work.

    1. **Execute the Unified Verification Command:**

        ```bash
        flutter pub run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
        ```

        This command generates code, analyzes static quality, and runs the full test suite. You **MUST** resolve all errors and critical warnings it reports.

    2. **Run Relevant Integration Tests:** After the Quality Gate passes, you **MUST** identify and run any integration tests relevant to your changes to confirm end-to-end functionality.

        * *Example*: A change in `DatabaseService` requires re-running `data_pipeline_test.dart` and `generic_group_summaries_test.dart`.
        * *Example*: A change in `Gs1Parser` requires re-running `image_scanning_test.dart`.
        * *Example*: Any update to deterministic grouping/validation logic (`DataInitializationService`, `DatabaseService`, or `data_validator.py`) requires re-running `integration_test/active_principle_grouping_test.dart`.

---

## 2. Technical Best Practices (The Immutable Rules)

These are the fundamental code quality principles for this project.

### 2.1. Code Quality and Readability

* **Comments Explain the "Why":** Comments should justify a design decision or clarify complex logic (`// WHY: ...`), not describe what the code does.
* **Zero Debugging Artifacts:** Before finalizing your changes, you **MUST** remove all `print()`, `debugPrint()`, and commented-out code.

#### **2.1.1. CRITICAL: Strict Adherence to Task Scope**

* **Rule of Focused Modification:** You **MUST** confine your modifications exclusively to the files and logic directly related to the current task, unless explicitly instructed otherwise.
* **Prohibition of Unsolicited Corrections:** You **MUST NEVER** perform "iterative corrections" or refactor code in files outside your assigned scope, even if you identify a potential error or inconsistency.
* **WHY:** This policy is critical to prevent scope creep, avoid introducing unintended side effects in unrelated modules, and maintain overall project stability. Each change must be deliberate and traceable to a specific request.
* **Correct Protocol:** If you identify a potential issue outside your current scope, you should report it as a separate concern to be addressed in a future, dedicated task. Do not fix it proactively.

### 2.2. Design System: Centralized Strategy with Shadcn UI

**CRITICAL:** The project uses a centralized, semantic design system based on **Shadcn UI**. This is a non-negotiable architectural constraint to ensure visual consistency and maintainability.

* **Absolute Prohibition:** You **MUST NEVER** use hardcoded styles directly in widgets. The following are strictly forbidden in widget code:
  * `BoxDecoration` (e.g., `BoxDecoration(color: Colors.blue, ...)`)
  * `TextStyle` (e.g., `TextStyle(fontSize: 16, color: Colors.red)`)
  * Direct color values (e.g., `Colors.grey`, `Color(0xFF...)`)
  * Magic numbers for `BorderRadius`, `EdgeInsets`, `SizedBox`, etc.

* **Mandatory Pattern:** ALL styles and spacing MUST be accessed via the `Shadcn` theme.

    ```dart
    // ✅ CORRECT: Using the Shadcn theme
    final theme = ShadTheme.of(context);
    ...
    ShadCard(
      title: Text('Generic Detected', style: theme.textTheme.h4),
      backgroundColor: theme.colorScheme.card,
    )

    // ❌ INCORRECT: Hardcoded styles and values
    Card(
      color: Colors.white, // FORBIDDEN
      child: Text(
        'Title',
        style: TextStyle(fontSize: 18), // FORBIDDEN
      ),
    )
    ```

* **Semantic Naming:** Custom styles (if ever necessary) must be named by their function, not their appearance.
  * ✅ `theme.colorScheme.destructive`, `theme.textTheme.muted`
  * ❌ `redColor`, `greyText`

* **Zero External UI Libraries:** You **MUST NOT** introduce any other UI component libraries. Flutter's native components and the **Shadcn UI** ecosystem provide everything necessary.

### 2.3. State Management: Minimalist and Local Approach

**Simplicity Principle:** Local `StatefulWidget` state remains the default. Riverpod is reserved for *targeted* cross-layer telemetry (e.g., background sync status or persisted preferences) where multiple widgets/services must observe the same source of truth.

* **`StatefulWidget` is still the Standard:** UI concerns such as `_isCameraActive`, `_infoBubbles`, or form inputs **MUST** be stored via local state and updated with `setState`.
* **Scoped Riverpod Usage:** Only introduce providers when data needs to be shared outside a single widget tree (e.g., `syncStatusProvider`, `updateFrequencyProvider`). Providers MUST wrap services already registered in `get_it` and should expose read-only state wherever possible.
* **No Global Mutable Singletons:** State is never stored in static fields or global variables. Riverpod + services replace the need for ad-hoc globals while keeping logic testable.
* **Service Access:** Widgets retrieve business services through `sl<T>()` (or Riverpod providers built on top of it) and never embed parsing/business logic directly in the UI layer.
* **ProviderScope coverage:** Every rendered widget tree (including tests via `pumpWidget`) MUST start with a `ProviderScope`. Missing scopes trigger `Bad state: No ProviderScope found` failures.
* **AsyncValue handling:** Always render loading/error branches via `AsyncValue.when(...)`. Only call `.requireValue` after an eager-init guard consumed the non-data states.
* **Avoid async gaps disposing providers:** Watch `autoDispose` providers before hitting an `await` boundary. The Riverpod docs highlight that the previous pattern (`await` then `ref.watch`) forces the provider to pause/dispose.
* **Prefer `@riverpod`-generated Notifiers:** Shared state belongs in code-generated Notifiers/AsyncNotifiers (via `riverpod_annotation`) so `riverpod_lint` enforces encapsulation. Expose imperative APIs (`updateStatus()`, `increment()`) instead of mutating `state` externally.
* **Static provider declarations:** Providers must be top-level `final` values. Never create providers dynamically inside builds; static declarations unlock caching, hot reload consistency, and linting.

### 2.4. Architecture: Strict Two-Layer Separation

The application enforces a simple but strict two-layer architecture.

* **UI Layer (Widgets):**
  * ✅ Manages UI state (via `StatefulWidget`).
  * ✅ Captures user interactions.
  * ✅ Displays data.
  * ✅ Directly calls service methods for business logic.
  * ❌ **NEVER** contains business logic (data parsing, complex DB queries).

* **Service Layer (Business Logic):**
  * ✅ Contains all business logic (e.g., `Gs1Parser`, `DatabaseService`).
  * ✅ Performs database operations.
  * ✅ Downloads and processes external data.
  * ✅ Is completely independent of the user interface.
  * ❌ **NEVER** manages UI state.
  * ❌ Has **NO** dependencies on `flutter/material.dart` or `flutter/widgets.dart`.

**Critical Rule:** Any bug or new feature related to data manipulation **MUST** be implemented or fixed in the appropriate service layer.

### 2.5. Performance and Optimization

* **Targeted Scanning:** The `MobileScannerController` **MUST** be configured to detect only `BarcodeFormat.dataMatrix` to minimize CPU usage.
* **Asynchronous Operations:** Any long-running operation (DB query, file parsing) **MUST** be `async` to avoid blocking the UI thread.
* **Duplicate Scan Prevention:** Logic (e.g., a `Set` of recently scanned CIP codes) **MUST** be implemented to prevent displaying the same info bubble multiple times in rapid succession.
* **Efficient Database Queries:** Complex queries use CTE (Common Table Expression) for pagination and filtering. Algorithmic processing in Dart (e.g., common prefix detection) is used for robust grouping.
* **Full-Text Search:** The application utilizes SQLite's FTS5 extension to provide fast, typo-tolerant searching across medication names, CIPs, and active ingredients, replacing slower `LIKE` queries.
* **Pagination:** Large result sets **MUST** be paginated to maintain UI responsiveness. Use infinite scroll with proper offset/limit management.

### 2.6. Data Model: Deterministic Generic Group Relationships

**CRITICAL:** The application uses a **deterministic** data model based on official relational data files from the *Base de Données Publique des Médicaments (BDPM)*. This eliminates predictive matching and fallback logic.

* **Data Sources:** The application downloads individual TXT files directly from BDPM:
  * `CIS_bdpm.txt` - Medication specialties with form, commercialization status, and manufacturer (titulaire)
  * `CIS_CIP_bdpm.txt` - Medicament information (CIS, CIP13, name)
  * `CIS_COMPO_bdpm.txt` - Active ingredient compositions with structured dosage information
  * `CIS_GENER_bdpm.txt` - Generic group relationships (source of truth)

* **Database Schema (Version 4):**
  * `specialites` - Medication specialties (cis_code, nom_specialite, procedure_type, forme_pharmaceutique, etat_commercialisation, titulaire)
  * `medicaments` - Basic medication info (code_cip, nom, cis_code)
  * `principes_actifs` - Active ingredients with structured dosage (code_cip, principe, dosage, dosage_unit)
  * `generique_groups` - Generic groups (group_id, libelle)
  * `group_members` - Group membership (code_cip, group_id, type)
    * `type = 0` for princeps, `type = 1` for generic
  * `medicament_summary` - **Single row per CIS** storing the canonical name (dosage/form stripped), princeps/generic flag, `group_id`, JSON-encoded shared active principles, `princeps_de_reference`, and `forme_pharmaceutique`. _All_ explorer/search/scan read paths must consult this table instead of recomputing joins at runtime.

* **Generic Detection:** Uses explicit group relationships from `group_members` table. **NEVER** infer generic relationships from active ingredient matching.

* **Data Extraction:** Must be validated with the python script.

* **Princeps Name Grouping:** The application uses an algorithmic word-based approach to find common base names for princeps within the same group. The `findCommonPrincepsName()` helper function in `lib/core/utils/medicament_helpers.dart` compares medication names word-by-word to identify the longest common prefix. This replaces fragile regex-based extraction and provides robust, deterministic grouping results.

* **Data Initialization:** `DataInitializationService` downloads TXT files directly, parses tab-separated values, and populates the relational schema. All complex fallback logic and regex-based extraction has been removed.
  * **Phase 1 – Staging:** Populate normalized tables (`specialites`, `medicaments`, `principes_actifs`, `generique_groups`, `group_members`) exactly as parsed from BDPM.
  * **Phase 2 – Aggregation:** Immediately call `_aggregateDataForSummary()` to recalculate every `medicament_summary` row. **No UI/service is allowed to backfill this table on-demand.**

* **Reset Policy:** `DatabaseService.clearDatabase()` must wipe both the staging tables and `medicament_summary`. Any developer utility that seeds test data **MUST** call `populateMedicamentSummary()` (see `test/database_service_test.dart`) before asserting on explorer/search behaviors.

* **Database Migration:** When the schema changes, a migration strategy is defined in `AppDatabase.migration`. For development, migrations recreate tables with the new schema. In production, proper `ALTER TABLE` migrations would be implemented.

#### **2.6.1. Data Source Integrity Auditor**

`data_validator.py` is the **definitive tool** for auditing the raw BDPM data format and the assumptions made by the Dart parser. This external Python audit script downloads the latest versions of the BDPM files and performs an in-depth analysis to validate all assumptions made by the Flutter parsing logic.

**When to Use:** You **MUST** run this script whenever you have the slightest doubt about the data's integrity, especially in the following scenarios:

* The data initialization process (`initializeDatabase()`) fails unexpectedly.
* Search results or generic group information appear incorrect or inconsistent.
* Before attempting to modify or extend the data parsing logic in `DataInitializationService`.
* To proactively check if the official data source format has changed.

**How to Run:**
The project is configured to use `uv`, a modern Python project and package manager. It automatically handles the script's dependencies (`pandas`, `requests`) in a temporary environment. No manual `pip install` or `requirements.txt` is needed.

```bash
uv run python data_validation/data_validator.py
```

The script generates a detailed audit report located at `data_validation/rapport_final.txt`.

#### **2.6.2. Prototyping with the Product Classifier**

`product_classifier.py` is a **developer utility** for rapidly testing and validating grouping logic with `pandas` before implementing it in Dart. This lightweight companion script mirrors the Drift joins with `pandas` and prints a human-readable summary (reference princeps name, common principles, dosages, forms) for any `group_id`. This tool is positioned as a **development aid** to facilitate rapid iteration during feature development, rather than a mandatory validation step.

* **How to Run:**

    ```bash
    uv run python data_validation/product_classifier.py
    ```

* **Workflow:** Edit the `test_group_ids` list inside the script to target specific BDPM groups, then review the printed analysis to validate naming, dosage coverage, and formulation diversity.

### 2.7. Architecture: Tooling & Enhancements

To improve robustness and maintainability, the project uses specific tooling that complements the core architecture.

* **Immutable Models (`freezed`):** All data models (e.g., `Medicament`, `ScanResult`, `Gs1DataMatrix`) **MUST** be defined as immutable classes using the `freezed` package. This eliminates an entire class of state-related bugs by guaranteeing that data objects cannot be modified after creation.
  * **Required Pattern:** Classes with factory constructors **MUST** be declared as `abstract class` (e.g., `abstract class Medicament with _$Medicament`).
  * **Union Types:** Sealed union types (like `ScanResult`) **MUST** use `sealed class` for compile-time exhaustive pattern matching.
  * **Pattern Matching:** Use `when()` method for pattern matching on union types. For Dart 3+, consider using native `switch` expressions when returning values, but `when()` is preferred for side-effect operations (logging, UI updates).
  * **Code Generation:** After modifying any `@freezed` class, **MUST** run `flutter pub run build_runner build --delete-conflicting-outputs`.

* **Service Location (`get_it`):** The project uses `get_it` as a simple service locator to decouple the UI layer from service implementations. Widgets **MUST** retrieve service instances (like `DatabaseService`) from the central locator (`sl<T>()`) instead of using static singletons. This improves testability by allowing mock services to be injected during widget tests.
* **Background Sync (`SyncService` + `AppPreferences` provider):** Automatic BDPM refreshes are orchestrated by `SyncService`, which (a) reads user preferences from the Riverpod-backed `AppPreferences` provider (SharedPreferences under the hood), (b) waits for network connectivity, (c) hashes each downloaded TXT file, and (d) triggers `DataInitializationService.initializeDatabase(forceRefresh: true)` when any hash changes. UI surfaces progress via Riverpod (`syncStatusProvider`), so new flows MUST publish state through providers rather than ad-hoc callbacks. Manual syncs (e.g., Settings) must call `checkForUpdates(force: true)` to reuse the same pipeline.

* **Type-Safe Database (`drift`):** All database interactions **MUST** be performed through the `drift` ORM. Raw SQL strings are strictly forbidden in service-layer code. `drift` generates a type-safe API from Dart-based schema definitions, providing compile-time safety for all queries and eliminating runtime SQL errors.
  * **Schema Definition:** Database schema is defined in `lib/core/database/database.dart` using Dart table classes (`@DriftDatabase`). After schema changes, **MUST** run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate type-safe query methods.
  * **Query Pattern for Simple Queries:** For basic CRUD operations, **MUST** use drift's type-safe query builder API (`select()`, `where()`, `join()`).
  * **Query Pattern for Complex Queries:** For all complex queries (e.g., those with CTEs, subqueries, or complex joins), you **MUST** use **`.drift` files**. Raw SQL strings via `customSelect()` are strictly forbidden. Queries are defined in `.drift` files, which provide full SQL syntax highlighting, IDE support, and compile-time validation against the Dart schema.
  * **Dynamic Queries:** For queries that require dynamic `WHERE` clauses, the standard is a **hybrid approach**: define the static part of the query (e.g., `SELECT` and `JOIN`s) in a `.drift` file, and then apply dynamic filters in Dart using the fluent `.where()` method on the generated `Selectable`.
  * **Companion Objects:** When inserting data from Maps, manually convert to Companion objects using `Companion(column: Value(data))` syntax. Drift does not provide `.fromJson()` on Companions.
  * **Testing:** Use `AppDatabase.forTesting(NativeDatabase.memory())` for in-memory test databases. This ensures complete test isolation without file system dependencies.
  * **Avoid:** Never use `customSelect()` or write raw SQL strings in service code. Never access `database` getter directly (use service methods instead). Never skip code generation after schema or `.drift` file changes.
  * **Algorithmic Processing:** When grouping or processing data requires word-based algorithms (e.g., finding common prefixes), perform the grouping in Dart after fetching individual rows from the database. This allows for more robust and maintainable logic compared to complex SQL aggregation.

### 2.8. Navigation with Nested Navigators

The application uses a robust **Nested Navigator** pattern to manage navigation stacks independently for each main tab (Scanner, Explorer). This provides a predictable user experience and correctly handles the Android system back button without manual state management.

* **Tab-Specific Stacks:** `MainScreen` contains an `IndexedStack` where each child is a `Navigator` widget, not a screen. This gives the Scanner tab and the Explorer tab their own isolated navigation histories.

* **Seamless Navigation:** When a user scans a code and taps "Explore Group," the `GroupExplorerView` is pushed onto the Scanner tab's local navigator stack. Hitting "Back" correctly pops this view and returns to the camera screen.

* **Preserved State:** Switching between tabs preserves the navigation state of each stack. A user can navigate deep into a group on the Explorer tab, switch to the Scanner tab, and then return to the Explorer tab to find their navigation history intact.

* **No `PopScope`:** This architecture eliminates the need for `PopScope` and complex state-tracking callbacks to manage back button behavior. The Flutter framework handles the navigation stack automatically and correctly.

---

## 3. Development Toolkit & Commands

Use the standard command-line tools to manage the project.

### Pre-Test Tooling

* Run `dart run tool/prepare_test_data.dart` (supports `--force` and `--dir=/abs/path`) before the Quality Gate to cache the official BDPM TXT payloads inside `.dart_tool/bdpm_cache`. This prevents repeated network downloads during integration tests.
* The cache directory is auto-detected. Override it by exporting `PHARMA_BDPM_CACHE=/absolute/path/to/cache` so both app runtime and tests reuse the same fixtures.
* Integration tests MUST seed data via `ensureIntegrationTestDatabase()` (`integration_test/test_bootstrap.dart`). This helper seeds once per run using the cached TXT files and removes any direct calls to `DataInitializationService.initializeDatabase()` inside tests.

* **Install/Update Dependencies:**

    ```bash
    flutter pub get
    ```

* **Static Code Analysis:**

    ```bash
    flutter analyze
    ```

* **Run All Tests:**

    ```bash
    flutter test
    ```

* **Quality Gate (Run Before Finalizing Changes):**

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
    ```

* **Test Suite:**
  * The project includes a comprehensive test suite with unit, widget, and integration tests. All tests **MUST** remain optimal and up-to-date.
  * **Unit Tests**: Cover critical business logic including GS1 Data Matrix parsing, TXT data initialization, and all database service operations.
  * **Widget Tests**: Verify that core UI components render correctly.
  * **Integration Tests**: Validate end-to-end user flows, such as the complete data initialization pipeline, barcode scanning from static images, and algorithmic princeps grouping.
  * **Test Maintenance is Mandatory:** Any modification to existing logic **MUST** be accompanied by a corresponding update to the relevant tests. A feature or fix is not considered complete until its tests are updated and passing.
  * **Note**: All tests utilize `drift`'s in-memory database for fast, isolated, and reliable execution without file system dependencies.

* **Update App Launcher Icons:**
    Run this command after modifying `assets/icon/icon.png` or the `flutter_launcher_icons` configuration in `pubspec.yaml`.

    ```bash
    flutter pub run flutter_launcher_icons:main
    ```

---

## 4. Documentation and Maintenance

### 4.1. `CHANGELOG.md` Protocol

You **MUST** maintain the `CHANGELOG.md` file at the project root.

* **When to Create an Entry:**
  * Create a new entry for a **major achievement** (e.g., setting up the architecture, finalizing the scan logic, integrating the design system).
  * Minor changes are added as bullet points under the latest major entry.
  * **CRITICAL:** Before creating a new entry, check if one already exists for the current day. If so, update the existing entry.

* **Entry Format:**
  * Always add new entries at the **top** of the file.
  * **Date Required:** Use the `date +%Y-%m-%d` command to get the current date in YYYY-MM-DD format.
  * Format: `# [YYYY-MM-DD] - Title of Major Achievement`
  * Follow with a concise summary (1-2 lines maximum).

* **Preserve History:** Never delete past entries. They may only be clarified if necessary.
