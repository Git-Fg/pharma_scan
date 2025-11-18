# PharmaScan

PharmaScan is a high-performance Flutter application designed for the rapid scanning and identification of pharmaceutical products (both generic and princeps) using GS1 Data Matrix codes.

## Features

- **Instant Data Matrix Scanning**: Utilizes the device camera to detect and parse GS1 barcodes in real-time.
- **Robust Scan Results**: The scanner UI displays the most recent scan prominently, with a short history of previous scans, using a simplified and fluid animation system that is resilient to rapid, successive scans.
- **Unified Group Explorer**: An intelligent view that presents a canonical overview of a medication group:
  - **Product-Centric Grouping**: Generics are grouped by product name and dosage, not by laboratory, providing a clear, decluttered view of available alternatives.
  - **Associated Therapies**: When viewing a group (e.g., "VALSARTAN"), the explorer proactively displays clickable cards for related combination therapies (e.g., "VALSARTAN/HYDROCHLOROTHIAZIDE") for seamless cross-discovery.
- **Fuzzy & Grouped Search**: The search engine is powered by a full-text search index (FTS5) for a superior experience:
  - **Typo Tolerance**: The search is resilient to spelling mistakes and partial queries.
  - **Grouped Results**: Search results are unified by group, showing one clear entry per product concept (e.g., "PARACETAMOL 500 mg") instead of an overwhelming list of every individual package.
- **One-Tap Search Reset**: A contextual clear control instantly resets the explorer search field, taking you back to the generic group summaries without manual text deletion.
- **Aggregated Source of Truth**: Every CIS (specialty) gets a single, denormalized `MedicamentSummary` row populated during initialization. This precomputes canonical names, princeps/generic flags, reference princeps, common active principles, and pharmaceutical forms so all explorer queries return instantly from a single table.
- **Form Category Filtering**: Browse medications by pharmaceutical form with 7 categories:
  - **Oral** (default): comprimé, gélule, capsule, lyophilisat, solution buvable, sirop, suspension buvable, comprimé orodispersible
  - **Injectable**: injectable, injection, perfusion, solution pour perfusion, poudre pour solution injectable, solution pour injection
  - **External Use**: crème, pommade, gel, lotion, pâte, cutanée, cutané, application locale, application cutanée, dispositif transdermique
  - **Sachet**: sachet, poudre pour solution buvable, poudre pour suspension buvable, granulé
  - **Ophthalmic**: collyre, ophtalmique, solution ophtalmique, pommade ophtalmique, gel ophtalmique
  - **Nasal/ORL**: nasale, auriculaire, buccale, aérosol, spray nasal, gouttes nasales, gouttes auriculaires
  - **Gynecological**: ovule, pessaire, comprimé vaginal, crème vaginale, gel vaginal, capsule vaginale, tampon vaginal, anneau vaginal
  - Intelligent exclusions prevent false positives (e.g., External Use excludes "vaginal" to avoid overlap with Gynecological)
- **Algorithmic Princeps Grouping**: Advanced word-based algorithm that identifies common base names for princeps within the same group, providing a clean "Generic Principle ↔ Princeps Reference" mapping in the explorer view. The algorithm compares medication names word-by-word to find the longest common prefix, replacing fragile regex-based extraction.
- **On-Device, Type-Safe Database**: Uses `drift` ORM for a fully offline, compile-time safe database built from official French public health data (BDPM).
- **Deterministic Data Model**: All relationships and data extraction are derived directly from official BDPM data files, ensuring 100% accuracy and eliminating all heuristic approximations. No regex-based extraction - all data comes from structured parsing of official TXT files.
- **Clean & Responsive UI**: Built with a minimalistic design system (`shadcn-ui/flutter`) for an efficient user experience.
- **Resilient Initialization & Recovery**: Startup initialization relies on versioned data checks inside `DataInitializationService`; when connectivity fails, the app surfaces a non-blocking banner with retry and Settings shortcuts, and users can force a full BDPM refresh from the Settings screen.
- **Automatic BDPM Sync**: A background `SyncService` tracks per-file SHA-256 hashes, honors user-defined frequencies (`none/daily/weekly/monthly`), retries until connectivity is available, and exposes progress via Riverpod so the UI can display Shad banners, manual "check now" actions, and toast notifications.

## Technology Stack

