# Domain Logic Documentation

**Version:** 1.0.0  
**Status:** Source of Truth for PharmaScan Domain Logic  
**Context:** This document contains all PharmaScan-specific business logic, data structures, and domain knowledge.

This document consolidates domain-specific knowledge that was previously scattered across rule files and documentation. For architectural patterns and technical standards, see `docs/ARCHITECTURE.md`.

---

## 1. Glossary

This section defines key terms used throughout the PharmaScan project to ensure consistent vocabulary in code, documentation, and AI-generated content.

### Core Data Terms

#### Source of Truth

* **Definition:** The primary, authoritative data store for the application.
* **Implementation:** The local Drift database (`AppDatabase`), specifically the `medicament_summary` table (denormalized, pre-aggregated).
* **Usage:** All read queries in Explorer/Search MUST query this table. It is populated during Phase 2 of `DataInitializationService`.
* **Never:** Do not query staging tables (`medicaments`, `specialites`) directly in UI or business logic layers.

#### Canonical Name

* **Definition:** A normalized, cleaned version of a medication name produced by `normalizePrincipleOptimal`.
* **Process:** The logic applies knowledge-injected subtraction (removing known Salts like 'Chlorhydrate', 'Maléate', and Forms like 'Base', 'Anhydre').
* **Optimization:** Handles inverted formats (e.g., 'SODIUM (CHLORURE DE)') and preserves pure electrolytes.
* **Normalization:** Diacritic removal is performed using the `diacritic` package (`removeDiacritics()`) to ensure consistency across business logic, search indexing, and query processing.
* **Usage:** Used for grouping, searching, and display. The canonical name is deterministic and stable for the same raw input.

#### Fraction Thérapeutique (FT)

* **Definition:** The chemical "Base" of a medication, often linked to a salt (Substance Active).
* **Usage:** When present in `CIS_COMPO`, it **overrides** the Substance Active for display purposes.
* **Example:** Used to display "Metformine" (FT) instead of "Metformine Chlorhydrate" (SA).

#### Group & Clustering (Regroupement)

* **Definition:** A visual cluster of medications sharing the same active principle(s), even across different administrative groups.
* **Hybrid Strategy:**
  1. **Hard Link:** Uses Princeps CIS code to link generics to their reference.
  2. **Soft Link:** Uses `normalizeCommonPrincipes` to cluster groups with identical composition (e.g., merging 'Mémantine' and 'Mémantine Base').
* **Safety:** Includes a "Suspicious Data" check to prevent merging unrelated groups (e.g., Néfopam vs Adriblastine) if they accidentally share a raw string in the source.
* **BDPM Groups:** Groups are initially defined in the `group_members` table with relationships stored in the database. Clustering logic operates on these base groups to create visual clusters.

#### Standalone (Médicament hors groupe)

* **Definition:** A medication that does not belong to any generic group in the BDPM database.
* **Characteristics:**
  * Standalone medications have no associated group relationships.
  * They may be unique formulations, special medications, or entries that have not been grouped.
* **Handling:** Search logic MUST explicitly handle standalone medications by performing `LEFT JOIN` checks or union queries, as `MedicamentSummary` might be sparse.

#### Princeps

* **Definition:** The original brand-name medication, typically the first medication developed with a specific active principle.
* **Characteristics:**
  * A princeps medication may appear in multiple groups (as a "chameleon" medication).
  * Princeps status is determined by the BDPM data and stored in the `medicament_summary` table.
  * Business rule: princeps status in ANY group wins (hardened against chameleon medications).

#### Generic (Générique)

* **Definition:** A medication that is therapeutically equivalent to a princeps medication but sold under a different name or by a different manufacturer.
* **Characteristics:**
  * Generic medications share the same active principle as their princeps.
  * They are linked through the `group_members` table relationship.
* **Detection:** Use `group_members` table relationships only. Never infer via string matching.

#### CIS (Code Identifiant de Spécialité)

* **Definition:** An 8-digit code that uniquely identifies a medication specialty in the BDPM database.
* **Format:** 8 digits (e.g., `61876780`)
* **Usage:** Primary key for medication identification in the database.

#### CIP13 (Code Identifiant de Présentation)

* **Definition:** A 13-digit code that uniquely identifies a medication presentation (box) in the BDPM database.
* **Format:** 13 digits (e.g., `3400949497294`)
* **Usage:** Used for barcode scanning (DataMatrix) and price identification.

