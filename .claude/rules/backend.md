---
paths:
  - "backend_pipeline/**/*"
  - "assets/database/**/*"
---

# Backend Pipeline Rules for PharmaScan

## Project Context

The backend pipeline processes French BDPM (Base de Données des Medicaments) data to generate a SQLite reference database for the Flutter frontend. It uses Bun runtime with Drizzle ORM and TypeScript.

- **Input**: BDPM TSV files (Windows-1252 encoded) from ANSM
- **Output**: `reference.db` (compressed to `reference.db.gz` for Flutter)
- **Runtime**: Bun (`bun:sqlite`, `drizzle-orm`, `zod`)
- **Tests**: `bun test`

## Directory Structure

```
backend_pipeline/
├── src/
│   ├── index.ts              # Pipeline orchestrator (7 phases)
│   ├── db.ts                 # SQLite schema, Drizzle integration
│   ├── types.ts              # Zod schemas, branded types
│   ├── sanitizer.ts          # Salt stripping, text normalization
│   ├── constants.ts          # Salt prefixes/suffixes
│   ├── utils.ts              # streamBdpmFile(), buildSearchVector()
│   ├── codegen/              # **NEW: Dart code generation**
│   │   ├── export_dart.ts    # Unified export orchestrator
│   │   ├── dart_generator.ts # Generate Dart types/queries
│   │   ├── dao_generator.ts  # Generate DAO references
│   │   └── utils.ts          # Code generation utilities
│   └── pipeline/
│       ├── 01_ingestion.ts   # Parse BDPM TSV files
│       ├── 02_profiling.ts   # Extract active substances, chemical IDs
│       ├── 03_election.ts    # Select princeps reference per group
│       ├── 04_clustering.ts  # Group by active substances
│       ├── 05_naming.ts      # LCS-based cluster naming
│       ├── 06_integration.ts # FTS5 index, UI tables
│       └── 07_export_schema.ts # **NEW: Export JSON contracts**
├── tool/
│   ├── audit_data.ts         # Data quality audit
│   ├── get_metrics.ts        # Pipeline metrics
│   └── export_missing_cis.ts # CIS export utility
├── test/
│   ├── integrity.test.ts     # Data quality gate tests
│   ├── sanitizer.test.ts     # Salt sanitization tests
│   └── safety_alerts.test.ts # Alert validation
├── scripts/
│   ├── download_bdpm.ts      # Fetch BDPM files from ANSM
│   └── dump_schema.sh        # **DEPRECATED: Use bun run export instead**
├── drizzle.config.ts         # Drizzle configuration
├── package.json              # Dependencies: drizzle-orm, zod, bun-sqlite
└── output/                   # Generated reference.db + JSON exports
```

## Pipeline Stages

### 1. Ingestion (`01_ingestion.ts`)
- Parse BDPM TSV files with **Windows-1252 encoding**
- Filter homeopathy by lab names (BOIRON, LEHNING, WELEDA)
- Handle "ghost CIS" (CIS in GENER but not SPECIALITE)
- Output: `cisData`, `cipData`, `generData`

### 2. Profiling (`02_profiling.ts`)
- Extract active substances and dosages via `sanitizer.ts`
- Compute **chemical IDs** for clustering
- Resolve FT>SA conflicts (forme therapeutique → substance active)
- Output: `profiles` (Map<CIS, substances>)

### 3. Election (`03_election.ts`)
- Select princeps reference for each generic group
- Handle multi-presentation groups
- Output: `elections` (Map<groupId, princepsCIS>)

### 4. Clustering (`04_clustering.ts`)
- Group medications by **shared active substances**
- Build **super-clusters** via chemical ID similarity
- Output: `superClusters` (clustered CIS groups)

### 5. Naming (`05_naming.ts`)
- Generate canonical cluster names using **LCS algorithm**
- Longest Common Substring for substance naming
- Output: `namedClusters` (with displayName, search_vector)

### 6. Integration (`06_integration.ts`)
- Attach orphan CIS to clusters
- Create **FTS5 trigram search index**
- Persist to SQLite with chunked inserts
- Output: `finalClusters`, `orphansAttached`

