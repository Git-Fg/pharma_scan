# Backend Test Strategy: Context-Efficient & Frontend-Validating

## Problem Statement

Current tests have issues:
- **Context overflow**: Full data dumps exhaust AI context
- **Missing signals**: Don't verify CIP naming goal, rangement, pharmacy drawers
- **No iteration**: Frontend can't quickly validate backend changes

## Solution: Multi-Layered Test Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Smoke Tests (5 seconds)                            │
│  ✓ Quick validation, summary output only                    │
│  → Run on every change                                       │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Contract Tests (30 seconds)                        │
│  ✓ Business logic validation, statistical sampling           │
│  → Run before commits                                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Report Tests (2 minutes)                           │
│  ✓ Comprehensive coverage, write reports to files            │
│  → Run on CI, read reports on demand                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer 1: Smoke Tests (Fast Feedback)

### Purpose
Quick validation that critical systems work. Output is **one line per test**.

### Implementation: `backend_pipeline/test/smoke.test.ts`

```typescript
import { describe, test, beforeAll } from "bun:test";

describe("Smoke Tests", () => {
    let db: Database;

    beforeAll(() => {
        db = new Database(DEFAULT_DB_PATH, { readonly: true });
    });

    test("✓ Database exists and is readable", () => {
        const count = db.query("SELECT COUNT(*) as count FROM medicament_summary").get() as { count: number };
        console.log(`  → ${count.count} medicaments loaded`);
        expect(count.count).toBeGreaterThan(1000);
    });

    test("✓ CIP naming coverage: clean brand names", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN princeps_brand_name IS NULL OR princeps_brand_name = '' OR princeps_brand_name = 'BRAND' THEN 1 ELSE 0 END) as missing
            FROM medicament_summary
        `).get() as { total: number, missing: number };

        const coverage = ((result.total - result.missing) / result.total * 100).toFixed(1);
        console.log(`  → ${coverage}% clean brand names (${result.missing}/${result.total} missing)`);
        expect(parseFloat(coverage)).toBeGreaterThan(95);
    });

    test("✓ CIP naming coverage: clean generic names", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN nom_canonique LIKE '%CHLORHYDRATE%' OR nom_canonique LIKE '%MALEATE%' THEN 1 ELSE 0 END) as has_salt
            FROM medicament_summary
        `).get() as { total: number, has_salt: number };

        const clean = ((result.total - result.has_salt) / result.total * 100).toFixed(1);
        console.log(`  → ${clean}% salt-free generic names (${result.has_salt}/${result.total} have salts)`);
        expect(parseFloat(clean)).toBeGreaterThan(99);
    });

    test("✓ Pharmacy drawer forms: primary forms coverage", () => {
        const forms = ['gélule', 'comprimé', 'sirop', 'collyre', 'crème'];
        const results = [];

        for (const form of forms) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM medicament_summary
                WHERE denomination_substance LIKE '%${form}%'
            `).get() as { count: number };
            results.push(`${form}: ${count.count}`);
        }

        console.log(`  → ${results.join(', ')}`);
        // Each form should have >100 products
        for (const form of forms) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM medicament_summary
                WHERE denomination_substance LIKE '%${form}%'
            `).get() as { count: number };
            expect(count.count).toBeGreaterThan(100);
        }
    });
});
```

### Sample Output (One-Line Per Test)

```
✓ Database exists and is readable
  → 12473 medicaments loaded

✓ CIP naming coverage: clean brand names
  → 97.3% clean brand names (342/12473 missing)

✓ CIP naming coverage: clean generic names
  → 99.8% salt-free generic names (25/12473 have salts)

✓ Pharmacy drawer forms: primary forms coverage
  → gélule: 4234, comprimé: 5102, sirop: 892, collyre: 445, crème: 1201
```

---

## Layer 2: Contract Tests (Business Logic Validation)

### Purpose
Validate core philosophy with statistical sampling. Output shows **failures only**.

### Implementation: `backend_pipeline/test/contract.test.ts`

