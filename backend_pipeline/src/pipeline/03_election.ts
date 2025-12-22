import type { ParsedCIS, ParsedGener } from '../types';

export interface PrincepsElection {
    groupId: string;
    goldenPrincepsCIS: string | null;
    goldenPrincepsName: string | null;
    method: 'ACTIVE_PRINCEPS' | 'FALLBACK_LABEL';
    secondaryPrinceps: { cis: string; name: string }[];
    candidatesCount: number;
}

export interface ElectionResult {
    elections: Map<string, PrincepsElection>;
    activePrincepsCount: number;
    fallbackCount: number;
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

function cleanFallbackLabel(label: string): string {
    // 1. Extract after last dash
    const parts = label.split(' - ');
    let extracted = parts.length > 1 ? parts[parts.length - 1].trim() : label;

    // 2. Clean basic (comma, form)
    const norm = normalizeString(extracted);

    const commaIndex = norm.indexOf(', ');
    if (commaIndex !== -1) {
        return norm.substring(0, commaIndex).trim();
    }

    const shapeKeywords = [
        ' COMPRIME', ' GELULE', ' SOLUTION', ' SUSPENSION', ' POUDRE',
        ' CREME', ' POMMADE', ' SIROP', ' SUPPOSITOIRE', ' INJECTABLE', ' LYOPHILISAT'
    ];

    for (const shape of shapeKeywords) {
        const idx = norm.lastIndexOf(shape);
        if (idx !== -1) {
            return norm.substring(0, idx).trim();
        }
    }

    return norm;
}

export function validateElection(result: ElectionResult): ValidationReport {
    const issues: string[] = [];

    // Active Princeps Rate (README: ~80% should have active princeps)
    const totalGroups = result.elections.size;
    const activePrincepsRate = result.activePrincepsCount / totalGroups;

    if (activePrincepsRate < 0.70) {
        issues.push(`Low active princeps rate: ${(activePrincepsRate * 100).toFixed(1)}%`);
    }

    // Fallback usage
    const fallbackRate = result.fallbackCount / totalGroups;
    if (fallbackRate > 0.30) {
        issues.push(`High fallback usage: ${(fallbackRate * 100).toFixed(1)}%`);
    }

    return { phase: 'ELECTION', issues };
}

export async function runElection(
    cisData: ParsedCIS[],
    generData: ParsedGener[]
): Promise<ElectionResult> {
    console.log('🗳️  Phase 3: Princeps Election (Highlander)');

    // Index CIS data
    const cisMap = new Map<string, ParsedCIS>();
    cisData.forEach(c => cisMap.set(c.cis, c));

    // Group by groupId
    const groups = new Map<string, ParsedGener[]>();
    generData.forEach(g => {
        if (!groups.has(g.groupId)) groups.set(g.groupId, []);
        groups.get(g.groupId)?.push(g);
    });

    const elections = new Map<string, PrincepsElection>();
    let countActive = 0;
    let countFallback = 0;

    for (const [groupId, members] of groups.entries()) {
        const type0 = members.filter(m => m.type === '0');

        // HIGHLANDER LOGIC
        // 1. Filter active candidates
        const activeCandidates = type0.filter(t0 => {
            const info = cisMap.get(t0.cis);
            if (!info) return false;

            const statusOk = info.status.includes('Active') || info.status.includes('Autorisation active');
            const commercialOk = info.commercialStatus.includes('Commercialis');
            return statusOk || commercialOk;
        });

        // 2. Sort by seniority (sortOrder)
        activeCandidates.sort((a, b) => parseInt(a.sortOrder || '999') - parseInt(b.sortOrder || '999'));

        let winnerCIS: string | null = null;
        let winnerName: string | null = null;
        const secondaries: { cis: string; name: string }[] = [];
        let method: 'ACTIVE_PRINCEPS' | 'FALLBACK_LABEL' = 'FALLBACK_LABEL';

        if (activeCandidates.length > 0) {
            const best = activeCandidates[0];
            const info = cisMap.get(best.cis);
            if (info) {
                winnerCIS = best.cis;
                winnerName = info.cleanName;
                method = 'ACTIVE_PRINCEPS';
                countActive++;

                // All other actives are secondaries
                for (let i = 1; i < activeCandidates.length; i++) {
                    const sec = activeCandidates[i];
                    const secInfo = cisMap.get(sec.cis);
                    if (secInfo) {
                        secondaries.push({ cis: sec.cis, name: secInfo.cleanName });
                    }
                }
            }
        }

        if (!winnerName) {
            // FALLBACK: Virtual princeps from group label
            const label = members[0].groupLabel;
            winnerName = cleanFallbackLabel(label);
            winnerCIS = null;
            countFallback++;
        }

        elections.set(groupId, {
            groupId,
            goldenPrincepsCIS: winnerCIS,
            goldenPrincepsName: winnerName!,
            method,
            secondaryPrinceps: secondaries,
            candidatesCount: type0.length
        });
    }

    console.log(`✅ Elected ${elections.size} Golden Princeps`);
    console.log(`   Active: ${countActive}, Fallback: ${countFallback}`);

    return {
        elections,
        activePrincepsCount: countActive,
        fallbackCount: countFallback
    };
}
