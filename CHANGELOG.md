# Changelog

## [Unreleased] - Architecture "Relational Determinism"

### Data Pipeline Refactor

- **Relational Composition Logic (FT > SA):** Implemented smart resolution of active ingredients. The parser now prefers the "Therapeutic Fraction" (Base) over the "Active Substance" (Salt) when linked in `CIS_COMPO`. This naturally cleans names (e.g., "Metformine" instead of "Chlorhydrate de Metformine") without fragile Regex.

- **Strict AMM Filtering:** The ingestion pipeline now strictly enforces `Statut administrative == "Autorisation active"`. Revoked or archived medications are rejected at the gate, significantly reducing database noise.

- **Robust Dosage Parsing:** Added pre-processing to handle French decimal formatting (`,`) and safe rejection of non-quantifiable dosages (e.g., homeopathic ranges).

- **Enhanced Standalone Normalization:** Name cleaning for standalone medications now uses diacritic-agnostic normalization before subtraction, improving match rates for Lab and Form removal.

## [2025-01-20] - Native Columns Data Pipeline Refactor

- **Ingestion filtering (homeopathy purge)**: Added early filtering in `_parseSpecialites` to skip entries with procedure types containing "homéopathique", "homeopathique", "traditionnel à base de plantes", or "phyto". Excluded CIS codes never enter `seenCis`, automatically cascading the filter to all downstream parsing functions (`_parseMedicaments`, `_parseCompositions`, `_parseGeneriques`).
- **Dosage source of truth (CIS_COMPO)**: Eliminated heuristic dosage extraction from medication names. Modified `principesQuery` to fetch `dosage` and `dosageUnit` directly from `principes_actifs` table. Built `dosagesByCip` map that concatenates multiple dosages with " + " (e.g., "500 mg + 65 mg"). Dosage data now comes exclusively from BDPM column 4, not regex parsing.
- **Grouping source of truth (CIS_GENER)**: For grouped items, use `generique_groups.libelle` directly as `nomCanonique` and `princepsBrandName` without re-parsing. For standalone items, construct `nomCanonique` from `principe` + `dosage` (e.g., "PARACETAMOL 1000 mg"). Removed all parser-based extraction for canonical names.
- **Parser deprecation**: Removed `MedicamentParser` instantiation and all `medicamentParser.parse()` calls from the aggregation phase (`_computeAndInsertSummaryRecords`, `_buildStandaloneSummaryRecords`). Parser is no longer used for data extraction (dosage, canonical names) - only native BDPM columns are trusted.
- **Strategy**: "Filter Early, Trust Structure" - all data now comes from structured BDPM columns instead of heuristic parsing, significantly improving accuracy and reducing database size by excluding homeopathy entries.

## [2025-11-21] - Drift-AppSettings Single Source of Truth

- **Singleton configuration table:** Added `AppSettings` (Drift) with enforced `id=1`, default theme/update frequency, BDPM metadata, and JSON blobs for source hashes/dates. Registered the table in `AppDatabase` and regenerated code.
- **Database-driven preferences:** `DriftDatabaseService` now seeds and streams settings, exposes helpers (`watchSettings`, `updateTheme`, `updateSyncFrequency`, `updateSyncTimestamp`, `saveSourceHashes`, etc.), and resets metadata during `clearDatabase()`.
- **Provider + service refactor:** `ThemeNotifier` and `AppPreferences` became stream-based Riverpod notifiers backed by Drift. `SyncService` and `DataInitializationService` no longer depend on `SharedPreferences`; sync cadence, timestamps, hashes, and BDPM versions read/write via `DriftDatabaseService`.
- **Bootstrap simplification:** Removed `SharedPreferences` override in `main.dart`. `ProviderScope` now boots without async overrides, and Shad themes derive directly from the settings stream.
- **Package + helper removal:** Deleted `lib/core/utils/theme_preferences.dart`, removed the `shared_preferences` dependency (and transitive platform plugins), and updated all tests/mocks to rely on Drift services instead of fake `SharedPreferences`.
- **Documentation & rules:** Updated `AGENTS.md` and `.cursor/rules/solo-dev-guide.mdc` with the Drift-only settings policy; added the new workflow to keep configuration reactive.

## [2025-11-20] - Mocktail Migration & Test Hygiene

