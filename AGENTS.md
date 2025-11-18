# PharmaScan - Development Manifest

Your primary mission is to contribute to the development of the **PharmaScan** application. This document is the single source of truth for all development principles, quality standards, and project architecture.

**Core Philosophy:** Prioritize **simplicity**, **robustness**, and **performance**. The application must be instantly responsive, even on low-end devices, as it is a professional tool intended for rapid, repetitive use. The code is the ultimate authority; your contributions must be clear, self-documenting, and rigorously tested.

Constraint : Always use context7 when I need code generation, setup or configuration steps, or
library/API documentation. This means you should automatically use the Context7 MCP
tools to resolve library id and get library docs without me having to explicitly ask.

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
When you use context7 for shadcn_ui, use the lib id "websites/flutter-shadcn-ui_mariuti"

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

#### **2.2.1. Toast Notifications: ShadSonner vs ShadToaster**

**CRITICAL:** The application uses **ShadSonner** as the standard toast notification system. `ShadToaster` is deprecated and **MUST NOT** be used in new code.

* **ShadSonner (Standard):**
  * ✅ **MUST** be used for all toast notifications throughout the application
  * ✅ Provides automatic stacking of multiple notifications without overlap
  * ✅ Better UX for background operations (sync, downloads, errors)
  * ✅ Native support for action buttons ("Fermer", "Réessayer", etc.)
  * ✅ Required for operations that may trigger multiple notifications (e.g., sync errors, scan failures)
  * **Usage Pattern:**

    ```dart
    final sonner = ShadSonner.of(context);
    final toastId = DateTime.now().millisecondsSinceEpoch;
    sonner.show(
      ShadToast(
        id: toastId,
        title: const Text('Title'),
        description: const Text('Description'),
        action: ShadButton.outline(
          onPressed: () => sonner.hide(toastId),
          child: const Text('Fermer'),
        ),
      ),
    );
    ```

  * **When to Use:**
    * Background sync operations (`SyncService`)
    * Scan errors and failures (`CameraScreen`)
    * Database operations (reset, sync) (`SettingsScreen`)
    * Any operation that may produce multiple notifications
    * Error notifications that benefit from action buttons

* **ShadToaster (Deprecated):**
  * ❌ **MUST NOT** be used in new code
  * ❌ Does not support proper stacking of multiple notifications
  * ❌ Limited action button support
  * ⚠️ Existing code using `ShadToaster` should be migrated to `ShadSonner` when touched

* **Configuration:**
  * `ShadSonner` is configured globally in `lib/main.dart` via the `ShadApp` builder
  * No toast theme configuration is required (removed from `ShadThemeData`)
  * All toasts automatically inherit the app's theme (light/dark mode)

#### **2.2.2. Typography Standardization via `ShadTextTheme`**

**CRITICAL:** All text styles **MUST** use semantic extensions from `ShadTextTheme`. Manual `TextStyle(...)` declarations and `copyWith()` modifications are strictly forbidden.

* **Absolute Prohibition:** You **MUST NEVER** use:
  * `TextStyle(...)` constructors directly
  * `textTheme.xxx.copyWith(...)` to modify colors, font sizes, or font weights
  * Manual style overrides that break semantic consistency

* **Mandatory Pattern:** Use semantic extensions exclusively:
  * `theme.textTheme.h4` - For titles and headings (e.g., medication names in cards)
  * `theme.textTheme.muted` - For secondary information (e.g., titulaires, CIP codes, dosages, descriptions)
  * `theme.textTheme.small` - For badges, labels, and captions
  * `theme.textTheme.lead` - For introductory or prominent text
  * `theme.textTheme.p` - For paragraph text

* **Usage Examples:**

    ```dart
    // ✅ CORRECT: Using semantic extensions
    final theme = ShadTheme.of(context);
    
    Text(medicament.nom, style: theme.textTheme.h4),
    Text(titulaire, style: theme.textTheme.muted),
    Text(codeCip, style: theme.textTheme.muted),
    Text('Description', style: theme.textTheme.muted),
    ShadBadge(child: Text('Label', style: theme.textTheme.small)),
    
    // ❌ INCORRECT: Manual styles or copyWith
    Text(
      medicament.nom,
      style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500), // FORBIDDEN
    ),
    Text(
      titulaire,
      style: theme.textTheme.small.copyWith(
        color: theme.colorScheme.mutedForeground, // FORBIDDEN
      ),
    ),
    Text(
      codeCip,
      style: TextStyle(fontSize: 14, color: Colors.grey), // FORBIDDEN
    ),
    ```

