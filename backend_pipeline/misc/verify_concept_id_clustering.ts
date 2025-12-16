
import { parseCompositions } from "../src/parsing";
import { computeClusters, ClusteringInput } from "../src/clustering";

async function verify() {
    console.log("🧪 Starting Concept ID Clustering Verification...");

    // --- Test 1: parsing.ts (Extracting Codes) ---
    console.log("\n--- Test 1: Parsing Substance Codes ---");

    // Mock CSV Data
    // Col 0: CIS, Col 2: Code Substance, Col 3: Denomination, Col 4: Dosage, Col 6: Nature (SA/FT), Col 7: Link
    const mockRows = [
        // CIS 1: Paracetamol 500mg (Code: 02202)
        ["1", "PARACETAMOL", "02202", "PARACETAMOL", "500 mg", "ref", "SA", "1"],

        // CIS 2: Amoxicillin + Clavulanic Acid (Codes: 00451, 00123)
        // Linked via different LinkIDs
        ["2", "AMOXICILLINE", "00451", "AMOXICILLINE", "1 g", "ref", "SA", "1"],
        ["2", "ACIDE CLAVULANIQUE", "00123", "ACIDE CLAVULANIQUE", "125 mg", "ref", "SA", "2"],

        // CIS 3: Same as CIS 2 but different order in file
        ["3", "ACIDE CLAVULANIQUE", "00123", "ACIDE CLAVULANIQUE", "125 mg", "ref", "SA", "1"],
        ["3", "AMOXICILLINE", "00451", "AMOXICILLINE", "1 g", "ref", "SA", "2"],
    ];

    async function* rowGenerator() {
        for (const row of mockRows) {
            yield row;
        }
    }

    const { flattened, codes } = await parseCompositions(rowGenerator());

    console.log("Flattened Map Size:", flattened.size);
    console.log("Codes Map Size:", codes.size);

    // Assertions
    if (!codes.has("1")) throw new Error("CIS 1 missing from codes map");
    if (JSON.stringify(codes.get("1")) !== JSON.stringify(["02202"])) throw new Error(`CIS 1 codes mismatch: ${JSON.stringify(codes.get("1"))}`);

    if (!codes.has("2")) throw new Error("CIS 2 missing from codes map");
    if (JSON.stringify(codes.get("2")) !== JSON.stringify(["00123", "00451"])) throw new Error(`CIS 2 codes mismatch (should be sorted): ${JSON.stringify(codes.get("2"))}`);

    if (!codes.has("3")) throw new Error("CIS 3 missing from codes map");
    if (JSON.stringify(codes.get("3")) !== JSON.stringify(["00123", "00451"])) throw new Error(`CIS 3 codes mismatch (should be sorted and idential to CIS 2): ${JSON.stringify(codes.get("3"))}`);

    console.log("✅ Test 1 Passed: Substance codes extracted and sorted correctly.");


    // --- Test 2: clustering.ts (Hard Linking via Codes) ---
    console.log("\n--- Test 2: Clustering via Substance Codes ---");

    const inputs: ClusteringInput[] = [
        // Group A: "PARACETAMOL 500 MG" (Code 02202)
        {
            groupId: "GRP_A",
            princepsCisCode: null,
            princepsReferenceName: "DOLIPRANE",
            princepsForm: "COMPRIME",
            commonPrincipes: "PARACETAMOL",
            substanceCodes: ["02202"],
            isPrincepsGroup: false
        },
        // Group B: "PARACETAMOL 1 G" (Code 02202) - Different Dosage, Different Text
        // Should link to Group A via code
        {
            groupId: "GRP_B",
            princepsCisCode: null,
            princepsReferenceName: "DAFALGAN",
            princepsForm: "EFFERVESCENT",
            commonPrincipes: "PARACETAMOL",
            substanceCodes: ["02202"],
            isPrincepsGroup: false
        },
        // Group C: "IBUPROFENE 400 MG" (Code 99999) - Should NOT cluster with A/B
        {
            groupId: "GRP_C",
            princepsCisCode: null,
            princepsReferenceName: "ADVIL",
            princepsForm: "COMPRIME",
            commonPrincipes: "IBUPROFENE",
            substanceCodes: ["99999"],
            isPrincepsGroup: false
        }
    ];

    const clusters = computeClusters(inputs);

    console.log("Clusters computed:", clusters.size);

    const clusterA = clusters.get("GRP_A");
    const clusterB = clusters.get("GRP_B");
    const clusterC = clusters.get("GRP_C");

    if (!clusterA || !clusterB || !clusterC) throw new Error("Missing clusters for groups");

    if (clusterA.clusterId !== clusterB.clusterId) {
        throw new Error(`Groups A and B should be in same cluster (shared code 02202). Got A=${clusterA.clusterId}, B=${clusterB.clusterId}`);
    }

    if (clusterA.clusterId === clusterC.clusterId) {
        throw new Error(`Group C should be in DIFFERENT cluster. Got C=${clusterC.clusterId} same as A=${clusterA.clusterId}`);
    }

    console.log(`✅ Test 2 Passed: Groups clustered correctly via Substance Code. ClusterID: ${clusterA.clusterId}`);
    console.log("🎉 All Verification Tests Passed!");
}

verify().catch(console.error);