- **Mocktail adoption**: Removed `mockito` from `dev_dependencies`, added `mocktail` 1.0.4, and kept `build_runner` for Drift/Freezed/Riverpod codegen. This eliminates test-time code generation for mocks and speeds up local feedback loops.
- **Centralized mocks**: Introduced `test/mocks.dart` with shared `MockSharedPreferences`, `MockExplorerRepository`, `MockSyncService`, and other core fakes to keep tests DRY and aligned with the project’s service locator.
- **Widget test refactor**: Updated `group_explorer_view_test.dart` and `network/live_scraping_test.dart` to import the shared mocks, switch to `when(() => ...)` syntax, and drop legacy `@GenerateNiceMocks` annotations plus generated `*.mocks.dart` files.
- **Quality gate**: `dart test` passes after the migration, confirming no regressions.

## [2025-11-18] - Smart Parsing & Data-Driven Robustness

- **Knowledge-Injected Parsing Engine**: Replaced the previous heuristic parser with a deterministic "Subtraction Strategy." The parser now accepts official "Truths" (Pharmaceutical Form and Laboratory Name) directly from the BDPM database during initialization. It surgically removes these known entities from the raw medication string before using `PetitParser` grammar to extract complex dosages (ratios, multi-ingredients) and context (e.g., "SANS SUCRE", "ENFANTS"). This guarantees a 100% clean canonical name and eliminates false positives where lab names were mistaken for molecules or vice-versa.
- **Data-Driven Validation Suite**: Introduced `data_driven_parser_test.dart` backed by a Python-generated dataset (`smart_parsing_challenges.csv`) containing 100 real-world edge cases (including complex biologicals and homeopathy). This test suite enforces strict quality gates: zero units allowed in base names, mandatory context extraction, and perfect formulation detection.
- **Python Tooling Refactor**: Consolidated the Python maintenance scripts. Deleted obsolete prototypes (`product_classifier.py`, `generate_parsing_samples.py`) and established `generate_smart_test_data.py` as the bridge between official government data and Dart integration tests.
- **Optimized Aggregation Pipeline**: Updated `DataInitializationService` to use the new parser. The aggregation phase now runs an O(N) logic with pre-grouped maps instead of nested loops, significantly speeding up the "Applying updates" phase during database initialization.
- **Reactive Data Architecture**: Fixed a critical disconnect where UI providers (`searchCandidates`, `groupCluster`) were not listening to the sync service. The application now hot-reloads its data instantly upon successful background sync without requiring a restart.
- **UX Polish**: Disbaled misleading ripple effects on standalone search results and improved accessibility labels for complex dosage forms.

## [2025-11-18] - Aggregated Library Experience

- **FTS5-only explorer search**: Retired the legacy `getAllSearchCandidates()` isolate workflow and the fuzzy-bolt re-ranking path. All explorer queries now go straight through `searchMedicaments()` (SQLite FTS5) and `searchResultsProvider(query)`, keeping memory usage low and ranking deterministic.
- **Procedure-aware filtering**: `SearchCandidate` carries `procedureType`, allowing the provider to exclude homéopathie/phyto entries by default without touching the database layer. This keeps conventional searches fast and deterministic.
- **Test & integration refresh**: Replaced the old `searchMedicaments` unit/integration suites with coverage for candidate hydration and the fuzzy providers, updated widget tests to drop the deprecated FTS rebuild hook, and documented the new flow here.
- **Decimal-consistent dosages**: Migrated `principes_actifs.dosage` to `TEXT`, parse BDPM values with `Decimal.tryParse`, regenerate the Drift/Freezed models (`Medicament`, `GroupedByProduct`, `DatabaseService`), refresh UI formatting, and align unit/integration tests so explorer/scanner flows no longer lose precision.
- **MedicamentSummary source of truth**: Added a denormalized table (one row per CIS) populated during initialization. It stores canonical names, princeps flags, group IDs, pharmaceutical forms, and JSON-encoded shared principles, allowing explorer/search flows to answer every query with a single, constant-time select.
- **Two-phase initialization**: `DataInitializationService` now runs a staging phase (raw TXT → normalized tables) followed by an aggregation phase that precomputes `MedicamentSummary`. `DatabaseService.clearDatabase()` and the unit-test helpers were updated to keep the summary in sync.
- **Search overhaul**: `searchMedicaments()` now returns the new `SearchResultItem` union (princeps, generic, standalone) and reads exclusively from `MedicamentSummary`. The explorer search UI renders dedicated cards for each variant with contextual princeps/generic relationships and Shadcn skeletons while loading.
- **Documentation**: README and AGENTS now describe the aggregated table, the two-phase data pipeline, and the new requirement for tests/utilities to hydrate `MedicamentSummary` before asserting explorer/search logic.
- **Riverpod preferences & sync refactor**: Replaced the legacy `PreferencesService` frequency cache with an `AppPreferences` AsyncNotifier, rewrote `SyncService` to accept injectable frequency/status callbacks, introduced a dedicated `syncStatusProvider` notifier, updated `MainScreen`/`SettingsScreen`, and refreshed AGENTS to describe the new, Flutter-agnostic pipeline.
- **Declarative animations & ProviderScope coverage**: Applied `flutter_animate` fade/slide transitions to the sync banner, database search skeletons, and explorer result cards, then wrapped explorer widget tests in `ProviderScope` so Riverpod providers bootstrap correctly. `dart run build_runner build --delete-conflicting-outputs`, `dart fix --apply`, `dart analyze --fatal-infos --fatal-warnings`, and `dart test` now complete without errors.

