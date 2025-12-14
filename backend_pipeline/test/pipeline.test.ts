import { describe, expect, test, beforeAll } from "bun:test";
import { spawnSync } from "child_process";
import { Database } from "bun:sqlite";
import { existsSync } from "fs";
import { join } from "path";
import { DEFAULT_DB_PATH } from "../src/db";

describe("Pipeline Integrity", () => {
    let db: Database;

    beforeAll(() => {
            if (!existsSync(DEFAULT_DB_PATH)) {
                // Attempt to build database automatically if missing
                const result = spawnSync("bun", ["src/index.ts"], { stdio: "inherit", cwd: join(__dirname, '..') });
                if (result.status !== 0) {
                    throw new Error(`Failed to build database at ${DEFAULT_DB_PATH}. Run 'bun run build:db' first.`);
                }
                if (!existsSync(DEFAULT_DB_PATH)) {
                    throw new Error(`Database still not found at ${DEFAULT_DB_PATH} after build. Run 'bun run build:db' first.`);
                }
            }
        db = new Database(DEFAULT_DB_PATH, { readonly: true });
    });

    test("Tables should exist", () => {
        const tables = db.query("SELECT name FROM sqlite_master WHERE type='table'").all() as { name: string }[];
        const tableNames = tables.map(t => t.name);
        expect(tableNames).toContain("medicaments");
        expect(tableNames).toContain("medicament_summary");
        expect(tableNames).toContain("search_index");
        expect(tableNames).toContain("laboratories");
        expect(tableNames).toContain("generique_groups");
    });

    test("Medicament Summary should be populated", () => {
        const count = db.query("SELECT COUNT(*) as count FROM medicament_summary").get() as { count: number };
        expect(count.count).toBeGreaterThan(1000); // Expect reasonable data volume
    });

    test("Clusters should be assigned", () => {
        const row = db.query("SELECT cluster_id FROM medicament_summary WHERE cluster_id IS NOT NULL LIMIT 1").get();
        expect(row).toBeDefined();
    });

    test("Laboratories should be populated", () => {
        const count = db.query("SELECT COUNT(*) as count FROM laboratories").get() as { count: number };
        expect(count.count).toBeGreaterThan(10);
    });

    test("FTS Search Index should return results", () => {
        // Need to query the virtual table. 
        // Note: FTS queries typically use MATCH
        const query = db.query("SELECT * FROM search_index WHERE search_index MATCH 'DOLIPRANE' LIMIT 5");
        const results = query.all();
        expect(results.length).toBeGreaterThan(0);
    });
});
