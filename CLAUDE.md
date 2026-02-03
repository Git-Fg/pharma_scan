# CLAUDE.md

This file provides a quick reference for working with PharmaScan.

## Core Philosophy Documentation

**Important**: Before making changes to the explorer, scanner, or backend pipeline, read the core philosophy documentation:

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) | Data model, CIP/CIS hierarchy, form prioritization | Working with data structures |
| [`docs/EXPLORER_CORE_GOAL.md`](docs/EXPLORER_CORE_GOAL.md) | CIP naming goal, rangement philosophy, UX principles | Working on explorer/scanner |
| [`docs/REGEX_BRITTLENESS.md`](docs/REGEX_BRITTLENESS.md) | Why regex is brittle, composition-based solution | Working on backend pipeline |

**Key Principle**: For each CIP, we need both a **clean Brand name** (for rangement) and a **clean Generic name** (for therapeutic equivalence). The system prioritizes **pharmacy drawer forms** (oral solids/liquids, collyre, ORL, gynéco, dermato).

---

## Project Context

PharmaScan - French pharmaceutical scanning app using BDPM data for medication lookup.

**Architecture**: Thin Client Pattern
- **Backend** (`backend_pipeline/`): Parses BDPM data → `reference.db`
- **Frontend** (`lib/`): Downloads and queries `reference.db`

## Core Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter + shadcn_ui_flutter |
| State | Riverpod 3.1.x + Hooks + Signals |
| DB | Drift (SQLite) + FTS5 Trigram |
| Nav | AutoRoute 11.0.0 |
| Models | Dart Mappable + Extension Types |

## Dependency Management

**Current Versions (Flutter 3.38.9 / Dart 3.10.8):**

| Package | Current | Latest | Status |
|---------|---------|--------|--------|
| riverpod | 3.1.0 | 3.2.0 | ⚠️ Blocked by Flutter SDK |
| drift | 2.30.1 | 2.30.1 | ✅ Current |
| auto_route | 11.0.0 | 11.1.0 | ✅ Current |

**Known Limitation - Riverpod 3.2.0:** Requires `analyzer ^9.0.0`, but Flutter 3.38 pins `test_api 0.7.7` requiring `analyzer <9.0.0`.

## Quick Commands

```bash
# Using Make (recommended)
make build          # Build everything (default)
make test           # Run all tests
make check          # All quality gates (format + analyze + lint + test)
make help           # Show all available targets

# Backend
cd backend_pipeline
bun run preflight   # Full pipeline: download + build + export + audit
bun run build       # Generate reference.db + run tests
bun run export      # Generate Dart code from schema
```

## Schema-Driven Code Generation

The backend exports JSON contracts that generate type-safe Dart code:

```bash
# From backend_pipeline/
bun run export      # Generates:
#   - output/schema.json, output/types.json, output/queries.json
#   - lib/core/database/generated/generated_types.dart
#   - lib/core/database/generated/generated_queries.dart
#   - lib/core/database/reference_schema.drift
```

## Layer Structure

```
lib/
├── core/      # Shared infra (cannot import features)
├── features/  # Business domains (scanner, explorer, restock, home, settings)
└── app/       # Entry, router, theme
```

**Rule**: `core` cannot import `features` (enforced by lint).
**Rule**: `features` cannot import other `features`.

## Development Standards

- SOLID principles, Composition > Inheritance
- Null safety required, avoid `!` unless guaranteed non-null
- Exhaustive switch statements
- Const constructors everywhere
- 80 char line limit, 20 line function target
- Use `developer.log()` not `print()`

## Manual Verification Data

Use these CIP codes for testing without physical products:

| CIP | Product | Type |
|-----|---------|------|
| **3400935955838** | DOLIPRANE 1000 mg | Reference |
| **3400934809408** | DOLIPRANE 150 mg | Form Variant |
| **3400931863014** | SPASFON LYOC 80 mg | Reference |
| **3400930985830** | SPASFON (Injectable) | Form Variant |
| **3400930234259** | AMOXICILLINE KRKA 1 g | Generic |
| **3400949500963** | ALDARA 5% | Cream |

## Detailed Rules

Specialized rules are in `.agent/rules/` and `.claude/rules/`:

| Rule File | Topic |
|-----------|-------|
| `.claude/rules/architecture.md` | Extension Types, Riverpod, Dual SQLite |
| `.claude/rules/scanner.md` | GS1 DataMatrix parsing |
| `.claude/rules/flutter-ui.md` | Shadcn UI + A11Y |
| `.claude/rules/quality.md` | Testing patterns |
| `.claude/rules/backend.md` | Pipeline architecture |