---

## 2. BDPM Data Pipeline (ETL)

The Base de Données Publique des Médicaments (BDPM) is the official French medication database maintained by ANSM (Agence Nationale de Sécurité du Médicament). This section documents the complete ETL (Extract, Transform, Load) pipeline.

### 2.1 Data Source

**URL:** `https://base-donnees-publique.medicaments.gouv.fr/telechargement.php`

**File Format:**

* **Encoding:** `ISO-8859-1` (Latin-1) or `Windows-1252`
* **Separator:** Tabulation (`\t`)
* **Delimiters:** None (no quotes)
* **NULL Values:** Empty string or consecutive tabs
* **Date Format:** `JJ/MM/AAAA` → Convert to `DATE (YYYY-MM-DD)`
* **Decimal Format:** Comma `,` (e.g., `12,50`) → Convert to `FLOAT` (`12.50`)

### 2.2 Pipeline Stages

#### Stage 1: Download and Cache

* Download BDPM TXT files from ANSM website
* Cache locally in `tool/data/` (reused if files already present)
* Handle download errors with fallback to cache

#### Stage 2: Sequential Parsing (Critical Order)

1. **Parse Conditions** (`CIS_CPD_bdpm.txt`)
   * Create mapping `Map<String, String> conditionsByCis`
   * Used during specialty parsing

2. **Parse MITM** (`CIS_MITM.txt`)
   * Create mapping `Map<String, String> mitmMap` (CIS → ATC)
   * Used during specialty parsing

3. **Parse Specialties** (`CIS_bdpm.txt`)
   * Filter homeopathic medications (BOIRON)
   * Enrich with conditions and ATC codes
   * Create `Set<String> seenCis` for validation

4. **Parse Medications** (`CIS_CIP_bdpm.txt`)
   * Depends on `seenCis` for CIS validation
   * Create mapping `Map<String, List<String>> cisToCip13`
   * **Critical:** This mapping is used for all subsequent steps

5. **Parse Compositions** (`CIS_COMPO_bdpm.txt`)
   * Depends on `cisToCip13` for valid CIS filtering
   * Replicate principles across all CIP13 of the CIS
   * **Deduplication Strategy:** Group composition rows by (CIS + Substance Code). If a row with type "FT" (Fraction Thérapeutique) exists for a given substance code, discard all rows with type "SA" (Substance Active) for that same substance code. This ensures FT (the chemical base) takes precedence over SA (the salt form) for display and grouping purposes.

6. **Parse Generics** (`CIS_GENER_bdpm.txt`)
   * Depends on `cisToCip13` and `medicamentCips` for validation
   * Create groups and relationships

7. **Parse Availability** (`CIS_CIP_Dispo_Spec.txt`)
   * Depends on `cisToCip13` for CIS → CIP13 expansion
   * Filter statuses (rupture/tension only)

#### Stage 3: Database Insertion

**Batch Insert:** All parsed data inserted in a single transaction:

* `Specialites`, `Medicaments`, `PrincipesActifs`
* `GeneriqueGroups`, `GroupMembers`
* `MedicamentAvailability`

**Reference:** `lib/core/database/daos/database_dao.dart`

#### Stage 4: Group Metadata Refinement

**Function:** `DatabaseDao.refineGroupMetadata()`

* Validate `princepsLabel` against type 0 members
* Clean `moleculeLabel`
* Improve metadata quality

#### Stage 5: SQL Aggregation

**Sequence:**

1. `DatabaseDao.populateSummaryTable()`
2. Transaction SQL:
   * Delete existing summaries
   * Insert grouped medications (`view_aggregated_grouped`)
   * Insert standalone medications (`view_aggregated_standalone`)

**Reference:** `lib/core/database/daos/database_dao.dart`

#### Stage 6: FTS5 Search Index

**Function:** `DatabaseDao.populateFts5Index()`

* Delete existing index
* Re-insert from `MedicamentSummary` with normalization

**Reference:** `lib/core/database/daos/database_dao.dart`

### 2.3 Error Handling

* Use `Either<ParseError, T>` for parsing (ROP - Railway Oriented Programming)
* Errors captured and logged via `LoggerService`
* Critical errors stop the pipeline; non-critical errors are logged and ignored

---

## 3. Normalization Logic

### 3.1 Principle Active Normalization

**Function:** `normalizePrincipleOptimal` (`lib/core/logic/sanitizer.dart`)