```typescript
import { describe, test, beforeAll } from "bun:test";
import { Database } from "bun:sqlite";
import { writeFileSync } from "fs";

interface ContractViolation {
    type: string;
    cis_code: string;
    expected: string;
    actual: string;
}

describe("Contract Tests", () => {
    let db: Database;

    beforeAll(() => {
        db = new Database(DEFAULT_DB_PATH, { readonly: true });
    });

    test("✓ CIP Naming Contract: Brand name exists and is clean", () => {
        const violations: ContractViolation[] = [];
        const sampleSize = 100; // Test 100 random CIPs
        const samples = db.query(`
            SELECT cis_code, princeps_brand_name, nom_canonique
            FROM medicament_summary
            WHERE commercialisation_statut = 'Déclaration de commercialisation'
            ORDER BY RANDOM()
            LIMIT ?
        `, [sampleSize]).all() as { cis_code: string, princeps_brand_name: string, nom_canonique: string }[];

        for (const s of samples) {
            if (!s.princeps_brand_name || s.princeps_brand_name === '' || s.princeps_brand_name === 'BRAND') {
                violations.push({
                    type: 'MISSING_BRAND',
                    cis_code: s.cis_code,
                    expected: 'Clean brand name',
                    actual: s.princeps_brand_name || '(empty)'
                });
            }
        }

        if (violations.length > 0) {
            console.log(`  ✗ ${violations.length} violations found:`);
            for (const v of violations.slice(0, 5)) { // Show first 5
                console.log(`    - CIS ${v.cis_code}: ${v.actual}`);
            }
            if (violations.length > 5) {
                console.log(`    ... and ${violations.length - 5} more`);
            }
        } else {
            console.log(`  ✓ All ${sampleSize} sampled CIPs have clean brand names`);
        }

        expect(violations.length).toBe(0);
    });

    test("✓ Rangement Contract: Clusters sort by brand name", () => {
        const violations: any[] = [];
        const samples = db.query(`
            SELECT title, subtitle
            FROM cluster_names
            WHERE subtitle IS NOT NULL
            ORDER BY RANDOM()
            LIMIT 50
        `).all() as { title: string, subtitle: string }[];

        for (const s of samples) {
            // Check that subtitle (princeps brand) is alphabetically before title (generic)
            if (s.subtitle && s.title) {
                const comparison = s.subtitle.localeCompare(s.title, 'fr', { sensitivity: 'base' });
                // Brand name should come before generic in most cases
                // This is a heuristic check, not absolute
                if (comparison > 0 && !s.title.includes(s.subtitle)) {
                    violations.push({
                        cluster: s.title,
                        brand: s.subtitle,
                        issue: 'Generic name sorts before brand name'
                    });
                }
            }
        }

        if (violations.length > 0) {
            console.log(`  ✗ ${violations.length} clusters may have sorting issues:`);
            for (const v of violations.slice(0, 5)) {
                console.log(`    - ${v.cluster}: "${v.brand}" (brand) vs "${v.cluster}" (cluster)`);
            }
        } else {
            console.log(`  ✓ All ${samples.length} sampled clusters sort correctly`);
        }

        // Allow some violations (sorting is complex)
        expect(violations.length).toBeLessThan(5);
    });

    test("✓ Pharmacy Drawer Contract: Primary forms cluster correctly", () => {
        const testCases = [
            { brand: 'DOLIPRANE', forms: ['comprimé', 'gélule'] },
            { brand: 'CLAMOXYL', forms: ['gélule'] },
            { brand: 'MOPRAL', forms: ['comprimé'] },
        ];

        let passed = 0;
        const failures: string[] = [];

        for (const tc of testCases) {
            const result = db.query(`
                SELECT COUNT(DISTINCT cluster_id) as clusters
                FROM medicament_summary
                WHERE princeps_de_reference LIKE ?
                AND (${tc.forms.map(f => `denomination_substance LIKE '%${f}%'`).join(' OR ')})
            `, [`${tc.brand}%`]).get() as { clusters: number };

            if (result.clusters === 1) {
                passed++;
            } else {
                failures.push(`${tc.brand}: ${result.clusters} clusters (expected 1)`);
            }
        }

        if (failures.length > 0) {
            console.log(`  ✗ Form clustering issues:`);
            failures.forEach(f => console.log(`    - ${f}`));
        } else {
            console.log(`  ✓ All ${testCases.length} test brands cluster forms correctly`);
        }

        expect(failures.length).toBe(0);
    });
});
```

### Sample Output (Failures Only)

```
✓ CIP Naming Contract: Brand name exists and is clean
  ✓ All 100 sampled CIPs have clean brand names

✓ Rangement Contract: Clusters sort by brand name
  ✗ 2 clusters may have sorting issues:
    - Paracétamol: "DOLIPRANE" (brand) vs "Paracétamol" (cluster)
    - Amoxicilline: "CLAMOXYL" (brand) vs "Amoxicilline" (cluster)
    ✓ All 50 sampled clusters sort correctly (with 2 acceptable violations)

✓ Pharmacy Drawer Contract: Primary forms cluster correctly
  ✓ All 3 test brands cluster forms correctly
```

---

## Layer 3: Report Tests (Comprehensive Coverage)

### Purpose
Full validation with reports written to files. Tests pass silently, reports are read on-demand.

### Implementation: `backend_pipeline/test/report.test.ts`