* **Benefits:**
  * Simplified maintenance: All typography is centralized in the theme
  * Automatic dark/light mode support without additional effort
  * Consistent visual hierarchy across the application
  * Reduced code complexity by eliminating manual style overrides

* **Implementation Locations:**
  * `InfoBubble` - Uses `h4` for titles, `muted` for descriptions, `small` for badges
  * `MedicamentCard` - Uses `h4` for medication names, `muted` for titulaires, codes, and dosages, `small` for condition badges

#### **2.2.3. Tabular Data Visualization with `ShadTable`**

**CRITICAL:** For any tabular data display (statistics, lists with aligned columns, complex compositions), you **MUST** use `ShadTable` instead of manual `Row`/`Column` layouts. This ensures proper column alignment, better readability, and consistency with the design system.

* **Absolute Prohibition:** You **MUST NEVER** use manual `Row`/`Column` layouts for tabular data:
  * ❌ `Row(children: [Column(...), Column(...)])` for statistics or aligned data
  * ❌ Manual alignment with `MainAxisAlignment.spaceAround` or `CrossAxisAlignment` for tabular content
  * ❌ Custom spacing calculations for column alignment

* **Mandatory Pattern:** Use `ShadTable.list` for tabular data:
  * ✅ **MUST** be used for statistics headers (e.g., Princeps | Génériques | Principes Actifs)
  * ✅ **MUST** be used for complex composition lists (e.g., CIP | Nom | Labo)
  * ✅ Provides automatic column alignment and consistent spacing
  * ✅ Better readability for structured data

* **Usage Pattern:**

    ```dart
    // ✅ CORRECT: Using ShadTable for tabular data
    final theme = ShadTheme.of(context);
    
    ShadTable.list(
      header: [
        ShadTableCell.header(
          child: Text('Groupe ID', style: theme.textTheme.table),
        ),
        ShadTableCell.header(
          child: Text('Princeps', style: theme.textTheme.table),
        ),
        ShadTableCell.header(
          child: Text('Principes Actifs', style: theme.textTheme.table),
        ),
      ],
      children: groups.map((summary) {
        return [
          ShadTableCell(
            child: Text(summary.groupId, style: theme.textTheme.p),
          ),
          ShadTableCell(
            child: Text(summary.princepsReferenceName, style: theme.textTheme.p),
          ),
          ShadTableCell(
            child: Text(summary.commonPrincipes, style: theme.textTheme.p),
          ),
        ];
      }).toList(),
    )
    
    // ❌ INCORRECT: Manual Row/Column layout for tabular data
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [Text('Label'), Text('Value')]),
        Column(children: [Text('Label'), Text('Value')]),
      ],
    )
    ```

* **Styling Guidelines:**
  * Use `theme.textTheme.table` for table headers (`ShadTableCell.header`)
  * Use `theme.textTheme.p` or `theme.textTheme.h4` for cell content depending on importance
  * For clickable rows, wrap cell content in `Material` + `InkWell` to maintain tap feedback
  * For horizontal scrolling on wide tables, wrap `ShadTable.list` in `SingleChildScrollView` with `scrollDirection: Axis.horizontal`

* **When to Use:**
  * Statistics dashboards (e.g., `DatabaseSearchView` header stats)
  * Complex composition lists (e.g., `ClusterDetailView` group listings)
  * Any data that benefits from column alignment (CIP codes, names, laboratories, dosages)
  * Comparison views where multiple values need to be aligned

* **Implementation Locations:**
  * `DatabaseSearchView` - Statistics header uses `ShadTable.list` for Princeps | Génériques | Principes Actifs
  * `ClusterDetailView` - Group listings use `ShadTable.list` for Groupe ID | Princeps | Principes Actifs

* **Benefits:**
  * Automatic column alignment without manual calculations
  * Consistent spacing and visual hierarchy
  * Better readability for structured data
  * Responsive behavior with horizontal scrolling support
  * Maintains design system consistency

#### **2.2.4. Advanced Filtering with `ShadSelect`, `ShadRadioGroup`, and `ShadPopover`**

**CRITICAL:** For filtering interfaces (type selection, form selection, advanced search options), you **MUST** use `ShadSelect`, `ShadRadioGroup`, and `ShadPopover` to provide a robust, type-safe, and visually consistent filtering experience.