- **Framework**: Flutter
- **UI Toolkit**: [shadcn-ui/flutter](https://pub.dev/packages/shadcn_ui)
- **Scanning**: [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- **Local Database**: [drift](https://pub.dev/packages/drift) - Type-safe ORM with compile-time query validation
- **Data Sources**: Official BDPM TXT files (direct downloads, no ZIP archives)
- **State Management**: Local `StatefulWidget` state for UI plus targeted Riverpod providers (e.g., background sync status, user preferences) where cross-layer coordination is required.
- **Architecture**: Clean Two-Layer (UI / Services)

## Getting Started

### Prerequisites

- Flutter SDK installed.
- An editor like VS Code or Android Studio.
- A physical device or emulator for testing.

### Installation & Setup

1. **Clone the repository:**

    ```bash
    git clone <your-repository-url>
    cd pharma_scan
    ```

2. **Install dependencies:**

    ```bash
    flutter pub get
    ```

3. **Run the application:**
    The first run will take some time as it needs to download three TXT files (~20MB total) from the official BDPM source and populate the local database.

    ```bash
    flutter run
    ```

## Data Architecture

The application uses a **deterministic data model** based on official relational data files from the French public medication database (BDPM):

- **Data Sources**: Direct downloads of individual TXT files:
  - `CIS_bdpm.txt` - Medication specialties with form, commercialization status, and manufacturer (titulaire)
  - `CIS_CIP_bdpm.txt` - Medication codes and names
  - `CIS_COMPO_bdpm.txt` - Active ingredient compositions with structured dosage information
  - `CIS_GENER_bdpm.txt` - Generic group relationships (authoritative source)

- **Database Schema**: Type-safe relational database using drift ORM with explicit generic group relationships:
  - Schema defined in Dart (`lib/core/database/database.dart`) with automatic code generation
  - Enriched data model: `Specialites` table includes `formePharmaceutique`, `etatCommercialisation`, and `titulaire` (manufacturer)
  - `PrincipesActifs` table includes structured `dosage` and `dosageUnit` fields
  - Generic groups are defined in `generique_groups` table
  - Group membership (princeps/generic) is stored in `group_members` table
  - `MedicamentSummary` is a denormalized, single-table “source of truth” keyed by `cis_code`, storing canonical specialty names, princeps/generic flags, reference princeps, JSON-encoded shared principles, forms, and group identifiers. All explorer queries (search, library, scan lookups) now read directly from this table for constant-time answers.
  - Common active ingredients for groups are extracted directly from `principes_actifs` table via SQL joins
  - Princeps names are grouped algorithmically using word-based common prefix detection (no regex)
  - **Compile-Time Safe SQL**: All complex SQL queries are defined in `.drift` files, which are parsed and validated against the schema at compile time. This eliminates an entire class of runtime SQL errors and ensures perfect consistency between the database schema and data access logic.
  - No predictive matching or heuristic approximations—all data and relationships are 100% deterministic.

- **Initialization**: On first launch, the app downloads all four TXT files, parses them, and populates the local database. The process now runs in two deterministic phases:
  1. **Staging** – TXT data is parsed into the normalized tables (`specialites`, `medicaments`, `principes_actifs`, `generique_groups`, `group_members`).
  2. **Aggregation** – `_aggregateDataForSummary()` computes one `MedicamentSummary` row per CIS, pre-calculating canonical names, group IDs, shared principles, and princeps references so the UI never recomputes them at runtime.
  Subsequent launches are instant as both layers persist locally.

- **Explorer Features**:
  - **Form Category Filtering**: Seven pharmaceutical form categories (Oral, Injectable, External Use, Sachet, Ophthalmic, Nasal/ORL, Gynecological) with intelligent keyword matching
  - **Smart Exclusions**: Prevents false positives (e.g., External Use excludes "vaginal" to avoid overlap with Gynecological)
  - **Group Summary View**: Clean "Principe(s) Actif(s) ↔ Princeps de Référence" mapping using algorithmic common prefix detection
  - **Infinite Scroll Pagination**: Efficient loading of large result sets (50 items per page)
  - **Full-Text Search**: Search is powered by an on-device FTS5 index, providing typo-tolerant, relevance-based results grouped by product concept.

## Project Mantras

This project adheres to a strict set of development principles focused on simplicity, robustness, and performance. For detailed guidelines, refer to `AGENTS.md`.

## Project Roadmap

The current version of PharmaScan is focused on rapid identification and generic/princeps equivalence. The following features are under consideration for future development, aiming to enrich the application with critical professional data. Each requires a thorough preliminary analysis of the official BDPM data files to ensure a robust and reliable implementation.

### 1. Regulatory Information (Prescription Status)

- **Feature Goal**: Display the specific prescription and dispensing conditions for each medication directly within the app's detail view (e.g., "Sur Ordonnance - Liste I", "Vente Libre", "Stupéfiant").

- **Core Modification**: This enhancement would involve integrating the `CIS_CPD_bdpm.txt` file into the data pipeline. A new field would be added to the local database to store this regulatory status, which would then be displayed using a clear badge or label in the user interface.

- **Required Analysis**: Before implementation, a thorough analysis of the `CIS_CPD_bdpm.txt` file is required. The primary task is to identify **all unique values** for the "Condition de prescription et de délivrance" to create a definitive mapping to user-friendly, standardized labels. This ensures that every regulatory status is handled correctly and presented unambiguously to the user.

### 2. Real-Time Availability Status (Stock Shortages)

- **Feature Goal**: Provide near real-time information on medication availability, highlighting products currently in "Rupture de stock" (Out of Stock) or "Tension d'approvisionnement" (Supply Tension). This would be a high-impact feature for daily professional use.

- **Core Modification**: This is a major architectural enhancement that would require moving beyond the current offline-first model. The implementation would involve integrating the `CIS_CIP_Dispo_Spec.txt` file.

- **Required Analysis**: The core challenge is the **high volatility** of this data. The analysis must focus on:
    1. **Update Frequency**: Determining how often the official source file is updated.
    2. **Architectural Impact**: Designing a new background service or an API-based mechanism to fetch this specific data far more frequently than the main database (e.g., daily).
    3. **UI/UX for Data Staleness**: Designing a clear way to inform the user about the age of the availability data (e.g., "Statut au 16/11/2025 à 08:00") to prevent decisions based on outdated information, especially when the device is offline.
