
import { readFileSync } from "fs";
import { join } from "path";

const AUDIT_FILE = join("data", "audit", "1_clusters_catalog.json");

interface Cluster {
    cluster_id: string;
    cluster_name: string;
    cluster_princeps: string | null;
    secondary_princeps: string[] | null;
    substance_label: string;
    cis_count: number;
}

function main() {
    console.log("🕵️  Auditing Cluster Quality...");

    try {
        const raw = readFileSync(AUDIT_FILE, "utf-8");
        const clusters: Cluster[] = JSON.parse(raw);

        console.log(`📊 Loaded ${clusters.length} clusters.`);

        // 1. Short Princeps Names (Truncation Risk)
        const shortNames = clusters.filter(c =>
            c.cluster_princeps &&
            c.cluster_princeps.length < 4 &&
            !["ZINC", "FER", "EAU", "GEL"].includes(c.cluster_princeps.toUpperCase()) // Allow legitimate short names
        );

        if (shortNames.length > 0) {
            console.log(`\n⚠️  Found ${shortNames.length} clusters with suspicious SHORT princeps names (< 4 chars):`);
            shortNames.forEach(c => {
                console.log(`   - [${c.cluster_id}] "${c.cluster_princeps}" (Substance: ${c.substance_label})`);
            });
        } else {
            console.log("\n✅ No suspicious short princeps names found.");
        }

        // 2. Split Clusters (Same Substance, Multiple Clusters)
        const substanceMap = new Map<string, Cluster[]>();
        clusters.forEach(c => {
            const sub = c.substance_label?.toUpperCase().trim();
            if (sub) {
                if (!substanceMap.has(sub)) substanceMap.set(sub, []);
                substanceMap.get(sub)!.push(c);
            }
        });

        let splitCount = 0;
        console.log("\n🔍 Checking for Split Clusters (Same Substance)...");
        for (const [sub, group] of substanceMap.entries()) {
            if (group.length > 1) {
                // Filter out cases where split might be legitimate (e.g. diff dosage if substance label doesn't capture it? 
                // But substance_label usually captures molecules. 
                // Verify if it's just "PARACETAMOL" split into 3 groups.)

                console.log(`   - "${sub}" is split into ${group.length} clusters:`);
                group.forEach(c => console.log(`     * [${c.cluster_id}] Princeps: "${c.cluster_princeps}" (Count: ${c.cis_count})`));
                splitCount++;
            }
        }

        if (splitCount === 0) {
            console.log("✅ No obvious split clusters found based on exact substance name match.");
        } else {
            console.log(`⚠️  Found ${splitCount} substances split across multiple clusters.`);
        }

    } catch (e) {
        console.error("❌ Failed to read or parse audit file:", e);
        console.log("   Make sure 'bun run preflight' has finished successfully.");
    }
}

main();