* **When to Use `ShadRadioGroup`:**
  * ✅ **MUST** be used for mutually exclusive choices (e.g., Allopathie vs Homéopathie)
  * ✅ **MUST** be used when there are 2-5 options that need to be clearly visible
  * ✅ Provides better UX for binary or small categorical choices
  * ✅ Better accessibility with clear radio button semantics

* **When to Use `ShadSelect`:**
  * ✅ **MUST** be used for single selection from a list of options (especially when the list is long or dynamic)
  * ✅ **MUST** be used when options are loaded from the database (e.g., pharmaceutical forms)
  * ✅ Provides better UX for long lists (>5 items) or when space is limited
  * ✅ Supports search functionality for very long lists
  * ✅ Better for dynamic content that may change over time

* **When to Use `ShadPopover`:**
  * ✅ **MUST** be used to contain filter controls that should not take permanent screen space
  * ✅ **MUST** be used when combining multiple filter types (e.g., `ShadRadioGroup` + `ShadSelect`)
  * ✅ Provides a clean, collapsible interface for advanced filtering
  * ✅ Better UX when filters are secondary to the main content

* **Mandatory Pattern:** Combine these components for filtering interfaces:

    ```dart
    // ✅ CORRECT: Using ShadPopover with ShadRadioGroup and ShadSelect
    final theme = ShadTheme.of(context);
    final popoverController = ShadPopoverController();
    
    ShadPopover(
      controller: popoverController,
      popover: (context) => SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filtres', style: theme.textTheme.h4),
                  if (hasActiveFilters)
                    ShadButton.ghost(
                      onPressed: () {
                        // Clear filters
                        popoverController.toggle();
                      },
                      child: Text('Réinitialiser', style: theme.textTheme.small),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Type de procédure',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShadRadioGroup<String?>(
                    initialValue: currentFilters.procedureType,
                    onChanged: (value) {
                      // Update filter
                    },
                    items: [
                      ShadRadio(value: null, label: const Text('Tous')),
                      ShadRadio(value: 'Autorisation', label: const Text('Allopathie')),
                      ShadRadio(
                        value: 'Enregistrement',
                        label: const Text('Homéopathie / Phytothérapie'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Forme pharmaceutique',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<String>>(
                    future: dbService.getDistinctPharmaceuticalForms(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const ShadProgress();
                      }
                      return ShadSelect<String?>(
                        minWidth: double.infinity,
                        placeholder: const Text('Toutes les formes'),
                        initialValue: currentFilters.formePharmaceutique,
                        options: [
                          ShadOption(value: null, child: const Text('Toutes les formes')),
                          ...snapshot.data!.map(
                            (form) => ShadOption(value: form, child: Text(form)),
                          ),
                        ],
                        selectedOptionBuilder: (context, value) {
                          return Text(value ?? 'Toutes les formes');
                        },
                        onChanged: (value) {
                          // Update filter
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      child: ShadButton.outline(
        onPressed: popoverController.toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.slidersHorizontal, size: 16),
            if (hasActiveFilters) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    )
    
    // ❌ INCORRECT: Manual dropdown or checkbox implementations
    DropdownButton<String>(
      items: [...], // FORBIDDEN
    )
    CheckboxListTile(...) // FORBIDDEN for filtering
    ```

* **Styling Guidelines:**
  * Use `theme.textTheme.h4` for popover titles
  * Use `theme.textTheme.small` with `fontWeight: FontWeight.w600` for filter section labels
  * Use `theme.textTheme.p` for option labels in `ShadRadio` and `ShadSelect`
  * Always provide a "Réinitialiser" or "Clear" button when filters are active
  * Show a visual indicator (e.g., colored dot) on the filter button when filters are active
  * Use `ShadPopoverController` to manage popover state (open/close)

* **State Management:**
  * Filter state **MUST** be managed via Riverpod providers (preferably `@riverpod`-generated notifiers)
  * Filter state **MUST** be observed by search/query providers to apply filters automatically
  * Use `ref.watch(filterProvider)` to observe filter changes
  * Use `ref.read(filterProvider.notifier).updateFilters(...)` to update filters

* **When to Use:**
  * Search/filter interfaces (e.g., `DatabaseSearchView` filters)
  * Settings panels with multiple choice options
  * Any interface requiring user selection from predefined options
  * Advanced search forms with multiple filter criteria

