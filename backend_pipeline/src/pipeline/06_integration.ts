import type { ParsedCIS } from '../types';
import type { ChemicalProfile } from './02_profiling';
import type { NamedCluster } from './05_naming';
import type { PrincepsElection } from './03_election';
import { findLongestCommonSubstring } from './05_naming';
import { computeCanonicalSubstance } from '../sanitizer';

export interface FinalCluster extends NamedCluster {
    orphansCIS: string[];
    secondaryPrinceps: string[];
    totalCIS: number;
    search_vector: string;
}

export interface IntegrationResult {
    finalClusters: FinalCluster[];
    orphansAttached: number;
    orphansIsolated: number;
}

export interface ValidationReport {
    phase: string;
    issues: string[];
}

export function validateIntegration(result: IntegrationResult): ValidationReport {
    const issues: string[] = [];

    // Orphan attachment (README: >3000 attached)
    if (result.orphansAttached < 1000) {
        issues.push(`Low orphan attachment: ${result.orphansAttached}`);
    }

    // Total CIS coverage (README: >14000 non-homeo CIS)
    const totalCIS = result.finalClusters.reduce((sum, c) => sum + c.totalCIS, 0);
    if (totalCIS < 10000) {
        issues.push(`Low total CIS coverage: ${totalCIS}`);
    }

    return { phase: 'INTEGRATION', issues };
}

