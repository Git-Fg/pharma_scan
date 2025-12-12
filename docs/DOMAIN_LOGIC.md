# Domain Logic Documentation

This document explains the business logic enforced by the Backend Pipeline (`backend_pipeline/`). The Mobile App consumes the output (`reference.db`) as a read-only artifact.

For architectural patterns and technical standards, see `docs/ARCHITECTURE.md`.

---

## 1. Glossary

### Core Data Terms

#### Backend Pipeline

* **Definition:** The TypeScript/Bun project in `backend_pipeline/` that downloads, parses, cleans, and aggregates ANSM data into a SQLite database.
* **Technology Stack:** Bun (TypeScript), SQLite (`bun:sqlite`)
* **Output:** `reference.db` (Gzipped for distribution)

#### Reference DB (`reference.db`)

* **Definition:** The artifact produced by the backend. It is downloaded by the mobile app.
* **Status:** Single Source of Truth for all medication data.
* **Usage:** The mobile app treats this database as read-only and performs no ETL operations.

#### Canonical Name

* **Definition:** A normalized, cleaned version of a medication name determined by the Backend (`src/sanitizer.ts`).
* **Process:** The logic applies knowledge-injected subtraction (removing known Salts like 'Chlorhydrate', 'Maléate', and Forms like 'Base', 'Anhydre').
* **Normalization:** Diacritic removal and text normalization performed in `backend_pipeline/src/sanitizer.ts`.
* **Usage:** Used for grouping, searching, and display. The canonical name is deterministic and stable for the same raw input.

#### Cluster (Regroupement)

* **Definition:** A visual grouping calculated by the Backend (`src/clustering.ts`).
* **Hybrid Strategy:**
  1. **Hard Link:** Groups by Princeps CIS code.
  2. **Soft Link:** Groups by normalized common principles using advanced string similarity.
* **LCP Naming:** The Longest Common Prefix is calculated by the backend for cluster labels.
* **Super-Vote:** A backend harmonization process that aligns composition display strings at the Cluster level.

#### Fraction Thérapeutique (FT)

* **Definition:** The chemical "Base" of a medication, often linked to a salt (Substance Active).
* **Usage:** When present in `CIS_COMPO`, it **overrides** the Substance Active for display purposes.
* **Example:** Used to display "Metformine" (FT) instead of "Metformine Chlorhydrate" (SA).

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

## 2. BDPM Data Pipeline (Server-Side ETL)

The ETL process is fully automated in `backend_pipeline`.

### 2.1 Technology Stack

* **Runtime:** Bun (TypeScript)
* **Database:** SQLite (`bun:sqlite`)
* **Output:** `reference.db.gz` (Gzipped for distribution)
* **Deployment:** GitHub Actions (weekly runs)

### 2.2 Pipeline Stages

#### Stage 1: Ingestion

* Downloads raw TXT files from ANSM website
* Handles encoding (ISO-8859-1/Windows-1252 to UTF-8)
* Validates file formats and schemas
* Location: `backend_pipeline/src/ingestion.ts`

#### Stage 2: Relational Parsing

* Groups components by `linkId` (FT/SA logic)
* Implements priority rules: FT (Fraction Thérapeutique) overrides SA (Substance Active)
* Location: `backend_pipeline/src/parsing.ts`

#### Stage 3: Sanitization

* Normalizes names via `backend_pipeline/src/sanitizer.ts`
* Removes salts, forms, and normalizes text for search
* Applies chemical knowledge for consistent naming

#### Stage 4: Clustering

* **Hard Link:** Groups by Princeps CIS code
* **Soft Link:** Groups by normalized common principles
* **LCP Naming:** Calculates Longest Common Prefix for cluster labels
* Location: `backend_pipeline/src/clustering.ts`

#### Stage 5: Aggregation

