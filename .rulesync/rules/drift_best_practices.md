# Drift Best Practices (Q4 2025)

## 1. Context
Drift 2.14+ introduced `TableManager` and `RowManager` APIs, which significantly modernize how we interact with the database. These APIs replace manual `select`, `insert`, `update`, and `delete` boilerplate with generated, type-safe, fluent accessors.

## 2. The Golden Rule: Prefer Managers over Manual SQL
**Do not write manual CRUD methods.**
The generated `database.managers.tableName` provides everything you need for 90% of use cases.

### 🚫 Bad Pattern (Legacy)
```dart
Future<List<Product>> getProductsByCategory(String category) {
  return (select(products)..where((p) => p.category.equals(category))).get();
}
```

### ✅ Good Pattern (2025 Standard)
```dart
Future<List<Product>> getProductsByCategory(String category) {
  return db.managers.products.filter((f) => f.category.equals(category)).get();
}
```

## 3. Best Practices

### A. Prefetching (Killing N+1)
Always use `withReferences` when fetching data that has related tables you intend to use immediately. This performs a single optimized JOIN query.

```dart
// Fetch product with its associated manufacturer
final product = await db.managers.products
    .filter((f) => f.id(1))
    .withReferences((prefetch) => prefetch(manufacturer: true))
    .getSingle();
```

### B. Reactive Streams
Use `.watch()` on the manager chain to get an auto-updating stream that respects table invalidations.

```dart
Stream<List<Product>> watchAvailableProducts() {
  return db.managers.products
      .filter((f) => f.isAvailable(true))
      .watch();
}
```

### C. Inserts & Updates
Use the generated `create` and `update` methods to ensure type safety and leverage default values automatically.

**Insert:**
```dart
await db.managers.products.create((c) => c(
  name: 'Aspirin',
  price: 5.0,
));
```

**Update:**
```dart
await db.managers.products
    .filter((f) => f.id(1))
    .update((c) => c(price: 6.0));
```

### D. Ordering
Chain `.orderBy` for clear, readable sorting.

```dart
db.managers.products.orderBy((o) => o.name.asc() & o.price.desc()).get();
```

## 4. When to drop down to SQL?
Use the standard Drift Query Builder (e.g., `select(products).join(...)`) ONLY when:
1.  The query requires complex joins not supported by `withReferences`.
2.  You need to use specific SQL functions or aggregations not exposed by the Manager API.
3.  You are performing a highly specific sub-query or Common Table Expression (CTE).

In all standard DAO scenarios, `db.managers.*` is the default.
