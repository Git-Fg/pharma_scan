# Regex Brittleness in PharmaScan

## Overview

The data pipeline relies heavily on regex-based string manipulation to normalize medication names and determine therapeutic equivalence. This approach works for standard cases but is **brittle** and breaks on edge cases.

**Core Issue**: The pipeline derives relationships from string patterns alone, lacking semantic understanding of pharmaceutical domain knowledge.

**Critical Context**: The brittleness mainly affects **common pharmacy drawer forms** (oral solids/liquids, collyre, ORL, gynéco, dermato) - these are the primary use case. If regex fails for rare injectables, that's acceptable. But it MUST be robust for daily scanned items.

---

## Pharmacy Drawers: The Priority Scope

### Primary Focus (Must Work)

Forms commonly found in pharmacy tiroirs:

| Category | Forms | Why Critical |
|----------|-------|-------------|
| **Oral Solids** | comprimé, gélule, lyophilisat | Most common scanned items |
| **Oral Liquids** | sirop, suspension, solution | Pediatric/elderly frequent |
| **Ophthalmic** | collyre, pommade oculaire | High frequency, small packaging |
| **ORL** | spray nasal, gouttes auriculaires | Common over-the-counter |
| **Gynécologique** | ovule, crème vaginale | Drawer staple items |
| **Dermatologique** | crème, pommade, gel | High turnover |
| **Inhalation** | inhalateur, spray | Chronic conditions |

### Secondary Scope (Nice to Have)

Less common but useful:
- Pastilles pour la toux, suppositoires, other forms

### Out of Scope (Acceptable to Fail)

Hospital/clinical/specialized forms:
- Injectables, perfusions, radiopharmaceuticals
- If regex fails here, it's not blocking the core use case

**Principle**: Optimize regex brittleness fixes for the 80% of daily scans first. The 20% (rare forms) can be improved later or handled manually.

---

## Regex Priority: Common Forms First

### Implications for Clustering Optimization

The regex brittleness fixes should be **prioritized by form frequency**:

#### Tier 1: Critical (Fix Immediately)

| Form | Typical BDPM Patterns | Priority |
|------|----------------------|----------|
| **Gélule** | "XXX mg, gélule", "XXX mg gélule", "gélules B/30" | 🔥 Critical |
| **Comprimé** | "comprimé", "comprimés", "comprimé pelliculé", "comprimé sécable" | 🔥 Critical |
| **Sirop** | "sirop", "solution buvable", "suspension buvable" | 🔥 Critical |
| **Collyre** | "collyre", "solution pour instillation", "gouttes oculaires" | 🔥 Critical |
| **Crème** | "crème", "pommade", "gel", "émulsion" | 🔥 Critical |

**Why**: These represent 80%+ of daily scans. Regex MUST handle these flawlessly.

#### Tier 2: Important (Fix Soon)

| Form | Typical BDPM Patterns | Priority |
|------|----------------------|----------|
| **Suppositoire** | "suppositoire", "supp" | ⚠️ Important |
| **Inhalateur** | "inhalateur", "spray buccal" | ⚠️ Important |
| **Ovule** | "ovule", "gélule vaginale" | ⚠️ Important |
| **Spray nasal** | "spray nasal", "solution pour pulvérisation" | ⚠️ Important |

#### Tier 3: Nice-to-Have (Fix Eventually)

| Form | Notes | Priority |
|------|-------|----------|
| **Injectable** | Hospital use, less common in community pharmacy | 📌 Later |
| **Perfusion** | Hospital use | 📌 Later |
| **Pastille** | Low frequency | 📌 Later |

### Example: Pharmacological Masking Priority

**Current** (Generic masking for all forms):
```typescript
// Tries to mask ALL galenic forms equally
const index = normLabel.lastIndexOf(normForm);
```

**Proposed** (Prioritized by form frequency):
```typescript
// High-priority forms get more robust handling
const HIGH_PRIORITY_FORMS = [
    "gélule", "comprimé", "sirop", "collyre", "crème"
    // These MUST match with typos, plurals, abbreviations
];

const LOW_PRIORITY_FORMS = [
    "injectable", "perfusion", "radiopharmaceutique"
    // These can fail gracefully
];
```

