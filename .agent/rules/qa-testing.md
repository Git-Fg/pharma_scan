---
trigger: always_on
---

# QA & Testing Protocols

## 1. The Quality Gate

You are responsible for the build health. Run this sequence (stop immediately if any step fails):

```bash
dart run build_runner build --delete-conflicting-outputs
dart fix --apply
dart analyze --fatal-infos --fatal-warnings
flutter test
```

Whenever the analyzer surfaces auto-fixable warnings or errors, rerun `dart fix --apply` before launching another analysis or test pass.

## 2. Testing Strategy

* **Unit Tests:** Focus on logic in `lib/core/`.
  * *Crucial:* `data_driven_parser_test.dart` ensures the parser handles edge cases from the CSV.
* **Integration Tests:** Validate flows using real DB logic (Drift in-memory).
  * *Example:* `explorer_flow_test.dart`, `data_pipeline_test.dart`.
* **Updates:** If you change logic (e.g., `DatabaseService`), you MUST update the relevant integration test.

## 3. Test Data

* Use `tool/prepare_test_data.dart` to cache BDPM TXT files in `tool/data/` (shared cache directory, ignored by Git).
* Use `AppDatabase.forTesting(NativeDatabase.memory())` for isolation.
* **Mandatory:** Before asserting Explorer logic, you must run `populateMedicamentSummary()` helper in tests to hydrate the aggregated table.

## 4. Resilience Tests (Layout & Constraints)

**Mandate:** Encourage the addition of widget tests with specific size constraints to verify adaptability without overflow.

* **Layout Tests:** Test widgets in constrained environments (e.g., 400px width vs 1000px width) to ensure they adapt correctly.
* **Overflow Prevention:** Verify that widgets handle edge cases (long text, empty lists, null values) without causing overflow errors.

**Example Pattern:**

```dart
// ✅ RECOMMENDED: Test widget at different sizes
testWidgets('Widget adapts to narrow screen', (tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(MyWidget());
  expect(find.byType(MyWidget), findsOneWidget);
  // Verify no overflow errors
});

testWidgets('Widget adapts to wide screen', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 800));
  await tester.pumpWidget(MyWidget());
  expect(find.byType(MyWidget), findsOneWidget);
  // Verify layout changes appropriately
});
```

## 5. State Tests (AsyncValue Coverage)

**Mandate:** MUST test error (`AsyncError`) and loading (`AsyncLoading`) states in widget tests using Riverpod overrides.

* **Full Coverage:** Every widget consuming Riverpod providers MUST test all `AsyncValue` states:
  * `AsyncLoading`: Show loading indicator or skeleton
  * `AsyncData`: Display data correctly
  * `AsyncError`: Show error UI with appropriate messaging

**Example Pattern:**

```dart
// ✅ REQUIRED: Test all AsyncValue states
testWidgets('Widget handles loading state', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        medicamentsProvider.overrideWith((ref) => Stream.value([]).asyncMap(
          (data) async {
            await Future.delayed(Duration(seconds: 1));
            return AsyncLoading<List<Medicament>>();
          },
        ).first),
      ],
      child: MyWidget(),
    ),
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});

testWidgets('Widget handles error state', (tester) async {
  final error = Exception('Test error');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        medicamentsProvider.overrideWith(
          (ref) => Stream.value(AsyncError<List<Medicament>>(error, StackTrace.empty)),
        ),
      ],
      child: MyWidget(),
    ),
  );
  expect(find.text('Error: Test error'), findsOneWidget);
});

testWidgets('Widget displays data correctly', (tester) async {
  final medicaments = [Medicament(id: 1, name: 'Test')];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        medicamentsProvider.overrideWith(
          (ref) => Stream.value(AsyncData(medicaments)),
        ),
      ],
      child: MyWidget(),
    ),
  );
  expect(find.text('Test'), findsOneWidget);
});
```

## 6. The Robot Testing Pattern (Optional/Recommended)

