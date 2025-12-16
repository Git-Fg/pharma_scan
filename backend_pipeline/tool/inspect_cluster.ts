
import { Database } from "bun:sqlite";
import { DEFAULT_DB_PATH } from "../src/db";

const db = new Database(DEFAULT_DB_PATH, { readonly: true });

const targetClusters = ["CLS_15F406C0", "CLS_EAFECA8D", "CLS_408BB600", "CLS_78EAAE3E", "CLS_6D94BC2C"];

console.log("🔍 Inspecting Suspicious Clusters...\n");

targetClusters.forEach(id => {
    const meta = db.query(`SELECT * FROM cluster_names WHERE cluster_id = ?`).get(id) as any;
    const members = db.query(`SELECT nom_canonique, is_princeps FROM medicament_summary WHERE cluster_id = ?`).all(id) as any[];

    console.log(`\nCluster [${id}]: "${meta?.cluster_princeps}" (Substance: ${meta?.cluster_name})`);
    console.log(`Members (${members.length}):`);
    members.forEach(m => console.log(` - ${m.nom_canonique} (Princeps: ${m.is_princeps})`));
});

db.close();
