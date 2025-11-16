# PharmaScan - Development Manifest

Your primary mission is to contribute to the development of the **PharmaScan** application. This document is the single source of truth for all development principles, quality standards, and project architecture.

**Core Philosophy:** Prioritize **simplicity**, **robustness**, and **performance**. The application must be instantly responsive, even on low-end devices, as it is a professional tool intended for rapid, repetitive use. The code is the ultimate authority; your contributions must be clear, self-documenting, and rigorously tested.

---

## 1. Core Protocols & Workflow

### **Workflow A: Code Development (Features & Fixes)**

This workflow applies to any code written or modified within the `lib/` directory.

1. **Understand:** Analyze the existing code and task objectives to align with the current architecture. The goal is to maintain a lightweight and coherent codebase.

2. **Implement:** Write clean, performant code, strictly adhering to the technical best practices defined in this document.

3. **Generate Code (NEW):** If you modify any data models (files annotated with `@freezed`), you **MUST** run the code generator to apply your changes.

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

4. **Verify (The Quality Gate):** Before finalizing your changes, you are responsible for validating your work. Execute the unified verification command:

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
    ```

    This command generates freezed code, analyzes static code quality, and runs the unit and widget test suite. You **MUST** resolve all errors and critical warnings it reports.

---

## 2. Technical Best Practices (The Immutable Rules)

These are the fundamental code quality principles for this project.

### 2.1. Code Quality and Readability

* **Comments Explain the "Why":** Comments should justify a design decision or clarify complex logic (`// WHY: ...`), not describe what the code does.
* **Zero Debugging Artifacts:** Before finalizing your changes, you **MUST** remove all `print()`, `debugPrint()`, and commented-out code.

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

**Simplicity Principle:** The PharmaScan application is designed to be simple. We will **NOT** use a global state management solution (like Riverpod, BLoC, etc.) unless future complexity absolutely requires it.

* **`StatefulWidget` is the Standard:** UI state (like `_isCameraActive` or the `_infoBubbles` list) **MUST** be managed locally using `StatefulWidget` and `setState`.
* **No Global State:** State is not shared between screens. This constraint maintains simplicity, predictability, and performance.
* **Service Access:** Widgets can instantiate and directly call service classes (like `DatabaseService`) as there is no complex logic to orchestrate.

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

* **Generic Detection:** Uses explicit group relationships from `group_members` table. **NEVER** infer generic relationships from active ingredient matching.

* **Data Extraction:** **CRITICAL - NO REGEX OR HEURISTICS**: All data extraction is performed through structured parsing of official TXT files. The application **MUST NEVER** use regex patterns, string manipulation, or heuristic approximations to extract data (e.g., laboratory names, dosages, active ingredient names). All data comes directly from the structured columns of the official BDPM files:
  * Laboratory (titulaire) comes from column 10 of `CIS_bdpm.txt`
  * Dosage comes from column 4 of `CIS_COMPO_bdpm.txt` and is parsed into numeric value and unit
  * Common active ingredients for groups are extracted via SQL joins on the `principes_actifs` table, not by parsing group labels

* **Data Initialization:** `DataInitializationService` downloads TXT files directly, parses tab-separated values, and populates the relational schema. All complex fallback logic and regex-based extraction has been removed.

* **Database Migration:** When the schema changes, a migration strategy is defined in `AppDatabase.migration`. For development, migrations recreate tables with the new schema. In production, proper `ALTER TABLE` migrations would be implemented.

### 2.7. Architecture: Tooling & Enhancements

To improve robustness and maintainability, the project uses specific tooling that complements the core architecture.

* **Immutable Models (`freezed`):** All data models (e.g., `Medicament`, `ScanResult`, `Gs1DataMatrix`) **MUST** be defined as immutable classes using the `freezed` package. This eliminates an entire class of state-related bugs by guaranteeing that data objects cannot be modified after creation.
  * **Required Pattern:** Classes with factory constructors **MUST** be declared as `abstract class` (e.g., `abstract class Medicament with _$Medicament`).
  * **Union Types:** Sealed union types (like `ScanResult`) **MUST** use `sealed class` for compile-time exhaustive pattern matching.
  * **Pattern Matching:** Use `when()` method for pattern matching on union types. For Dart 3+, consider using native `switch` expressions when returning values, but `when()` is preferred for side-effect operations (logging, UI updates).
  * **Code Generation:** After modifying any `@freezed` class, **MUST** run `flutter pub run build_runner build --delete-conflicting-outputs`.

* **Service Location (`get_it`):** The project uses `get_it` as a simple service locator to decouple the UI layer from service implementations. Widgets **MUST** retrieve service instances (like `DatabaseService`) from the central locator (`sl<T>()`) instead of using static singletons. This improves testability by allowing mock services to be injected during widget tests.

* **Type-Safe Database (`drift`):** All database interactions **MUST** be performed through the `drift` ORM. Raw SQL strings are strictly forbidden in service-layer code. `drift` generates a type-safe API from Dart-based schema definitions, providing compile-time safety for all queries and eliminating runtime SQL errors.
  * **Schema Definition:** Database schema is defined in `lib/core/database/database.dart` using Dart table classes (`@DriftDatabase`). After schema changes, **MUST** run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate type-safe query methods.
  * **Query Pattern:** Use drift's type-safe query builder API (`select()`, `where()`, `join()`) instead of raw SQL strings. For complex queries, use `customSelect()` as a last resort.
  * **Companion Objects:** When inserting data from Maps, manually convert to Companion objects using `Companion(column: Value(data))` syntax. Drift does not provide `.fromJson()` on Companions.
  * **Testing:** Use `AppDatabase.forTesting(NativeDatabase.memory())` for in-memory test databases. This ensures complete test isolation without file system dependencies.
  * **Avoid:** Never write raw SQL strings in service code. Never access `database` getter directly (use service methods instead). Never skip code generation after schema changes.

---

## 3. Development Toolkit & Commands

Use the standard command-line tools to manage the project.

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
  * Unit tests: `test/database_service_test.dart` (12 tests) - Verifies deterministic generic group relationships, multiple princeps, one-to-many CIS to CIP13 mapping, database statistics, and search functionality
  * Unit tests: `test/gs1_parser_test.dart` (4 tests) - Verifies GS1 Data Matrix parsing with different formats (spaces, FNC1, malformed)
  * Unit tests: `test/data_initialization_service_test.dart` (4 tests) - Verifies TXT file parsing with correct column indices and one-to-many relationship handling
  * Widget test: `test/widget_test.dart` (1 test) - Verifies app launches successfully with drift database
  * Integration tests: `integration_test/` - End-to-end data pipeline, image scanning, and CSV parsing verification tests
  * **Total**: 21 unit/widget tests covering all critical logic paths including search, statistics, and data operations
  * **Note**: Tests use drift's in-memory database (`AppDatabase.forTesting()`) for complete isolation and fast execution.

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