### 7. Schema Export (`07_export_schema.ts`) **NEW**
- Export database schema as JSON contracts
- Extract tables, columns, indexes, foreign keys via PRAGMA
- Output: `schema.json`, `types.json`, `queries.json`

## Code Generation System **NEW**

### Architecture
The backend now exports JSON contracts that generate type-safe Dart code for Flutter:

```
Backend (TypeScript)              Frontend (Dart)
====================              ==============
07_export_schema.ts    ->       schema.json
                          ->       types.json
                          ->       queries.json

dart_generator.ts       ->       generated_types.dart
dao_generator.ts        ->       generated_queries.dart
                         ->       dao_references.dart
```

### Generated Files

| Backend Output | Flutter Generated | Purpose |
|----------------|-------------------|---------|
| `output/schema.json` | - | Tables, columns, indexes, foreign keys |
| `output/types.json` | `generated_types.dart` | Type constants, extension type mappings |
| `output/queries.json` | `generated_queries.dart` | QueryContract definitions |
| - | `dao_references.dart` | Reference implementations |

### Usage

```bash
# From backend_pipeline/
bun run export          # Full export (JSON + Dart + schema + artifacts)
bun run export:json     # JSON contracts only
bun run export:schema   # Legacy schema dump (deprecated)
```

### Type Constants Example

```dart
// Auto-generated from backend/types.json
const Map<String, String> kColumnExtensionTypes = {
  'cis_code': 'CisId',
  'cip_code': 'Cip13',
  'group_id': 'GroupId',
  'cluster_id': 'ClusterId',
};
```

### Query Contracts Example

```dart
// Auto-generated from backend/queries.json
const List<QueryContract> kExplorerQueryContracts = [
  QueryContract(
    name: 'watchClusters',
    description: 'Search clusters using FTS5 trigram',
    returnType: 'Stream<List<ClusterEntity>>',
    sql: '''SELECT * FROM cluster_index ORDER BY title ASC LIMIT 100''',
  ),
];
```

## Database Schema

**Core Tables** (defined in `src/db.ts`):

| Table | Purpose |
|-------|---------|
| `specialites` | Raw BDPM medication data |
| `medicaments` | Product presentations (CIP codes) |
| `medicament_summary` | Denormalized medication info |
| `cluster_names` | Cluster metadata with princeps reference |
| `cluster_index` | UI-ready cluster listings |
| `generique_groups` | Generic group definitions |
| `group_members` | CIP-to-group mappings |
| `product_scan_cache` | Denormalized scanner cache |
| `search_index` | FTS5 trigram virtual table |

**Key Patterns**:
- All tables use **SQLite STRICT mode**
- Chunked inserts with max **2000 rows** per transaction
- `PRAGMA foreign_keys = ON/OFF` for batch operations
- FTS5 trigram tokenizer for fuzzy search

**Performance PRAGMAs (2026 Best Practice):**

Add to `ReferenceDatabase` constructor in `src/db.ts`:

```typescript
// WAL mode for better concurrency and performance
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

  // Memory optimization
PRAGMA cache_size = 10000;  // ~40MB page cache
PRAGMA temp_store = MEMORY;
PRAGMA mmap_size = 2147483648;  // 2GB - safer allocation (2026 best practice)
PRAGMA page_size = 4096;  // Align with SSD block size
PRAGMA busy_timeout = 5000;  // Handle lock contention gracefully
PRAGMA auto_vacuum = INCREMENTAL;  // Space management

// Query optimization
PRAGMA optimize;

// Post-pipeline maintenance (run after bulk inserts)
VACUUM;
ANALYZE;
INSERT INTO search_index(search_index) VALUES('optimize');  // Optimize FTS5
```

## Branded Types (Zod 4.x Pattern)

Use Zod `.brand()` for compile-time type safety:

```typescript
// From src/types.ts - Zod 4.x implementation
export const CisIdSchema = z.string().length(8).brand("CisId");
export type CisId = z.infer<typeof CisIdSchema>;

export const Cip13Schema = z.string().length(13).brand("Cip13");
export type Cip13 = z.infer<typeof Cip13Schema>;

export const GroupIdSchema = z.string().min(1).brand("GroupId");
export type GroupId = z.infer<typeof GroupIdSchema>;

export const ClusterIdSchema = z.string().min(1).brand("ClusterId");
export type ClusterId = z.infer<typeof ClusterIdSchema>;

export const ChemicalIdSchema = z.string().min(1).brand("ChemicalId");
export type ChemicalId = z.infer<typeof ChemicalIdSchema>;

// Usage with validation
const cisCode = CisIdSchema.parse("60131710"); // ✓ Valid
const invalid = CisIdSchema.parse("123");      // ✗ Throws ZodError
```

## Key Utilities

| Function | Location | Purpose |
|----------|----------|---------|
| `streamBdpmFile()` | `utils.ts` | Stream large TSV files |
| `buildSearchVector()` | `utils.ts` | Build FTS5 search vector |
| `normalizeForSearch()` | `sanitizer.ts` | Strip salts, normalize text |
| `normalizeIngredient()` | `sanitizer.ts` | Extract active ingredient |

## Running the Pipeline

```bash
# Full pipeline: download + build + export + audit
cd backend_pipeline && bun run preflight

# Or step by step:
bun run download      # Fetch BDPM files
bun run build         # Run 6-phase pipeline + tests
bun run export        # Sync schema to Flutter Drift
bun run tool          # Run data audit
bun run metrics       # Get pipeline metrics
```

## Validation Thresholds

| Check | Expected Range |
|-------|---------------|
| Homeopathy rate | 5-15% |
| Active princeps rate | > 70% |
| Orphan attachment | > 1000 |
| Ghost CIS | < 3000 |
| Unique chemical IDs | 2000-3000 |

## Dependencies

```json
{
  "dependencies": {
    "drizzle-orm": "^0.45.1",
    "zod": "^4.2.1",
    "iconv-lite": "^0.7.1"
    // NOTE: bun-sqlite-generate removed - package doesn't exist in npm registry
  },
  "devDependencies": {
    "@types/bun": "latest",
    "drizzle-kit": "^0.31.8"
  }
}
```

## Code Standards

- **No `any`**: Use Zod schemas for input validation
- **No `console.log`**: Use structured logging with phase prefixes
- **Named exports**: All functions must be exported
- **Bun SQLite**: Use `bun:sqlite` for native performance
- **Stream large files**: Use `streamBdpmFile()` for BDPM files
- **Chunked inserts**: Max 2000 rows per transaction

## Frontend Sync

### Unified Export Command
```bash
bun run export  # Generates JSON + Dart + schema + syncs artifacts
```

### What Gets Generated

1. **JSON Contracts** (`output/`):
   - `schema.json` - Database schema (tables, columns, indexes, foreign keys)
   - `types.json` - Branded types, entity definitions
   - `queries.json` - Query contracts for DAOs

2. **Dart Code** (`lib/core/database/generated/`):
   - `generated_types.dart` - Type constants (`kBrandedTypes`, `kColumnExtensionTypes`)
   - `generated_queries.dart` - QueryContract definitions (`kExplorerQueryContracts`)
   - `dao_references.dart` - Reference implementations (copy to manual DAOs)

3. **Drift Schema** (`lib/core/database/`):
   - `reference_schema.drift` - SQL DDL for reference tables

4. **Database Artifacts** (`assets/`):
   - `test/reference.db` - Uncompressed for testing
   - `database/reference.db.gz` - Compressed for app distribution

### When to Run

- After any schema change in `src/db.ts`
- After adding/modifying query contracts in `07_export_schema.ts`
- After updating type definitions

### Legacy Command (Deprecated)
```bash
bun run export:schema  # Old dump_schema.sh - use 'bun run export' instead
```

## References

- [BDPM Data ANSM](https://www.data.gouv.fr/fr/datasets/base-de-donnees-publique-des-medicaments/)
- [BDPM Tools GitHub](https://github.com/TinyMan/bdpm-tools)
- [Drizzle ORM](https://drizzle.dev/)
- [Bun Runtime](https://bun.sh/docs/runtime)