* **Majority Vote:** Harmonizes composition display strings within groups
* **Super-Vote:** Harmonizes composition at the Cluster level (Substance only)
* Generates `medicament_summary` pre-aggregated table
* Location: `backend_pipeline/src/aggregation.ts`

#### Stage 6: SQL Generation

* Populates `medicament_summary` and `search_index` (FTS5)
* Creates optimized views for mobile consumption
* Generates compressed `reference.db.gz` artifact

### 2.3 Data Processing Rules

#### Parsing Strategy

* **Compositions:** Priority given to Fraction Thérapeutique (FT) over Substance Active (SA) for atomic consistency
* **Generics:** 3-Tier strategy (Relational > Text Split > Smart Split) for molecule extraction
* **Validation:** Cross-reference validation between related tables

#### Clustering Algorithm

* **Safety:** Includes "Suspicious Data" check to prevent merging unrelated groups
* **Fuzzy Matching:** Uses normalized string similarity for soft clustering
* **Confidence Scoring:** Each cluster has a confidence score based on matching quality

---

## 3. Search Architecture (FTS5)

**Index:** `search_index` virtual table in `reference.db`

**Tokenization:** `unicode61 remove_diacritics 2` for full compatibility with backend

**Normalization:** The `normalize_text` SQL function used in the app MUST match `normalizeForSearch` in `backend_pipeline/src/sanitizer.ts`

### 3.1 Search Index Structure

```sql
CREATE VIRTUAL TABLE search_index USING fts5(
  cis_code UNINDEXED,
  molecule_name,
  brand_name,
  tokenize='unicode61 remove_diacritics 2'
);
```

**Columns:**
* `cis_code`: UNINDEXED (primary key for linking)
* `molecule_name`: Pre-normalized molecule name
* `brand_name`: Pre-normalized brand name

### 3.2 Normalization Consistency

The mobile app's search normalization logic must match the backend's `normalizeForSearch` function exactly:

1. Removes diacritics
2. Lowercases
3. Replaces punctuation with spaces
4. Collapses whitespace and trims

---

## 4. Synchronization Protocol

### 4.1 Backend Generation

1. **Weekly Schedule:** Runs automatically via GitHub Actions
2. **Version Control:** Uses Git tags for versioning
3. **Artifact Generation:** Creates `reference.db.gz`
4. **Release Management:** Publishes to GitHub Releases

### 4.2 Mobile Update Process

1. **Check:** `DataInitializationService` checks GitHub Release tag
2. **Download:** If new tag found, downloads `reference.db.gz`
3. **Validation:** Verifies database integrity
4. **Replace:** Atomically replaces local database
5. **Restart:** Restarts database connections

### 4.3 Fallback Strategy

The mobile app contains legacy Dart parsers (`lib/core/services/ingestion/`) strictly for emergency offline bootstrapping. These parsers are **deprecated** and should not be used for normal operation.

---

## 5. Analysis Tools

### 5.1 Backend Analysis

**Tool:** `bun run tool` in `backend_pipeline/`

**Available Commands:**
* `bun run tool audit` - Data quality analysis
* `bun run tool validate` - Schema validation
* `bun run tool cluster-analyze` - Clustering debug output
* `bun run tool search-test` - Search index testing

### 5.2 Mobile Testing

For mobile-specific UI testing, create scripts in `tool/` using Dart/Flutter testing framework. Do not use the legacy Python scripts.

### 5.3 Data Debugging

* **Backend:** Use TypeScript logging in `backend_pipeline/src/debug.ts`
* **Mobile:** Use Flutter's built-in logging for database queries
* **Cross-reference:** Compare `reference.db` structure with backend schema

---

## 6. Database Structure (Backend-Defined)

### 6.1 Schema Source of Truth

**Primary Definition:** `backend_pipeline/src/db.ts`

**Mobile Synchronization:** `lib/core/database/schema.sql`

### 6.2 Core Tables

#### `medicament_summary` (Pre-aggregated)

