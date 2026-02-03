---
paths:
  - "lib/**/*.dart"
  - "test/**/*.dart"
---

# Architecture Rules for PharmaScan

## Overview

PharmaScan is a French pharmaceutical scanning app using **Thin Client Pattern**:
- **Backend** (`backend_pipeline/`): Parses BDPM data, generates `reference.db`
- **Frontend** (`lib/`): Dumb client that downloads and queries `reference.db`

## Layer Isolation

```
lib/
├── core/           # Shared infrastructure (can import nothing above)
│   ├── constants/  # App-wide constants
│   ├── database/   # Drift DAOs, schema, connection
│   ├── domain/     # Extension Types, semantic types, models
│   ├── providers/  # Global Riverpod providers (20+)
│   ├── services/   # Business services
│   ├── ui/         # Shared UI components, theme
│   └── widgets/    # Reusable widgets
├── features/       # Business domains (MUST NOT import other features)
│   ├── scanner/    # Barcode scanning + identification
│   ├── explorer/   # Database browsing + search
│   ├── restock/    # Inventory management
│   ├── home/       # Main screen + tabs
│   └── settings/   # App configuration
└── app/            # App entry, router, theme config
```

### Import Rules (Enforced by Lint)

| From | To | Allowed? |
|------|-----|----------|
| `features/` | `core/` | Yes |
| `features/` | `features/` | **No** |
| `core/` | `features/` | **No** |

**Imports flow**: `features` -> `core` -> nothing above

## State Management

### Riverpod Providers (Global State)

```dart
@riverpod
class ScannerNotifier extends _$ScannerNotifier {
  @override
  FutureOr<ScannerState> build() async { ... }
}
```

- Use `@riverpod` annotation for all global state
- Use `AsyncValue` for all async operations
- Use `AsyncValue.guard()` for safe async execution
- Prefix state classes with feature name (e.g., `ScannerState`, `RestockState`)

### Dart 3 Pattern Matching for AsyncValue (2026 Best Practice)

Use switch expressions for cleaner AsyncValue handling:

```dart
// Old pattern (still valid but verbose)
return asyncValue.when(
  data: (value) => DataWidget(value),
  error: (err, stack) => ErrorWidget(err),
  loading: () => LoadingWidget(),
);

// Modern Dart 3 pattern (recommended)
return switch (asyncValue) {
  AsyncData(:final value) => DataWidget(value),
  AsyncError(:final error) => ErrorWidget(error),
  _ => LoadingWidget(),
};

// With guards for specific error types
return switch (asyncValue) {
  AsyncData(:final value) => DataWidget(value),
  AsyncError(:final error) when error is NetworkException => NetworkErrorWidget(),
  AsyncError(:final error) => ErrorWidget(error),
  _ => LoadingWidget(),
};
```

### Signals (High-Frequency UI Only)

```dart
// scanner_bubbles.dart
final scanBubbles = <ScanBubble>[].signal();
```

Use Signals **only** for:
- Animations
- Scanner bubbles overlay
- Real-time UI updates (>60fps)

**Alternative:** Consider Riverpod's `select()` for many use cases:

```dart
// Instead of Signals for derived state
final itemCount = ref.watch(
  cartProvider.select((cart) => cart.items.length)
); // Only rebuilds when count changes

// Combine multiple providers efficiently
final totalPrice = ref.watch(
  cartProvider.select((cart) => 
    cart.items.fold(0, (sum, item) => sum + item.price)
  )
);
```

### Side Effects Pattern

Never mutate state for side effects (toasts, haptics, navigation). Use `StreamController.broadcast()`:

```dart
final _sideEffects = StreamController<ScannerSideEffect>.broadcast(sync: true);

Stream<ScannerSideEffect> get sideEffects => _sideEffects.stream;

void _emit(ScannerSideEffect effect) {
  if (_sideEffects.isClosed) return;
  _sideEffects.add(effect);
}
```

### Provider Lifecycle Management (Riverpod 3.x)

Use `ref.onDispose()` for resource cleanup:

