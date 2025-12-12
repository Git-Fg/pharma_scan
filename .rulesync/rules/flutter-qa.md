---
targets:
  - '*'
root: false
globs:
  - '**/*'
cursor:
  alwaysApply: true
  globs:
    - '**/*'
---
# QA & Testing (2025 Standard)

## Quality Gate (Run Before Every Commit)

```bash
dart fix --apply
dart analyze --fatal-infos --fatal-warnings
flutter test
```

**Auto-Fix Discipline:** If analyzer surfaces fixable warnings, run `dart fix --apply` (up to 3x) before manual review.

## SQL-First Testing for Data-Driven Tests

**Core Principle:** In an external DB-driven architecture, tests should use **raw SQL inserts/updates** (`customInsert`/`customUpdate`) instead of generated companion types. This matches production (backend ETL pipeline) and avoids `build_runner` dependency.

**✅ PREFERRED (SQL-First):**

```dart
// Insert medicament_summary using raw SQL
await database.customInsert(
  '''
  INSERT INTO medicament_summary (
    cis_code, nom_canonique, princeps_de_reference, is_princeps, is_otc
  ) VALUES (?, ?, ?, ?, ?)
  ''',
  variables: [
    Variable.withString('12345678'),
    Variable.withString('Doliprane 500'),
    Variable.withString('Doliprane 500'),
    Variable.withBool(true),
    Variable.withBool(true),
  ],
  updates: {database.medicamentSummary},
);
```

**❌ AVOID (Companion Types - Only for Legacy Tests):**

```dart
// Requires build_runner and generated types
await database.into(database.medicamentSummary).insert(
  MedicamentSummaryCompanion.insert(cisCode: '12345678', ...),
);
```

**Guidelines:**
- Use `customInsert`/`customUpdate` for all new tests involving `medicament_summary` or FTS5 tables
- For nullable TEXT fields, use empty string `''` (SQLite treats as NULL)
- Always include `updates: {database.tableName}` parameter
- Use `normalizeForSearch()` for FTS5 index values
- See `docs/TESTING.md` for complete patterns and examples

## Mocking Strategy

**Library:** `mocktail` exclusively (FORBIDDEN: `mockito`)

```dart
import 'package:mocktail/mocktail.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  late MockDatabaseService database;
  
  setUp(() {
    database = MockDatabaseService();
    registerFallbackValue(const ItemSummary());
  });
  
  test('returns empty list', () async {
    when(() => database.fetchItems()).thenAnswer((_) async => []);
    // ...
  });
}
```

## Interaction Patterns

1. **Unit/Widget Tests (`test/**/*.dart`):**
   - ✅ Use direct interactions: `tester.tap()`, `tester.pump()`, `find.byType()`, `find.byKey()`, `find.text(Strings.*)`.
   - ❌ Do not create Robot/PageObject classes for widget tests (overkill for solo dev).

2. **Integration Tests (`integration_test/**/*.dart`):**
   - ✅ Use Robot Pattern (Page Objects) to encapsulate multi-step user journeys and reduce fragility.

```dart
// ✅ Integration robot example
class ExplorerRobot {
  ExplorerRobot(this.tester);
  final WidgetTester tester;
  
  Future<void> searchFor(String term) async { /* ... */ }
  void expectResultCount(int count) { /* ... */ }
}
```

## String Literals Ban

**FORBIDDEN:** String literals in `find.text()`, `find.byTooltip()`, `find.bySemanticsLabel()`

**REQUIRED:** Use `Strings.*` constants

```dart
// ❌ FORBIDDEN
expect(find.text('Search'), findsOneWidget);

// ✅ REQUIRED
import 'package:your_app/core/utils/strings.dart';
expect(find.text(Strings.search), findsOneWidget);
```

## Layout Resilience Tests

```dart
testWidgets('adapts to narrow screen', (tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(MyWidget());
  expect(find.byType(MyWidget), findsOneWidget);
});

testWidgets('adapts to wide screen', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 800));
  await tester.pumpWidget(MyWidget());
  // Verify layout changes appropriately
});
```

## Anti-Patterns

- ❌ String literals in tests (use `Strings.*`)
- ❌ `mockito` (use `mocktail`)
- ❌ Over-engineering simple tests with Robots
- ✅ Robot pattern for complex flows
- ✅ Direct finders for simple tests
- ✅ `Strings.*` for all text expectations