**Benefit**: Development effort focuses on what matters most for daily use.

---

## Why Regex Is Used

### BDPM Data Inconsistency
The BDPM source files have inconsistent naming:
- "AMOXICILLINE TRIHYDRATE" vs "AMOXICILLINE"
- "CHLORHYDRATE DE PROPRANOLOL" vs "PROPRANOLOL"
- "HEMIFUMARATE D'ATOMOXETINE" vs "ATOMOXETINE"

### Pipeline Strategy
1. Strip salt prefixes/suffixes (regex)
2. Find Longest Common Substring (LCS) for cluster naming
3. Mask galenic forms (substring matching)

---

## How Regex Brittleness Affects CIP Naming

### The Core Goal for CIPs

For each CIP in the system, we need:
1. **Clean Brand Name**: For alphabetical sorting and scanner display
2. **Clean Generic Name**: For therapeutic equivalence and clustering

### How Regex Brittleness Breaks This

| Issue | Regex Approach | What Happens | Desired Behavior |
|-------|---------------|--------------|------------------|
| **Salt in BDPM data** | `AMOXICILLINE TRIHYDRATE` → `AMOXICILLINE` | Works if pattern matched | ✅ Should work always |
| **Missing pattern** | `TOSYLATE D'OLANZAPINE` → No match | ❌ Breaks, shows raw name | ✅ Should show "Olanzapine" |
| **LCS failure** | `["Advil", "Ibuprofène"]` → No common substring | ❌ No relationship found | ✅ Should link via composition |
| **Placeholder brand** | `princeps_brand_name = "BRAND"` | ⚠️ Falls back to generic name | ✅ Should have clean brand |

### Real-World Impact on Scanner/Explorer

```
User scans: CIP 3400930234259 (Clamoxyl)
  ↓
Current: Regex salt stripping + LCS naming
  ↓
Result: "CLAMOXYL 500 MG GELULE B/30" (raw BDPM name)
  ↓
User sees: Confusing, not alphabetically sortable

Desired: Composition lookup → clean brand/generic names
  ↓
Result: Brand: "Clamoxyl" | Generic: "Amoxicilline"
  ↓
User sees: Clear, alphabetically sorted under "C"
```

### The Rangement Problem

When regex fails, alphabetical sorting breaks:

| Brand Name | Sort Position (Regex) | Sort Position (Desired) |
|------------|----------------------|-------------------------|
| "CLAMOXYL" | ✅ Under "C" | ✅ Under "C" |
| "AMOXICILLINE TEVA" | ⚠️ Under "A" (should be under "C" for Clamoxyl) | ✅ Under "C" |
| "PARACETAMOL" | ⚠️ Under "P" (should be under "D" for Doliprane) | ✅ Under "D" |
| "IBUPROFENE BIOGARAN" | ⚠️ Under "I" (should be under "A" for Advil) | ✅ Under "A" |

**Root Cause**: No semantic link between brand names and their generic equivalents. Regex can't understand that "Ibuprofène Biogaran" is a generic of "Advil".

---

## Brittle Point #1: Salt Stripping

### Complexity
65+ salt patterns with complex edge cases:

```
Prefixes (must check longest-first):
- CHLORHYDRATE DE, CHLORHYDRATE D'
- HEMIFUMARATE DE, HEMIFUMARATE D'
- SESQUIHYDRATE, MONOHYDRATE, DIHYDRATE
- TETRAHYDRATE, PENTAHYDRATE, HEXAHYDRATE
- ... 50+ more

Suffixes (removed with while loop):
- MONOHYDRATE, DIHYDRATE, TRIHYDRATE
- ANHYDRE, SODIQUE, POTASSIQUE
- MAGNESIEN, CALCIQUE
- ... 40+ more
```

### Problems

#### 1. Order Dependency
```
MUST check "CHLORHYDRATE DE" before "CHLORHYDRATE"
Otherwise: "CHLORHYDRATE DE PROPRANOLOL" → " DE PROPRANOLOL" (broken)
```

