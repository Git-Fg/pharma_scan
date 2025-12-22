import type { SuperCluster } from './04_clustering';
import type { PrincepsElection } from './03_election';

export interface NamedCluster extends SuperCluster {
    displayName: string;
    namingMethod: 'LCS_CONSENSUS' | 'SINGLE_SOURCE' | 'BRAND_EXTRACTION_FALLBACK';
    sampleNames: string[];
}

export interface NamingResult {
    namedClusters: NamedCluster[];
}

export interface ValidationReport {
    phase: string;
    issues: string[];
}

function normalizeString(str: string): string {
    return str.trim().toUpperCase()
        .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
        .replace(/\s+/g, ' ');
}

export function findLongestCommonSubstring(strings: string[]): string {
    if (strings.length === 0) return "";
    if (strings.length === 1) return strings[0];

    // 1. Tokenization (clean dosages for LCS)
    const tokenized = strings.map(s => {
        let clean = normalizeString(s);
        // Mask decimal numbers
        clean = clean.replace(/(\d)[.,](\d)/g, '$1DECIMAL$2');
        // Split
        return clean.split(/[\s\-,.()]+/)
            .map(t => t.replace('DECIMAL', ','))
            .filter(t => t.length > 0);
    });

    const shortest = tokenized.reduce((a, b) => a.length < b.length ? a : b);

    // Heuristic: Look for word sequences
    for (let len = shortest.length; len > 0; len--) {
        for (let start = 0; start <= shortest.length - len; start++) {
            const candidate = shortest.slice(start, start + len);
            const candidateStr = candidate.join(' ');

            // Strict regex (Word Boundary)
            const regex = new RegExp(`\\b${candidateStr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i');

            const allMatch = strings.every(s => regex.test(normalizeString(s)));
            if (allMatch) return candidateStr;
        }
    }

    return "";
}

function extractBrandName(rawName: string): string {
    let res = normalizeString(rawName);
    // Remove standard dosages
    res = res.replace(/[\d.,]+\s*(MG|G|ML|%|UI|M\.?U\.?I|MCG|MICROGRAMMES?)\b/gi, '');
    // Remove isolated numbers
    res = res.replace(/\b\d+\b/g, '');

    const words = res.split(/\s+/).filter(w => w.length > 2);
    // Basic stopwords
    const stop = ['POUR', 'NOURRISSON', 'ENFANT', 'ADULTE', 'SANS', 'AVEC'];
    const candidates = words.filter(w => !stop.includes(w));

    return candidates[0] || "UNKNOWN";
}

export function validateNaming(result: NamingResult): ValidationReport {
    const issues: string[] = [];

    // LCS truncation check (README: TIMOPTOL 0 problem)
    const truncated = result.namedClusters.filter(c => /^\d+$/.test(c.displayName || ''));
    if (truncated.length > 5) {
        issues.push(`LCS truncation detected: ${truncated.map(c => c.displayName).join(', ')}`);
    }

    // Short names
    const shortNames = result.namedClusters.filter(c => (c.displayName?.length || 0) < 3);
    if (shortNames.length > 10) {
        issues.push(`Too many short names: ${shortNames.length}`);
    }

    return { phase: 'NAMING', issues };
}

export async function runNaming(
    superClusters: SuperCluster[],
    elections: Map<string, PrincepsElection>
): Promise<NamingResult> {
    console.log('🏷️  Phase 5: LCS Naming Engine');

    const namedClusters: NamedCluster[] = [];

    for (const cluster of superClusters) {
        // Collect all Golden Princeps names from source groups
        const princepsNames: string[] = [];

        for (const groupId of cluster.sourceGroupIds) {
            const election = elections.get(groupId);
            if (election?.goldenPrincepsName) {
                princepsNames.push(election.goldenPrincepsName);
            }
        }

        let displayName: string;
        let namingMethod: 'LCS_CONSENSUS' | 'SINGLE_SOURCE' | 'BRAND_EXTRACTION_FALLBACK';

        if (princepsNames.length === 0) {
            // Fallback: No princeps found
            displayName = `CLUSTER_${cluster.chemicalId.substring(0, 8)}`;
            namingMethod = 'BRAND_EXTRACTION_FALLBACK';
        } else if (princepsNames.length === 1) {
            // Single source: Use as-is
            displayName = princepsNames[0];
            namingMethod = 'SINGLE_SOURCE';
        } else {
            // Multiple sources: Apply LCS
            const lcs = findLongestCommonSubstring(princepsNames);

            if (lcs.length >= 3 && !/^\d+$/.test(lcs)) {
                displayName = lcs;
                namingMethod = 'LCS_CONSENSUS';
            } else {
                // LCS failed: Fallback to brand extraction
                displayName = extractBrandName(princepsNames[0]);
                namingMethod = 'BRAND_EXTRACTION_FALLBACK';
            }
        }

        namedClusters.push({
            ...cluster,
            displayName,
            namingMethod,
            sampleNames: princepsNames.slice(0, 5)
        });
    }

    const lcsCount = namedClusters.filter(c => c.namingMethod === 'LCS_CONSENSUS').length;
    console.log(`✅ Named ${namedClusters.length} clusters`);
    console.log(`   LCS consensus: ${lcsCount}`);

    return { namedClusters };
}