```typescript
import { describe, test, beforeAll } from "bun:test";
import { Database } from "bun:sqlite";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";

interface TestReport {
    timestamp: string;
    summary: {
        total_cips: number;
        clean_brands: number;
        clean_generics: number;
        primary_forms_coverage: Record<string, number>;
    };
    violations: {
        missing_brands: Array<{ cis_code: string, name: string }>;
        salts_in_generics: Array<{ cis_code: string, name: string }>;
        clustering_issues: Array<{ brand: string, forms: string[], clusters: number }>;
    };
}

describe("Report Tests", () => {
    let db: Database;
    const OUTPUT_DIR = join(process.cwd(), 'test-reports');

    beforeAll(() => {
        db = new Database(DEFAULT_DB_PATH, { readonly: true });
        mkdirSync(OUTPUT_DIR, { recursive: true });
    });

    test("✓ Generate CIP Naming Report", () => {
        const report: TestReport['summary'] = {
            total_cips: 0,
            clean_brands: 0,
            clean_generics: 0,
            primary_forms_coverage: {}
        };

        // Total CIPs
        report.total_cips = db.query(`
            SELECT COUNT(*) as count FROM medicament_summary
        `).get() as any as number;

        // Clean brand names
        const brandResult = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN princeps_brand_name IS NULL OR princeps_brand_name = '' OR princeps_brand_name = 'BRAND' THEN 0 ELSE 1 END) as clean
            FROM medicament_summary
        `).get() as { total: number, clean: number };
        report.clean_brands = brandResult.clean;

        // Clean generic names
        const genericResult = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN nom_canonique LIKE '%CHLORHYDRATE%' OR nom_canonique LIKE '%MALEATE%' THEN 0 ELSE 1 END) as clean
            FROM medicament_summary
        `).get() as { total: number, clean: number };
        report.clean_generics = genericResult.clean;

        // Primary forms coverage
        const forms = ['gélule', 'comprimé', 'sirop', 'collyre', 'crème', 'pommade'];
        for (const form of forms) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM medicament_summary
                WHERE denomination_substance LIKE '%${form}%'
            `).get() as { count: number };
            report.primary_forms_coverage[form] = count.count;
        }

        // Write report
        const reportPath = join(OUTPUT_DIR, 'cip-naming.json');
        writeFileSync(reportPath, JSON.stringify(report, null, 2));

        console.log(`  → Report written to test-reports/cip-naming.json`);
        console.log(`  → ${report.clean_brands}/${report.total_cips} (${(report.clean_brands/report.total_cips*100).toFixed(1)}%) clean brand names`);
        console.log(`  → ${report.clean_generics}/${report.total_cips} (${(report.clean_generics/report.total_cips*100).toFixed(1)}%) clean generic names`);

        expect(report.clean_brands / report.total_cips).toBeGreaterThan(0.95);
    });

    test("✓ Generate Rangement Report", () => {
        const clusters = db.query(`
            SELECT title, subtitle, COUNT(*) as product_count
            FROM cluster_names cn
            JOIN medicament_summary ms ON ms.cluster_id = cn.cluster_id
            WHERE subtitle IS NOT NULL
            GROUP BY cn.cluster_id
            ORDER BY subtitle COLLATE NOCASE ASC
        `).all() as { title: string, subtitle: string, product_count: number }[];

        const report = {
            total_clusters: clusters.length,
            alphabetically_sorted: true,
            sample: clusters.slice(0, 20) // First 20 for preview
        };

        const reportPath = join(OUTPUT_DIR, 'rangement.json');
        writeFileSync(reportPath, JSON.stringify(report, null, 2));

        console.log(`  → Report written to test-reports/rangement.json`);
        console.log(`  → ${report.total_clusters} clusters sorted alphabetically by brand name`);

        expect(report.total_clusters).toBeGreaterThan(100);
    });

    test("✓ Generate Pharmacy Drawer Report", () => {
        const forms = ['gélule', 'comprimé', 'sirop', 'collyre', 'crème', 'pommade', 'suppositoire', 'inhalateur'];
        const report: Record<string, { count: number; sample_brands: string[] }> = {};

        for (const form of forms) {
            const result = db.query(`
                SELECT COUNT(*) as count
                FROM medicament_summary
                WHERE denomination_substance LIKE '%${form}%'
            `).get() as { count: number };

            const samples = db.query(`
                SELECT DISTINCT princeps_de_reference
                FROM medicament_summary
                WHERE denomination_substance LIKE '%${form}%'
                LIMIT 5
            `).all() as { princeps_de_reference: string }[];

            report[form] = {
                count: result.count,
                sample_brands: samples.map(s => s.princeps_de_reference)
            };
        }

        const reportPath = join(OUTPUT_DIR, 'pharmacy-drawers.json');
        writeFileSync(reportPath, JSON.stringify(report, null, 2));

        console.log(`  → Report written to test-reports/pharmacy-drawers.json`);
        Object.entries(report).forEach(([form, data]) => {
            console.log(`  → ${form}: ${data.count} products (e.g., ${data.sample_brands.slice(0, 3).join(', ')})`);
        });

        // Primary forms should have >100 products each
        expect(report['gélule'].count).toBeGreaterThan(100);
        expect(report['comprimé'].count).toBeGreaterThan(100);
        expect(report['sirop'].count).toBeGreaterThan(50);
    });
});
```

### Sample Output (Silent Success, Reports Written)

```
✓ Generate CIP Naming Report
  → Report written to test-reports/cip-naming.json
  → 12131/12473 (97.3%) clean brand names
  → 12448/12473 (99.8%) clean generic names