This function transforms raw active principle names into canonical names for grouping. It achieves **94.5% consistency** in principle grouping.

**Normalization Steps:**

1. **Base Normalization**
   * Remove diacritics (`removeDiacritics`)
   * Convert to uppercase
   * Remove "ACIDE" prefix

2. **Stereochemical Prefix Handling**
   * `(S)-LACTATE DE SODIUM` → `LACTATE DE SODIUM`
   * Pattern: `^\(([RS])\s*\)\s*-\s*(.+)$`

3. **Inverted Format Handling**
   * `SODIUM (VALPROATE DE)` → `VALPROATE`
   * `MÉMANTINE (CHLORHYDRATE DE)` → `MÉMANTINE`
   * Pattern: `^([A-Z0-9\-]+)\s*\(\s*([^()]+?)\s+DE\s*\)$`

4. **Pure Inorganic Salt Protection**
   * Protects: `MAGNESIUM`, `SODIUM`, `BICARBONATE DE SODIUM`, `CHLORURE DE POTASSIUM`
   * These names are returned as-is (no salt removal)

5. **Lexical Noise Removal**
   * Removes: `SOLUTION DE`, `CONCENTRAT DE`, `FORME PULVERULENTE`, `LIQUIDE`

6. **Molecular Core Extraction**
   * Uses PetitParser grammar (`buildMedicamentBaseNameParser()`)
   * Extracts base name ignoring variants

7. **Salt Prefix Removal**
   * Removes prefixes: `CHLORHYDRATE DE`, `SULFATE DE`, `MALÉATE DE`, etc.
   * **Reference:** `lib/core/constants/chemical_constants.dart`

8. **Controlled Mineral Removal**
   * Removes `DE SODIUM`, `DE POTASSIUM`, etc. only for organic molecules
   * Protects pure electrolytes (handled by step 4)

9. **Salt Suffix Removal**
   * Removes suffixes: `ARGININE`, `TOSILATE`, `BASE`, etc.
   * **Reference:** `lib/core/constants/chemical_constants.dart`

10. **Special Cases**
    * `OMEGA-3` / `OMEGA 3` → `OMEGA-3`
    * `CALCITONINE` variants → `CALCITONINE`
    * Orthographic corrections: `CARBOCYSTEINE` → `CARBOCISTEINE`

11. **Final Cleanup**
    * Remove terminal parentheses
    * Normalize multiple spaces
    * Remove trailing commas

**Example Transformations:**

| Input (Raw) | Output (Canonical) | Transformation |
| :--- | :--- | :--- |
| `CHLORHYDRATE DE METFORMINE` | `METFORMINE` | Salt prefix removal |
| `METFORMINE BASE` | `METFORMINE` | Base suffix removal |
| `SODIUM (VALPROATE DE)` | `VALPROATE` | Inverted format |
| `CHLORHYDRATE D'AMANTADINE` | `AMANTADINE` | Prefix with apostrophe |
| `BICARBONATE DE SODIUM` | `BICARBONATE DE SODIUM` | Protected (pure electrolyte) |
| `(S)-LACTATE DE SODIUM` | `LACTATE DE SODIUM` | Stereochemical prefix |
| `ACIDE TRANEXAMIQUE` | `TRANEXAMIQUE` | "ACIDE" removal |

---

## 4. Search Engine

### 4.1 FTS5 Implementation

**Virtual Table:** `search_index`

```sql
CREATE VIRTUAL TABLE search_index USING fts5(
  cis_code UNINDEXED,
  canonical_name,
  princeps_name,
  active_principles,
  tokenize='trigram'
);
```

**Columns:**

* `cis_code`: UNINDEXED (link to `MedicamentSummary`)
* `canonical_name`: Normalized canonical name
* `princeps_name`: Normalized princeps name
* `active_principles`: Concatenated normalized active principles

**Tokenization:** `trigram` enables fuzzy matching (typos, variations).

### 4.2 Normalization Function

**SQL Function:** `normalize_text`

Registered in `configureAppSQLite()` via the `diacritic` package:

1. Removes diacritics (`removeDiacritics`)
2. Converts to lowercase

**Usage:** All `search_index` columns are normalized via this function during insertion.

### 4.3 Query Normalization

User queries must be normalized using the same `diacritic` helper to match index content.

**Reference:** `CatalogDao._escapeFts5Query`

---

## 5. Scanning Logic

### 5.1 GS1 DataMatrix Parsing

