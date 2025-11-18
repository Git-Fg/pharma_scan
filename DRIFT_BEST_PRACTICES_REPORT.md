# Drift Best Practices Audit Report

This document identifies areas where the codebase can be improved to better align with Drift best practices for performance, security, and maintainability.

## Executive Summary

**Overall Status:** ⚠️ **Good Foundation, Needs Optimization**

The codebase demonstrates solid understanding of Drift fundamentals:
- ✅ Correct use of batch operations (automatic transactions)
- ✅ Good use of parameterized queries in most places
- ✅ Proper migration strategy
- ⚠️ **Missing indexes** on frequently queried columns (performance impact)
- ⚠️ **SQL injection risk** in LIKE clauses (security concern)
- ⚠️ **Query optimization opportunities** (multiple sequential queries)

---

## 1. CRITICAL: Missing Database Indexes

### Issue
The database schema lacks indexes on frequently queried columns, which can significantly impact query performance, especially as data volume grows.

### Impact
- **High**: Performance degradation on queries filtering by foreign keys or commonly searched columns
- Slow joins and WHERE clauses on `codeCip`, `cisCode`, `groupId`, etc.

### Current State
```dart
// No indexes defined on:
// - medicaments.cisCode (foreign key, frequently joined)
// - principes_actifs.codeCip (foreign key, frequently filtered)
// - group_members.groupId (frequently filtered/joined)
// - group_members.codeCip (foreign key)
// - medicament_summary.groupId (frequently filtered)
// - medicament_summary.clusterKey (frequently filtered)
```

### Recommendation
Add indexes using Drift's `@Index` annotation:

```dart
// lib/core/database/database.dart

class Medicaments extends Table {
  TextColumn get codeCip => text()();
  TextColumn get cisCode => text().references(Specialites, #cisCode)();

  @override
  Set<Column> get primaryKey => {codeCip};
}

// Add after class definition:
@TableIndex(
  name: 'idx_medicaments_cis_code',
  columns: {#cisCode},
)
class Medicaments extends Table {
  // ... existing code
}

class PrincipesActifs extends Table {
  // ... existing code
  
  @TableIndex(
    name: 'idx_principes_code_cip',
    columns: {#codeCip},
  )
  // ... rest of class
}

class GroupMembers extends Table {
  // ... existing code
  
  @TableIndex(
    name: 'idx_group_members_group_id',
    columns: {#groupId},
  )
  @TableIndex(
    name: 'idx_group_members_code_cip',
    columns: {#codeCip},
  )
  // ... rest of class
}

class MedicamentSummary extends Table {
  // ... existing code
  
  @TableIndex(
    name: 'idx_medicament_summary_group_id',
    columns: {#groupId},
  )
  @TableIndex(
    name: 'idx_medicament_summary_cluster_key',
    columns: {#clusterKey},
  )
  @TableIndex(
    name: 'idx_medicament_summary_forme_pharmaceutique',
    columns: {#formePharmaceutique},
  )
  @TableIndex(
    name: 'idx_medicament_summary_procedure_type',
    columns: {#procedureType},
  )
  // ... rest of class
}
```

### Migration Required
After adding indexes, increment schema version and add migration:

```dart
@override
int get schemaVersion => 8; // Increment from 7

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // ... existing migrations ...
      
      if (from < 8) {
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_medicaments_cis_code 
          ON medicaments(cis_code)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_principes_code_cip 
          ON principes_actifs(code_cip)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_group_members_group_id 
          ON group_members(group_id)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_group_members_code_cip 
          ON group_members(code_cip)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_medicament_summary_group_id 
          ON medicament_summary(group_id)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_medicament_summary_cluster_key 
          ON medicament_summary(cluster_key)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_medicament_summary_forme_pharmaceutique 
          ON medicament_summary(forme_pharmaceutique)
        ''');
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_medicament_summary_procedure_type 
          ON medicament_summary(procedure_type)
        ''');
      }
    },
  );
}
```

---

## 2. CRITICAL: SQL Injection Risk in LIKE Clauses

### Issue
String interpolation in LIKE clauses, even with quote escaping, is vulnerable and not following Drift best practices.

### Location
`lib/core/services/database_service.dart` lines 781, 795, 803

```dart
// ❌ CURRENT (VULNERABLE)
final formConditions = formKeywords
    .map((kw) => "forme_pharmaceutique LIKE '%${kw.replaceAll("'", "''")}%'")
    .join(' OR ');
```

### Problem
- Manual quote escaping is error-prone
- Doesn't handle all SQL injection vectors (e.g., Unicode, special characters)
- Not using Drift's parameterized query system