#### 2. Accent Handling
```
Must normalize accents before matching
"HÉMIFUMARATE" ≠ "HEMIFUMARATE" without normalization
```

#### 3. Special Cases
```
"D'" vs "DE" prefixes have special handling
HEMIFUMARATE D'ATOMOXETINE → ATOMOXETINE (works)
HEMIFUMARATE DE ATOMOXETINE → ATOMOXETINE (works)
HEMIFUMARATE DE L'ATOMOXETINE → L'ATOMOXETINE (broken!)
```

#### 4. Complex While Loop
```
Suffix removal requires while loop for multi-step removal
"PARACETAMOL CHLORHYDRATE MONOHYDRATE"
  → Remove "MONOHYDRATE" → "PARACETAMOL CHLORHYDRATE"
  → Remove "CHLORHYDRATE" → "PARACETAMOL"
But what if order is wrong?
```

### Real-World Failures

| Input | Expected | Actual |
|-------|----------|--------|
| "AMOXICILLINE TRIHYDRATE" | "AMOXICILLINE" | ✅ Works |
| "HEMIFUMARATE D'ATOMOXETINE" | "ATOMOXETINE" | ✅ Works |
| "CHLORHYDRATE DE PROPRANOLOL" | "PROPRANOLOL" | ⚠️ Order-dependent |
| "SELS DE POTASSIUM" | "POTASSIUM" | ❌ Pattern missing |
| "TOSYLATE D'OLANZAPINE" | "OLANZAPINE" | ❌ Pattern missing |

---

## Brittle Point #2: LCS Algorithm

### Implementation
```
Uses Longest Common Substring with word boundary regex
Checks if candidate substring exists in all strings
```

### Problems

#### 1. No Semantic Understanding
```
"Paracetamol" ≠ "Acétaminophène" (same drug, different names)
"Doliprane" ≠ "Paracétamol" (brand vs ingredient)
LCS cannot understand therapeutic equivalence
```

#### 2. TIMOPTOL 0 Issue
```
LCS can result in single-digit truncations
"TIMOPTOL 0.25%" + "TIMOPTOL 0.50%"
LCS might produce: "TIMOPTOL 0" (ambiguous)
```

#### 3. Word Boundary Issues
```
Regex \b doesn't work with accented characters
"AMOXICILLINE" might not match "AMOXICILLINE" (with accent)
```

#### 4. Context-Blind
```
Doesn't understand pharmaceutical conventions
"IBUPROFENE 400 mg" vs "IBUPROFENE 600 mg"
LCS doesn't know these are posologically equivalent
```

### Real-World Failures

| Inputs | Expected LCS | Actual LCS |
|--------|--------------|------------|
| ["Advil", "Ibuprofène"] | "Ibuprofène" | "" (no match) |
| ["Doliprane", "Paracétamol"] | "Paracétamol" | "" (no match) |
| ["TIMOPTOL 0.25%", "TIMOPTOL 0.50%"] | "TIMOPTOL" | "TIMOPTOL 0" |
| ["Clamoxyl", "Amoxicilline"] | "Amoxicilline" | "" (no match) |

---

## Brittle Point #3: Pharmacological Masking

### Implementation
```
Finds last occurrence of galenic form in string
Removes form and trailing punctuation
```

### Problems

#### 1. Exact Form Required
```
Must have exact galenic form in database
"comprimé" ≠ "comprimés" (plural)
"gélule" ≠ "gelule" (missing accent)
```

#### 2. Comma Dependency
```
Relies on consistent formatting
"CLAMOXYL 500 mg, gélule" → "CLAMOXYL 500 mg" ✅
"CLAMOXYL 500 mg gélule" → "CLAMOXYL 500 mg gélule" ❌
```

#### 3. No Fallback Logic
```
If form not found, entire string is returned
No partial matching or similarity scoring
```

### Real-World Failures

| Input | Form | Expected | Actual |
|-------|------|----------|--------|
| "CLAMOXYL 500 mg, gélule" | "gélule" | "CLAMOXYL 500 mg" | ✅ Works |
| "CLAMOXYL 500 mg gelule" | "gélule" | "CLAMOXYL 500 mg" | ❌ No match |
| "CLAMOXYL 500 mg, comprimés" | "comprimé" | "CLAMOXYL 500 mg" | ❌ Singular/plural |
| "CLAMOXYL 500 mg gélule" | "gélule" | "CLAMOXYL 500 mg" | ❌ Missing comma |

