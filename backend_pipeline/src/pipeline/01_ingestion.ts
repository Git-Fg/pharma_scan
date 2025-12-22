import * as fs from 'fs';
import * as path from 'path';
import {
    ParsedCIS, ParsedCISSchema,
    ParsedGener, ParsedGenerSchema,
    ParsedCIP, ParsedCIPSchema
} from '../types';

const HOMEO_LABS = ['BOIRON', 'LEHNING', 'WELEDA'];
const HOMEO_KEYWORDS = ['HOMEOPATHI', 'DILUTION'];







export interface ValidationReport {
    phase: string;
    issues: string[];
}

function normalizeString(str: string): string {
    return str
        .trim()
        .toUpperCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/\((S)?E\)/g, '')
        .replace(/\s+/g, ' ')
        .replace(/MEDICAMENTEUX\s*\(SE\)/g, 'MEDICAMENTEUX')
        .trim();
}

function aggressiveSubtract(normName: string, normShape: string): string | null {
    const tokens = normShape.split(/[\s\(\),;:\.\/]+/).filter(t => t.length > 2);
    if (tokens.length === 0) return null;

    const pivot = tokens[0];
    const regex = new RegExp(`\\b${pivot}\\b`, 'g');
    let match;
    let lastMatchIndex = -1;

    while ((match = regex.exec(normName)) !== null) {
        lastMatchIndex = match.index;
    }

    if (lastMatchIndex > 0) {
        let cleaned = normName.substring(0, lastMatchIndex).trim();
        cleaned = cleaned.replace(/[,.;:\-\/]+$/, '').trim();
        if (cleaned.length > 1) {
            return cleaned;
        }
    }
    return null;
}

function subtractShape(name: string, shape: string): string {
    const normName = normalizeString(name);

    // Strategy 1: First Comma Split
    const firstCommaIndex = normName.indexOf(', ');
    if (firstCommaIndex !== -1) {
        return normName.substring(0, firstCommaIndex).trim();
    }

    // Strategy 2: Cut From Shape
    const normShape = normalizeString(shape);
    const shapeIndex = normName.lastIndexOf(normShape);

    if (shapeIndex !== -1) {
        let cleaned = normName.substring(0, shapeIndex).trim();
        cleaned = cleaned.replace(/[,.;:\-\/]+$/, '').trim();
        return cleaned;
    }

    // Strategy 3: Aggressive Fallback
    const aggressiveResult = aggressiveSubtract(normName, normShape);
    if (aggressiveResult !== null) return aggressiveResult;

    return normName;
}

export function validateIngestion(result: IngestionResult): ValidationReport {
    const issues: string[] = [];

    // Ghost CIS check (README: 2430 ghosts found)
    const ghostCount = result.ghostCIS.length;
    if (ghostCount > 3000) issues.push(`Ghost CIS explosion: ${ghostCount}`);

    // Shape subtraction anomalies (README: target 0)
    if (result.cleaningAnomalies > 10) {
        issues.push(`Shape subtraction failed: ${result.cleaningAnomalies} anomalies`);
    }

    // Homeopathy detection sanity (README: ~9.33%)
    const homeoRate = result.homeoCount / result.totalCIS;
    if (homeoRate < 0.05 || homeoRate > 0.15) {
        issues.push(`Homeopathy rate anomaly: ${(homeoRate * 100).toFixed(1)}%`);
    }

    return { phase: 'INGESTION', issues };
}




export interface IngestionResult {
    cisData: ParsedCIS[];
    generData: ParsedGener[];
    cipData: ParsedCIP[];
    ghostCIS: string[];
    cleaningAnomalies: number;
    homeoCount: number;
    totalCIS: number;
    validationErrors: {
        cisErrors: number;
        generErrors: number;
        cipErrors: number;
    };
}

