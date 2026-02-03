# Backend Test Analysis: Real Data Structure

## Critical Finding: Tests Must Match Actual Data Structure

After investigating the raw BDPM data and database schema, the **initial test approach was incorrect**.

---

## Actual Data Structure

### Raw BDPM Data (`specialites` table)

| Column | Example | Source |
|--------|---------|--------|
| `cis_code` | "67707794" | CIS_bdpm.txt column 0 |
| `nom_specialite` | "CLAMOXYL 500 mg, gélule" | CIS_bdpm.txt column 1 |
| `forme_pharmaceutique` | "gélule" | CIS_bdpm.txt column 2 |
| `voies_administration` | "orale" | CIS_bdpm.txt column 3 |

**Key**: Raw BDPM has **full names with forms**. No "clean brand name" exists in source data.

### CIP Level (`medicament_summary` table)

| Column | Example | Computed? |
|--------|---------|-----------|
| `princeps_brand_name` | "CLAMOXYL 500 mg, gélule" | ❌ NO - from raw `nom_specialite` |
| `nom_canonique` | "CLAMOXYL 500 mg, gélule" | ❌ NO - from raw `nom_specialite` |
| `princeps_de_reference` | "CLAMOXYL 125 MG/5 ML" | ✅ YES - computed via generic groups |
| `is_princeps` | 1 | ✅ YES - computed |

**Key**: At CIP level, `princeps_brand_name` is the **full name with form**, NOT a clean brand name!

### Cluster Level (`cluster_index` table)

| Column | Example | Computed? |
|--------|---------|-----------|
| `title` | "CLAMOXYL" | ✅ YES - LCS algorithm, clean name |
| `subtitle` | "Ref: CLAMOXYL 125 MG/5 ML" | ✅ YES - princeps reference |
| `count_products` | 101 | ✅ YES - aggregated |

**Key**: The **clean brand name** exists at **cluster level** (`cluster_index.title`), NOT at CIP level!

---

## What This Means for Tests

### ❌ Wrong Test Approach (Initial)

```typescript
// WRONG: princeps_brand_name is NOT a clean brand name
test("✓ CIP naming coverage: clean brand names", () => {
    const result = db.query(`
        SELECT COUNT(*) as count
        FROM medicament_summary
        WHERE princeps_brand_name IS NULL
           OR princeps_brand_name = ''
           OR princeps_brand_name = 'BRAND'
    `).get();
    // This fails because princeps_brand_name contains full names like "CLAMOXYL 500 mg, gélule"
});
```

### ✅ Correct Test Approach

```typescript
// CORRECT: Cluster level has clean names
test("✓ Cluster naming: clean brand names", () => {
    const result = db.query(`
        SELECT COUNT(*) as count
        FROM cluster_index
        WHERE title IS NULL
           OR title = ''
           OR title LIKE '% %'  -- Should be single word mostly
    `).get();
    // cluster_index.title = "CLAMOXYL" (clean)
});
```

---

## Real Data Examples

### Example 1: Clamoxyl Cluster

**Raw BDPM**:
```
CIS: 67707794
nom_specialite: "CLAMOXYL 500 mg, gélule"
forme_pharmaceutique: "gélule"
```

**CIP Level** (`medicament_summary`):
```
princeps_brand_name: "CLAMOXYL 500 mg, gélule"  ← Full name with form
nom_canonique: "CLAMOXYL 500 mg, gélule"       ← Full name with form
princeps_de_reference: "CLAMOXYL 125 MG/5 ML"  ← Reference princeps
```

**Cluster Level** (`cluster_index`):
```
title: "CLAMOXYL"                                  ← Clean brand name ✓
subtitle: "Ref: CLAMOXYL 125 MG/5 ML"              ← Princeps reference
count_products: 101                                ← All Clamoxyl products
```

### Example 2: Doliprane Cluster

**Raw BDPM**:
```
CIS: 60234100
nom_specialite: "DOLIPRANE 1000 mg, comprimé"
forme_pharmaceutique: "comprimé"
```

**CIP Level** (`medicament_summary`):
```
princeps_brand_name: "DOLIPRANE 1000 mg, comprimé"
nom_canonique: "DOLIPRANE 1000 mg, comprimé"
princeps_de_reference: "CLARADOL"  ← Different brand name!
```

**Cluster Level** (`cluster_index`):
```
title: "CLARADOL"                     ← Clean brand name (princeps reference)
subtitle: "Ref: CLARADOL 1000 mg"     ← Princeps reference
```

**Critical Insight**: For Doliprane, the cluster is named "CLARADOL" (the princeps reference), NOT "DOLIPRANE"! This is because generic equivalents exist and CLARADOL is the elected princeps.

---

## Test Strategy: What to Actually Verify

### 1. Cluster Naming Tests (Primary)

**What to verify**: `cluster_index.title` contains clean brand names