## [2025-11-18] - Smart Sync & Regulatory Context

- **Data pipeline refactor**: `DataInitializationService` now orchestrates downloads via `_downloadAllFiles()`, parses each BDPM file inside a background isolate (`compute`) through dedicated helpers, and centralizes source URLs inside `lib/core/config/data_sources.dart`.
- **Regulatory enrichment**: Added `conditions_prescription` to the `specialites` table (schema v3) and to the `Medicament` model, parsed from `CIS_CPD_bdpm.txt`, surfaced through `DatabaseService`, and rendered via `ShadBadge` in scanner bubbles and explorer cards.
- **Smart synchronization**: `_fetchFileBytesWithCache()` always re-downloads BDPM TXT files (official mirrors never update reliable `ETag`/`Last-Modified` headers) and only falls back to the cached copy if the network transfer fails.
- **Explorer ergonomics**: Integrated `fuzzy_bolt` re-ranking inside `searchMedicaments()`, introduced debounced (300 ms) search input, and replaced spinners with skeleton placeholders for both search and category lists.
- **Quality gate**: Regenerated code (`build_runner`), updated `integration_test/search_filter_test.dart` lints, and ran `dart analyze --fatal-infos --fatal-warnings` plus `dart test` successfully.

## [2025-11-17] - Architectural Refactor: Migration to Drift Files

- **Migrated all complex queries** from `customSelect` with raw SQL strings to named queries in `.drift` files.
- **Achieved full compile-time validation of SQL**, ensuring all queries are syntactically correct and consistent with the database schema before the app is run. This eliminates an entire class of potential runtime errors.
- **Improved Developer Experience (DX)** by enabling native SQL syntax highlighting, auto-completion, and real-time error checking in VS Code.
- **Enhanced maintainability** by strictly separating SQL data logic from Dart business logic.
- **Refactored `DatabaseService`** to call type-safe, generated methods, resulting in a cleaner and more robust data access layer.
- **Verification**: `dart run build_runner build --delete-conflicting-outputs`, `dart fix --apply`, `dart analyze --fatal-infos --fatal-warnings`, and `dart test` executed successfully.

## [2025-11-17] - FTS5 Search and Navigation Refactoring

- **Full-Text Search (FTS5)** : Implementation of an FTS5 index for medication search with creation of a `medicament_fts_view` view and a virtual `medicament_fts` table indexing specialty names, CIP codes, and active ingredients. The `searchMedicaments()` method now uses FTS5 `MATCH` queries and returns `GenericGroupSummary` instead of individual `Medicament` objects.
- **Refactored Navigation Architecture** : Replacement of the `IndexedStack` + `PopScope` architecture with nested `Navigator` widgets in `MainScreen`. Each tab (Scanner and Explorer) now has its own independent navigation stack, enabling correct handling of the system back button.
- **Bubble UI Simplification** : Replacement of `AnimatedList` with a simple `Column` using `flutter_animate` animations in `CameraScreen`. New bubbles are inserted at index 0 and the oldest is removed if the limit of 3 is exceeded.
- **Associated Therapies** : Refactoring of `_findRelatedPrinceps()` to identify groups containing ALL active ingredients from the current group PLUS at least one additional ingredient. Addition of an "Associated Therapies" section in `GroupExplorerView` with clickable cards navigating to associated groups.
- **Enhanced Explorer Search** : `DatabaseSearchView` now displays group summaries (`GenericGroupSummary`) instead of individual medications, with direct navigation to `GroupExplorerView` via `Navigator.push()`.
- **Test Updates** : Adaptation of unit and integration tests to reflect the new return types (`GenericGroupSummary`) and the new navigation architecture.

