---
paths:
  - "lib/core/**/*.dart"
  - "lib/features/**/*.dart"
---

# API Design Principles for PharmaScan

## User-Centric API Design

Design APIs from the perspective of the consumer:

```dart
// GOOD: Clear, intuitive API
final product = await catalogDao.getProductByCip(cip13);
print(product.name);

// BAD: Unclear purpose, verbose
final result = await dao.query('SELECT * FROM products WHERE cip = ?', [cip]);
```

## Documentation Requirements

All public APIs MUST have documentation:

```dart
/// Retrieves a product by its CIP-13 code.
///
/// Returns `null` if the product is not found.
///
/// Throws [DatabaseException] on connection errors.
Future<Product?> getProductByCip(Cip13 cip);
```

## Documentation Guidelines

- Start with single-sentence summary ending with period
- Blank line after summary
- Explain parameters, returns, exceptions
- Use `///` for doc comments
- No trailing comments in code

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `ProductDao`, `ScannerNotifier` |
| Functions | camelCase | `getProductByCip`, `parseBarcode` |
| Variables | camelCase | `scanResult`, `cipCode` |
| Constants | camelCase | `maxRetryCount`, `defaultTimeout` |
| Files | snake_case | `product_dao.dart`, `scanner_store.dart` |

## Function Design

- **Single purpose**: One function does one thing
- **Target**: <20 lines per function
- **Exhaustive**: Use switch expressions

```dart
ProductStatus status(Product product) => switch (product) {
      Product(:final isArchived) when isArchived => ProductStatus.archived,
      Product(:final stock) when stock > 0 => ProductStatus.inStock,
      _ => ProductStatus.outOfStock,
    };
```

## Error Handling

```dart
// Use specific exceptions
throw ProductNotFoundException(cip: cip);

// Never swallow errors silently
try {
  await database.save(product);
} on DatabaseException catch (e, s) {
  developer.log(
    'Failed to save product',
    error: e,
    stackTrace: s,
  );
  rethrow;
}
```

## References

- [Effective Dart](https://dart.dev/effective-dart)