---

## The Core Issue: No Semantic Understanding

### What the Pipeline Does
```
Algorithmic string manipulation
Brand: "CLAMOXYL" → ???
Ingredient: "AMOXICILLINE" → ???
Result: No relationship derived from strings alone
```

### What the Pipeline Should Use
```
BDPM data already contains composition
CIS_COMPO_bdpm.txt:
CIS: 61983278
Substance Code: 0045 (amoxicilline)
Result: Direct brand → ingredient lookup
```

### Examples of Semantic Gaps

| Brand | Ingredient | Current Approach | Desired Approach |
|-------|------------|------------------|------------------|
| Doliprane | Paracétamol | ❌ No regex match | ✅ Composition lookup |
| Clamoxyl | Amoxicilline | ❌ No regex match | ✅ Composition lookup |
| Advil | Ibuprofène | ❌ No regex match | ✅ Composition lookup |
| Spasfon | Phloroglucinol | ❌ No regex match | ✅ Composition lookup |

---

## Impact on User Experience

### Scanner Flow (Current - Brittle)
```
1. User scans: "CLAMOXYL" barcode
2. Pipeline uses: Salt stripping + LCS + masking
3. Result: Might fail on edge case
4. User sees: "Unknown medication" or confusing name ❌
```

### Scanner Flow (Desired - Robust)
```
1. User scans: "CLAMOXYL" barcode
2. Lookup: CIP → CIS → Composition (substance)
3. Result: Always finds active ingredient
4. User sees: "Amoxicilline" ✅
```

---

## Potential Solutions

### 1. Composition-Based Lookup (Recommended)

Use BDPM composition data directly:

```
function getActiveIngredient(cipCode: CIP): string {
    const cis = getCISFromCIP(cipCode);
    const composition = getCIS_COMPO(cis);
    return composition.substanceName; // Direct lookup
}
```

**Advantages**:
- No regex needed
- Always accurate (source of truth)
- Handles all edge cases

### 2. Pre-Computed Alias Tables

Manual overrides for known brands:

```
const BRAND_ALIASES = {
    "CLAMOXYL": "AMOXICILLINE",
    "DOLIPRANE": "PARACETAMOL",
    "ADVIL": "IBUPROFENE",
    // ...
};
```

**Advantages**:
- Simple implementation
- Covers common cases
- Easy to maintain

**Disadvantages**:
- Manual effort required
- Doesn't scale to new medications

### 3. Semantic Indexing

Pre-compute brand → ingredient mappings:

```
function buildSemanticIndex() {
    // Scan all composition entries
    // Build brandName → substanceName map
    // Store as lookup table
}
```

**Advantages**:
- Automatic from BDPM data
- No manual curation
- Handles edge cases

---

## Recommended Solution

**Primary Solution**: Composition-based lookup using BDPM composition data

**Rationale**:
- BDPM already contains the data we need
- No regex brittleness
- Always accurate (source of truth)
- Simple implementation

**Implementation Strategy**:
1. Parse composition data from BDPM source
2. Create CIP → substance relationship
3. Add clean brand/generic name fields to all medication records
4. Use these fields for display and sorting

**Result**: Every CIP has both a clean brand name (for rangement) and a clean generic name (for therapeutic equivalence display).

---

## Philosophical Takeaways

### 1. String Manipulation ≠ Domain Understanding
- Regex operates on characters, not pharmaceutical concepts
- Cannot understand therapeutic equivalence
- Breaks on edge cases

### 2. Use the Source of Truth
- BDPM already has composition data
- Don't derive what's already provided
- Direct lookup > pattern matching

### 3. User Experience Depends on Clean Data
- Scanner needs clear brand names
- Alphabetical sorting needs consistency
- Regex brittleness directly impacts UX

### 4. Fail-Safe Design
- When regex fails, user gets confusing data
- Composition lookup always works
- Robustness > cleverness