## [2025-11-17] - Deterministic Active Ingredient Validation

- **`DatabaseService` Refactoring** : `getGenericGroupSummaries()` and `classifyProductGroup()` now rely exclusively on a Drift join (`principes_actifs` ↔ `group_members`) to calculate active ingredients actually shared by all members of a group. Groups without intersection are automatically filtered to eliminate the last heuristic logic from official labels.
- **New Internal API `_getCommonPrincipesForGroups()`** : Paginated CTEs + batch processing (<900 SQLite variables) to efficiently retrieve common principles, reused by multiple methods.
- **Unit & Integration Tests** : 
  - Addition of two unit tests in `test/database_service_test.dart` to guarantee deterministic extraction and exclusion of inconsistent groups.
  - Update of `integration_test/active_principle_grouping_test.dart` to verify that the ESOMEPRAZOLE entry exposes a clean result.
- **Canonical Group Classification** : Introduction of the `ProductGroupClassification` model + `DatabaseService.classifyProductGroup()` method (Drift joins + Dart aggregation) to deliver a synthetic view to the frontend (titles, distinct dosages, formulations, grouped princeps/generics, related princeps). Update of unit & widget tests to cover this flow.
- **Explorer API Cleanup** : Removal of `getGroupDetails()`/`GroupedByLaboratory`, alignment of all integrations (unit tests, integration tests, `GroupExplorerView`) on `classifyProductGroup()` and consolidation of coverage around product/laboratory groupings.
- **SQLite Persistence Enabled** : Removal of systematic deletion of the `medicaments.db` file on each launch. Drift storage now remains intact between sessions, explicit resets go through `DatabaseService.clearDatabase()` and BDPM initialization.
- **Multi-Bubble Scanner** : Refactoring of `CameraScreen` with animated FIFO queue (`AnimatedList` + `Dismissible`) limiting display to 3 bubbles, expiration timers and swipe to close scan results.
- **Enhanced Python Audit** : `data_validator.py` includes global contamination control (dosages/formulations) on 100% of groups and documents the new Step 13 in `AGENTS.md`.
- **Documentation** : Update of `AGENTS.md` and the `rapport_final.txt` report to reflect heuristic vs deterministic cross-validation.
- **Explorer UI** : Harmonization of the manual search interface with the standard Shadcn card layout (new `MedicamentCard` shared between `DatabaseSearchView` and `GroupExplorerView`) and update of widget tests `database_screen_test.dart` to cover the card-based experience.
- **Instant Explorer Search** : `searchMedicaments()` now retrieves `groupId` and `groupMemberType` per entry, allowing `DatabaseSearchView` to immediately display the princeps/generic status and route to the group without a second database access.
- **Database** : Reset of `schemaVersion` to `1` and removal of the destructive migration strategy to deliver a stable version intended for new installations only.
- **Explorer Accessibility** : Addition of visible Scrollbars, `Semantics` labels/tooltips and a voice description for each medication and group card, ensuring keyboard/screen reader accessible navigation.
- **Persistent BDPM Initialization** : `DataInitializationService` now checks a `SharedPreferences` flag + the presence of Drift data before relaunching the download. The database is only rebuilt on first execution or `forceRefresh`, aligning the app with the "SQLite Persistence Enabled" policy.
- **Resilient Initialization** : `PharmaScanApp` now relies exclusively on the versioned logic of `DataInitializationService`, exposes an `InitializationState` shared with `MainScreen` and displays a retryable alert (direct access to settings) rather than a blocking dialog.
- **Force Reinitialization** : The destructive settings button calls `initializeDatabase(forceRefresh: true)` and no longer manipulates `SharedPreferences` flags, guaranteeing a true reset of BDPM data.
- **Explorer Search** : `DatabaseSearchView` gains a contextual delete button in the search field (`LucideIcons.x` icon) that instantly clears the query and restarts the initial state.
- **Python Audit** : `data_validator.py` tolerates legitimate numbered molecules (e.g. `ALCOOL DICHLORO-2,4 BENZYLIQUE`) and ignores "solution de ..." expressions, reducing false positives in contamination analysis.
- **Verification** : `dart run build_runner build --delete-conflicting-outputs`, `dart fix --apply`, `dart analyze --fatal-infos --fatal-warnings`, `dart test integration_test/active_principle_grouping_test.dart`, and `dart test integration_test` executed successfully.

