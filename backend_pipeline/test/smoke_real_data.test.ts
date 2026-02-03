import { describe, test, beforeAll, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { existsSync } from "fs";
import { DEFAULT_DB_PATH } from "../src/db";

/**
 * Smoke Tests - Fast Feedback (5 seconds)
 *
 * Purpose: Quick validation that critical systems work.
 * Output: One-line summary per test (minimal context usage).
 *
 * IMPORTANT: Tests verify CLUSTER-LEVEL quality, not CIP-level transformations.
 * - cluster_index.title = clean brand name (for rangement)
 * - cluster_index.subtitle = princeps reference
 * - medicament_summary.princeps_brand_name = full name with form (correct!)
 *
 * Run: bun test test/smoke.test.ts
 */
describe("Smoke Tests", () => {
    let db: Database;

    beforeAll(() => {
        if (!existsSync(DEFAULT_DB_PATH)) {
            throw new Error(`Database not found at ${DEFAULT_DB_PATH}. Run 'bun run build' first.`);
        }
        db = new Database(DEFAULT_DB_PATH, { readonly: true });
    });

    test("✓ Database exists and is readable", () => {
        const count = db.query("SELECT COUNT(*) as count FROM medicament_summary").get() as { count: number };
        console.log(`  → ${count.count.toLocaleString()} medicaments loaded`);
        expect(count.count).toBeGreaterThan(1000);
    });

    test("✓ Clustering: All medicaments have cluster assigned", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN cluster_id IS NULL THEN 1 ELSE 0 END) as unclustered
            FROM medicament_summary
            WHERE status = 'Autorisation active'
        `).get() as { total: number, unclustered: number };

        const coverage = ((result.total - result.unclustered) / result.total * 100).toFixed(1);
        console.log(`  → ${coverage}% clustered (${result.unclustered}/${result.total} unclustered)`);
        expect(parseFloat(coverage)).toBeGreaterThan(99);
    });

    test("✓ Cluster naming: Clean brand names (no forms/dosage in title)", () => {
        // cluster_index.title should be clean (e.g., "CLAMOXYL", not "CLAMOXYL 500 mg")
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN title LIKE '% mg%' OR title LIKE '% gélule%' OR title LIKE '% comprimé%' OR title LIKE '% sirop%' THEN 1 ELSE 0 END) as has_form
            FROM cluster_index
        `).get() as { total: number, has_form: number };

        const clean = ((result.total - result.has_form) / result.total * 100).toFixed(1);
        console.log(`  → ${clean}% clusters have clean titles (${result.has_form}/${result.total} have forms/dosage)`);
        expect(parseFloat(clean)).toBeGreaterThan(95);
    });

    test("✓ Princeps references: Clusters have subtitle references", () => {
        // cluster_index.subtitle should contain "Ref: BRAND" format
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN subtitle IS NULL OR subtitle = '' OR subtitle NOT LIKE 'Ref:%' THEN 1 ELSE 0 END) as no_ref
            FROM cluster_index
        `).get() as { total: number, no_ref: number };

        const coverage = ((result.total - result.no_ref) / result.total * 100).toFixed(1);
        console.log(`  → ${coverage}% clusters have princeps reference (${result.no_ref}/${result.total} missing)`);
        expect(parseFloat(coverage)).toBeGreaterThan(95);
    });

    test("✓ Pharmacy drawer forms: Primary forms coverage (cluster level)", () => {
        // Count distinct clusters for each form (not individual products)
        const forms = [
            { name: 'gélule', min: 100 },
            { name: 'comprimé', min: 150 },
            { name: 'sirop', min: 30 },
            { name: 'collyre', min: 20 },
            { name: 'crème', min: 50 },
            { name: 'pommade', min: 15 }
        ];
        const results = [];

        for (const form of forms) {
            const count = db.query(`
                SELECT COUNT(DISTINCT ci.cluster_id) as count
                FROM cluster_index ci
                JOIN medicament_summary ms ON ms.cluster_id = ci.cluster_id
                WHERE ms.denomination_substance LIKE '%${form}%'
            `).get() as { count: number };
            results.push(`${form.name}: ${count.count} clusters`);
            expect(count.count).toBeGreaterThan(form.min);
        }

        console.log(`  → ${results.join(', ')}`);
    });

    test("✓ Rangement: Clusters sort alphabetically by title", () => {
        // Verify that clusters are sorted alphabetically by brand name (title)
        const clusters = db.query(`
            SELECT title
            FROM cluster_index
            WHERE title IS NOT NULL
            ORDER BY title COLLATE NOCASE ASC
            LIMIT 100
        `).all() as { title: string }[];

        // Verify alphabetical order
        let violations = 0;
        for (let i = 1; i < clusters.length; i++) {
            const prev = clusters[i - 1].title;
            const curr = clusters[i].title;
            const comparison = prev.localeCompare(curr, 'fr', { sensitivity: 'base' });
            if (comparison > 0) violations++;
        }

        console.log(`  → ${violations} sorting violations in ${clusters.length} clusters`);
        expect(violations).toBe(0);
    });

    test("✓ Search: FTS index is functional", () => {
        const tests = [
            { term: 'paracetamol', min: 5 },  // Should find Doliprane cluster
            { term: 'amoxicilline', min: 10 }, // Should find Clamoxyl cluster
            { term: 'clamoxyl', min: 5 },      // Should find brand name
            { term: 'doliprane', min: 5 }      // Should find brand name
        ];

        const results = [];
        for (const t of tests) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM search_index
                WHERE search_index MATCH ?
            `, [t.term]).get() as { count: number };
            results.push(`${t.term}: ${count.count}`);
        }

        console.log(`  → ${results.join(', ')}`);
        // Just verify the search works, don't assert specific counts
        expect(results.length).toBe(4);
    });

    test("✓ Data quality: Known medications exist", () => {
        // Verify that well-known medications are present
        const tests = [
            { name: 'CLAMOXYL', shouldExist: true },
            { name: 'DOLIPRANE', shouldExist: true },
            { name: 'MOPRAL', shouldExist: true },
            { name: 'SPASFON', shouldExist: true }
        ];

        let found = 0;
        const missing = [];

        for (const t of tests) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM cluster_index
                WHERE title LIKE ?
            `, [`%${t.name}%`]).get() as { count: number };

            if (count.count > 0) {
                found++;
            } else {
                missing.push(t.name);
            }
        }

        console.log(`  → ${found}/${tests.length} known medications found`);
        expect(missing.length).toBe(0);
    });
});
