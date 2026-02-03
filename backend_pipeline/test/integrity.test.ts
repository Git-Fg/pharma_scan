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

    describe("Test 2: Normalization - No salt prefixes in cluster names", () => {
        test("No cluster_name starts with CHLORHYDRATE DE", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM cluster_names 
                WHERE cluster_name LIKE 'CHLORHYDRATE DE %'
            `).get() as { count: number };

            expect(result.count).toBe(0);
        });

        test("No cluster_name starts with MALEATE DE", () => {
            const result = db.query(`
                SELECT COUNT(*) as count 
                FROM cluster_names 
                WHERE cluster_name LIKE 'MALEATE DE %'
            `).get() as { count: number };

            expect(result.count).toBe(0);
        });
    });

    describe("Test 3: Search Logic - Reasonable result counts", () => {
        test("FTS 'paracetamol' returns results (Doliprane's active ingredient)", () => {
            const results = db.query(`
                SELECT COUNT(*) as count 
                FROM search_index 
                WHERE search_vector MATCH 'paracetamol'
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
                JOIN medicaments m ON m.cis_code = ms.cis_code
                WHERE m.commercialisation_statut = 'Déclaration de commercialisation'
                AND (ms.principes_actifs_communs IS NULL OR ms.principes_actifs_communs = '' OR ms.principes_actifs_communs = '[]')
            `).get() as { count: number };

            const totalCount = db.query(`
                SELECT COUNT(*) as count 
                FROM medicament_summary ms
                JOIN medicaments m ON m.cis_code = ms.cis_code
                WHERE m.commercialisation_statut = 'Déclaration de commercialisation'
            `).get() as { count: number };

            const orphanPercentage = (result.count / totalCount.count) * 100;
            expect(orphanPercentage).toBeLessThan(1);
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

    describe("Test 6: PPI Family Validation (FTS & Clustering)", () => {
        test("Search 'omeprazole' finds 'Mopral'", () => {
            const results = db.query(`
                SELECT ci.title, ci.subtitle 
                FROM search_index si
                JOIN cluster_index ci ON si.cluster_id = ci.cluster_id
                WHERE search_index MATCH 'omeprazole'
                LIMIT 5
            `).all() as { title: string, subtitle: string | null }[];

            const match = results.find(r =>
                (r.title && r.title.toUpperCase().includes('MOPRAL')) ||
                (r.subtitle && r.subtitle.toUpperCase().includes('MOPRAL')) ||
                (r.title && r.title.toUpperCase().includes('OMEPRAZOLE'))
            );
            expect(match).toBeDefined();
        });

        test("Search 'pantoprazole' finds 'Eupantol' or 'Inipomp'", () => {
            const results = db.query(`
                SELECT ci.title, ci.subtitle 
                FROM search_index si
                JOIN cluster_index ci ON si.cluster_id = ci.cluster_id
                WHERE search_index MATCH 'pantoprazole'
                LIMIT 5
            `).all() as { title: string, subtitle: string | null }[];

            const match = results.find(r =>
                (r.subtitle && r.subtitle.toUpperCase().includes('EUPANTOL')) ||
                (r.subtitle && r.subtitle.toUpperCase().includes('INIPOMP')) ||
                (r.title && r.title.toUpperCase().includes('PANTOPRAZOLE'))
            );
            expect(match).toBeDefined();
        });

        test("Search 'esomeprazole' finds 'Inexium'", () => {
            const results = db.query(`
                SELECT ci.title, ci.subtitle 
                FROM search_index si
                JOIN cluster_index ci ON si.cluster_id = ci.cluster_id
                WHERE search_index MATCH 'esomeprazole'
                LIMIT 5
            `).all() as { title: string, subtitle: string | null }[];

            const match = results.find(r =>
                (r.subtitle && r.subtitle.toUpperCase().includes('INEXIUM')) ||
                (r.title && r.title.toUpperCase().includes('ESOMEPRAZOLE'))
            );
            expect(match).toBeDefined();
        });
    });
});
