import type { ParsedGener } from '../types';
import type { ChemicalProfile } from './02_profiling';

export interface SuperCluster {
    chemicalId: string;
    superClusterId: string;
    sourceGroupIds: string[];
    sourceCIS: string[];
}

export interface ClusteringResult {
    superClusters: SuperCluster[];
    discardedGroups: number;
}

export interface ValidationReport {
    phase: string;
    issues: string[];
}

export function validateClustering(result: ClusteringResult): ValidationReport {
    const issues: string[] = [];

    // Super-cluster count (README: ~377 after merge)
    const clusterCount = result.superClusters.length;
    if (clusterCount < 300) issues.push(`Too few clusters: ${clusterCount}`);
    if (clusterCount > 1000) issues.push(`Cluster explosion: ${clusterCount}`);

    // Dosage-agnostic merge test (GLUCOPHAGE example)
    const hasMultiGroupClusters = result.superClusters.some(c => c.sourceGroupIds.length > 2);
    if (!hasMultiGroupClusters) {
        issues.push('No super-clusters with multiple groups detected (dosage-agnostic merge may have failed)');
    }

    return { phase: 'CLUSTERING', issues };
}

export async function runClustering(
    generData: ParsedGener[],
    profiles: Map<string, ChemicalProfile>
): Promise<ClusteringResult> {
    console.log('⚗️  Phase 4: Chemical Super-Clustering');

    // 1. Build group membership map
    const groupMembers = new Map<string, string[]>();
    generData.forEach(g => {
        if (!groupMembers.has(g.groupId)) groupMembers.set(g.groupId, []);
        groupMembers.get(g.groupId)?.push(g.cis);
    });

    // 2. Calculate group chemical signatures (majority vote)
    const groupSignatures = new Map<string, string>();
    let countDiscardedGroups = 0;

    for (const [groupId, members] of groupMembers.entries()) {
        const signatures = members
            .map(cis => profiles.get(cis)?.chemicalId)
            .filter(Boolean) as string[];

        if (signatures.length === 0) {
            countDiscardedGroups++;
            continue;
        }

        // Majority vote
        const counts = new Map<string, number>();
        signatures.forEach(s => counts.set(s, (counts.get(s) || 0) + 1));

        const sorted = Array.from(counts.entries()).sort((a, b) => b[1] - a[1]);
        const winner = sorted[0][0];

        groupSignatures.set(groupId, winner);
    }

    // 3. Merge groups by chemicalId
    const chemicalClusters = new Map<string, string[]>();

    for (const [groupId, chemId] of groupSignatures.entries()) {
        if (!chemicalClusters.has(chemId)) chemicalClusters.set(chemId, []);
        chemicalClusters.get(chemId)?.push(groupId);
    }

    // 4. Build super-clusters
    const superClusters: SuperCluster[] = [];

    for (const [chemId, groupIds] of chemicalClusters.entries()) {
        const allCIS = groupIds.flatMap(gid => groupMembers.get(gid) || []);
        const uniqueCIS = [...new Set(allCIS)];

        superClusters.push({
            chemicalId: chemId,
            superClusterId: `SCL_${chemId}`,
            sourceGroupIds: groupIds,
            sourceCIS: uniqueCIS
        });
    }

    console.log(`✅ Created ${superClusters.length} super-clusters`);
    console.log(`   Discarded groups: ${countDiscardedGroups}`);
    console.log(`   Max groups per cluster: ${Math.max(...superClusters.map(s => s.sourceGroupIds.length))}`);

    return {
        superClusters,
        discardedGroups: countDiscardedGroups
    };
}