* **When to Use:** Robot classes are **recommended** for complex, multi-step user flows that are reused across multiple tests. They help keep complex tests readable and maintainable.
* **When NOT to Use:** For simple unit/widget tests with straightforward interactions, **direct finders and actions are perfectly fine**. Don't over-engineer simple tests.
* **Solution (for complex flows):** Encapsulate finder/gesture logic inside Robot classes stored in `test/robots/`.
  * Constructor signature: `class ExplorerRobot { ExplorerRobot(this.tester); final WidgetTester tester; }`
  * Expose semantic actions: `Future<void> searchFor(String term)`, `void expectResultCount(int count)`.
* **Usage (complex flows):** Tests read like user stories: `final robot = ExplorerRobot(tester); await robot.searchFor('Doliprane'); robot.expectResultCount(3);`.
* **Direct Testing (simple tests):** For simple tests, **explicitly authorized** to use `await tester.tap(find.byKey(...))`, `find.text(...)`, `find.byType(...)`, etc. directly in test bodies. Keep it simple.

**Example - Simple Test (Direct Approach):**
```dart
// ✅ PERFECTLY FINE: Direct finders for simple tests
testWidgets('displays medication name', (tester) async {
  await tester.pumpWidget(MyWidget(medication: testMedication));
  expect(find.text('Doliprane'), findsOneWidget);
  await tester.tap(find.byKey(Key('details-button')));
  await tester.pumpAndSettle();
  expect(find.text('Details'), findsOneWidget);
});
```

**Example - Complex Flow (Robot Pattern):**
```dart
// ✅ RECOMMENDED: Robot for complex, reusable flows
testWidgets('full search and filter flow', (tester) async {
  final robot = ExplorerRobot(tester);
  await robot.searchFor('Doliprane');
  await robot.openFilterSheet();
  await robot.selectFilter('Generic');
  robot.expectResultCount(5);
});
```

## 7. Mocking Strategy (Mocktail Only)

* **Library:** Use `mocktail` everywhere. Do NOT reintroduce `mockito` or generated stubs.
* **Shared Setup:** Place reusable mock classes and `registerFallbackValue` helpers inside `test/mocks.dart`.
* **Pattern:**

```dart
class MockDatabaseService extends Mock implements DriftDatabaseService {}

void main() {
  late MockDatabaseService database;

  setUp(() {
    database = MockDatabaseService();
    registerFallbackValue(const MedicamentSummary());
  });

  test('returns empty list', () async {
    when(() => database.fetchSomething()).thenAnswer((_) async => []);
    // ...
  });
}
```

## 8. String Literals in Tests (Strict Ban)

* **Rule:** NEVER use string literals (e.g., `'Search'`, `'Error'`, `'Fermer'`) in `find.text()`, `find.byTooltip()`, or `find.bySemanticsLabel()` calls.
* **Requirement:** You MUST import `package:pharma_scan/core/utils/strings.dart` and use the `Strings.*` constants.
* **Dynamic Text:** If a test needs to verify a string with variables (e.g., "3 items", "Génériques (5)"), create a static helper method in `Strings` (e.g., `Strings.itemCount(3)`, `Strings.genericCount(5)`) and use it in both the UI and the test.
* **Rationale:** `Strings` class is the single source of truth for both UI and tests. This ensures tests automatically adapt to copy changes and prevents synchronization drift between UI and test expectations.

**Example Pattern:**

```dart
// ❌ FORBIDDEN: Hardcoded string literals in tests
expect(find.text('Rechercher'), findsOneWidget);
expect(find.byTooltip('Ouvrir les réglages'), findsOneWidget);
expect(find.text('Génériques (3)'), findsOneWidget);

// ✅ REQUIRED: Use Strings constants
import 'package:pharma_scan/core/utils/strings.dart';

expect(find.text(Strings.search), findsOneWidget);
expect(find.byTooltip(Strings.openSettings), findsOneWidget);
expect(find.text(Strings.genericCount(3)), findsOneWidget);

// ❌ FORBIDDEN: Manual string interpolation in tests
expect(find.text('CIP ${codeCip}'), findsOneWidget);

// ✅ REQUIRED: Use Strings helper or construct consistently
expect(find.text('${Strings.cip} ${codeCip}'), findsOneWidget);
```