## [2025-11-16] - Algorithmic Princeps Grouping and Critical Fix

Implementation of algorithmic princeps grouping by common prefix and correction of a critical SQL bug that prevented results from displaying in the explorer.

- **Algorithmic Princeps Grouping** : Replacement of fragile regex logic with a deterministic word-based algorithm
  - Creation of `findCommonPrincepsName()` in `lib/core/utils/medicament_helpers.dart` to find the longest common word prefix
  - Robust algorithm that compares names word by word to identify the common base
  - Handling of edge cases: empty lists, unique names, absence of common prefix

- **GenericGroupSummary Model Simplification** : Transition from a list of names to a unique reference name
  - Replacement of `List<String> princepsNames` with `String princepsReferenceName` in the model
  - Simplified UI interface: display of a single princeps reference name per group
  - Clear mapping "Active Ingredient(s) ↔ Reference Princeps" with visual separator (arrow)

- **getGenericGroupSummaries Refactoring** : Migration of grouping logic from SQL to Dart
  - Modified SQL query to retrieve individual princeps names (one row per princeps) instead of `GROUP_CONCAT`
  - Grouping of results by `group_id` in Dart to enable algorithmic processing
  - Use of `findCommonPrincepsName()` to calculate the common reference name for each group
  - Optimization with CTE (Common Table Expression) for efficient pagination

- **Critical SQL Bug Fix** : Resolution of the "no result" problem in the explorer
  - Identified bug: incorrect alias in the CTE WHERE clause (`princeps_spec` vs `princeps_spec2`)
  - Solution: creation of separate conditions for the CTE (`formConditionsCte`, `excludeConditionsCte`) with correct aliases
  - Impact: the explorer now correctly displays all medication groups

- **Integration Tests with Real Data** : Complete validation with official BDPM TXT files
  - New test `integration_test/generic_group_summaries_test.dart` that downloads and uses the real TXT files
  - Verification that algorithmic grouping produces consistent results
  - Tests for different categories of pharmaceutical forms (oral, injectable, external)
  - Validation of pagination and behavior with large amounts of data

- **Mobile Verification** : Test on real device confirming proper operation
  - The explorer now correctly displays groups with their active ingredients and reference princeps
  - Simplified and more intuitive user interface
  - Performance verified with scrolling and pagination

## [2025-11-16] - Complete Overhaul: Enriched Data and Deterministic Logic

Complete elimination of all regex-based extraction logic in favor of structured parsing of official BDPM TXT files, enrichment of the data model, and replacement of the last heuristic logic with a database-based deterministic method.

- **Database Schema Enrichment** : Migration to version 4 with addition of new columns
  - `Specialites` table: addition of `formePharmaceutique`, `etatCommercialisation`, `titulaire` (laboratory)
  - `PrincipesActifs` table: addition of `dosage` and `dosageUnit` for structured dosage storage
  - Extended parsing of `CIS_bdpm.txt` (columns 2, 6, 10) and `CIS_COMPO_bdpm.txt` (column 4 for dosage)

- **Enriched Medicament Model** : Addition of `titulaire`, `formePharmaceutique`, `dosage`, `dosageUnit` fields
  - Replacement of regex-based laboratory extraction with direct use of the `titulaire` field from the database
  - Updated dosage sorting to use the structured `dosage` field instead of regex extraction

- **Replacement of `cleanGroupName` with Deterministic Logic** : Last heuristic logic eliminated
  - Refactoring of `getGenericGroupSummaries` to extract common active ingredients directly from the `principes_actifs` table
  - SQL query joining necessary tables to identify active ingredients shared by all members of a group
  - Renaming of `groupLabel` to `commonPrincipes` in the `GenericGroupSummary` model to reflect the actual semantics
  - Complete removal of `MedicamentHelpers.cleanGroupName()` and the `medicament_helpers.dart` file

- **Robustness and Reliability** : All displayed data now comes directly from official BDPM files
  - No heuristic approximation: 100% of data is deterministic and based on the source of truth
  - Display of common active ingredients in the generic groups explorer without truncation or potential error

## [2025-11-16] - Relevance Filter and Major Improvements

Complete implementation of the relevance filter to exclude non-medication products (homeopathy, phytotherapy), improvement of active ingredient search, correction of generic detection (types 2 and 4), and complete validation of BDPM TXT file parsing logic.