```dart
@riverpod
Stream<ScanResult> scanStream(Ref ref) {
  final controller = StreamController<ScanResult>.broadcast();
  
  // Cleanup when provider is disposed
  ref.onDispose(() {
    controller.close();
    _logger.info('Scan stream disposed');
  });
  
  // Pause/resume support (Riverpod 3.x)
  ref.onCancel(() {
    _logger.info('Scan stream paused (no listeners)');
  });
  
  ref.onResume(() {
    _logger.info('Scan stream resumed');
  });
  
  return controller.stream;
}
```

### Ref.mounted and Auto-Retry (Riverpod 3.x)

Check if provider is still mounted before async operations:

```dart
@riverpod
class ProductNotifier extends _$ProductNotifier {
  @override
  Future<Product> build(String cip) async {
    // Automatic retry on failure (Riverpod 3.x)
    return AsyncValue.guard(() async {
      final dao = ref.read(catalogDaoProvider);
      return await dao.getProductByCip(Cip13.validated(cip));
    });
  }
  
  Future<void> refresh() async {
    // Check if still mounted before operation
    if (!ref.mounted) return;
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await ref.read(catalogDaoProvider).getProductByCip(
        Cip13.validated(cip),
      );
    });
  }
}
```

## Extension Types (Semantic IDs)

Use extension types to prevent mixing similar types:

```dart
/// CIP-13 code (13 digits) for presentations.
extension type Cip13(String _value) implements String {
  factory Cip13.validated(String value) {
    assert(value.length == 13, 'CIP code must be exactly 13 digits');
    return value as Cip13;
  }
}

/// CIS code (8 digits) for pharmaceutical specialties.
extension type CisCode(String _value) implements String {
  factory CisCode.validated(String value) {
    assert(value.length == 8, 'CIS code must be exactly 8 digits');
    return value as CisCode;
  }
}

/// Group identifier for generic clusters.
extension type GroupId(String _value) implements String {
  factory GroupId.validated(String value) {
    assert(value.isNotEmpty, 'Group ID cannot be empty');
    return value as GroupId;
  }
}

/// Cluster identifier for cluster-based search.
extension type ClusterId(String _value) implements String {
  factory ClusterId.validated(String value) {
    assert(value.isNotEmpty, 'Cluster ID cannot be empty');
    return value as ClusterId;
  }
}
```

### Validation Pattern

- Use `*.validated()` factory for runtime assertions
- Use `*.unsafe()` only for tests/edge cases
- All extension types `implements String` for seamless interoperability
- Use `@redeclare` when redeclaring members from supertypes (e.g., to add custom validation)

## Database Pattern

### Dual SQLite Databases

1. **`reference.db`**: Downloaded BDPM data (read-only)
2. **`user.db`**: Local user data (restock, history)

Connected via SQLite `ATTACH DATABASE` - DAOs query both transparently.

### Scanner Cache Table

Scanner uses denormalized `product_scan_cache` table for single-PK lookups (CIP-13).

## UI Theme

- Use `context.shadColors.*` - never direct colors (enforced by `avoid_direct_colors` lint)
- Brand colors in `lib/core/ui/theme/brand_colors.dart`

## Code Generation

- **NEVER edit `*.g.dart`, `*.drift.dart` files**
- Run: `dart run build_runner build --delete-conflicting-outputs`

## Logger Service

- `print()` is **BANNED** - use `LoggerService`
- Inject via `loggerProvider`

## References

- [Riverpod Documentation](https://riverpod.dev/docs/introduction/getting_started)
- [Riverpod 3.0 Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [Riverpod 3.2.0 Changelog - mounted, isPaused, weak listeners](https://pub.dev/packages/riverpod/changelog)
- [Dart Extension Types](https://dart.dev/language/extension-types)
- [Dart 3 Pattern Matching](https://dart.dev/language/patterns)
- [Flutter Architecture Blueprints](https://github.com/wcandillon/flutter-architecture-blueprints)
- [Riverpod Inversion of Control](https://levelup.gitconnected.com/riverpod-inversion-of-control-dependency-injection-dependency-inversion-and-service-locator-24a1c6972ed6)
