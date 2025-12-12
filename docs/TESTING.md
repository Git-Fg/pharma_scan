# Testing Guide

**Version:** 1.0.0  
**Status:** Source of Truth for Testing Patterns  
**Context:** This document explains testing strategies for the external DB-driven architecture.

---

## SQL-First Testing for Data-Driven Tests

### Core Principle

In an **external DB-driven architecture**, the mobile app consumes pre-aggregated data from `medicament_summary` (populated by the backend ETL pipeline). Tests should reflect this reality by using **raw SQL inserts/updates** instead of relying on generated companion types.

### Why SQL-First?

1. **No Build Runner Dependency:** Tests can run without `build_runner` generating companion types
2. **Matches Production:** Tests insert data the same way the backend pipeline does (via SQL)
3. **Type Safety:** SQL is explicit and doesn't require dynamic type workarounds
4. **Maintainability:** SQL changes are easier to track than generated code changes

### Pattern: Use `customInsert` / `customUpdate`

**✅ PREFERRED (SQL-First):**

```dart
// Insert medicament_summary using raw SQL
await database.customInsert(
  '''
  INSERT INTO medicament_summary (
    cis_code, nom_canonique, princeps_de_reference, is_princeps,
    group_id, member_type, principes_actifs_communs, formatted_dosage,
    is_hospital, is_narcotic, is_list1, is_otc, princeps_brand_name
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''',
  variables: [
    Variable.withString('12345678'),
    Variable.withString('Doliprane 500'),
    Variable.withString('Doliprane 500'),
    Variable.withBool(true),
    Variable.withString(''),  // NULL for standalone
    Variable.withInt(0),
    Variable.withString('[]'),
    Variable.withString(''),
    Variable.withBool(false),
    Variable.withBool(false),
    Variable.withBool(false),
    Variable.withBool(true),
    Variable.withString('Doliprane'),
  ],
  updates: {database.medicamentSummary},
);
```

**❌ AVOID (Companion Types - Only for Legacy Tests):**

```dart
// This requires build_runner and generated types
await database.into(database.medicamentSummary).insert(
  MedicamentSummaryCompanion.insert(
    cisCode: '12345678',
    nomCanonique: 'Doliprane 500',
    // ... many fields
  ),
);
```

### When to Use Each Approach

| Approach | Use Case | Example |
|----------|----------|---------|
| **SQL (`customInsert`)** | New tests, `medicament_summary` inserts, FTS5 index population | `test/core/database/sql_logic_test.dart` |
| **SQL (`customUpdate`)** | Updates to existing rows | `setPrincipeNormalizedForAllPrinciples()` |
| **Helper Functions** | Legacy tests that already use `IngestionBatch`, base table inserts | `test/core/database/search_engine_test.dart` |

### Example: Complete Test Setup

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('medicament_summary queries', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      // Populate medicament_summary using SQL
      await database.customInsert(
        'INSERT INTO medicament_summary (cis_code, nom_canonique, princeps_de_reference, is_princeps, is_otc) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('12345678'),
          Variable.withString('Doliprane 500'),
          Variable.withString('Doliprane 500'),
          Variable.withBool(true),
          Variable.withBool(true),
        ],
        updates: {database.medicamentSummary},
      );

      // Populate FTS5 search index
      await database.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('12345678'),
          Variable.withString(normalizeForSearch('Doliprane 500')),
          Variable.withString(normalizeForSearch('Doliprane')),
        ],
        updates: {database.searchIndex},
      );
    });

    test('queries medicament_summary correctly', () async {
      final results = await database.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('Doliprane'),
      );
      expect(results, isNotEmpty);
      expect(results.first.data.cisCode, '12345678');
    });
  });
}
```

### Handling Nullable Fields

For nullable TEXT columns, use empty string `''` (SQLite treats empty strings as NULL when appropriate):

```dart
Variable.withString(groupId ?? ''),  // NULL group_id for standalone
Variable.withString(formattedDosage ?? ''),  // NULL dosage
```

For nullable INTEGER/BOOLEAN columns, use appropriate defaults:

```dart
Variable.withInt(0),  // member_type default
Variable.withBool(false),  // is_hospital default
```

### FTS5 Virtual Tables

FTS5 virtual tables (like `search_index`) **must** use raw SQL inserts:

```dart
await database.customInsert(
  'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
  variables: [
    Variable.withString(cisCode),
    Variable.withString(normalizeForSearch(moleculeName)),
    Variable.withString(normalizeForSearch(brandName)),
  ],
  updates: {database.searchIndex},
);
```

### Legacy Helper Functions

The `buildXCompanion()` helper functions in `test/test_utils.dart` are **deprecated** and maintained only for backward compatibility with existing tests that use `IngestionBatch`.

**⚠️ Important:** These helpers require `build_runner` to generate companion types. They will fail at compile-time if `build_runner` hasn't been run.

**For all new tests, use SQL inserts instead.** If you must use helpers (e.g., migrating legacy tests), they return `dynamic` and require `// ignore: avoid_dynamic_calls` comments.