export async function runIntegration(
    namedClusters: NamedCluster[],
    cisData: ParsedCIS[],
    profiles: Map<string, ChemicalProfile>,
    elections: Map<string, PrincepsElection>
): Promise<IntegrationResult> {
    console.log('🔗 Phase 6: Orphan Integration');

    // 1. Identify orphans (CIS not in any generic group)
    const groupedCIS = new Set<string>();
    namedClusters.forEach(cluster => {
        cluster.sourceCIS.forEach(cis => groupedCIS.add(cis));
    });

    const orphans = cisData.filter(c => !c.isHomeo && !groupedCIS.has(c.cis));
    console.log(`   Found ${orphans.length} orphans`);

    // 2. Build chemicalId index
    const clustersByChemId = new Map<string, NamedCluster>();
    namedClusters.forEach(c => clustersByChemId.set(c.chemicalId, c));

    // 3. Attach orphans to clusters
    const orphanAttachments = new Map<string, string[]>(); // chemicalId -> orphan CIS[]
    let countAttached = 0;
    let countIsolated = 0;

    // Debug stats
    let debugNoProfile = 0;
    let debugNoCluster = 0;
    const missingChemIds = new Map<string, { count: number, example: string }>();

    for (const orphan of orphans) {
        const profile = profiles.get(orphan.cis);
        if (!profile) {
            countIsolated++;
            debugNoProfile++;
            continue;
        }

        const chemId = profile.chemicalId;
        if (clustersByChemId.has(chemId)) {
            if (!orphanAttachments.has(chemId)) orphanAttachments.set(chemId, []);
            orphanAttachments.get(chemId)?.push(orphan.cis);
            countAttached++;
        } else {
            countIsolated++;
            debugNoCluster++;

            // Track missing chem IDs
            if (!missingChemIds.has(chemId)) {
                missingChemIds.set(chemId, { count: 0, example: orphan.originalName });
            }
            missingChemIds.get(chemId)!.count++;
        }
    }

    console.log(`\n🔍 Orphan Isolation Analysis:`);
    console.log(`   - Missing Profile: ${debugNoProfile}`);
    console.log(`   - No Matching Cluster: ${debugNoCluster}`);

    if (debugNoCluster > 0) {
        console.log(`   - Top 10 Missing Chemical IDs (Potential Orphan-Only Clusters):`);
        const sortedMissing = [...missingChemIds.entries()].sort((a, b) => b[1].count - a[1].count).slice(0, 10);
        sortedMissing.forEach(([id, stats]) => {
            console.log(`     • ${id}: ${stats.count} CIS (e.g. ${stats.example})`);
        });
    }
    console.log('');


    // 4. Promote unattached orphans to new clusters (Recovery Strategy)
    const orphansPromoted = new Map<string, string[]>(); // chemId -> cis[]

    // Re-iterate to collect unattached orphans that have a profile
    for (const orphan of orphans) {
        const profile = profiles.get(orphan.cis);
        if (profile && !clustersByChemId.has(profile.chemicalId)) {
            if (!orphansPromoted.has(profile.chemicalId)) {
                orphansPromoted.set(profile.chemicalId, []);
            }
            orphansPromoted.get(profile.chemicalId)!.push(orphan.cis);
        }
    }

    let countPromoted = 0;
    const promotedClusters: FinalCluster[] = [];

    for (const [chemId, cisList] of orphansPromoted.entries()) {
        const profile = profiles.get(cisList[0])!;

        // Use the first orphan's name as the cluster name (simplified)
        let rawDisplayName = cisData.find(c => c.cis === cisList[0])?.originalName.split(',')[0] || "Unknown";

        // Remove dosage from name if possible to be generic
        rawDisplayName = rawDisplayName.replace(/\d+\s*(mg|g|ml|%)\b/gi, '').trim();

        const displayName = computeCanonicalSubstance(rawDisplayName);

        const substanceNames = profile.substances.map(s => s.name).join(' ');

        promotedClusters.push({
            chemicalId: chemId,
            superClusterId: `ORPH_${chemId}`,
            sourceGroupIds: [],
            sourceCIS: [],
            displayName: displayName,
            namingMethod: 'SINGLE_SOURCE',
            sampleNames: [displayName],
            orphansCIS: cisList,
            secondaryPrinceps: [],
            totalCIS: cisList.length,
            search_vector: `${displayName} ${substanceNames}`.toUpperCase()
        });
        countPromoted += cisList.length;
    }

    console.log(`   - 🚀 Promoted ${promotedClusters.length} new clusters from ${countPromoted} orphans`);

    // 5. Build final clusters with secondary princeps (Existing Clusters)
    const processedExistingClusters: FinalCluster[] = [];

    for (const cluster of namedClusters) {
        const orphansCIS = orphanAttachments.get(cluster.chemicalId) || [];

        // Collect secondary princeps from all source groups
        const secondaryPrinceps: string[] = [];
        for (const groupId of cluster.sourceGroupIds) {
            const election = elections.get(groupId);
            if (election?.secondaryPrinceps) {
                election.secondaryPrinceps.forEach(sp => {
                    if (!secondaryPrinceps.includes(sp.name)) {
                        secondaryPrinceps.push(sp.name);
                    }
                });
            }
        }

        // Apply LCS/Trigram consolidation to secondary princeps
        const consolidatedSecondaries: string[] = [];
        if (secondaryPrinceps.length > 0) {
            // Group similar names using simple prefix matching
            const grouped = new Map<string, string[]>();
            for (const name of secondaryPrinceps) {
                const prefix = name.split(' ')[0];
                if (!grouped.has(prefix)) grouped.set(prefix, []);
                grouped.get(prefix)?.push(name);
            }

            // Take LCS of each group
            for (const group of grouped.values()) {
                if (group.length === 1) {
                    consolidatedSecondaries.push(group[0]);
                } else {
                    const lcs = findLongestCommonSubstring(group);
                    if (lcs.length >= 3) {
                        consolidatedSecondaries.push(lcs);
                    } else {
                        consolidatedSecondaries.push(group[0]);
                    }
                }
            }
        }

        // Compute search vector
        let profile: ChemicalProfile | undefined;
        let sampleCis = "";
        for (const cis of cluster.sourceCIS) {
            profile = profiles.get(cis);
            if (profile) {
                sampleCis = cis;
                break;
            }
        }
        if (!sampleCis) {
            sampleCis = cluster.sourceCIS[0];
            profile = profiles.get(sampleCis);
        }
        const substanceNames = profile?.substances.map(s => s.name).join(' ') || "";

        if (processedExistingClusters.length < 5) {
            // Debug logging for cluster processing (remove in production)
        }

        const rawNames = cluster.sourceCIS.slice(0, 5)
            .map(cis => cisData.find(c => c.cis === cis)?.originalName.split(',')[0] || '')
            .filter(n => n);

        const searchVector = [
            cluster.displayName,
            ...consolidatedSecondaries,
            substanceNames,
            ...rawNames
        ].join(' ').toUpperCase();


        processedExistingClusters.push({
            ...cluster,
            orphansCIS,
            secondaryPrinceps: consolidatedSecondaries,
            totalCIS: cluster.sourceCIS.length + orphansCIS.length,
            search_vector: searchVector
        });
    }

    // Merge Promoted + Existing
    const finalClusters = [...processedExistingClusters, ...promotedClusters];

    console.log(`✅ Integrated ${finalClusters.length} final clusters`);
    console.log(`   Orphans attached: ${countAttached}`);
    console.log(`   Orphans Promoted: ${countPromoted}`);
    console.log(`   Orphans isolated (No Profile): ${debugNoProfile}`);

    return {
        finalClusters,
        orphansAttached: countAttached + countPromoted,
        orphansIsolated: debugNoProfile
    };
}