* **Purpose:** Main table for mobile app queries
* **Generation:** Populated by backend aggregation
* **Key Columns:**
  * `cis_code`: Primary identifier
  * `nom_canonique`: Normalized name
  * `cluster_id`: Visual grouping identifier
  * `princeps_de_reference`: Reference princeps name
  * `composition_display`: Pre-formatted composition
  * `prix_min` / `prix_max`: Price range
  * Regulatory flags (hospital_only, list1, list2, etc.)

#### `search_index` (FTS5)

* **Purpose:** Full-text search
* **Tokenization:** Unicode61 with diacritic removal for consistent ligature handling
* **Normalization:** Applied at insert time

### 6.3 Schema Synchronization Rule

**CRITICAL:** Changes to `medicament_summary` schema MUST be done in `backend_pipeline/src/db.ts` first, then synced to `lib/core/database/schema.sql`. The mobile app does not modify the database structure.

---

## 7. API Gateway Pattern

### 7.1 No Mobile ETL

The mobile application does NOT perform ETL operations. It is a "Smart Viewer" that:

* Downloads pre-processed `reference.db`
* Presents data through optimized queries
* Maintains local cache of user-specific data (scan history, settings)

### 7.2 Local-Only Data

Tables managed exclusively by the mobile app:

* `scan_history`: User's scanning history
* `restock_items`: Inventory management
* `settings`: User preferences
* `user_data`: Any user-specific data

---

## 8. Mobile Application Patterns

### 8.1 Database Access

* **Read Operations:** Query `medicament_summary` directly
* **Search:** Use FTS5 through `search_index`
* **Local Data:** Use separate DAOs for mobile-managed tables

### 8.2 UI Data Binding

* **Domain Entities:** Extension types on `MedicamentSummaryRow`
* **State Management:** Riverpod providers for data access
* **Search UI:** Reactive search with debouncing

### 8.3 Offline-First Design

* **Core Data:** Available offline via `reference.db`
* **Updates:** Background sync when network available
* **Fallback:** Legacy parsers for emergency use only

---

## 9. Development Workflow

### 9.1 Backend Changes

1. Modify logic in `backend_pipeline/src/`
2. Run tests with `bun test`
3. Generate new `reference.db` locally
4. Test with mobile app using local database
5. Commit and push to trigger GitHub Actions

### 9.2 Mobile Changes

1. Update UI/UX components
2. Test with current `reference.db`
3. No database schema changes allowed

### 9.3 Synchronized Changes

When database schema changes are needed:

1. Update `backend_pipeline/src/db.ts`
2. Generate migration scripts
3. Update `lib/core/database/schema.sql`
4. Test both backend and mobile
5. Release coordinated updates

---

## 10. Scanning Logic

### 10.1 GS1 DataMatrix Parsing

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

### 10.2 GS1 Compliance Rules

* Supported AIs: `01` (GTIN/CIP14→CIP13), `10` (batch), `11` (manufacturing date), `17` (expiry), `21` (serial).
* Variable-length fields (`10`, `21`) end strictly at FNC1 (`\x1D`) or end-of-string—no heuristic lookahead for other AIs.
* Dates YYMMDD: if day is `00`, use the last day of the month (applies to `11` and `17`).
* Optional GTIN guard: GTIN starting with `034` corresponds to FR pharma/parapharma; derived CIP13 strips the leading 0.
* Normalization: whitespace and FNC1 are normalized to a single internal separator before parsing.

### 10.3 Duplicate Handling Strategy (Restock mode)

* Parse GS1 → CIP13 and AI 21 serial.
* If serial already exists for the CIP (DB unique constraint), emit `DuplicateScanEvent` (cip, serial, productName, currentQuantity) and stop insertion; haptic: warning.
* Otherwise, insert into `scanned_boxes` and increment `restock_items`; haptic: success.
* UI responds to `DuplicateScanEvent` with a dialog allowing quantity override; confirmation calls `forceUpdateQuantity` and clears the event.

