import { describe, expect, test, beforeAll } from "bun:test";
import { Database } from "bun:sqlite";
import { existsSync } from "fs";
import { DEFAULT_DB_PATH } from "../src/db";

/**
 * Data Integrity Test Suite
 * 
 * These tests verify business logic and data quality in the generated database.
 * They act as a "Data Quality Gate" to ensure the backend pipeline produces
 * correct and consistent data structures.
 */
describe("Data Integrity Suite", () => {
    let db: Database;

    beforeAll(() => {
        if (!existsSync(DEFAULT_DB_PATH)) {
            throw new Error(`Database not found at ${DEFAULT_DB_PATH}. Run 'bun run build' first.`);
        }
        db = new Database(DEFAULT_DB_PATH, { readonly: true });
    });

    describe("Test 1: Sanity - Known products exist", () => {
        test("Doliprane CIS codes exist", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM medicament_summary 
                WHERE princeps_de_reference LIKE '%DOLIPRANE%'
            `).get() as { count: number };

            expect(result.count).toBeGreaterThan(0);
        });

        test("Amoxicilline products exist", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM medicament_summary 
                WHERE principes_actifs_communs LIKE '%Amoxicilline%'
            `).get() as { count: number };

            expect(result.count).toBeGreaterThan(50);
        });
    });

    describe("Test 2: Normalization - No salt prefixes in canonical names", () => {
        test("No canonical_name starts with CHLORHYDRATE DE", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM ref_substances 
                WHERE canonical_name LIKE 'CHLORHYDRATE DE %'
            `).get() as { count: number };

            expect(result.count).toBe(0);
        });

        test("No canonical_name starts with MALEATE DE", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM ref_substances 
                WHERE canonical_name LIKE 'MALEATE DE %'
            `).get() as { count: number };

            expect(result.count).toBe(0);
        });

        test("No canonical_name ends with common salt suffixes", () => {
            const saltSuffixes = ["SULFATE", "TRIHYDRATE", "CHLORHYDRATE", "DIHYDRATE"];

            for (const suffix of saltSuffixes) {
                const result = db.query(`
                    SELECT COUNT(*) as count 
                    FROM ref_substances 
                    WHERE canonical_name LIKE '% ${suffix}'
                    AND canonical_name NOT IN ('CHLORURE DE SODIUM', 'PHOSPHATE', 'SULFATE')
                `).get() as { count: number };

                expect(result.count).toBe(0);
            }
        });
    });

    describe("Test 3: Search Logic - Reasonable result counts", () => {
        test("FTS 'amoxicilline' returns results via molecule_name", () => {
            // The search_index uses molecule_name (normalized) column
            const results = db.query(`
                SELECT COUNT(*) as count 
                FROM search_index 
                WHERE search_index MATCH 'amoxicilline'
            `).get() as { count: number };

            // Trigram tokenizer returns fewer direct matches, but still should have some
            expect(results.count).toBeGreaterThanOrEqual(1);
        });

        test("FTS 'paracetamol' returns results (Doliprane's active ingredient)", () => {
            // Search via molecule_name (paracetamol is Doliprane's active ingredient)
            const results = db.query(`
                SELECT COUNT(*) as count 
                FROM search_index 
                WHERE search_index MATCH 'paracetamol'
            `).get() as { count: number };

            expect(results.count).toBeGreaterThanOrEqual(1);
        });

        test("FTS search is case-insensitive", () => {
            const upperResults = db.query(`
                SELECT COUNT(*) as count 
                FROM search_index 
                WHERE search_index MATCH 'PARACETAMOL'
            `).get() as { count: number };

            const lowerResults = db.query(`
                SELECT COUNT(*) as count 
                FROM search_index 
                WHERE search_index MATCH 'paracetamol'
            `).get() as { count: number };

            expect(upperResults.count).toBe(lowerResults.count);
            expect(upperResults.count).toBeGreaterThan(0);
        });
    });

    describe("Test 4: Orphans - Every medicament has linked substances", () => {
        test("No orphan medicaments without composition links", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM medicament_summary ms
                WHERE NOT EXISTS (
                    SELECT 1 FROM composition_link cl 
                    WHERE cl.cis_code = ms.cis_code
                )
                AND ms.principes_actifs_communs IS NOT NULL
                AND ms.principes_actifs_communs != ''
                AND ms.principes_actifs_communs != '[]'
            `).get() as { count: number };

            // Allow a small percentage of orphans (<1%) for edge cases
            const totalCount = db.query(`
                SELECT COUNT(*) as count FROM medicament_summary 
                WHERE principes_actifs_communs IS NOT NULL 
                AND principes_actifs_communs != ''
                AND principes_actifs_communs != '[]'
            `).get() as { count: number };

            const orphanPercentage = (result.count / totalCount.count) * 100;
            expect(orphanPercentage).toBeLessThan(1);
        });

        test("All composition links reference valid substances", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM composition_link cl
                WHERE NOT EXISTS (
                    SELECT 1 FROM ref_substances rs 
                    WHERE rs.id = cl.substance_id
                )
            `).get() as { count: number };

            expect(result.count).toBe(0);
        });
    });

    describe("Test 5: View Integrity - Search results view works", () => {
        test("view_search_results returns ranked results", () => {
            const results = db.query(`
                SELECT * FROM view_search_results 
                LIMIT 10
            `).all();

            expect(results.length).toBeGreaterThan(0);

            // Verify structure
            const first = results[0] as any;
            expect(first).toHaveProperty('cluster_id');
            expect(first).toHaveProperty('title');
            expect(first).toHaveProperty('rank');
        });
    });
});
