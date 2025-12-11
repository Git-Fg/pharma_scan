import { Database, type SQLQueryBindings } from "bun:sqlite";
import fs from "node:fs";
import path from "node:path";
import type {
  Cluster,
  GroupRow,
  Presentation,
  Product,
  ProductGroupingUpdate
} from "./types";

export const DEFAULT_DB_PATH = path.join("data", "reference.db");

export class ReferenceDatabase {
  private db: Database;

  constructor(databasePath: string) {
    const fullPath = databasePath === ":memory:" ? databasePath : path.resolve(databasePath);
    if (fullPath !== ":memory:") {
      fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    }
    console.log(`📂 Opening database at: ${fullPath}`);
    this.db = new Database(fullPath, { create: true, readwrite: true });
    this.db.exec("PRAGMA journal_mode = DELETE;");
    this.db.exec("PRAGMA synchronous = NORMAL;");
    this.db.exec("PRAGMA foreign_keys = ON;");
    this.db.exec("PRAGMA locking_mode = NORMAL;");
    this.initSchema();
    console.log(`✅ Database initialized successfully`);
  }

  private initSchema() {
    this.db.exec(`
      -- 1. Clusters (Visual grouping)
      CREATE TABLE IF NOT EXISTS clusters (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        princeps_label TEXT NOT NULL,
        substance_code TEXT NOT NULL,
        text_brand_label TEXT
      );

      -- 2. Groups (Administrative)
      CREATE TABLE IF NOT EXISTS groups (
        id TEXT PRIMARY KEY,
        cluster_id TEXT NOT NULL,
        label TEXT NOT NULL,
        canonical_name TEXT NOT NULL,
        historical_princeps_raw TEXT,
        generic_label_clean TEXT,
        naming_source TEXT NOT NULL,
        princeps_aliases TEXT NOT NULL,
        safety_flags TEXT NOT NULL,
        routes TEXT NOT NULL,
        FOREIGN KEY(cluster_id) REFERENCES clusters(id)
      );

      -- 3. Products (Materialized View)
      CREATE TABLE IF NOT EXISTS manufacturers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL UNIQUE
      );

      CREATE TABLE IF NOT EXISTS products (
        cis TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        is_princeps INTEGER NOT NULL,
        generic_type INTEGER NOT NULL DEFAULT 99,
        group_id TEXT,
        form TEXT,
        routes TEXT,
        type_procedure TEXT,
        surveillance_renforcee INTEGER NOT NULL DEFAULT 0,
        manufacturer_id INTEGER,
        marketing_status TEXT,
        date_amm TEXT,
        regulatory_info TEXT NOT NULL,
        composition TEXT NOT NULL,
        composition_codes TEXT NOT NULL,
        composition_display TEXT NOT NULL,
        drawer_label TEXT NOT NULL,
        FOREIGN KEY(group_id) REFERENCES groups(id),
        FOREIGN KEY(manufacturer_id) REFERENCES manufacturers(id)
      );

      -- 4. Presentations (Scanner)
      CREATE TABLE IF NOT EXISTS presentations (
        cip13 TEXT PRIMARY KEY,
        cis TEXT NOT NULL,
        price_cents INTEGER,
        reimbursement_rate TEXT,
        market_status TEXT,
        availability_status TEXT,
        ansm_link TEXT,
        date_commercialisation TEXT,
        FOREIGN KEY(cis) REFERENCES products(cis)
      );

      -- 5. FTS5 Index (Pre-computed for instant search)
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        label,
        normalized_text,
        cis UNINDEXED,
        tokenize='trigram'
      );
    `);
  }

  private prepareInsert<T extends Record<string, SQLQueryBindings | null>>(
    table: string,
    columns: ReadonlyArray<keyof T>
  ) {
    const cols = columns.map(String).join(", ");
    const vals = columns.map(() => "?").join(", ");

    return (rows: ReadonlyArray<T>) => {
      for (const row of rows) {
        const values = columns.map((col) => row[col]) as SQLQueryBindings[];
        const stmt = this.db.prepare(`INSERT OR REPLACE INTO ${table} (${cols}) VALUES (${vals})`);
        stmt.run(...values);
      }
    };
  }