export async function runIngestion(dataDir: string, outputDir: string): Promise<IngestionResult> {
    console.log('🚀 Phase 1: Ingestion & Normalization');

    const INPUT_CIS = path.join(dataDir, 'CIS_bdpm.txt');
    const INPUT_GENER = path.join(dataDir, 'CIS_GENER_bdpm.txt');
    const INPUT_CIP = path.join(dataDir, 'CIS_CIP_bdpm.txt');

    // 1. PROCESS CIS_BDPM
    const cisContent = fs.readFileSync(INPUT_CIS, 'utf-8');
    const cisLines = cisContent.split('\n');

    const cisData: ParsedCIS[] = [];
    const cleaningAnomalies: string[] = [];

    let countTotal = 0;
    let countHomeo = 0;
    let cisValidationErrors = 0;

    for (const line of cisLines) {
        if (!line.trim()) continue;
        const cols = line.split('\t');

        if (cols.length < 11) continue;

        countTotal++;
        const cis = cols[0].trim();
        const originalName = cols[1].trim();
        const shape = cols[2].trim();
        const lab = cols[10].trim();
        const voies = cols[3].trim();
        const procedure = cols[5].trim();
        const dateAmm = cols[7].trim();
        const isSurveillance = cols[11].trim().toUpperCase() === 'OUI' || cols[11].trim().toUpperCase().includes('RENFORCÉE');

        // Homeopathy detection
        let isHomeo = false;
        let homeoReason: string | null = null;

        const normLab = normalizeString(lab);
        const normName = normalizeString(originalName);

        if (HOMEO_LABS.some(l => normLab.includes(l))) {
            isHomeo = true;
            homeoReason = `LAB: ${lab}`;
        } else if (HOMEO_KEYWORDS.some(kw => normName.includes(kw))) {
            isHomeo = true;
            homeoReason = 'KEYWORD detected';
        }

        if (isHomeo) countHomeo++;

        const cleanName = subtractShape(originalName, shape);

        // Cleaning validation
        if (!isHomeo && shape.length > 2 && cleanName === normalizeString(originalName) && !originalName.includes(shape.toUpperCase())) {
            cleaningAnomalies.push(`${cis}\t${originalName}\t[FORME: ${shape}]`);
        }

        const rawObj = {
            cis,
            originalName,
            shape,
            cleanName,
            lab,
            isHomeo,
            homeoReason,
            status: cols[4].trim(),
            commercialStatus: cols[6].trim(),
            voies,
            procedure,
            dateAmm,
            isSurveillance,
            titulaireId: 0
        };

        const parsed = ParsedCISSchema.safeParse(rawObj);
        if (parsed.success) {
            cisData.push(parsed.data);
        } else {
            cisValidationErrors++;
            if (cisValidationErrors <= 5) {
                console.warn(`CIS validation error for ${cis}:`, parsed.error.issues[0]?.message);
            }
        }
    }

    // 2. PROCESS CIS_GENER
    const generContent = fs.readFileSync(INPUT_GENER, 'utf-8');
    const generLines = generContent.split('\n');
    const generData: ParsedGener[] = [];
    let generValidationErrors = 0;

    for (const line of generLines) {
        if (!line.trim()) continue;
        const cols = line.split('\t');
        if (cols.length < 5) continue;

        const rawObj = {
            groupId: cols[0].trim(),
            groupLabel: cols[1].trim(),
            cis: cols[2].trim(),
            type: cols[3].trim(),
            sortOrder: cols[4].trim()
        };

        const parsed = ParsedGenerSchema.safeParse(rawObj);
        if (parsed.success) {
            generData.push(parsed.data);
        } else {
            generValidationErrors++;
            if (generValidationErrors <= 5) {
                console.warn(`GENER validation error for group ${cols[0]}:`, parsed.error.issues[0]?.message);
            }
        }
    }

    // 3. PROCESS CIS_CIP (Medicaments)
    console.log('📦 Ingesting CIP/Presentation data...');
    const cipContent = fs.readFileSync(INPUT_CIP, 'utf-8');
    const cipLines = cipContent.split('\n');
    const cipData: ParsedCIP[] = [];
    let cipValidationErrors = 0;

    for (const line of cipLines) {
        if (!line.trim()) continue;
        const cols = line.split('\t');
        if (cols.length < 13) continue;

        const priceStr = cols[9].trim().replace(',', '.');
        const price = priceStr ? parseFloat(priceStr) : null;

        const rawObj = {
            cis: cols[0].trim(),
            cip7: cols[1].trim(),
            presentationLabel: cols[2].trim(),
            status: cols[3].trim(),
            commercialisationStatus: cols[4].trim(),
            dateCommercialisation: cols[5].trim(),
            cip13: cols[6].trim(),
            agrement: cols[7].trim(),
            tauxRemboursement: cols[8].trim(),
            prix: cols[9].trim(),
            priceFormatted: price
        };

        const parsed = ParsedCIPSchema.safeParse(rawObj);
        if (parsed.success) {
            cipData.push(parsed.data);
        } else {
            cipValidationErrors++;
            if (cipValidationErrors <= 5) {
                console.warn(`CIP validation error for ${cols[0]}:`, parsed.error.issues[0]?.message);
            }
        }
    }

    // 4. DETECT GHOST CIS
    const validCisSet = new Set(cisData.map(c => c.cis));
    const ghostCIS = generData
        .map(g => g.cis)
        .filter(cis => !validCisSet.has(cis));

    console.log(`✅ Processed ${cisData.length} CIS, ${generData.length} generic groups, ${cipData.length} CIPs`);
    console.log(`   Homeopathy: ${countHomeo} (${((countHomeo / countTotal) * 100).toFixed(1)}%)`);
    console.log(`   Ghost CIS: ${ghostCIS.length}`);
    console.log(`   Cleaning anomalies: ${cleaningAnomalies.length}`);

    if (cisValidationErrors > 0 || generValidationErrors > 0 || cipValidationErrors > 0) {
        console.log(`⚠️  Validation errors: CIS=${cisValidationErrors}, GENER=${generValidationErrors}, CIP=${cipValidationErrors}`);
    }

    return {
        cisData,
        generData,
        cipData,
        ghostCIS,
        cleaningAnomalies: cleaningAnomalies.length,
        homeoCount: countHomeo,
        totalCIS: countTotal,
        validationErrors: {
            cisErrors: cisValidationErrors,
            generErrors: generValidationErrors,
            cipErrors: cipValidationErrors
        }
    };
}

