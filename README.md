# PharmaScan

PharmaScan is a high-performance Flutter application designed for the rapid scanning and identification of pharmaceutical products (both generic and princeps) using GS1 Data Matrix codes.

## Features

- **Instant Data Matrix Scanning**: Utilizes the device camera to detect and parse GS1 barcodes in real-time.
- **Smart Medication Identification (Quick View)**: After scanning, an info bubble provides a concise, actionable summary:
  - **Princeps Scan**: Shows the active ingredient and lists laboratories producing generic versions.
  - **Generic Scan**: Directly lists the associated brand-name (princeps) medication(s).
- **Generic Group Explorer (Deep Dive)**: An advanced, interactive view to explore the full context of a medication group, featuring:
  - **User-Centric View Modes**: Instantly toggle the display between `Generic → Princeps` (default) and `Princeps → Generic` layouts to fit your workflow.
  - **Bicolumn Layout**: A clear, side-by-side comparison of all princeps and generics in the group.
  - **Powerful Sorting**: Instantly sort medications by name or dosage.
- **Intelligent Search**: The explorer's search function understands medication names, CIP codes, and **active ingredients**, allowing you to find what you need even with partial information.
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

## Technology Stack

- **Framework**: Flutter
- **UI Toolkit**: [shadcn-ui/flutter](https://pub.dev/packages/shadcn_ui)
- **Scanning**: [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- **Local Database**: [drift](https://pub.dev/packages/drift) - Type-safe ORM with compile-time query validation
- **Data Sources**: Official BDPM TXT files (direct downloads, no ZIP archives)
- **State Management**: `StatefulWidget` (Local State)
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
  - Common active ingredients for groups are extracted directly from `principes_actifs` table via SQL joins
  - Princeps names are grouped algorithmically using word-based common prefix detection (no regex)
  - No predictive matching, inference, or regex-based extraction - all relationships and data come directly from official BDPM data
  - All queries are type-safe, eliminating runtime SQL errors

- **Initialization**: On first launch, the app downloads all four TXT files, parses them, and populates the local database. Subsequent launches are instant as the database persists locally.

- **Explorer Features**:
  - **Form Category Filtering**: Seven pharmaceutical form categories (Oral, Injectable, External Use, Sachet, Ophthalmic, Nasal/ORL, Gynecological) with intelligent keyword matching
  - **Smart Exclusions**: Prevents false positives (e.g., External Use excludes "vaginal" to avoid overlap with Gynecological)
  - **Group Summary View**: Clean "Principe(s) Actif(s) ↔ Princeps de Référence" mapping using algorithmic common prefix detection
  - **Infinite Scroll Pagination**: Efficient loading of large result sets (50 items per page)
  - **Search Integration**: Search by name, CIP code, or active ingredient with relevance filtering

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
