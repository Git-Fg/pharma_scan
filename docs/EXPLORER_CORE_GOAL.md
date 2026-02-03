# Explorer Page: Core Goal & Philosophy

## Overview

The **Explorer** is the medication database browser. Its primary purpose is to help users find medications and understand **therapeutic equivalence** between brand names and active ingredients.

---

## Pharmacy Drawers Focus: The "Tiroirs" Priority

### What This Means

The explorer and clustering optimization should focus on medication forms commonly found in **pharmacy drawers (tiroirs)**:

**Primary Focus (Core Use Case)**:
- **Oral solids**: comprimé, gélule, lyophilisat
- **Oral liquids**: sirop, suspension, solution buvable
- **Eye care**: collyre, pommade oculaire
- **ORL**: spray nasal, gouttes auriculaires
- **Gynécologique**: ovule, crème vaginale
- **Dermatologique**: crème, pommade, gel
- **Inhalation**: inhalateur, spray buccal

**Secondary Focus (Nice-to-have)**:
- Pastilles, suppositoires, injectables and other less common forms hard to parse

**Lower Priority**:
- hospital-only forms, specialized preparations

**Why This Matters**: These are the items pharmacists actually scan and organize daily. The regex and clustering must be robust for these forms first.

---

## The Core Goal: CIP Naming & Rangement

### The Fundamental Requirement

**For each CIP code in the system, we need:**

1. **Clean Brand Name**: The commercial brand name
   - Used for alphabetical sorting ("rangement")
   - Used for user-facing display
   - Used for scanner result lookup
   - Example: "CLAMOXYL", "DOLIPRANE", "ADVIL"

2. **Clean Generic Name**: The active ingredient/chemical name
   - Used for therapeutic equivalence display
   - Used for cluster grouping
   - Used for generic product identification
   - Example: "amoxicilline", "paracétamol", "ibuprofène"

### Why This Matters

```
User scans barcode → Get CIP → Show Brand name → User understands product
                    ↓
              Show Generic name → User sees alternatives/generics
```

**Without clean names**: Scanner shows raw BDPM data like "AMOXICILLINE TRIHYDRATE 500 MG GELULE B/30"

**With clean names**: Scanner shows "Clamoxyl 500 mg (amoxicilline)"

---

## Rangement: Alphabetical Ordering Philosophy

### What is "Rangement"?

**Rangement** = Ordering/arranging medications alphabetically by their **clean brand name**.

The goal: Users should be able to scan any product and easily find it ordered alongside its brand name equivalents.

### The Sorting Philosophy

```
Clusters (A-Z by Princeps Brand Name)
  └── Products (Priority: Shortage > Hospital > Alphabetical)
```

### Cluster-Level Sorting

Clusters are sorted by their **princeps brand name**, not by generic name.

**Result**: "Amoxicilline (Réf: Clamoxyl)" appears under **C**, not **A**

### Product-Level Sorting

Within clusters, products are sorted by priority:

1. **Shortage items** (alert users to stock issues)
2. **Hospital-only** (push to bottom)
3. **Alphabetical** (by brand/generic name)

### The "Clean Brand Name" Challenge

**Current State**:
- Brand name field can contain placeholder values like "BRAND"
- No explicit "clean brand name" concept
- Inconsistent fallback to generic name when brand missing

**Example of Inconsistency**:

| CIP | Brand Name | Generic Name | Display Name |
|-----|-----------|--------------|--------------|
| 3400930234259 | "CLAMOXYL" | "AMOXICILLINE" | "Clamoxyl" ✅ |
| 3400935955838 | "DOLIPRANE" | "PARACETAMOL" | "Doliprane" ✅ |
| 34009XXXXXXXX | "BRAND" | "IBUPROFENE" | "Ibuprofène" ⚠️ |

**Issue**: When brand name = "BRAND", products sort alphabetically by generic name instead of brand name.

### Desired Rangement Behavior

```
A
├── ADVIL (Ibuprofène)
├── AUGMENTIN (Amoxicilline + Acide clavulanique)
B
├── BACTRIM (Cotrimoxazole)
C
├── CLAMOXYL (Amoxicilline)
├── COORDINATE (Ibuprofène + Pseudoéphédrine)
D
├── DOLIPRANE (Paracétamol)
```

**Key Principle**: Generics should sort under their princeps brand, not by their own name.

