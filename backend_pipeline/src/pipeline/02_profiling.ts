import * as fs from 'fs';
import * as path from 'path';
import type { ParsedCIS } from '../types';

export interface ChemicalProfile {
    cis: string;
    chemicalId: string;
    substances: {
        code: string;
        name: string;
        dosage: string;
    }[];
}

export interface SubstanceMeta {
    code: string;
    variations: string[];
    canonicalName: string;
    strategy: 'UNIQUE' | 'PARENTHESIS' | 'SHORTEST';
}

export interface ProfilingResult {
    profiles: Map<string, ChemicalProfile>;
    substanceDictionary: Map<string, SubstanceMeta>;
    ftSaConflictsResolved: number;
}

export interface ValidationReport {
    phase: string;
    issues: string[];
}

interface RawCompoLine {
    cis: string;
    substanceCode: string;
    substanceName: string;
    dosage: string;
    nature: string;
    linkId: string;
}

function normalizeString(str: string): string {
    return str.trim().toUpperCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function getCanonicalName(variations: Set<string>): { name: string, strategy: 'UNIQUE' | 'PARENTHESIS' | 'SHORTEST' } {
    const vars = Array.from(variations);
    if (vars.length === 0) return { name: "UNKNOWN", strategy: 'UNIQUE' };
    if (vars.length === 1) return { name: vars[0], strategy: 'UNIQUE' };

    const withParens = vars.filter(v => v.includes('(') && v.includes(')') && v.indexOf('(') > 0);

    if (withParens.length > 0) {
        withParens.sort((a, b) => a.length - b.length);
        return { name: withParens[0], strategy: 'PARENTHESIS' };
    }

    vars.sort((a, b) => a.length - b.length);
    return { name: vars[0], strategy: 'SHORTEST' };
}

export function validateProfiling(result: ProfilingResult): ValidationReport {
    const issues: string[] = [];

    // ChemicalID cardinality (README: 2458 unique)
    const uniqueChemIds = new Set([...result.profiles.values()].map(p => p.chemicalId));
    if (uniqueChemIds.size < 2000) issues.push(`Too few chemicalIds: ${uniqueChemIds.size}`);
    if (uniqueChemIds.size > 3000) issues.push(`Suspicious chemicalId explosion: ${uniqueChemIds.size}`);

    // FT>SA resolution sanity (README: ~5500 conflicts)
    if (result.ftSaConflictsResolved < 4500 || result.ftSaConflictsResolved > 6500) {
        issues.push(`FT>SA conflict count anomaly: ${result.ftSaConflictsResolved}`);
    }

    return { phase: 'PROFILING', issues };
}

export async function runProfiling(
    cisData: ParsedCIS[],
    dataDir: string
): Promise<ProfilingResult> {
    console.log('🧪 Phase 2: Chemical Profiling');

    const INPUT_COMPO = path.join(dataDir, 'CIS_COMPO_bdpm.txt');

    // 1. Build whitelist (exclude homeopathy)
    const validCisSet = new Set<string>();
    let countHomeoExcluded = 0;

    for (const item of cisData) {
        if (!item.isHomeo) {
            validCisSet.add(item.cis);
        } else {
            countHomeoExcluded++;
        }
    }

    console.log(`   Valid CIS: ${validCisSet.size} (${countHomeoExcluded} homeo excluded)`);

    // 2. Read and filter CIS_COMPO
    const content = fs.readFileSync(INPUT_COMPO, 'utf-8');
    const lines = content.split('\n');

    const compoByCis = new Map<string, RawCompoLine[]>();
    const substanceVariations = new Map<string, Set<string>>();

    let countLinesKept = 0;
    let countLinesSkippedHomeo = 0;

    for (const line of lines) {
        if (!line.trim()) continue;
        const cols = line.split('\t');
        if (cols.length < 8) continue;

        const cis = cols[0].trim();

        if (!validCisSet.has(cis)) {
            countLinesSkippedHomeo++;
            continue;
        }

        const code = cols[2].trim();
        const name = cols[3].trim();
        const dosage = cols[4].trim();
        const nature = cols[6].trim();
        const linkId = cols[7].trim();

        const normName = normalizeString(name);

        if (normName.includes('HOMEOPATHIQUE')) {
            countLinesSkippedHomeo++;
            continue;
        }

        countLinesKept++;

        if (!compoByCis.has(cis)) compoByCis.set(cis, []);
        compoByCis.get(cis)?.push({ cis, substanceCode: code, substanceName: name, dosage, nature, linkId });

        if (!substanceVariations.has(code)) substanceVariations.set(code, new Set());
        substanceVariations.get(code)?.add(normName);
    }

    // 3. Create canonical substance dictionary
    const substanceDictionary = new Map<string, SubstanceMeta>();

    for (const [code, vars] of substanceVariations.entries()) {
        const { name, strategy } = getCanonicalName(vars);

        substanceDictionary.set(code, {
            code,
            variations: Array.from(vars),
            canonicalName: name,
            strategy
        });
    }

    // 4. Resolve FT>SA and generate chemical signatures
    const profiles = new Map<string, ChemicalProfile>();
    let countFTSA_Resolved = 0;

    for (const [cis, lines] of compoByCis.entries()) {
        const byLink = new Map<string, RawCompoLine[]>();
        const independentLines: RawCompoLine[] = [];

        for (const l of lines) {
            if (l.linkId && l.linkId !== '0') {
                if (!byLink.has(l.linkId)) byLink.set(l.linkId, []);
                byLink.get(l.linkId)?.push(l);
            } else {
                independentLines.push(l);
            }
        }

        const finalSubstances: RawCompoLine[] = [...independentLines];

        for (const [linkId, group] of byLink.entries()) {
            if (group.length === 1) {
                finalSubstances.push(group[0]);
            } else {
                const ft = group.find(g => g.nature === 'FT' || g.nature === 'ST');
                if (ft) {
                    finalSubstances.push(ft);
                    countFTSA_Resolved++;
                } else {
                    finalSubstances.push(group[0]);
                }
            }
        }

        finalSubstances.sort((a, b) => a.substanceCode.localeCompare(b.substanceCode));

        const activeSubstanceCodes = finalSubstances.map(s => s.substanceCode);
        const chemicalId = activeSubstanceCodes.join('+');

        profiles.set(cis, {
            cis,
            chemicalId,
            substances: finalSubstances.map(s => ({
                code: s.substanceCode,
                name: substanceDictionary.get(s.substanceCode)?.canonicalName || s.substanceName,
                dosage: s.dosage
            }))
        });
    }

    const uniqueChemIds = new Set([...profiles.values()].map(p => p.chemicalId));
    console.log(`✅ Generated ${profiles.size} chemical profiles`);
    console.log(`   Unique chemicalIds: ${uniqueChemIds.size}`);
    console.log(`   FT>SA conflicts resolved: ${countFTSA_Resolved}`);

    return {
        profiles,
        substanceDictionary,
        ftSaConflictsResolved: countFTSA_Resolved
    };
}