---

## 11. Restock Logic

### Mode Rangement (Restock Mode)

* **Définition :** Un mode du scanner dédié à l'inventaire rapide ou à la réception de commande.
* **Comportement :** Le scan ne bloque pas la caméra (pas de popup). Il ajoute silencieusement le produit à une liste persistante (`RestockItems`) et émet une vibration de succès.
* **Dédoublonnage :** Scanner un produit déjà présent dans la liste incrémente sa quantité (`quantity + 1`) au lieu de créer une nouvelle ligne.

### Débouncing du Scanner (Caméra vs Galerie)

* **Clé unique par boîte :** `${cip}::${serial ?? ''}` stockée dans une Map `_scanCooldowns`.
* **Caméra (par défaut) :** Cooldown de 2s par clé pour ignorer les scans répétés du même objet pendant la fenêtre courte.
* **Galerie (force = true) :** Bypass complet du cooldown et des doublons ; si une bulle existe déjà pour ce CIP, elle est retirée avant traitement pour rejouer l'animation d'ajout.
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

## 12. UI & Presentation

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

### Hero + Compact Layout

* **Hiérarchie visuelle forte :** Le princeps (ou, à défaut, le premier générique) est présenté en `PrincepsHeroCard` (surface ShadCard bordure primary) avec badges réglementaires et indicateurs prix/remboursement mis en avant.
* **Liste compacte des génériques :** Les membres génériques utilisent `CompactGenericTile` (ligne 48–56px) affichant uniquement le laboratoire, les icônes d'état (prix, hôpital) et les badges critiques (rupture/arrêt). Le tri pénurie → hôpital → nom est conservé depuis le provider.
* **Progressive Disclosure :** Le tap sur le hero ou une tuile ouvre `MedicationDetailSheet` via `showShadSheet(side: bottom)`, qui contient toutes les métadonnées (CIP, titulaire complet, prix/remboursement, conditions, disponibilité, badges). Les listes restent scannables, le détail reste à la demande.

---

## 13. File Structure Reference

### 13.1 Backend (Source of Truth)

```
backend_pipeline/
├── src/
│   ├── ingestion.ts     # ANSM data download
│   ├── parsing.ts       # BDPM file parsing
│   ├── sanitizer.ts     # Text normalization
│   ├── clustering.ts    # Advanced clustering
│   ├── aggregation.ts   # Data aggregation
│   ├── db.ts           # Database schema
│   └── debug.ts        # Debug utilities
├── tool/               # Analysis scripts
└── dist/               # Generated artifacts
```

### 13.2 Mobile (Consumer)

```
lib/
├── core/
│   ├── database/
│   │   ├── daos/        # Data access objects
│   │   ├── schema.sql   # Synchronized schema
│   │   └── providers.dart # Database providers
│   ├── services/
│   │   ├── ingestion/   # Deprecated fallback only
│   │   └── data_initialization_service.dart # DB sync
│   └── logic/           # Mobile-only business logic
└── features/
    ├── explorer/        # Data browsing
    ├── scanner/         # Barcode scanning
    └── restock/         # Inventory management
```

### 13.3 BDPM Files

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

---

## 14. Testing Strategy

### 14.1 Backend Tests

* **Unit Tests:** Individual parsing and transformation functions
* **Integration Tests:** Full pipeline with sample data
* **Schema Tests:** Database structure validation
* **Performance Tests:** Large dataset processing

### 14.2 Mobile Tests

* **Unit Tests:** UI components and business logic
* **Integration Tests:** Database queries and search
* **UI Tests:** User workflows and interactions
* **Mock Data:** Use pre-generated `reference.db` for testing

### 14.3 End-to-End Tests

* **Sync Tests:** Database download and update
* **Search Tests:** Query accuracy and performance
* **UI Flow Tests:** Complete user journeys

---