**Migration:** When refactoring tests that use helpers, replace them with `customInsert` calls following the SQL-first pattern above.

### Best Practices

1. **SQL-First:** Always prefer `customInsert`/`customUpdate` for new tests
2. **Explicit Columns:** List all columns explicitly in INSERT statements (don't rely on defaults)
3. **Variable Binding:** Always use `Variable.withString()` / `Variable.withBool()` / `Variable.withInt()` for parameters
4. **Updates Parameter:** Always include `updates: {database.tableName}` to notify Drift of changes
5. **Normalization:** Use `normalizeForSearch()` for FTS5 index values
6. **Test Isolation:** Each test should set up its own data (no shared state)

### Migration Path

When refactoring existing tests:

1. Identify tests using `MedicamentSummaryCompanion.insert()` or similar
2. Replace with `customInsert` using the SQL pattern above
3. Remove dependency on generated companion types
4. Update test to verify data consumption (querying) rather than data generation (aggregation)

---

## Integration Tests & The Golden Database

### Strategy: "Test Against Reality"

Instead of seeding integration tests with potentially outdated SQL strings, we use a **Golden Database** artifact.

*   **File:** `test/assets/golden.db`
*   **Source:** It is a copy of the actual `reference.db` generated by the backend pipeline.
*   **Benefits:**
    1.  **Schema Validation:** Guarantees the app code works with the *exact* SQLite file format delivered in production (indexes, views, triggers).
    2.  **Data Realism:** Tests run against real-world data complexity (accents, strange casing, null values).
    3.  **Performance:** FTS5 queries are tested against a realistic index size.

### Workflow: Synchronizing Test Assets

We use **VS Code Tasks** to automate the synchronization of the schema and the golden database.

**Task:** `sync:backend`

Run this task via `Cmd+Shift+P` -> `Tasks: Run Task` -> `sync:backend` whenever you modify the backend pipeline.

**What it does:**
1.  Copies `backend_pipeline/data/schema.sql` -> `lib/core/database/dbschema.drift`
2.  Copies `backend_pipeline/data/reference.db` -> `test/assets/golden.db`

### Usage in Tests

Use the helper `loadGoldenDatabase()` to instantiate the DB in integration tests:

```dart
import 'helpers/golden_db_helper.dart';

testWidgets('search works on real data', (tester) async {
  // 1. Load the golden artifact (copies it to a temp file to avoid locks)
  final db = await loadGoldenDatabase();

  // 2. Inject it
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MyApp(),
    ),
  );

  // 3. Assert
  await tester.enterText(find.byType(TextField), 'Doliprane');
  await tester.pumpAndSettle();
  expect(find.text('Paracétamol'), findsWidgets);

  await db.close();
});
```

---

## Unit Tests vs Integration Tests

### Unit Tests (`test/**/*.dart`)

- **Focus:** Individual functions, DAOs, providers
- **Database:** Use `AppDatabase.forTesting()` with in-memory SQLite
- **Data Setup:** SQL inserts or helper functions (SQL preferred)
- **Pattern:** Direct function calls, no UI rendering

### Integration Tests (`integration_test/**/*.dart`)

- **Focus:** End-to-end user flows
- **Database:** Use real database file or golden database
- **Data Setup:** Pre-populated database or SQL scripts
- **Pattern:** Robot pattern (Page Objects) for UI interactions

---

## References

- **SQL Schema:** `lib/core/database/dbschema.drift`
- **Example SQL Test:** `test/core/database/sql_logic_test.dart`
- **Example FTS5 Test:** `test/core/database/search/fts_ranking_test.dart`
- **Backend Pipeline:** `backend_pipeline/README.md` (for ETL logic reference)