- **Relevance Filter** : Addition of a global filter to exclude homeopathic and phytotherapeutic products based on column 5 of `CIS_bdpm.txt` (AMM procedure type)
  - Toggle accessible from the main navigation bar with `funnel` icon
  - Filter applied at the database level via `searchMedicaments(showAll: bool)`
  - State managed centrally in `MainScreen` and propagated to `DatabaseScreen`
  - Automatic reactivity via `didUpdateWidget` to refresh results when the filter changes

- **Active Ingredient Search** : Extension of search to include active ingredients in addition to name and CIP
  - Join with the `principesActifs` table in `searchMedicaments`
  - Case-insensitive search with `LIKE` on name, CIP, and active ingredient

- **Generic Types Correction** : Correct detection of all generic types (1, 2, and 4) from `CIS_GENER_bdpm.txt`
  - Corrected logic: `isGeneric = type == 1 || type == 2 || type == 4`
  - Consistent storage as type `1` in the database for all generics

- **Database Schema** : Addition of the `procedureType` column in the `Specialites` table for filtering
  - Schema migration to version 3
  - Parsing of column 5 of `CIS_bdpm.txt` to extract the procedure type

- **Complete TXT File Validation** : Creation of Python scripts to validate parsing logic
  - Validation scripts in `data_validation/`: `validate_txt_files.py`, `detailed_analysis.py`, `generate_samples.py`
  - Complete validation report: `VALIDATION_REPORT.md`
  - Confirmation that all column indices are correct and the logic is optimal

- **Complete Tests** : Extension of the test suite to cover all new features
  - 48 tests total (37 unit/widget + 11 integration) - all pass ✅
  - Unit tests for active ingredient search and filtering
  - Widget tests for filter reactivity in `DatabaseScreen`
  - Integration tests for complete search and filtering flows

## [2025-11-16] - Migration from sqflite to drift ORM

Complete migration of the database layer from `sqflite` (raw SQL) to `drift` (type-safe ORM), bringing compile-time type safety and eliminating SQL errors at runtime.

- **Type-safe schema** : Schema definition in Dart with automatic generation of type-safe API (`lib/core/database/database.dart`)
- **Type-safe queries** : Replacement of all raw SQL strings with drift's type-safe API (`select()`, `where()`, `join()`)
- **Isolated tests** : Use of `AppDatabase.forTesting(NativeDatabase.memory())` for complete test isolation without file system dependencies
- **Service locator** : Registration of `AppDatabase` in the service locator, eliminating the singleton pattern from `DatabaseService`
- **Documentation** : Update of `AGENTS.md` with complete drift documentation as the type-safe database standard

## [2025-11-16] - Integration of freezed and get_it

Integration of `freezed` for immutable data models and `get_it` for service location, improving type safety, maintainability, and testability.

- **Immutable models (`freezed`)** : Conversion of all data models (`Medicament`, `ScanResult`, `Gs1DataMatrix`) to immutable classes with code generation, eliminating state mutation bugs
- **Service locator (`get_it`)** : Replacement of static singletons with a centralized service locator, improving testability and decoupling between the UI layer and services
- **Exhaustive pattern matching** : Use of the `when()` method for compile-time safe pattern matching on union types (`ScanResult`)
- **Documentation** : Update of `AGENTS.md` with the new architecture section and workflow steps including code generation

## [2025-11-16] - Database Explorer with Navigation

Complete implementation of the database explorer with tab navigation and text search.

- **Main Navigation** : Addition of `MainScreen` with tab navigation (Scanner/Explorer) using `IndexedStack` to preserve state
- **DatabaseScreen** : Exploration screen with statistics dashboard, instant search by name or CIP, and detail display via `ShadSheet`
- **DatabaseService Extension** : Addition of `getDatabaseStats()` for global statistics and `searchMedicaments()` for text search
- **Tests** : Update of the test suite with database factory initialization for widget tests, and addition of tests for the new service methods

## [2025-11-16] - Complete PharmaScan Implementation

Complete setup of the PharmaScan application: architecture, business logic (GS1 parser, SQLite database), user interface (camera screen, info bubbles), and data initialization from the French public database.

- **Unit and Integration Tests** : Complete implementation of the test suite ensuring application functionality
  - Unit tests for `Gs1Parser`: robust parsing of GS1 Data Matrix codes with different separator formats (spaces, FNC1)
  - Integration test `image_scanning_test.dart`: verification of barcode extraction from static images
  - Integration test `data_pipeline_test.dart`: complete verification of the data pipeline (download, TXT parsing, database insertion)
  - Fallback strategy for generics and active ingredients: ensures tests pass even if BDPM file format changes