---

## User-Facing Goals

### 1. Find Medications by Any Identifier
Users can search for medications using:
- **Brand names**: "Clamoxyl", "Doliprane", "Advil"
- **Active ingredients**: "amoxicilline", "paracétamol", "ibuprofène"
- **CIP barcodes**: "3400935955838"
- **CIS codes**: "61983278"

### 2. Understand Therapeutic Equivalence
Users can see relationships between:
- **Princeps ↔ Generics**: Original vs generic equivalents
- **Brand ↔ Ingredient**: Commercial name vs active substance
- **Related medications**: Same molecule, different dosages

### 3. Browse by Chemical Clusters
Users can explore medications grouped by:
- **Active substance**: All amoxicillin products together
- **Dosage**: 500 mg, 1000 mg variants
- **Pharmaceutical form**: Tablet, capsule, injectable

### 4. Filter and Compare
Users can filter by:
- **Administration route**: Oral, injectable, topical
- **Regulatory status**: List I/II, hospital-only
- **Availability**: Stock shortages/alerts
- **Pricing**: Price ranges and refund rates

---

## The Clamoxyl Example

### User Journey

```
1. User scans "CLAMOXYL" barcode
   ↓
2. Scanner finds CIP: 3400930234259
   ↓
3. Explorer opens cluster: Amoxicilline
   ↓
4. Display name: "Amoxicilline" (active ingredient)
   ↓
5. Princeps: CLAMOXYL (original brand)
   ↓
6. Generics: All amoxicillin 500 mg generics
```

### Data Flow Philosophy

```
Raw Input: "CLAMOXYL 500 mg, gélule"
  ↓ (Scanner)
CIP: 3400930234259
  ↓ (Database Lookup)
CIS: 61983278
  ↓ (Composition Lookup)
ChemicalID: "0045" (amoxicilline)
  ↓ (Cluster Lookup)
Cluster: Amoxicilline
  ↓ (Princeps Election)
PrincepsBrand: "CLAMOXYL"
  ↓ (Display)
User sees: "Amoxicilline" cluster with Clamoxyl as reference
```

---

## Display Logic Philosophy

### Smart Naming Hierarchy

```
1. Princeps brand name (if non-empty and not 'BRAND')
2. Princeps reference name
3. Canonical generic name
4. Specialty name
```

**Example**: "AMOXICILLINE TEVA 500 mg" → displays as "Amoxicilline"

### Aggregation Philosophy

Multiple medications in a group show aggregated values:

| Property | Aggregation |
|----------|-------------|
| Price | Min-max range (€4.50 - €12.00) |
| Refund | All applicable rates (65%, 100%) |
| Conditions | Union of all conditions |
| Availability | Worst status (shortage > OK) |

---

## Search Philosophy

### Full-Text Search with Trigram Tokenization

- Optimized for French medication names
- Handles partial matches
- Accent-insensitive
- Typo-tolerant

### Query Normalization

- Lowercase
- Remove accents
- Remove extra spaces
- Handle typos

---

## Equivalence Display Philosophy

### Princeps Indicators
- **Badge**: "Princeps" or "Réf"
- **Visual**: Hero card styling
- **Priority**: Always shown first

### Generic Indicators
- **Badge**: "Générique"
- **Visual**: List items below princeps
- **Count**: "X génériques disponibles"

### Related Medications
- **Section**: "Médicaments apparentés"
- **Content**: Princeps from related clusters
- **Purpose**: Show same molecule, different dosages

---

## User Experience Philosophy

| Goal | Principle |
|------|-----------|
| Quick search | Instant results, no network required |
| Clear equivalence | Princeps hero card, generics list |
| Confidence building | Regulatory badges, pricing info |
| Comprehensive browsing | A-Z sidebar, filter options |
| Offline capable | Full database on device |

---

## Core Architectural Principles

### 1. Brand-Centric Organization
- Users think in terms of brand names
- Alphabetical ordering follows brands
- Generics reference their princeps

### 2. Scanner-First Design
- CIP is the primary entry point
- Scanner drives the UX
- All data traceable to CIP

### 3. Therapeutic Clarity
- Show relationships, don't hide them
- Princeps defines the reference
- Generics clearly labeled

### 4. Offline Performance
- Full database on device
- No network required for core features
- Fast local queries
