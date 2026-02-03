import { Database } from "bun:sqlite";
import { DEFAULT_DB_PATH } from "../src/db";

const args = process.argv.slice(2);

if (args.length === 0) {
    console.log("Usage: bun tool/inspect_cluster.ts <cluster_id_1> [cluster_id_2] ...");
    console.log("Example: bun tool/inspect_cluster.ts CLS_15F406C0 CLS_EAFECA8D");
    process.exit(1);
}

const db = new Database(DEFAULT_DB_PATH, { readonly: true });

console.log("🔍 Inspecting Clusters...\n");

args.forEach((id) => {
    const meta = db
        .query(`SELECT * FROM cluster_names WHERE cluster_id = ?`)
        .get(id) as any;

    if (!meta) {
        console.log(`\n❌ Cluster [${id}]: NOT FOUND`);
        return;
    }

    const members = db
        .query(
            `SELECT nom_canonique, is_princeps FROM medicament_summary WHERE cluster_id = ?`
        )
        .all(id) as any[];

    console.log(
        `\nCluster [${id}]: "${meta?.cluster_princeps}" (Substance: ${meta?.cluster_name})`
    );
    console.log(`Members (${members.length}):`);
    members.forEach((m) =>
        console.log(` - ${m.nom_canonique} (Princeps: ${m.is_princeps})`)
    );
});

db.close();