### Recommendation
Use Drift's parameterized queries with `Variable`:

```dart
// ✅ RECOMMENDED (SAFE)
Future<List<GenericGroupSummary>> getGenericGroupSummaries({
  List<String>? formKeywords,
  List<String>? excludeKeywords,
  List<String>? procedureTypeKeywords,
  int limit = 100,
  int offset = 0,
}) async {
  final conditions = <String>[];
  final variables = <Variable>[];

  if (procedureTypeKeywords != null && procedureTypeKeywords.isNotEmpty) {
    final subConditions = procedureTypeKeywords.map((kw) {
      variables.add(Variable.withString('%$kw%'));
      return 's.procedure_type LIKE ?';
    }).join(' OR ');
    
    conditions.add('''
      EXISTS (
        SELECT 1
        FROM specialites s
        WHERE s.cis_code = medicament_summary.cis_code
          AND ($subConditions)
      )
    ''');
  } else if (formKeywords != null && formKeywords.isNotEmpty) {
    final formConditions = formKeywords.map((kw) {
      variables.add(Variable.withString('%$kw%'));
      return 'forme_pharmaceutique LIKE ?';
    }).join(' OR ');
    
    conditions.add('($formConditions)');
    
    if (excludeKeywords?.isNotEmpty == true) {
      final excludeConditions = excludeKeywords!.map((kw) {
        variables.add(Variable.withString('%$kw%'));
        return 'forme_pharmaceutique NOT LIKE ?';
      }).join(' AND ');
      
      conditions.add('($excludeConditions)');
    }
  }

  final whereClause = conditions.isNotEmpty 
      ? 'WHERE ${conditions.join(' AND ')}'
      : '';

  variables.add(Variable.withInt(limit));
  variables.add(Variable.withInt(offset));

  final query = _db.customSelect(
    '''
    SELECT DISTINCT
      principes_actifs_communs as common_principes,
      princeps_de_reference,
      group_id
    FROM medicament_summary
    $whereClause
    ORDER BY nom_canonique
    LIMIT ? OFFSET ?
    ''',
    variables: variables,
    readsFrom: {_db.medicamentSummary},
  );

  // ... rest of method
}
```

---

## 3. Performance: Multiple Sequential Queries

### Issue
`getScanResultByCip()` performs 4-5 sequential database queries that could be optimized with a single joined query.

### Location
`lib/core/services/database_service.dart` lines 29-170

### Current Pattern
```dart
// ❌ Sequential queries (4-5 round trips)
final medicamentRow = await _db.select(_db.medicaments)...getSingleOrNull();
final summaryRow = await _db.select(_db.medicamentSummary)...getSingleOrNull();
final specialiteRow = await _db.select(_db.specialites)...getSingleOrNull();
final principesData = await _db.select(_db.principesActifs)...get();
final genericLabsRows = await _db.select(_db.specialites)...get(); // if needed
```

### Recommendation
Combine into a single query with joins:

```dart
// ✅ Single query with joins
Future<ScanResult?> getScanResultByCip(String codeCip) async {
  final query = _db.select(_db.medicaments).join([
    innerJoin(
      _db.specialites,
      _db.specialites.cisCode.equalsExp(_db.medicaments.cisCode),
    ),
    innerJoin(
      _db.medicamentSummary,
      _db.medicamentSummary.cisCode.equalsExp(_db.medicaments.cisCode),
    ),
  ])..where(_db.medicaments.codeCip.equals(codeCip));

  final result = await query.getSingleOrNull();
  if (result == null) return null;

  final medData = result.readTable(_db.medicaments);
  final specData = result.readTable(_db.specialites);
  final summaryData = result.readTable(_db.medicamentSummary);

  // Still need separate query for principes_actifs (1-to-many)
  final principesData = await _db.select(_db.principesActifs)
      ..where((tbl) => tbl.codeCip.equals(codeCip));
  final principes = await principesData.get();
  
  // ... rest of logic
}
```

**Performance Improvement:** Reduces 4-5 queries to 2 queries.

---

## 4. Transaction Management

### Current State: ✅ Good
Batch operations correctly use Drift's `batch()` method, which automatically wraps operations in transactions.

```dart
// ✅ CORRECT - batch() automatically uses transactions
await _db.batch((batch) {
  batch.insertAll(...);
  batch.insertAll(...);
});
```

### Recommendation
Consider explicit transactions for complex multi-step operations that combine batch and custom SQL:

```dart
// For operations that mix batch and custom SQL
await _db.transaction(() async {
  await _db.batch((batch) {
    // batch operations
  });
  
  await _db.customStatement('...');
  
  // More operations
});
```

