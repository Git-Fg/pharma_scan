import { Database, type SQLQueryBindings } from "bun:sqlite";
import type {
  Cluster,
  GroupRow,
  Presentation,
  Product,
  ProductGroupingUpdate
} from "./types";

export class ReferenceDatabase {
  private db: Database;

  constructor(path: string) {
    this.db = new Database(path, { create: true });
    this.db.exec("PRAGMA journal_mode = WAL;");
    this.db.exec("PRAGMA synchronous = NORMAL;");
    this.db.exec("PRAGMA foreign_keys = ON;");
    this.initSchema();
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
    const stmt = this.db.prepare(`INSERT OR REPLACE INTO ${table} (${cols}) VALUES (${vals})`);

    return this.db.transaction((rows: ReadonlyArray<T>) => {
      for (const row of rows) {
        const values = columns.map((col) => row[col]) as SQLQueryBindings[];
        stmt.run(...values);
      }
    });
  }

  public insertClusters(rows: ReadonlyArray<Cluster>) {
    const columns = [
      "id",
      "label",
      "princeps_label",
      "substance_code",
      "text_brand_label"
    ] as const satisfies ReadonlyArray<keyof Cluster>;
    this.prepareInsert<Cluster>("clusters", columns)(rows);
  }

  public insertGroups(rows: ReadonlyArray<GroupRow>) {
    const columns = ["id", "cluster_id", "label"] as const satisfies ReadonlyArray<keyof GroupRow>;
    this.prepareInsert("groups", columns)(rows);
  }

  public insertProducts(rows: ReadonlyArray<Product>) {
    const safeRows = rows.map((row) => ({
      ...row,
      is_princeps: row.is_princeps ? 1 : 0,
      surveillance_renforcee: row.surveillance_renforcee ? 1 : 0
    }));

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

    this.prepareInsert("products", columns)(safeRows);
  }

  public insertManufacturers(rows: ReadonlyArray<{ id: number; label: string }>) {
    const columns = ["id", "label"] as const satisfies ReadonlyArray<"id" | "label">;
    this.prepareInsert("manufacturers", columns)(rows);
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
            $is_princeps: item.is_princeps ? 1 : 0,
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
    this.db.exec("VACUUM; ANALYZE;");
  }

  // Testing helper: raw query access (read-only usage in tests)
  public rawQuery<T extends Record<string, unknown>>(sql: string): ReadonlyArray<T> {
    return this.db.query<T, []>(sql).all();
  }
}