* **Implementation Locations:**
  * `DatabaseSearchView` - Uses `ShadPopover` containing `ShadRadioGroup` (procedure type) and `ShadSelect` (pharmaceutical form) for filtering search results

* **Benefits:**
  * Type-safe filtering with compile-time guarantees
  * Consistent visual design across all filter interfaces
  * Better accessibility with proper semantic components
  * Automatic theme support (light/dark mode)
  * Clean, collapsible UI that doesn't clutter the main interface
  * Easy to extend with additional filter types

### 2.3. State Management: Minimalist and Local Approach

**Simplicity Principle:** Local `StatefulWidget` state remains the default. Riverpod is reserved for *targeted* cross-layer telemetry (e.g., background sync status or persisted preferences) where multiple widgets/services must observe the same source of truth.

When you use context7, riverpod library id is : `websites/pub_dev-riverpod`

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
* **Isolate-Based Fuzzy Search:** The application uses `FuzzyBolt` to provide fast, typo-tolerant searching. `DatabaseService` exposes a list of candidates from `medicament_summary`, and the search provider executes fuzzy matching in a background isolate to prevent UI blocking.
* **Pagination:** Large result sets **MUST** be paginated to maintain UI responsiveness. Use infinite scroll with proper offset/limit management.

### 2.6. Data Model: Deterministic & Knowledge-Injected Parsing

**CRITICAL:** The application uses a **deterministic** data model based on official relational data files from the *Base de Données Publique des Médicaments (BDPM)*. We strictly avoid heuristic guessing when structured data is available.

* **Data Sources:** The application downloads individual TXT files directly from BDPM:
  * `CIS_bdpm.txt` - Medication specialties with form, commercialization status, and manufacturer (titulaire)
  * `CIS_CIP_bdpm.txt` - Medicament information (CIS, CIP13, name)
  * `CIS_COMPO_bdpm.txt` - Active ingredient compositions with structured dosage information
  * `CIS_GENER_bdpm.txt` - Generic group relationships (source of truth)

* **Parsing Strategy: Knowledge Injection:**
  * We do **not** parse medication names (e.g., "DOLIPRANE 1000 mg, comprimé") blindly using Regex.
  * Instead, we inject the **official truth** from the relational database (`forme_pharmaceutique` from `CIS_bdpm.txt` and `titulaire` from `CIS_bdpm.txt`) directly into the parser.
  * **The Parser's Job:** Subtract the known official Form and known official Lab from the raw string. What remains is treated as the Canonical Name and Dosage.
  * **Fallback:** Only if the official data is missing or disjoint from the raw text does the parser fall back to grammar-based extraction (PetitParser).

* **Database Schema (Version 7):**
  * `specialites` - Medication specialties (cis_code, nom_specialite, procedure_type, forme_pharmaceutique, etat_commercialisation, titulaire, conditions_prescription)
  * `medicaments` - Basic medication info (code_cip, nom, cis_code)
  * `principes_actifs` - Active ingredients with structured dosage (code_cip, principe, dosage, dosage_unit)
  * `generique_groups` - Generic groups (group_id, libelle)
  * `group_members` - Group membership (code_cip, group_id, type)
    * `type = 0` for princeps, `type = 1` for generic
  * `medicament_summary` - **Single row per CIS** storing the canonical name (dosage/form stripped), princeps/generic flag, `group_id`, JSON-encoded shared active principles, `princeps_de_reference`, and `forme_pharmaceutique`. *All* explorer/search/scan read paths must consult this table instead of recomputing joins at runtime.

* **Generic Detection:** Uses explicit group relationships from `group_members` table. **NEVER** infer generic relationships from active ingredient matching.

* **Princeps Name Grouping:** The application uses an algorithmic word-based approach to find common base names for princeps within the same group. The `findCommonPrincepsName()` helper function in `lib/core/utils/medicament_helpers.dart` compares medication names word-by-word to identify the longest common prefix. This replaces fragile regex-based extraction and provides robust, deterministic grouping results.

* **Data Initialization:** `DataInitializationService` downloads TXT files directly, parses tab-separated values, and populates the relational schema. All complex fallback logic and regex-based extraction has been removed.
  * **Phase 1 – Staging:** Populate normalized tables (`specialites`, `medicaments`, `principes_actifs`, `generique_groups`, `group_members`) exactly as parsed from BDPM.
  * **Phase 2 – Aggregation:** Call `_aggregateDataForSummary()` to recalculate every `medicament_summary` row. This phase uses the **Knowledge-Injected Parsing** strategy to populate the `nom_canonique` and `cluster_key` fields cleanly.

