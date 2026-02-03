# Backend vs Frontend Data Flow Analysis

## The Core Issue Identified

After investigating the backend data, frontend code, and documentation, **there's a fundamental disconnect** between:

1. **What the philosophy documents say we should have**
2. **What the backend actually produces**
3. **What the frontend expects and uses**

---

## Data Flow: Backend → Frontend

### Backend Data Structure

| Level | Table | Field | Actual Data |
|-------|-------|-------|-------------|
| **CIP** | `medicaments` | `cip_code` | "3400931587538" |
| **CIS** | `medicament_summary` | `princeps_brand_name` | "CLAMOXYL 500 mg, gélule" |
| **CIS** | `medicament_summary` | `nom_canonique` | "CLAMOXYL 500 mg, gélule" |
| **CIS** | `medicament_summary` | `princeps_de_reference` | "CLAMOXYL 125 MG/5 ML" |
| **Cluster** | `cluster_index` | `title` | "CLAMOXYL" ✓ (clean!) |
| **Cluster** | `cluster_index` | `subtitle` | "Ref: CLAMOXYL 125 MG/5 ML" |

### Frontend Display Logic

From `view_group_detail_extensions.dart`:

```dart
// For product display name
String get displayName {
    if (isPrinceps) {
        final brandName = princepsBrandName.trim();  // "CLAMOXYL 500 mg, gélule"
        if (brandName.isNotEmpty && brandName.toUpperCase() != 'BRAND') {
            return brandName;  // Returns FULL NAME with form!
        }
        return princepsDeReference.trim();
    }
    final nom = nomCanonique;
    final parts = nom.split(' - ');
    return parts.first.trim();
}

// For group header title
final brandName = first.princepsBrandName.trim();  // "CLAMOXYL 500 mg, gélule"
final title = (brandName.isNotEmpty)
    ? brandName  // Uses FULL NAME, not cluster name!
    : (princepsRef.isNotEmpty ? princepsRef : nomCanon);
```

---

## The Problem

### Philosophy vs Reality

| Philosophy Document | Reality |
|---------------------|--------|
| **For each CIP, need clean Brand Name** (e.g., "CLAMOXYL") | `princeps_brand_name` = "CLAMOXYL 500 mg, gélule" |
| **For each CIP, need clean Generic Name** (e.g., "amoxicilline") | Generic name is buried in full name or cluster level |
| **Rangement: Sort by brand name** | Frontend sorts by `displayName` which includes form! |

### What Actually Happens

1. **User scans**: CIP 3400931587538
2. **Backend lookup**: `princeps_brand_name` = "CLAMOXYL 500 mg, gélule"
3. **Frontend displays**: "CLAMOXYL 500 mg, gélule" (not clean!)
4. **Rangement sorts**: "CLAMOXYL 500 mg, gélule" under "C" (with form)

**Result**: The system works, but NOT according to the philosophy docs' ideal state.

---

## Root Cause Analysis

### Why `princeps_brand_name` Contains Full Names

Looking at the backend pipeline code comments:

```typescript
// From view_group_detail_extensions.dart line 27
// Correction: n'utilise princepsBrandName que s'il est non vide ET différent de 'BRAND'
```

This comment suggests:
1. `princeps_brand_name` was originally intended to be a CLEAN brand name
2. But it's actually populated with the FULL name from `nom_specialite`
3. The "BRAND" placeholder check exists but never fires (no actual "BRAND" values in data)

### Why Cluster Titles Have 90.2% Forms/Dosage

The test revealed:
- 2,386 out of 2,426 clusters have forms/dosage in their title
- Examples: "DOLIPRANEVITAMINEC /", "CODOLIPRANE ADULTES /"
- LCS (Longest Common Substring) algorithm produces these complex names

**Root Cause**: LCS doesn't isolate the brand name from the full medication name.

---

## The Real Questions

### Question 1: Is the Philosophy Wrong?

**Maybe.** The philosophy assumes we can have:
- Clean Brand Name: "CLAMOXYL" (just the brand)
- Clean Generic Name: "amoxicilline" (just the ingredient)

But in reality:
- BDPM doesn't have separate "brand name" field
- Raw data is "CLAMOXYL 500 mg, gélule" (brand + dosage + form)
- Parsing this cleanly is very hard (regex brittleness!)

### Question 2: Is the Backend Wrong?

**Partially.** The backend produces:
- Full names in `princeps_brand_name` (matches BDPM `nom_specialite`)
- Clean names in `cluster_index.title` (LCS algorithm result)

**Issue**: LCS produces names like "DOLIPRANEVITAMINEC /" instead of clean "DOLIPRANE".

### Question 3: Is the Frontend Wrong?

**No.** The frontend correctly uses what the backend provides. It displays `princeps_brand_name` which is the full medication name - this is actually useful for users!

---

## What the Tests Should Actually Verify

### ✓ What Works (Don't Break This)

1. **Full name display**: "CLAMOXYL 500 mg, gélule" is USEFUL for users
2. **Cluster grouping**: All Clamoxyl forms ARE in one cluster
3. **Princeps reference**: "Ref: CLAMOXYL 125 MG/5 ML" is shown
4. **Search functionality**: Finding "clamoxyl" works

### ⚠️ What Could Be Better (Optimization)

1. **Rangement**: Could sort by "CLAMOXYL" instead of "CLAMOXYL 500 mg, gélule"
   - Current: Sorts by full name (with form)
   - Ideal: Sorts by clean brand name

2. **Scanner display**: Could show "Clamoxyl 500 mg" instead of "CLAMOXYL 500 mg, gélule"
   - Current: Full BDPM name
   - Ideal: Clean brand + dosage (remove form)

3. **Cluster names**: Could be cleaner than "DOLIPRANEVITAMINEC /"
   - Current: LCS produces complex names
   - Ideal: Just "DOLIPRANE" or "PARACETAMOL"

---

## Recommended Test Strategy

### Focus on What Matters for User Experience

**Don't test**: Whether `princeps_brand_name` is "clean" (it's not, and that's okay)

**Do test**:
1. ✓ Cluster grouping works (all Clamoxyl forms together)
2. ✓ Search works (find "clamoxyl" returns results)
3. ✓ Princeps reference exists (shows which is reference)
4. ✓ Pharmacy drawer forms are well-represented
5. ✓ Data completeness (low orphan rate)

### Accept Reality Over Philosophy

The philosophy documents describe an **ideal state** that may not be achievable with BDPM data alone.

**Actual state**:
- BDPM has "CLAMOXYL 500 mg, gélule" as the medication name
- We can parse out "CLAMOXYL" (brand) and "500 mg" (dosage) and "gélule" (form)
- But this is exactly the regex brittleness problem!

**Better approach**:
1. Accept that `princeps_brand_name` = full name (this is correct!)
2. Add a NEW computed field for "clean brand name" at cluster level
3. Use composition lookup for generic names
4. Tests should verify the NEW fields, not the existing ones

---

## Conclusion

The core issue is **not that tests are wrong** - it's that:

1. **The philosophy documents describe an ideal state** that doesn't match the implementation
2. **The backend produces what BDPM gives it** (full names with forms)
3. **The frontend correctly displays what the backend provides**
4. **Tests verify the wrong things** (cleanliness vs functionality)

**Recommendation**: Update tests to verify **functionality** (clustering, search, completeness) rather than **cleanliness** (no forms in names).

The "clean brand name" concept needs to be **implemented as a new feature**, not tested as if it already exists.
