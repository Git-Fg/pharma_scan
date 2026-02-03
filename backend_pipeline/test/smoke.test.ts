import { describe, test, beforeAll } from "bun:test";
import { Database } from "bun:sqlite";
import { existsSync } from "fs";
import { DEFAULT_DB_PATH } from "../src/db";

/**
 * Smoke Tests - Fast Feedback (5 seconds)
 *
 * Purpose: Quick validation that critical systems work.
 * Output: One-line summary per test (minimal context usage).
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

    test("✓ CIP naming coverage: clean brand names", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN princeps_brand_name IS NULL OR princeps_brand_name = '' OR princeps_brand_name = 'BRAND' THEN 1 ELSE 0 END) as missing
            FROM medicament_summary
        `).get() as { total: number, missing: number };

        const coverage = ((result.total - result.missing) / result.total * 100).toFixed(1);
        console.log(`  → ${coverage}% clean brand names (${result.missing.toLocaleString()}/${result.total.toLocaleString()} missing)`);
        expect(parseFloat(coverage)).toBeGreaterThan(95);
    });

    test("✓ CIP naming coverage: clean generic names (no salts)", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN nom_canonique LIKE '%CHLORHYDRATE%' OR nom_canonique LIKE '%MALEATE%' OR nom_canonique LIKE '%SULFATE%' OR nom_canonique LIKE '%CITRATE%' THEN 1 ELSE 0 END) as has_salt
            FROM medicament_summary
        `).get() as { total: number, has_salt: number };

        const clean = ((result.total - result.has_salt) / result.total * 100).toFixed(1);
        console.log(`  → ${clean}% salt-free generic names (${result.has_salt}/${result.total} have salts)`);
        expect(parseFloat(clean)).toBeGreaterThan(99);
    });

    test("✓ Pharmacy drawer forms: primary forms coverage", () => {
        const forms = [
            { name: 'gélule', min: 500 },
            { name: 'comprimé', min: 1000 },
            { name: 'sirop', min: 200 },
            { name: 'collyre', min: 100 },
            { name: 'crème', min: 300 },
            { name: 'pommade', min: 100 }
        ];
        const results = [];

        for (const form of forms) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM medicament_summary
                WHERE denomination_substance LIKE '%${form}%'
            `).get() as { count: number };
            results.push(`${form.name}: ${count.count.toLocaleString()}`);
            expect(count.count).toBeGreaterThan(form.min);
        }

        console.log(`  → ${results.join(', ')}`);
    });

    test("✓ Clustering: All medicaments have cluster assigned", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN cluster_id IS NULL THEN 1 ELSE 0 END) as unclustered
            FROM medicament_summary
        `).get() as { total: number, unclustered: number };

        const coverage = ((result.total - result.unclustered) / result.total * 100).toFixed(1);
        console.log(`  → ${coverage}% clustered (${result.unclustered}/${result.total} unclustered)`);
        expect(parseFloat(coverage)).toBeGreaterThan(99);
    });

    test("✓ Rangement: Clusters have princeps brand reference", () => {
        const result = db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN subtitle IS NULL OR subtitle = '' THEN 1 ELSE 0 END) as no_brand
            FROM cluster_names
        `).get() as { total: number, no_brand: number };

        const coverage = ((result.total - result.no_brand) / result.total * 100).toFixed(1);
        console.log(`  → ${coverage}% clusters have brand reference (${result.no_brand}/${result.total} missing)`);
        expect(parseFloat(coverage)).toBeGreaterThan(95);
    });

    test("✓ Search: FTS index is functional", () => {
        const tests = [
            { term: 'paracetamol', min: 10 },
            { term: 'amoxicilline', min: 50 },
            { term: 'ibuprofène', min: 20 }
        ];

        const results = [];
        for (const t of tests) {
            const count = db.query(`
                SELECT COUNT(*) as count
                FROM search_index
                WHERE search_index MATCH ?
            `, [t.term]).get() as { count: number };
            results.push(`${t.term}: ${count.count}`);
            expect(count.count).toBeGreaterThan(t.min);
        }

        console.log(`  → ${results.join(', ')}`);
    });
});
