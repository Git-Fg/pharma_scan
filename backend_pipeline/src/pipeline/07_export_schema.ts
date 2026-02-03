import { Database } from "bun:sqlite";
import { promises as fs } from "fs";
import path from "path";

/**
 * Phase 7: Schema Export
 *
 * Exports database schema and type definitions as JSON for frontend code generation.
 * This enables type-safe, automated synchronization between backend and frontend.
 *
 * NON-INVASIVE: Only reads from the database, does not modify any ETL logic.
 */

export interface ColumnExport {
  name: string;
  type: string;
  nullable: boolean;
  primaryKey: boolean;
  autoIncrement: boolean;
  defaultValue: string | null;
}

export interface TableExport {
  name: string;
  columns: ColumnExport[];
  indexes: IndexExport[];
  foreignKeys: ForeignKeyExport[];
}

export interface IndexExport {
  name: string;
  unique: boolean;
  columns: string[];
}

export interface ForeignKeyExport {
  column: string;
  referencedTable: string;
  referencedColumn: string;
  onDelete?: string;
  onUpdate?: string;
}

export interface SchemaExport {
  version: string;
  exportedAt: string;
  databasePath: string;
  tables: TableExport[];
  views: ViewExport[];
}

export interface ViewExport {
  name: string;
  sql: string;
}

export interface TypeDefinitionExport {
  name: string;
  type: "string" | "number" | "boolean" | "array" | "object";
  length?: number;
  nullable: boolean;
  enum?: string[];
  description?: string;
}

export interface TypeExport {
  zodSchemas: Record<string, TypeDefinitionExport>;
  brandedTypes: Record<string, TypeDefinitionExport>;
  entities: Record<string, TypeDefinitionExport>;
}

export interface QueryContract {
  name: string;
  description: string;
  parameters: ParameterContract[];
  returnType: string;
  sql: string;
}

export interface ParameterContract {
  name: string;
  type: string;
  description?: string;
}

export interface QueriesExport {
  explorer: QueryContract[];
  catalog: QueryContract[];
  restock: QueryContract[];
}

export interface ExportResult {
  schema: SchemaExport;
  types: TypeExport;
  queries: QueriesExport;
}

/**
 * Extracts table schema from SQLite database using PRAGMA commands
 */
function extractTableSchema(db: Database): TableExport[] {
  const tables: TableExport[] = [];

  const tableRows = db.query(
    `
    SELECT name FROM sqlite_master
    WHERE type='table'
      AND name NOT LIKE 'sqlite_%'
      AND name NOT LIKE 'search_%'
      ORDER BY name
  `
  ).all() as { name: string }[];

  for (const { name } of tableRows) {
    // Get column information
    const columnRows = db.query(
      `
      PRAGMA table_info(${name})
    `
    ).all() as {
      name: string;
      type: string;
      notnull: number;
      pk: number;
      dflt_value: string | null;
    }[];

    // Get index information
    const indexRows = db.query(
      `
      PRAGMA index_list(${name})
    `
    ).all() as {
      name: string;
      unique: number;
      origin: string;
    }[];

    const indexes: IndexExport[] = [];
    for (const index of indexRows) {
      if (index.origin === "pk") continue; // Skip primary key index

      const indexInfoRows = db
        .query(`PRAGMA index_info(${index.name})`)
        .all() as { name: string }[];

      indexes.push({
        name: index.name,
        unique: index.unique === 1,
        columns: indexInfoRows.map((info) => info.name),
      });
    }

    // Get foreign key information
    const fkRows = db
      .query(
        `
        PRAGMA foreign_key_list(${name})
      `
      )
      .all() as {
      id: number;
      table: string;
      from: string;
      to: string;
      on_update: string;
      on_delete: string;
      }[];

    const fkExports: ForeignKeyExport[] = [];
    for (const fk of fkRows) {
      fkExports.push({
        column: fk.from,
        referencedTable: fk.to,
        referencedColumn: fk.table,
        onUpdate: fk.on_update,
        onDelete: fk.on_delete,
      });
    }

    tables.push({
      name,
      columns: columnRows.map((col) => ({
        name: col.name,
        type: col.type,
        nullable: col.notnull === 0,
        primaryKey: col.pk > 0,
        autoIncrement: col.dflt_value?.toLowerCase() === "null",
        defaultValue: col.dflt_value ?? null,
      })),
      indexes,
      foreignKeys: fkExports,
    });
  }

  return tables;
}