  public insertClusters(rows: ReadonlyArray<Cluster>) {
    console.log(`📊 Inserting ${rows.length} clusters...`);
    const columns = [
      "id",
      "label",
      "princeps_label",
      "substance_code",
      "text_brand_label"
    ] as const satisfies ReadonlyArray<keyof Cluster>;
    this.prepareInsert<Cluster>("clusters", columns)(rows);
    console.log(`✅ Inserted ${rows.length} clusters`);
  }

  public insertGroups(rows: ReadonlyArray<GroupRow>) {
    console.log(`📊 Inserting ${rows.length} groups...`);
    const columns = [
      "id",
      "cluster_id",
      "label",
      "canonical_name",
      "historical_princeps_raw",
      "generic_label_clean",
      "naming_source",
      "princeps_aliases",
      "safety_flags",
      "routes"
    ] as const satisfies ReadonlyArray<keyof GroupRow>;
    this.prepareInsert("groups", columns)(rows);
    console.log(`✅ Inserted ${rows.length} groups`);
  }

  public insertProducts(rows: ReadonlyArray<Product>) {
    const columns = [
      "cis",
      "label",
      "is_princeps",
      "generic_type",
      "group_id",
      "form",
      "routes",
      "type_procedure",
      "surveillance_renforcee",
      "manufacturer_id",
      "marketing_status",
      "date_amm",
      "regulatory_info",
      "composition",
      "composition_codes",
      "composition_display",
      "drawer_label"
    ] as const satisfies ReadonlyArray<keyof Product>;

    console.log(`📊 Inserting ${rows.length} products...`);
    this.prepareInsert("products", columns)(rows);
    console.log(`✅ Inserted ${rows.length} products`);
  }

  public insertManufacturers(rows: ReadonlyArray<{ id: number; label: string }>) {
    console.log(`📊 Inserting ${rows.length} manufacturers...`);
    const columns = ["id", "label"] as const satisfies ReadonlyArray<"id" | "label">;
    this.prepareInsert("manufacturers", columns)(rows);
    console.log(`✅ Inserted ${rows.length} manufacturers`);
  }

  public updateProductGrouping(
    rows: ReadonlyArray<ProductGroupingUpdate>
  ) {
    const stmt = this.db.prepare(
      `UPDATE products
       SET group_id=$group_id,
           is_princeps=$is_princeps,
           generic_type=$generic_type
       WHERE cis=$cis`
    );

    this.db.transaction((items: typeof rows) => {
      for (const item of items) {
        stmt.run(
          {
            $cis: item.cis,
            $group_id: item.group_id,
            $is_princeps: item.is_princeps,
            $generic_type: item.generic_type
          } satisfies Record<string, string | number | boolean>
        );
      }
    })(rows);
  }

  public insertPresentations(rows: ReadonlyArray<Presentation>) {
    const columns = [
      "cip13",
      "cis",
      "price_cents",
      "reimbursement_rate",
      "market_status",
      "availability_status",
      "ansm_link",
      "date_commercialisation"
    ] as const satisfies ReadonlyArray<keyof Presentation>;
    this.prepareInsert<Presentation>("presentations", columns)(rows);
  }

  public populateSearchIndex() {
    this.db.exec(`
      DELETE FROM search_index;
      INSERT INTO search_index (label, normalized_text, cis)
      SELECT label, label, cis FROM products;
    `);
  }

  public optimize() {
    // WAL mode requires checkpoint before vacuum to avoid IOERR on some FS
    this.db.exec("PRAGMA wal_checkpoint(TRUNCATE); VACUUM; ANALYZE;");
  }

  public close() {
    this.db.close();
  }

  // Testing helper: raw query access (read-only usage in tests)
  public rawQuery<T extends Record<string, unknown>>(sql: string): ReadonlyArray<T> {
    return this.db.query<T, []>(sql).all();
  }
}