PharmaScan supports scanning medication barcodes (DataMatrix) using GS1 standards.

**Format:** GS1 DataMatrix contains:

* Application Identifier (AI) codes
* Data fields (CIP13, batch number, expiry date, etc.)

**Parsing Rules:**

* Extract CIP13 from GS1 code
* Validate CIP13 format (13 digits)
* Lookup medication in database using CIP13

**Reference:** `lib/core/services/gs1_parser.dart`

---

## 6. Database Structure

### 6.1 Core Tables

#### `Specialites`

* **PK:** `cisCode` (Text, 8 digits)

* Stores specialty metadata (name, form, routes, etc.)

#### `Medicaments`

* **PK:** `codeCip` (Text, 13 digits)

* **FK:** `cisCode` → `Specialites`
* Stores presentation data (price, reimbursement, etc.)

#### `PrincipesActifs`

* **PK:** `id` (Int, auto-increment)

* **FK:** `codeCip` → `Medicaments`
* Stores active principles with normalization

#### `GeneriqueGroups`

* **PK:** `groupId` (Text)

* Stores generic group metadata

#### `GroupMembers`

* **PK:** `codeCip` (Text)

* **FK:** `groupId` → `GeneriqueGroups`
* Links medications to groups (type: 0=Princeps, 1=Generic)

#### `MedicamentAvailability`

* **PK:** `codeCip` (Text)

* Stores ANSM availability status (rupture, tension)

### 6.2 Aggregated Table

#### `MedicamentSummary`

* **PK:** `cisCode` (Text)

* Denormalized, pre-aggregated view for UI
* Populated via SQL views: `view_aggregated_grouped` and `view_aggregated_standalone`

**Key Columns:**

* `nomCanonique`: Canonical name (normalized)
* `isPrinceps`: Boolean (is princeps medication)
* `groupId`: Generic group ID (NULL for standalone)
* `principesActifsCommuns`: JSON array of common active principles
* `princepsDeReference`: Reference princeps name
* `priceMin` / `priceMax`: Price range for group
* Various regulatory flags (`isHospitalOnly`, `isList1`, `isList2`, etc.)

---

## 7. Analysis Tools

### 7.1 Python Scripts for BDPM Analysis

**Tool:** `tool/parser_lab.py` (via `uv run tool/parser_lab.py`)

**Purpose:**

* Generate JSON golden files for parsing validation
* Test normalization strategies
* Analyze grouping logic
* Validate data transformations

**Output Files:**

* `tool/data/golden_parsing_test.json` (line-level, by composition)
* `tool/data/golden_parsing_by_cis.json` (CIS-level, aggregated SA/FT segments)

**Usage:**

```bash
uv run tool/parser_lab.py
```

### 7.2 Golden Test Workflow

1. **Generate Golden Files:** Run `parser_lab.py` to generate JSON golden files
2. **Dart Golden Tests:**
   * `test/core/medicament_grammar_golden_test.dart` validates parsing logic
   * Filters entries with `parsing_mode == "strict"`
   * Applies `parseMoleculeSegment` to validate canonical name generation

**Rule:** Any modification to medication grammar (Python or Dart) must be accompanied by:

* Regeneration of JSON golden files via `parser_lab.py`
* Passing the corresponding Dart golden tests

---

## 8. File Structure Reference

### 8.1 BDPM Files

| File | Description | Frequency |
| :--- | :--- | :--- |
| `CIS_bdpm.txt` | Specialties (master table) | Daily |
| `CIS_CIP_bdpm.txt` | Presentations (boxes) | Daily |
| `CIS_COMPO_bdpm.txt` | Compositions (active principles) | Daily |
| `CIS_GENER_bdpm.txt` | Generic groups | Daily |
| `CIS_CPD_bdpm.txt` | Prescription conditions | Daily |
| `CIS_HAS_SMR_bdpm.txt` | HAS SMR evaluations | Daily |
| `CIS_HAS_ASMR_bdpm.txt` | HAS ASMR evaluations | Daily |
| `HAS_LiensPageCT_bdpm.txt` | HAS PDF links | Daily |
| `CIS_CIP_Dispo_Spec.txt` | Availability status | Real-time |
| `CIS_MITM.txt` | ATC codes | Irregular |
| `CIS_InfoImportantes.txt` | Important information | Irregular |

### 8.2 Key Implementation Files