/**
 * Extracts view definitions (materialized views for UI)
 */
function extractViews(db: Database): ViewExport[] {
  const viewRows = db
    .query(
      `
      SELECT name, sql FROM sqlite_master
      WHERE type='view'
      ORDER BY name
    `
    )
    .all() as { name: string; sql: string }[];

  return viewRows.map((view) => ({
    name: view.name,
    sql: view.sql,
  }));
}

/**
 * Exports Zod schema types as JSON contract
 */
function exportTypeDefinitions(): TypeExport {
  return {
    zodSchemas: {
      CisId: {
        name: "CisId",
        type: "string",
        length: 8,
        nullable: false,
        description: "8-character CIS code identifier",
      },
      Cip13: {
        name: "Cip13",
        type: "string",
        length: 13,
        nullable: false,
        description: "13-digit CIP code (GTIN-13)",
      },
      GroupId: {
        name: "GroupId",
        type: "string",
        nullable: false,
        description: "Generic group identifier",
      },
    },
    brandedTypes: {
      CisId: {
        name: "CisId",
        type: "string",
        length: 8,
        nullable: false,
        description: "Branded CIS code type",
      },
      Cip13: {
        name: "Cip13",
        type: "string",
        length: 13,
        nullable: false,
        description: "Branded CIP13 type",
      },
    },
    entities: {
      ClusterIndexData: {
        name: "ClusterIndexData",
        type: "object",
        nullable: false,
        description: "Cluster search result",
      },
      MedicamentSummary: {
        name: "MedicamentSummary",
        type: "object",
        nullable: false,
        description: "Medicament summary view",
      },
      GroupDetailEntity: {
        name: "GroupDetailEntity",
        type: "object",
        nullable: false,
        description: "Group detail with all properties",
      },
    },
  };
}

/**
 * Exports query contracts for type-safe DAO generation
 */
function exportQueryContracts(): QueriesExport {
  return {
    explorer: [
      {
        name: "watchClusters",
        description: "Search clusters using FTS5 trigram or return all ordered by princeps",
        parameters: [
          {
            name: "query",
            type: "string",
            description: "Search query (empty = return all)",
          },
        ],
        returnType: "Stream<List<ClusterEntity>>",
        sql: `
-- When query is empty
SELECT * FROM cluster_index ORDER BY title ASC LIMIT 100

-- When query has value
SELECT ci.* FROM cluster_index ci
INNER JOIN search_index si ON si.cluster_id = ci.cluster_id
WHERE search_index MATCH ?
ORDER BY si.rowid LIMIT 50
        `,
      },
      {
        name: "getClusterContent",
        description: "Get all products within a specific cluster",
        parameters: [
          {
            name: "clusterId",
            type: "string",
            description: "Cluster identifier",
          },
        ],
        returnType: "Future<List<ClusterProductEntity>>",
        sql: `
SELECT cis_code, cluster_id, nom_canonique as nom_complet, is_princeps
FROM medicament_summary
WHERE cluster_id = ?
ORDER BY is_princeps DESC, nom_canonique ASC
        `,
      },
      {
        name: "watchAllClustersOrderedByPrinceps",
        description: "Watch all clusters ordered by princeps name (A-Z)",
        parameters: [],
        returnType: "Stream<List<ClusterEntity>>",
        sql: `
SELECT * FROM ui_explorer_list
ORDER BY subtitle COLLATE NOCASE ASC
        `,
      },
    ],
    catalog: [
      {
        name: "watchGroupDetails",
        description: "Watch all products in a group (including same principles)",
        parameters: [
          {
            name: "groupId",
            type: "string",
            description: "Group identifier",
          },
        ],
        returnType: "Stream<List<GroupDetailEntity>>",
        sql: `
SELECT ugd.*
FROM ui_group_details ugd
WHERE ugd.group_id = ?
ORDER BY ugd.is_princeps DESC, ugd.nom_canonique ASC
        `,
      },
      {
        name: "fetchRelatedPrinceps",
        description: "Find related therapies (superset groups)",
        parameters: [
          {
            name: "groupId",
            type: "string",
            description: "Target group ID",
          },
        ],
        returnType: "Future<List<GroupDetailEntity>>",
        sql: `
SELECT DISTINCT ugd.*
FROM ui_group_details ugd
INNER JOIN medicament_summary ms ON ugd.group_id = ms.group_id
WHERE ugd.group_id != ?
  AND ugd.is_princeps = 1
  AND ms.principes_actifs_communs IS NOT NULL
  AND json_array_length(ms.principes_actifs_communs) > ?
  AND json_valid(?)
  AND NOT EXISTS (
    SELECT 1 FROM json_each(?) as target
    WHERE target.value NOT IN (
      SELECT value FROM json_each(ms.principes_actifs_communs)
    )
  )
ORDER BY ugd.princeps_de_reference ASC
        `,
      },
    ],
    restock: [],
  };
}

