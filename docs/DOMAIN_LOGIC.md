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

### 2.1 Schema Layer (BDPM Schema)

* **Location:** `lib/core/services/ingestion/schema/`
* **Content:** `bdpm_parsers.dart` (locale-safe primitives for dates, decimals, booleans).
* **Usage:** Ingestion parsers now stream BDPM rows directly into Drift `Companion` objects; column positions are documented in each parser. When ANSM updates a TXT layout, adjust the column offsets in the corresponding parser.

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

## 3. Stratégie de Parsing (Hybrid Relational)

### 3.1 Philosophie : "La Base avant le Texte"

Au lieu de parser les libellés textuels complexes (et sales) des groupes génériques, nous privilégions la structure relationnelle de la BDPM.

**L'algorithme des 3 Tiers :**

1. **Tier 1 (Relationnel - Prioritaire) :**

    * On identifie le Princeps (Type 0) du groupe.
    * On joint avec `CIS_COMPO` : Si une ligne `FT` (Fraction Thérapeutique) existe, c'est le nom officiel de la molécule. Sinon, on prend la `SA` (Substance Active).
    * On joint avec `CIS_bdpm` : C'est le nom commercial officiel du Princeps.
    * *Fiabilité : 100%*.

2. **Tier 2 (Split Simple) :**

    * Si le relationnel échoue (médicament radié/historique), on coupe le libellé brut sur `" - "`.
    * Partie Gauche = Molécule. Partie Droite = Princeps.

3. **Tier 3 (Smart Split - Dernier Recours) :**

    * Si le formatage est sale (tirets manquants, mauvais charset), on applique des Regex correctives (injecter des espaces avant les Majuscules de marque) avant de splitter.

### ADR : Maintien de l'approche hybride (Princeps + Normalisation Nom)

* **Décision :** Nous conservons l'approche hybride actuelle (lien princeps prioritaire + normalisation de nom) plutôt que l'usage du Code Substance unique.
* **Raison :** Les jeux BDPM présentent des incohérences (codes substance manquants ou multiples pour un même produit). Les tests terrain montrent que l'approche hybride est plus robuste pour l'usage « tiroir » en pharmacie.
* **Conséquence :** Pas de regroupement direct par Code Substance tant que la qualité BDPM ne s'améliore pas. Revenir à ce point si de nouvelles données stabilisent le Code Substance.

### 3.2 Transparence de la Donnée

L'application stocke et peut afficher le `RAW_LABEL_ANSM` et la `parsing_method` utilisée pour permettre la vérification humaine en cas de doute.

---

## 4. Search Architecture (FTS5)

This section is the source of truth for PharmaScan search behavior (schema, normalization, and query strategy). Rule files stay generic.

**Scope:** This section owns all PharmaScan-specific FTS5 choices (tokenizer, normalization functions). Technical guardrails remain in `.cursor/rules/`.

### 4.1 FTS5 Implementation (Divide & Conquer)

**Virtual Table:** `search_index`

```sql
CREATE VIRTUAL TABLE search_index USING fts5(
  cis_code UNINDEXED,
  molecule_name,
  brand_name,
  tokenize='trigram'
);
```

**Columns:**

* `cis_code`: UNINDEXED (link to `MedicamentSummary`)
* `molecule_name`: Clean molecule/libellé (optimisé côté ingestion)
* `brand_name`: Princeps brand name (optimisé côté ingestion)

**Tokenization:** `trigram` enables typo tolerance.

### 4.2 Normalization Function (Single Source of Truth)

**Canonical Function:** `normalizeForSearch` in `lib/core/logic/sanitizer.dart`

**Behavior (2025 standard for trigram FTS):**

1. Removes diacritics (`removeDiacritics`)
2. Lowercases
3. Replaces `- ' " : .` with spaces (prevents trigram token splits on punctuation)
4. Collapses whitespace and trims

**SQL UDF:** `normalize_text`

* Registered in `configureAppSQLite()` and delegates to `normalizeForSearch` (no inline duplication).
* Applied to `molecule_name` and `brand_name` at insert time.
* Guarantees parity between query normalization and indexed content.

### 4.3 Query Normalization & Targeting

* Client-side normalization uses the same `normalizeForSearch` (shared with SQL UDF) to ensure `Search Query == Indexed Content`.
* FTS query targets columns explicitly per term: `{molecule_name brand_name} : "term"` joined with `AND` across terms.
* Typos are handled by the trigram tokenizer; no heuristic regex needed.
* Escape user-supplied query terms via `escapeFts5Query()` before issuing FTS searches to avoid operator injection and keep queries deterministic.

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

**Implementation Notes:**

* Current implementation is a small hand-rolled state machine in `lib/core/utils/gs1_parser.dart` (single pass, branch-per-AI) for minimal allocations in scan flows.
* For any new structured parsing (multi-token or nested grammars), prefer PetitParser over bespoke loops to avoid duplicating parser behavior.
* If GS1 parsing needs to expand to additional AI codes or richer validation, consider migrating the current parser to PetitParser for readability and testability; keep the single-pass version only if perf measurements justify it.

**Reference:** `lib/core/utils/gs1_parser.dart`

### 5.2 GS1 Compliance Rules

* Supported AIs: `01` (GTIN/CIP14→CIP13), `10` (batch), `11` (manufacturing date), `17` (expiry), `21` (serial).
* Variable-length fields (`10`, `21`) end strictly at FNC1 (`\x1D`) or end-of-string—no heuristic lookahead for other AIs.
* Dates YYMMDD: if day is `00`, use the last day of the month (applies to `11` and `17`).
* Optional GTIN guard: GTIN starting with `034` corresponds to FR pharma/parapharma; derived CIP13 strips the leading 0.
* Normalization: whitespace and FNC1 are normalized to a single internal separator before parsing.

