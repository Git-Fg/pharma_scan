# Relational Best of Both Worlds Implementation

**Date:** 2025-12-14  
**Status:** ✅ COMPLETE  
**Approach:** FK Constraints + Drift withReferences() API

---

## 🎯 Overview

This implementation enforces proper Foreign Key relationships in the backend SQLite schema, enabling Drift to auto-generate the `.withReferences()` API for type-safe relational queries.

---

## ✅ Phase 1: Backend Schema Alignment (Complete)

### 1.1 FK Constraints Added

| Table | FK Column | References | ON DELETE |
|-------|-----------|------------|-----------|
| `medicaments` | `cis_code` | `medicament_summary(cis_code)` | CASCADE |
| `medicament_availability` | `cip_code` | `medicaments(cip_code)` | CASCADE |
| `principes_actifs` | `cip_code` | `medicaments(cip_code)` | CASCADE |
| `group_members` | `cip_code` | `medicaments(cip_code)` | CASCADE |
| `group_members` | `group_id` | `generique_groups(group_id)` | CASCADE |
| `product_scan_cache` | `cip_code` | `medicaments(cip_code)` | CASCADE |
| `product_scan_cache` | `cis_code` | `medicament_summary(cis_code)` | CASCADE |
| `product_scan_cache` | `titulaire_id` | `laboratories(id)` | SET NULL |
| `safety_alerts` | `cis_code` | `specialites(cis_code)` | CASCADE |
| `medicament_summary` | `titulaire_id` | `laboratories(id)` | (none) |
| `medicament_summary` | `cluster_id` | `cluster_names(cluster_id)` | (none) |

### 1.2 FK Enforcement During ETL

Added `disableForeignKeys()` and `enableForeignKeys()` methods to `db.ts`:

```typescript
// Disable during bulk insert (allows out-of-order inserts)
db.disableForeignKeys();

// ... all inserts ...

// Re-enable and validate at the end
db.enableForeignKeys(); // Runs PRAGMA foreign_key_check
```

---

## ✅ Phase 2: Flutter Schema Sync (Complete)

### 2.1 Generated References

Drift auto-generated the following reference classes:

- `$ProductScanCacheReferences`
  - `.cipCode` → `$MedicamentsProcessedTableManager`
  - `.cisCode` → `$MedicamentSummaryProcessedTableManager`
  - `.titulaireId` → `$LaboratoriesProcessedTableManager?`

- `$MedicamentsReferences`
  - `.cisCode` → `$MedicamentSummaryProcessedTableManager`

- `$GroupMembersReferences`
  - `.cipCode` → `$MedicamentsProcessedTableManager`
  - `.groupId` → `$GeneriqueGroupsProcessedTableManager`

### 2.2 Prefetch Hooks

Drift generated typed prefetch hooks:

```dart
// Available on ProductScanCache manager
PrefetchHooks Function({bool cipCode, bool cisCode, bool titulaireId})
```

---

## ✅ Phase 3: Flutter Logic Refactoring (Complete)

### 3.1 CatalogDao.getProductByCip()

**Before (77 lines, 4-table JOIN, manual mapping):**
```dart
final rows = await customSelect('''
  SELECT ms.*, ls.name AS labName, m.prix_public...
  FROM medicament_summary ms
  INNER JOIN medicaments m ON ms.cis_code = m.cis_code
  LEFT JOIN laboratories ls ON ls.id = ms.titulaire_id
  LEFT JOIN medicament_availability ma ON ma.cip_code = m.cip_code
  WHERE m.cip_code = ?1
''').get();
// ... 50 lines of manual row mapping ...
```

**After (15 lines, single-table PK lookup, type-safe):**
```dart
final cache = await attachedDatabase.managers.productScanCache
    .filter((f) => f.cipCode.cipCode.equals(cipString))
    .getSingleOrNull();

return (
  summary: MedicamentEntity.fromProductCache(cache),
  cip: codeCip,
  price: cache.prixPublic,
  // ... all fields from denormalized cache ...
);
```

### 3.2 FK-Based Filtering

When a column has a FK constraint, Drift exposes it as a nested composer:

```dart
// OLD (before FK constraints)
.filter((f) => f.cipCode.equals(cipString))

// NEW (with FK constraints)  
.filter((f) => f.cipCode.cipCode.equals(cipString))
//              ^FK ref   ^actual column
```

### 3.3 Using withReferences() (Alternative Approach)

If we wanted to query `medicaments` directly with automatic JOIN:

```dart
final result = await db.managers.medicaments
    .filter((f) => f.cipCode.equals(cipString))
    .withReferences((prefetch) => prefetch(
          cisCode: true,  // Auto-JOIN medicament_summary
        ))
    .getSingleOrNull();

// Access joined data
final summary = result?.refs.cisCode;
```

---

## 📊 Results

### Generated Drift Classes

| Class | Purpose |
|-------|---------|
| `$ProductScanCacheReferences` | Access to related rows |
| `$ProductScanCacheFilterComposer` | Type-safe FK-based filtering |
| `$ProductScanCacheOrderingComposer` | Ordering through FKs |
| `$ProductScanCacheAnnotationComposer` | Annotation access |
| `$ProductScanCacheProcessedTableManager` | Full manager with prefetch |

### Performance Comparison

| Metric | Before | After |
|--------|--------|-------|
| Query Type | 4-table JOIN | Single PK lookup |
| Code Lines | 77 | 15 |
| Type Safety | Manual `row.read()` | Full type inference |
| FK Validation | Runtime | DB-enforced |

---

## 📁 Files Modified

### Backend (TypeScript)
- `backend_pipeline/src/db.ts`
  - Added FK constraints to multiple tables
  - Added `disableForeignKeys()` / `enableForeignKeys()` methods
- `backend_pipeline/src/index.ts`
  - Added FK disable/enable calls around ETL

### Flutter (Dart)
- `lib/core/database/daos/catalog_dao.dart`
  - Updated filter syntax for FK columns
  - Added missing required params to MedicamentSummaryData
- `lib/features/explorer/domain/entities/medicament_entity.dart`
  - Fixed imports

---

## 🔑 Key Learnings

### 1. FK Columns Become Nested Composers

When you add `REFERENCES`, Drift changes the filter API:
```dart
// No FK: f.column.equals(value)
// With FK: f.column.referencedColumn.equals(value)
```

### 2. ETL Order Matters

FK constraints require parent rows to exist before child rows. Solution:
```typescript
db.disableForeignKeys();
// insert in any order
db.enableForeignKeys(); // validates at end
```

### 3. PrefetchHooks Enable withReferences()

Drift auto-generates `PrefetchHooks` for every FK relationship:
```dart
PrefetchHooks Function({bool fkColumn1, bool fkColumn2})
```

---

## ✅ Checklist

- [x] Backend: `cip_code` and `cis_code` used consistently
- [x] Backend: `FOREIGN KEY` constraints added to `db.ts`
- [x] Backend: FK disable/enable for ETL order independence
- [x] Flutter: Schema synced and code regenerated
- [x] Flutter: `CatalogDao` uses proper FK-based filtering
- [x] Flutter: App compiles without errors
- [ ] Testing: Scanner verified (requires manual test)

---

**Status:** ✅ **IMPLEMENTATION COMPLETE**