/**
 * Main export function - extracts schema and writes JSON files
 */
export async function runSchemaExport(
  dbPath: string,
  outputDir: string
): Promise<ExportResult> {
  console.log("📋 Exporting schema contract...");

  const db = new Database(dbPath, { readonly: true });

  try {
    // Extract schema
    const tables = extractTableSchema(db);
    const views = extractViews(db);

    const schema: SchemaExport = {
      version: "1.0.0",
      exportedAt: new Date().toISOString(),
      databasePath: path.basename(dbPath),
      tables,
      views,
    };

    // Extract type definitions
    const types = exportTypeDefinitions();

    // Extract query contracts
    const queries = exportQueryContracts();

    // Ensure output directory exists
    await fs.mkdir(outputDir, { recursive: true });

    // Write schema.json
    const schemaPath = path.join(outputDir, "schema.json");
    await fs.writeFile(
      schemaPath,
      JSON.stringify(schema, null, 2),
      "utf-8"
    );
    console.log(
      `   ✅ schema.json (${(JSON.stringify(schema).length / 1024).toFixed(1)} KB)`
    );

    // Write types.json
    const typesPath = path.join(outputDir, "types.json");
    await fs.writeFile(
      typesPath,
      JSON.stringify(types, null, 2),
      "utf-8"
    );
    console.log(
      `   ✅ types.json (${(JSON.stringify(types).length / 1024).toFixed(1)} KB)`
    );

    // Write queries.json
    const queriesPath = path.join(outputDir, "queries.json");
    await fs.writeFile(
      queriesPath,
      JSON.stringify(queries, null, 2),
      "utf-8"
    );
    console.log(
      `   ✅ queries.json (${(JSON.stringify(queries).length / 1024).toFixed(1)} KB)`
    );

    console.log(`\n📦 Schema export complete!`);
    console.log(`   Tables: ${tables.length}`);
    console.log(`   Views: ${views.length}`);
    console.log(
      `   Queries: ${queries.explorer.length + queries.catalog.length}`
    );

    return { schema, types, queries };
  } finally {
    db.close();
  }
}

/**
 * Validation report for schema export phase
 */
export interface ValidationReport {
  phase: string;
  issues: string[];
}

export function validateSchemaExport(result: ExportResult): ValidationReport {
  const issues: string[] = [];

  // Validate table count
  if (result.schema.tables.length < 10) {
    issues.push(`Too few tables exported: ${result.schema.tables.length}`);
  }

  // Validate type exports
  const expectedTypes = ["CisId", "Cip13", "GroupId"];
  for (const type of expectedTypes) {
    if (!result.types.zodSchemas[type]) {
      issues.push(`Missing type definition: ${type}`);
    }
  }

  // Validate query contracts
  if (result.queries.explorer.length === 0) {
    issues.push("No explorer query contracts exported");
  }

  return { phase: "SCHEMA_EXPORT", issues };
}