### 5.3 Duplicate Handling Strategy (Restock mode)

* Parse GS1 → CIP13 and AI 21 serial.
* If serial already exists for the CIP (DB unique constraint), emit `DuplicateScanEvent` (cip, serial, productName, currentQuantity) and stop insertion; haptic: warning.
* Otherwise, insert into `scanned_boxes` and increment `restock_items`; haptic: success.
* UI responds to `DuplicateScanEvent` with a dialog allowing quantity override; confirmation calls `forceUpdateQuantity` and clears the event.

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
* Deep dive on aggregation SQL: `docs/view_aggregated_grouped.md`

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

1. **Generate Golden Files:** Run `parser_lab.py` to generate JSON golden files (still useful for relational cross-checks).
2. **Dart Tests:** Hybrid parsing is now covered by targeted unit tests (`test/core/ingestion/hybrid_parsing_test.dart`) instead of grammar-based goldens.

**Rule:** Any modification to parsing must keep the 3-tier hybrid contract green (relational > text split > smart split) and keep golden files in sync when they are used for data sanity checks.

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

## 9. File Schema Contract (Validation)

To protect database integrity, BDPM files are validated before parsing.

| File | Expected Columns | Key Validation |
| :--- | :--- | :--- |
| `CIS_bdpm.txt` | 12 | Col 0: CIS (8 digits) |
| `CIS_CIP_bdpm.txt` | ≥10 | Col 0: CIS (8 digits), Col 6: CIP13 (13 digits) |
| `CIS_COMPO_bdpm.txt` | 8 | Col 0: CIS (8 digits) |
| `CIS_GENER_bdpm.txt` | ≥4 | Col 2: CIS (8 digits) |
| `CIS_CPD_bdpm.txt` | 2 | Col 0: CIS (8 digits) |
| `CIS_CIP_Dispo_Spec.txt` | 4 | Col 0: CIS (8 digits) |
| `CIS_MITM.txt` | 2 | Col 0: CIS (8 digits) |

Validation runs before any DB transaction; failures delete cached files and surface `InitializationStep.error`.

### 8.2 Key Implementation Files

* **Parser:** `lib/core/services/ingestion/bdpm_file_parser.dart`
* **Normalization:** `lib/core/logic/sanitizer.dart`
* **Constants:** `lib/core/constants/chemical_constants.dart`
* **Database:** `lib/core/database/daos/database_dao.dart`
* **Views:** `lib/core/database/views.drift`
* **Queries:** `lib/core/database/queries.drift`
* **GS1 Parser:** `lib/core/utils/gs1_parser.dart`

---

## 10. UI/UX Domain Terms

### Adaptive Overlay

* **Definition:** A pattern for transitioning between different UI contexts (e.g., full screen to modal, modal to sheet) that adapts to screen size and device type.
* **Implementation:** Uses `showModalBottomSheet` or `showShadSheet` with `side: ShadSheetSide.bottom` on mobile, and may use `ShadDialog` or `ShadPopover` on larger screens.
* **Purpose:** Provides consistent user experience across device sizes while respecting platform conventions.

### Domain Entity (Extension Type)

* **Definition:** An extension type wrapper around Drift rows that enforces invariants without runtime allocation.
* **Characteristics:**
  * Zero-cost abstraction: exposes only the allowed surface from the underlying row.
  * Adds computed getters/validation where needed; no JSON/mapping ceremony.
  * Keeps UI/services decoupled from raw Drift classes while preserving type safety.
* **Example:** `extension type ClusterSummaryExt(MedicamentSummaryRow row)` to expose normalized getters for clustering/search UI.

### Mapper

* **Definition:** A function, extension, or class that transforms database rows (Drift-generated classes) into Domain Entities.
* **Purpose:** Maintains separation between database layer and domain layer.
* **Location:** Typically defined as extensions on Domain Entities or as static methods in mapper classes.
* **Usage:** Services use mappers to convert `MedicamentRow` → `ScanResult` before exposing to UI.

---

## 11. Architecture Domain Terms

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

### Débouncing du Scanner (Caméra vs Galerie)

* **Clé unique par boîte :** `${cip}::${serial ?? ''}` stockée dans une Map `_scanCooldowns`.
* **Caméra (par défaut) :** Cooldown de 2s par clé pour ignorer les scans répétés du même objet pendant la fenêtre courte.
* **Galerie (force = true) :** Bypass complet du cooldown et des doublons ; si une bulle existe déjà pour ce CIP, elle est retirée avant traitement pour rejouer l’animation d’ajout.
* **Nettoyage :** Les entrées de cooldown sont purgées périodiquement (TTL ~5 min) pour éviter la croissance en longue session.

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

---

## 12. UI & Présentation (Hero + Compact)

* **Hiérarchie visuelle forte :** Le princeps (ou, à défaut, le premier générique) est présenté en `PrincepsHeroCard` (surface ShadCard bordure primary) avec badges réglementaires et indicateurs prix/remboursement mis en avant.
* **Liste compacte des génériques :** Les membres génériques utilisent `CompactGenericTile` (ligne 48–56px) affichant uniquement le laboratoire, les icônes d’état (prix, hôpital) et les badges critiques (rupture/arrêt). Le tri pénurie → hôpital → nom est conservé depuis le provider.
* **Progressive Disclosure :** Le tap sur le hero ou une tuile ouvre `MedicationDetailSheet` via `showShadSheet(side: bottom)`, qui contient toutes les métadonnées (CIP, titulaire complet, prix/remboursement, conditions, disponibilité, badges). Les listes restent scannables, le détail reste à la demande.