* **Reset Policy:** `DatabaseService.clearDatabase()` must wipe both the staging tables and `medicament_summary`. Any developer utility that seeds test data **MUST** call `populateMedicamentSummary()` (see `test/database_service_test.dart`) before asserting on explorer/search behaviors.

#### **2.6.1. Data Source Integrity Auditor**

`data_validator.py` is the **definitive tool** for auditing the raw BDPM data format. It downloads the latest versions of the BDPM files and performs an in-depth analysis to ensure the file structure (columns, separators, encoding) matches the Dart parser's expectations.

**When to Use:** You **MUST** run this script whenever you have the slightest doubt about the data's integrity, especially in the following scenarios:

* The data initialization process (`initializeDatabase()`) fails unexpectedly.
* Search results or generic group information appear incorrect or inconsistent.
* Before attempting to modify or extend the data parsing logic in `DataInitializationService`.
* To proactively check if the official data source format has changed.

**How to Run:**

```bash
uv run python data_validation/data_validator.py
```

#### **2.6.2. Data-Driven Parser Validation**

To ensure the "Knowledge-Injected" parser handles the immense variety of French medication names (16,000+ entries) without regression, we use a data-driven testing approach.

1. **Generate Test Data:** Run `python data_validation/generate_smart_test_data.py`. This script downloads fresh BDPM data and creates a CSV file (`smart_parsing_challenges.csv`) containing "Tricky" cases (Ratios, complex units) and random samples, paired with their official "Truth" (Form, Lab).
2. **Run Dart Tests:** The test file `test/core/parser/data_driven_parser_test.dart` reads this CSV and verifies that the parser correctly strips the official Form and Lab from the raw name without leaving artifacts.

This replaces the deprecated `product_classifier.py` and `generate_parsing_samples.py` scripts.

### 2.7. Architecture: Tooling & Enhancements

To improve robustness and maintainability, the project uses specific tooling that complements the core architecture.

* **Immutable Models (`freezed`):** All data models (e.g., `Medicament`, `ScanResult`, `Gs1DataMatrix`, `ParsedName`) **MUST** be defined as immutable classes using the `freezed` package.
* **PetitParser:** Used for grammar-based extraction of Dosages and Context keywords. Regex is used *only* for tokenization and cleanup, not for complex parsing logic.
* **Service Location (`get_it`):** The project uses `get_it` as a simple service locator to decouple the UI layer from service implementations. Widgets **MUST** retrieve service instances (like `DatabaseService`) from the central locator (`sl<T>()`) instead of using static singletons.
* **Background Sync (`SyncService` + `AppPreferences` provider):** Automatic BDPM refreshes are orchestrated by `SyncService`. The UI observes sync progress via `syncStatusProvider`.

### 2.8. Navigation with Nested Navigators

The application uses a robust **Nested Navigator** pattern to manage navigation stacks independently for each main tab (Scanner, Explorer).

---

## 3. Development Toolkit & Commands

Use the standard command-line tools to manage the project.

### Pre-Test Tooling

* Run `dart run tool/prepare_test_data.dart` (supports `--force` and `--dir=/abs/path`) before the Quality Gate to cache the official BDPM TXT payloads inside `.dart_tool/bdpm_cache`.
* **Refresh Parser Test Data:** If you suspect the BDPM data format has evolved or to test against new real-world edge cases:

    ```bash
    uv run python data_validation/generate_smart_test_data.py
    ```

* **Install/Update Dependencies:** `flutter pub get`
* **Static Code Analysis:** `flutter analyze`
* **Run All Tests:** `flutter test`
* **Quality Gate (Run Before Finalizing Changes):**

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test && flutter test integration_test
    ```

---

## 4. Documentation and Maintenance

### 4.1. `CHANGELOG.md` Protocol

You **MUST** maintain the `CHANGELOG.md` file at the project root using the defined format.

---

Context7 Library :

* Freezed : `rrousselgit/freezed`
* Riverpod : `websites/pub_dev-riverpod`
* shadcnui : `websites/flutter-shadcn-ui_mariuti`
* flutter_animate : `gskinner/flutter_animate`
* drift : `websites/pub_dev_drift`