**Current Status:** Not critical - batch operations are sufficient for current use cases.

---

## 5. Query Optimization: Use of CustomSelect

### Current State: ⚠️ Mixed
Custom SQL is used appropriately for complex queries, but some could benefit from Drift's type-safe query builders.

### Location
`lib/core/services/database_service.dart` - Multiple `customSelect` usages

### Analysis
- ✅ **Good Use**: Complex CTE queries (`getCommonPrincipesForGroups`, `findRelatedPrinceps`) - appropriate for custom SQL
- ✅ **Good Use**: Aggregations with GROUP BY in `getClusterSummaries`
- ⚠️ **Could Improve**: Simple queries that could use type-safe builders

### Recommendation
Keep custom SQL for complex queries, but prefer type-safe builders for simple selects:

```dart
// ✅ GOOD - Complex query, custom SQL is appropriate
await _db.customSelect(
  '''
  WITH member_counts AS (...)
  SELECT ...
  ''',
  // ...
);

// ⚠️ CONSIDER - Simple query, could use type-safe builder
// Instead of:
customSelect('SELECT * FROM medicament_summary WHERE cis_code = ?', ...)

// Prefer:
_db.select(_db.medicamentSummary)
  ..where((tbl) => tbl.cisCode.equals(cisCode));
```

**Current Status:** Acceptable - the balance between type safety and complexity is reasonable.

---

## 6. Schema Design

### Current State: ✅ Good
- Proper use of foreign keys
- Normalized schema design
- Appropriate use of nullable columns
- Good separation of concerns (staging tables vs. summary table)

### Recommendation
Consider adding check constraints for data integrity:

```dart
class GroupMembers extends Table {
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get groupId => text().references(GeneriqueGroups, #groupId)();
  IntColumn get type => integer()(); // 0 for princeps, 1 for generic

  @override
  Set<Column> get primaryKey => {codeCip};
  
  // Could add check constraint (requires custom migration)
  // CHECK (type IN (0, 1))
}
```

**Note:** SQLite check constraints require custom migrations. This is optional and depends on data integrity requirements.

---

## 7. Batch Insert Performance

### Current State: ✅ Good
Batch operations correctly use `InsertMode.replace` and are properly batched.

### Observation
```dart
// ✅ CORRECT - Using batch with replace mode
batch.insertAll(
  _db.specialites,
  specialites.map(...),
  mode: InsertMode.replace,
);
```

### Recommendation
Consider chunking very large batches (10,000+ rows) to avoid memory issues:

```dart
Future<void> insertBatchData({...}) async {
  const chunkSize = 5000;
  
  for (var i = 0; i < specialites.length; i += chunkSize) {
    final chunk = specialites.sublist(
      i,
      i + chunkSize > specialites.length ? specialites.length : i + chunkSize,
    );
    
    await _db.batch((batch) {
      batch.insertAll(
        _db.specialites,
        chunk.map(...),
        mode: InsertMode.replace,
      );
      // ... other tables
    });
  }
}
```

**Current Status:** Not critical unless experiencing memory issues with large datasets.

---

## Priority Recommendations

### 🔴 High Priority
1. **Add database indexes** (Section 1) - Significant performance improvement
2. **Fix SQL injection risk** (Section 2) - Security concern

### 🟡 Medium Priority
3. **Optimize sequential queries** (Section 3) - Performance improvement
4. **Consider check constraints** (Section 6) - Data integrity

### 🟢 Low Priority
5. **Refactor simple customSelect to type-safe builders** (Section 5) - Code maintainability
6. **Add chunking for large batches** (Section 7) - Scalability (if needed)

---

## Testing Recommendations

After implementing changes:

1. **Performance Testing:**
   - Benchmark queries before/after adding indexes
   - Measure query execution time for `getScanResultByCip`, `getGenericGroupSummaries`

2. **Security Testing:**
   - Test SQL injection vectors against parameterized LIKE queries
   - Verify no regression in filtering functionality

3. **Migration Testing:**
   - Test migration from schema version 7 to 8 (with indexes)
   - Verify indexes are created correctly
   - Test on empty and populated databases

---

## References

- [Drift Documentation - Indexes](https://drift.simonbinder.eu/docs/advanced-features/indexes/)
- [Drift Documentation - Custom SQL](https://drift.simonbinder.eu/docs/advanced-features/custom_sql/)
- [Drift Documentation - Transactions](https://drift.simonbinder.eu/docs/transactions/)
- [Drift Documentation - Migrations](https://drift.simonbinder.eu/docs/advanced-features/migrations/)

