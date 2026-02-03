# CLAUDE.md (Backend Pipeline)

This file provides guidance for Claude Code when working with the `backend_pipeline/` TypeScript ETL.

## Role

**Elite TypeScript/Node.js ETL Engineer** specializing in pharmaceutical data pipelines.

---

## Architecture Overview

- **Input**: BDPM TSV files (Windows-1252 encoded)
- **Pipeline**: 7-phase sequential ETL
  1. Ingestion → 2. Profiling → 3. Election → 4. Clustering → 5. Naming → 6. Integration → 7. Schema Export
- **Output**:
  - SQLite `reference.db` (compressed to `reference.db.gz` for Flutter distribution)
  - JSON contracts (`schema.json`, `types.json`, `queries.json`)
  - Generated Dart code (`generated_types.dart`, `generated_queries.dart`, `dao_references.dart`)
- **Runtime**: Bun (`bun:sqlite`, `bun:test`)

---

## Quick Commands

**Using Make (from project root)**:
| Command | Purpose |
|---------|---------|
| `make preflight` | Full backend pipeline: download + build + export + audit |
| `make backend` | Build backend pipeline only |
| `make backend-test` | Run backend tests |
| `make backend-export` | Export schema + generate Dart code |

**Direct Bun commands** (from `backend_pipeline/`):
| Command | Purpose |
|---------|---------|
| `bun run preflight` | Full pipeline: download + build + export + audit |
| `bun run build` | Generate `reference.db` + run tests |
| `bun test` | Run all tests |
| `bun run download` | Fetch fresh BDPM data files |
| `bun run export` | Sync schema to Flutter Drift files |
| `bun run tool` | Run data audit tools |
| `bun run metrics` | Get pipeline metrics |

---

## Pipeline Phases

### 1. Ingestion (`01_ingestion.ts`)
- Parse BDPM TSV files with Windows-1252 encoding
- Detect and filter homeopathy (BOIRON, LEHNING, WELEDA labs)
- Handle "ghost CIS" (CIS in GENER but not SPECIALITE)

### 2. Profiling (`02_profiling.ts`)
- Extract active substances and dosages
- Compute chemical IDs for clustering
- Resolve FT>SA conflicts (forme thérapeutique → substance active)

### 3. Election (`03_election.ts`)
- Select princeps reference for each generic group
- Handle multi-presentation groups

### 4. Clustering (`04_clustering.ts`)
- Group medications by shared active substances
- Build super-clusters via chemical ID similarity

### 5. Naming (`05_naming.ts`)
- Generate canonical cluster names using LCS algorithm
- Longest Common Substring for substance naming

### 6. Integration (`06_integration.ts`)
- Attach orphan CIS to clusters
- Create FTS5 search index with trigram tokenizer
- Persist to SQLite with chunked inserts

### 7. Schema Export (`07_export_schema.ts`)
- Export database schema as JSON contract
- Generate type-safe Dart code for Flutter
- Extract tables, columns, indexes, foreign keys using PRAGMA
- Write `schema.json`, `types.json`, `queries.json`

---

## Type Safety Rules

- **No `any`**: Use Zod schemas for input validation
- **Branded types**: `CisId` (8 chars), `Cip13` (13 chars), `GroupId`, `ClusterId`
- **No `console.log`**: Use structured logging with phase prefixes

---

## Database Rules

- **Schema sync**: Run `bun run export` after any `src/db.ts` schema change
- **FTS5 trigram**: Search vector built via `buildSearchVector()` in `utils.ts`
- **Chunked inserts**: Max 2000 rows per transaction (SQLite limit)
- **STRICT tables**: All tables use SQLite STRICT mode
- **Attached DB**: Frontend uses SQLite `ATTACH DATABASE` pattern

---

## Validation Thresholds

| Check | Expected Range |
|-------|---------------|
| Homeopathy rate | 5-15% |
| Active princeps rate | > 70% |
| Orphan attachment | > 1000 |
| Ghost CIS | < 3000 |
| Unique chemicalIds | 2000-3000 |

---

## Key Files

| Path | Purpose |
|------|---------|
| `src/index.ts` | Pipeline orchestrator (7 phases) |
| `src/db.ts` | SQLite schema, chunked inserts, Drizzle |
| `src/types.ts` | Zod schemas, branded ID types |
| `src/sanitizer.ts` | Salt stripping, normalization |
| `src/constants.ts` | Salt prefixes/suffixes |
| `src/utils.ts` | `streamBdpmFile()`, `buildSearchVector()` |
| `src/pipeline/01_ingestion.ts` - `07_export_schema.ts` | Pipeline phases |
| `src/codegen/dart_generator.ts` | Generate Dart types from JSON |
| `src/codegen/dao_generator.ts` | Generate DAO reference implementations |
| `src/codegen/export_dart.ts` | Unified export orchestrator |
| `test/integrity.test.ts` | Data quality gate tests |
| `test/golden_salts.test.ts` | Salt sanitization golden masters |

---

## Frontend Sync

**Schema-Driven Code Generation**:
- JSON contracts exported to `output/` directory
- Dart code generated to `lib/core/database/generated/`
- Drift schema updated to `lib/core/database/reference_schema.drift`
- Database artifacts synced to `assets/` (test and app)

**Generated Files**:
| File | Purpose |
|------|---------|
| `generated_types.dart` | Type constants (`kBrandedTypes`, `kColumnExtensionTypes`) |
| `generated_queries.dart` | QueryContract definitions (`kExplorerQueryContracts`) |
| `dao_references.dart` | Reference implementations (copy to manual DAOs) |

**Commands**:
```bash
# From project root (using Make)
make backend-export   # Full export (JSON + Dart + schema + artifacts)
make export-json      # JSON contracts only

# From backend_pipeline/ (direct Bun)
bun run export        # Full export (JSON + Dart + schema + artifacts)
bun run export:json   # JSON contracts only
bun run export:schema # Legacy schema dump (deprecated, use export instead)
```

**When to Run**:
- After any schema change in `src/db.ts`
- After adding/modifying query contracts in `07_export_schema.ts`
- After updating type definitions

---

## Code Standards

- Use `bun:sqlite` for native performance
- Stream large files with `streamBdpmFile()`
- All validation via Zod schemas
- Named exports for all functions
- Strict typing on all data transformations