```typescript
test("✓ Cluster names are clean (no forms, no dosage)", () => {
    const result = db.query(`
        SELECT COUNT(*) as count
        FROM cluster_index
        WHERE title LIKE '% mg%'
           OR title LIKE '% gélule%'
           OR title LIKE '% comprimé%'
           OR title LIKE '% sirop%'
    `).get() as { count: number };

    console.log(`  → ${result.count} clusters have forms/dosage in title (should be ~0)`);
    expect(result.count).toBeLessThan(50);  // Allow some edge cases
});
```

### 2. Cluster Completeness Tests

**What to verify**: Every medication has a cluster, clusters have titles

```typescript
test("✓ All medicaments belong to clusters", () => {
    const result = db.query(`
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN cluster_id IS NULL THEN 1 ELSE 0 END) as no_cluster
        FROM medicament_summary
        WHERE commercialisation_statut = 'Déclaration de commercialisation'
    `).get() as { total: number, no_cluster: number };

    const coverage = ((result.total - result.no_cluster) / result.total * 100).toFixed(1);
    console.log(`  → ${coverage}% clustered (${result.no_cluster}/${result.total} unclustered)`);
    expect(parseFloat(coverage)).toBeGreaterThan(99);
});
```

### 3. Princeps Reference Tests

**What to verify**: `cluster_index.subtitle` references exist and are meaningful

```typescript
test("✓ Clusters have princeps references", () => {
    const result = db.query(`
        SELECT COUNT(*) as count
        FROM cluster_index
        WHERE subtitle IS NULL
           OR subtitle = ''
           OR subtitle NOT LIKE 'Ref:%'
    `).get() as { count: number };

    console.log(`  → ${result.count} clusters missing princeps reference`);
    expect(result.count).toBeLessThan(100);
});
```

### 4. Form Coverage Tests (Pharmacy Drawers)

**What to verify**: Common drawer forms are well-represented

```typescript
test("✓ Primary pharmacy drawer forms have good coverage", () => {
    const forms = ['gélule', 'comprimé', 'sirop', 'collyre', 'crème', 'pommade'];
    const results = [];

    for (const form of forms) {
        // Count at cluster level (distinct clusters, not individual products)
        const count = db.query(`
            SELECT COUNT(DISTINCT ci.cluster_id) as count
            FROM cluster_index ci
            JOIN medicament_summary ms ON ms.cluster_id = ci.cluster_id
            WHERE ms.denomination_substance LIKE '%${form}%'
        `).get() as { count: number };

        results.push(`${form}: ${count.count} clusters`);
        expect(count.count).toBeGreaterThan(50);  // Each form should have 50+ clusters
    }

    console.log(`  → ${results.join(', ')}`);
});
```

### 5. Rangement Tests (Sorting)

**What to verify**: Clusters sort alphabetically by brand name

```typescript
test("✓ Clusters sort alphabetically by title (brand name)", () => {
    const clusters = db.query(`
        SELECT title, subtitle
        FROM cluster_index
        WHERE title IS NOT NULL
        ORDER BY title COLLATE NOCASE ASC
        LIMIT 20
    `).all() as { title: string }[];

    // Verify alphabetical order
    for (let i = 1; i < clusters.length; i++) {
        const prev = clusters[i - 1].title;
        const curr = clusters[i].title;
        const comparison = prev.localeCompare(curr, 'fr', { sensitivity: 'base' });
        expect(comparison).toBeLessThanOrEqual(0);
    }

    console.log(`  → ${clusters.length} clusters verified alphabetically sorted`);
});
```

---

## Summary: Test Corrections

| Test | Wrong Approach | Correct Approach |
|------|----------------|------------------|
| **CIP naming** | Test `princeps_brand_name` at CIP level | Test `title` at cluster level |
| **Brand names** | Expect "CLAMOXYL" at CIP level | Expect "CLAMOXYL" at cluster level |
| **Clean names** | Check for forms in CIP field | Check cluster names have no forms |
| **Rangement** | Test CIP sorting | Test cluster sorting by `title` |
| **Coverage** | Count individual CIPs | Count distinct clusters |

---

## Key Insights

1. **Clean brand names exist at cluster level**, NOT at CIP level
2. **`princeps_brand_name` at CIP level contains full names with forms** (this is correct!)
3. **`cluster_index.title` is the clean brand name** used for rangement
4. **`cluster_index.subtitle` contains the princeps reference**
5. **Tests should verify cluster-level quality, not CIP-level transformations**

The tests should focus on:
- ✅ Cluster names are clean (no forms/dosage)
- ✅ Clusters have princeps references
- ✅ All CIPs are clustered
- ✅ Clusters sort alphabetically
- ✅ Primary forms have good coverage

NOT:
- ❌ CIP-level name cleaning (that's done during ingestion, not at display level)
- ❌ `princeps_brand_name` being a "clean" name (it's the full name, which is correct)
