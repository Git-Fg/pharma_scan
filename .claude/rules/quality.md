---
paths:
  - "**/*test.dart"
  - "lib/core/**/*"
  - "analysis_options.yaml"
---

# Quality Rules for PharmaScan

## Pre-Commit Checklist

Before every commit, run:

```bash
# 1. Format code (with CI exit flag)
dart format --set-exit-if-changed .

# 2. Apply fixes
dart fix --apply

# 3. Run analysis (with fatal warnings)
dart analyze --fatal-infos --fatal-warnings .

# 4. Run custom_lint for Riverpod-specific rules
dart run custom_lint

# 5. Run unit tests
flutter test
```

## Quality Gates

| Command | Purpose |
|---------|---------|
| `dart format .` | Format code to Dart style |
| `dart fix --apply` | Apply automatic fixes |
| `dart analyze` | Type checking and linting |
| `flutter test` | Run all tests |
| `bun test` | Run backend tests |

## Test Categories

### Unit Tests (`test/**/*.dart`)

Test single functions, methods, classes in isolation:

```dart
test('description', () {
  final result = myFunction(input);
  expect(result, expectedValue);
});
```

### Provider Tests

Use `ProviderContainer` for Riverpod testing (2026 Pattern):

```dart
// For modern Notifier pattern
test('ScannerNotifier builds', () async {
  final container = ProviderContainer(
    overrides: [
      catalogDaoProvider.overrideWithValue(mockCatalogDao),
    ],
  );
  
  // REQUIRED: Cleanup to prevent memory leaks
  addTearDown(container.dispose);
  
  // Read async provider
  final state = await container.read(scannerNotifierProvider.future);
  expect(state, isA<ScannerState>());
});

// Testing with listeners
test('Provider with listener', () {
  final container = ProviderContainer(
    overrides: [
      someProvider.overrideWithValue(mockValue),
    ],
  );
  addTearDown(container.dispose);
  
  final listener = Listener<AsyncValue<MyType>>();
  container.listen(
    someProvider,
    listener.call,
    fireImmediately: true,
  );
  
  verify(() => listener(null, const AsyncValue.loading())).called(1);
});
```

Widget tests with Riverpod:

```dart
testWidgets('Widget reads provider', (tester) async {
  await tester.pumpWidget(
    ProviderScope(child: MyWidget()),
  );
  expect(find.text('Hello'), findsOneWidget);
});
```

### DAO Tests

Use in-memory database for Drift tests:

```dart
late TestDatabase db;
setUp(() {
  db = TestDatabase();
});
tearDown(() async {
  await db.close();
});

test('Create and read user', () async {
  final id = await db.createUser('John');
  final user = await db.watchUser(id).first;
  expect(user.name, 'John');
});
```

### Mocking with Mocktail (REQUIRED Pattern)

Always register fallback values for custom types:

```dart
@Tags(['unit'])
void main() {
  setUpAll(() {
    // REQUIRED for any() with custom types
    registerFallbackValue(const ScanResult.empty());
    registerFallbackValue(Cip13.validated('3400000000000'));
  });
  
  group('CatalogDao', () {
    late CatalogDao mockDao;
    
    setUp(() {
      mockDao = MockCatalogDao();
    });
    
    test('scans product', () async {
      when(() => mockDao.getProductByCip(any()))
        .thenAnswer((_) async => ScanResult(
          cip: Cip13.validated('3400930011177'),
          name: 'Test Product',
        ));
      
      final result = await mockDao.getProductByCip(
        Cip13.validated('3400930011177')
      );
      expect(result.name, 'Test Product');
    });
  });
}
```

### Golden File Testing

```dart
@Tags(['golden'])
void main() {
  testWidgets('ProductCard matches golden', (tester) async {
    await tester.pumpWidget(
      ShadTheme(
        data: ShadThemeData(),
        child: ProductCard(
          product: testProduct,
        ),
      ),
    );
    
    await expectLater(
      find.byType(ProductCard),
      matchesGoldenFile('goldens/product_card.png'),
    );
  });
}
```

Run golden tests:
```bash
flutter test --tags golden --update-goldens  # Update snapshots
flutter test --tags golden                    # Verify against snapshots
```

### E2E Testing with Patrol

```dart
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('Full scan cycle', ($) async {
    await $.pumpWidgetAndSettle(PharmaScanApp());
    
    // Navigate to scanner
    await $(#scannerTab).tap();
    
    // Simulate scan (in real device test, uses actual camera)
    await $.pump();
    
    // Verify result displayed
    expect($('Product found'), findsOneWidget);
  });
}
```

### Test Tags

Separate test types with tags:

```dart
@Tags(['integration', 'slow'])
void main() { ... }
```

Run tagged tests:
```bash
flutter test --tags integration   # Run only integration tests
flutter test --tags '!slow'       # Exclude slow tests
```

## Analyzer Configuration (`analysis_options.yaml`)

```yaml
include: package:flutter_lints/flutter.yaml  # Use flutter.yaml instead of recommended.yaml

analyzer:
  plugins:
    - custom_lint  # REQUIRED for Riverpod projects
  exclude:
    - '**.g.dart'
    - '**.drift.dart'
    - '**.freezed.dart'  # If using freezed
  errors:
    unused_import: error
    deprecated_member_use: error
  language:
    strict-casts: true
    strict-inference: true  # REQUIRED for 2026 - catches implicit dynamic
    strict-raw-types: true

linter:
  rules:
    - avoid_print
    - prefer_single_quotes: true
    - always_use_package_imports: true

# Custom lint configuration (add to analysis_options.yaml)
custom_lint:
  rules:
    - missing_provider_scope: true
    - provider_parameters: true
    - avoid_public_notifier_properties: true
```

## Coverage Requirements

Generate coverage report:
```bash
flutter test --coverage

# Filter out generated files (REQUIRED for accurate metrics)
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  '**/*.drift.dart' \
  '**/*.freezed.dart' \
  'lib/generated/**' \
  'lib/**/generated/**' \
  -o coverage/lcov.info

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Enforce 80% threshold (optional - install dlcov)
dart pub global activate dlcov
dlcov -c 80 -i coverage/lcov.info
```

**Target**: 80%+ line coverage on core logic (not UI).

### Coverage Configuration

Create `coverage_exclusions.txt`:
```
lib/**/*.g.dart
lib/**/*.drift.dart
lib/**/*.freezed.dart
lib/generated/**
```

Create `dart_test.yaml` for test configuration:
```yaml
tags:
  golden:
    skip: false
  integration:
    timeout: 5m
  slow:
    timeout: 10m
```

## Dev Dependencies (pubspec.yaml)

Add these to `dev_dependencies`:
```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  riverpod_lint: ^3.1.2
```

## Testing Tools

| Tool | Purpose |
|------|---------|
| `flutter_test` | Widget and unit testing |
| `mocktail` | Mocking for Dart |
| `patrol` | E2E testing on real devices |
| `integration_test` | App-level integration tests |

## Backend Tests (`backend_pipeline/`)

```bash
cd backend_pipeline && bun test
```

Run with coverage:
```bash
bun test --coverage
```

## References

- [Flutter Testing Overview](https://docs.flutter.dev/testing/overview)
- [Riverpod Testing](https://riverpod.dev/docs/how_to/testing)
- [Drift Database Testing](https://drift.simonbinder.eu/testing/)
- [Dart Test Tags](https://pub.dev/packages/test)