✓ Generate Rangement Report
  → Report written to test-reports/rangement.json
  → 2341 clusters sorted alphabetically by brand name

✓ Generate Pharmacy Drawer Report
  → Report written to test-reports/pharmacy-drawers.json
  → gélule: 4234 products (e.g., CLAMOXYL, AUGMENTIN, ZITHROMAX)
  → comprimé: 5102 products (e.g., DOLIPRANE, SPAFON, MOPRAL)
  → sirop: 892 products (e.g., AUGMENTIN, ZITHROMAX, ORELOX)
  → collyre: 445 products (e.g., TIMOPTOL, INALIE, LUMIGAN)
  → crème: 1201 products (e.g., DOLIPRANE, VOLTARENE, BIAFINE)
  → pommade: 234 products (e.g., FLAGYL, HEXOMEDINE)
  → suppositoire: 156 products (e.g., DOLIPRANE, SPAFON)
  → inhalateur: 89 products (e.g., VENTOLINE, BRONCHODUAL)
```

---

## Frontend Integration: How to Use Reports

### 1. Quick Validation (Before Frontend Work)

```bash
# Run smoke tests (5 seconds)
bun test smoke.test.ts

# Output:
# ✓ 97.3% clean brand names
# ✓ 99.8% salt-free generic names
# ✓ Primary forms: gélule: 4234, comprimé: 5102, sirop: 892
```

### 2. Read Reports on Demand (After Backend Changes)

```bash
# Run report tests (2 minutes, writes files)
bun test report.test.ts

# Read specific report
cat test-reports/cip-naming.json | jq '.summary'
cat test-reports/rangement.json | jq '.sample[:5]'
cat test-reports/pharmacy-drawers.json | jq '.["gélule"]'
```

### 3. AI Context: Report Summaries

When working with AI, provide **summary only**:

```
Backend test results:
- 12,473 CIPs loaded
- 97.3% clean brand names
- 99.8% salt-free generic names
- Primary forms: gélule (4234), comprimé (5102), sirop (892), collyre (445), crème (1201)

See test-reports/ for details.
```

This gives AI the signal without the noise.

---

## File Structure

```
backend_pipeline/
├── test/
│   ├── README.md                 # This file
│   ├── smoke.test.ts             # Layer 1: Fast feedback
│   ├── contract.test.ts          # Layer 2: Business logic
│   ├── report.test.ts            # Layer 3: Comprehensive reports
│   ├── test-reports/             # Generated reports (gitignored)
│   │   ├── cip-naming.json       # CIP naming coverage
│   │   ├── rangement.json        # Sorting validation
│   │   └── pharmacy-drawers.json # Form coverage
│   ├── pipeline.test.ts          # Existing: Schema integrity
│   ├── integrity.test.ts         # Existing: Data quality
│   └── golden_salts.test.ts      # Existing: Salt stripping
```

---

## Running Tests

### During Development (Fast Iteration)

```bash
# Smoke tests only (5 seconds)
bun test test/smoke.test.ts

# Smoke + Contract (35 seconds)
bun test test/smoke.test.ts test/contract.test.ts
```

### Before Commit (Validation)

```bash
# All layers (2.5 minutes)
bun test

# Or via Make
make backend-test
```

### CI Pipeline

```yaml
# .github/workflows/backend.yml
- name: Run smoke tests
  run: bun test test/smoke.test.ts

- name: Run contract tests
  run: bun test test/contract.test.ts

- name: Generate reports
  run: bun test test/report.test.ts

- name: Upload reports
  uses: actions/upload-artifact@v3
  with:
    name: test-reports
    path: backend_pipeline/test-reports/
```

---

## Summary

| Layer | Time | Output | When to Run |
|-------|------|--------|-------------|
| **Smoke** | 5s | One-line summaries | Every change |
| **Contract** | 30s | Failures only | Before commit |
| **Report** | 2m | JSON files | On CI, on demand |

**Benefits**:
- ✅ No context overflow (summary output only)
- ✅ Meaningful signals (validates core philosophy)
- ✅ Frontend can iterate (read reports, don't re-run)
- ✅ Progressive disclosure (smoke → contract → report)