* **Parser:** `lib/core/services/ingestion/bdpm_file_parser.dart`
* **Normalization:** `lib/core/logic/sanitizer.dart`
* **Constants:** `lib/core/constants/chemical_constants.dart`
* **Database:** `lib/core/database/daos/database_dao.dart`
* **Views:** `lib/core/database/views.drift`
* **Queries:** `lib/core/database/queries.drift`
* **GS1 Parser:** `lib/core/services/gs1_parser.dart`

---

## 9. UI/UX Domain Terms

### Adaptive Overlay

* **Definition:** A pattern for transitioning between different UI contexts (e.g., full screen to modal, modal to sheet) that adapts to screen size and device type.
* **Implementation:** Uses `showModalBottomSheet` or `showShadSheet` with `side: ShadSheetSide.bottom` on mobile, and may use `ShadDialog` or `ShadPopover` on larger screens.
* **Purpose:** Provides consistent user experience across device sizes while respecting platform conventions.

### Domain Entity

* **Definition:** A pure Dart class (using `dart_mappable`) that represents a business concept without database-specific annotations.
* **Characteristics:**
  * Immutable (all fields are `final`).
  * Uses standard Dart classes with `@MappableClass()` annotation and mixin.
  * No dependencies on Drift-generated classes.
  * Used throughout the application layers (UI, services, business logic).
* **Example:** `ScanResult`, `ClusterSummary`, `GenericGroupSummary`.

### Mapper

* **Definition:** A function, extension, or class that transforms database rows (Drift-generated classes) into Domain Entities.
* **Purpose:** Maintains separation between database layer and domain layer.
* **Location:** Typically defined as extensions on Domain Entities or as static methods in mapper classes.
* **Usage:** Services use mappers to convert `MedicamentRow` → `ScanResult` before exposing to UI.

---

## 10. Architecture Domain Terms

### Box Protocol

* **Definition:** The Flutter rendering rule: "Constraints go down, Sizes go up. Parent sets position."
* **Implication:** Infinite widgets (ListView, Column without bounds) cannot be placed directly in unbounded parents.
* **Solution:** Use `Expanded` or `Flexible` to break infinity in Flex layouts.
* **Prohibition:** Never use `IntrinsicHeight` or `IntrinsicWidth` in lists or frequently-rebuilt loops.

### Agnostic Component

* **Definition:** A reusable widget that does not make assumptions about its context (e.g., whether it's in a dialog, sheet, or full screen).
* **Characteristics:**
  * Does NOT contain `Scaffold`.
  * Does NOT call `Navigator.pop()` directly.
  * Exposes callbacks (`onClose`, `onConfirm`, `onSave`) for parent to handle navigation/actions.
* **Purpose:** Enables widget reuse across different UI contexts.

---

**Note:** For technical architecture patterns, see `docs/ARCHITECTURE.md`. For maintenance procedures, see `docs/MAINTENANCE.md`.

---

## 11. Logique de Rangement (Restock)

### Mode Rangement (Restock Mode)

* **Définition :** Un mode du scanner dédié à l'inventaire rapide ou à la réception de commande.
* **Comportement :** Le scan ne bloque pas la caméra (pas de popup). Il ajoute silencieusement le produit à une liste persistante (`RestockItems`) et émet une vibration de succès.
* **Dédoublonnage :** Scanner un produit déjà présent dans la liste incrémente sa quantité (`quantity + 1`) au lieu de créer une nouvelle ligne.

### Stratégies de Tri (Sorting Strategy)

La liste de rangement peut être triée selon deux axes, configurables dans les réglages globaux :

1. **Tri par Princeps (Défaut - "Tiroir Logic") :**

   * Les génériques sont classés sous la lettre de leur Princeps de référence.
   * *Exemple :* "Amoxicilline Biogaran" est classé à la lettre **C** (pour Clamoxyl).
   * **But :** Faciliter le rangement physique dans les pharmacies classées par molécules/princeps.

2. **Tri par Produit (Classique) :**

   * Les produits sont classés par leur nom commercial propre.
   * *Exemple :* "Amoxicilline Biogaran" est classé à la lettre **A**.

### Focus Princeps (UI Logic)

Une règle d'affichage prioritaire pour les génériques :

* Si un produit est un générique et que son princeps est connu, le nom du **Princeps** devient le titre principal (H4 Bold), et le nom réel du produit passe en sous-titre.
* Cette inversion hiérarchique vise à réduire la charge cognitive lors de la recherche du tiroir adéquat.
