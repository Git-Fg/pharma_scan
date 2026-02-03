import { readFileSync, existsSync } from "fs";
import { join } from "path";

const AUDIT_DIR = join(process.cwd(), "output", "audit");

interface Cluster {
    cluster_id: string;
    cluster_name: string;
    cluster_princeps: string | null;
    secondary_princeps: string[] | null;
    substance_label: string;
    cis_count: number;
}

interface Metrics {
    totalClusters: number;
    orphanRate: number;
    princepsCoverage: number;
    shortNameAlerts: number;
}

const SHORT_NAME_WHITELIST = ["ZINC", "FER", "EAU", "GEL", "AIR", "SEL"];

function main() {
    const clusterFile = join(AUDIT_DIR, "1_clusters_catalog.json");

    if (!existsSync(clusterFile)) {
        console.error(JSON.stringify({ error: "Audit file not found. Run 'bun run tool' first." }));
        process.exit(1);
    }

    const clusters: Cluster[] = JSON.parse(readFileSync(clusterFile, "utf8"));

    const metrics: Metrics = {
        totalClusters: clusters.length,
        orphanRate:
            clusters.filter((c) => c.cluster_name?.startsWith("ORPH_")).length /
            clusters.length,
        princepsCoverage:
            clusters.filter((c) => c.cluster_princeps).length / clusters.length,
        shortNameAlerts: clusters.filter((c) => {
            const name = c.cluster_princeps || c.cluster_name;
            if (!name) return false;
            const isShort = name.length < 4;
            const isWhitelisted = SHORT_NAME_WHITELIST.includes(name.toUpperCase());
            return isShort && !isWhitelisted;
        }).length,
    };

    console.log(JSON.stringify(metrics, null, 2));
}

main();
