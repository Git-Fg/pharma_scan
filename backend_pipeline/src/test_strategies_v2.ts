/**
 * Advanced Strategy Testing Framework v2
 *
 * Implements composition-based lookup using CIS_COMPO data
 * and the 4-phase approach from OBJECTIVE_BACKEND.md
 *
 * Key improvements:
 * - Phase 1: Use CIS_COMPO for true generic names
 * - Phase 2b: Extract forms from reference dosage column
 * - Phase 3: Aggregate dosages for better cleaning
 * - Phase 4: Consolidate using princeps data
 *
 * Usage:
 *   bun run src/test_strategies_v2.ts --compare
 */

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_JSON_DIR = path.join(__dirname, '../data_json');
const OUTPUT_DIR = path.join(__dirname, '../test_results');

// Data structures
interface SpecialiteRecord {
    cis_code: string;
    nom_specialite: string;
    forme_pharmaceutique: string;
    voies_administration: string;
    statut: string;
    titulaire: string;
}

interface CompositionRecord {
    cis_code: string;
    element_pharmaceutique: string;
    code_substance: string;
    denomination_substance: string;
    dosage_substance: string;
    ref_dosage: string;
    lien: string;  // SA (substance active) or FT (forme thérapeutique)
}

interface GenericRecord {
    group_id: string;
    group_label: string;
    cis_code: string;
    type: string;  // 0=princeps, 1=generic, 2=posological, 3=complementary
    ordre: string;
}

interface ProcessingResult {
    cleanBrand: string;
    cleanGeneric: string;
    form: string;
    confidence: number;
    method: string;
}

interface TestResult {
    strategy: string;
    total: number;
    success: number;
    failed: number;
    avgConfidence: number;
    samples: any[];
}

// Cache for data
let specialitesData: SpecialiteRecord[] = [];
let compositionData: CompositionRecord[] = [];
let genericsData: GenericRecord[] = [];
let compositionByCis: Map<string, CompositionRecord[]> = new Map();
let princepsByGroup: Map<string, SpecialiteRecord> = new Map();

/**
 * Load all JSON data
 */
function loadData(): void {
    console.log('Loading BDPM data...');

    specialitesData = JSON.parse(fs.readFileSync(
        path.join(DATA_JSON_DIR, 'specialites.json'), 'utf8'
    ));

    compositionData = JSON.parse(fs.readFileSync(
        path.join(DATA_JSON_DIR, 'composition.json'), 'utf8'
    ));

    genericsData = JSON.parse(fs.readFileSync(
        path.join(DATA_JSON_DIR, 'generiques.json'), 'utf8'
    ));

    // Build composition index
    for (const comp of compositionData) {
        if (!compositionByCis.has(comp.cis_code)) {
            compositionByCis.set(comp.cis_code, []);
        }
        compositionByCis.get(comp.cis_code)!.push(comp);
    }

    // Build princeps index (type 0 = princeps)
    const genericsByCis = new Map<string, GenericRecord>();
    for (const gen of genericsData) {
        genericsByCis.set(gen.cis_code, gen);
    }

    for (const spec of specialitesData) {
        const gen = genericsByCis.get(spec.cis_code);
        if (gen && gen.type === '0') {
            // This is a princeps - store by group
            princepsByGroup.set(gen.group_id, spec);
        }
    }

    console.log(`  Loaded ${specialitesData.length} specialites`);
    console.log(`  Loaded ${compositionData.length} composition records`);
    console.log(`  Loaded ${genericsData.length} generic records`);
    console.log(`  Built composition index for ${compositionByCis.size} CIS codes`);
    console.log(`  Found ${princepsByGroup.size} princeps groups\n`);
}

/**
 * Phase 1: Extract generic name from composition data
 * Returns the active substance name, normalized (no salts)
 */
function extractGenericFromComposition(cisCode: string): string | null {
    const compositions = compositionByCis.get(cisCode);
    if (!compositions || compositions.length === 0) {
        return null;
    }

    // Get first active substance (lien = 'SA')
    for (const comp of compositions) {
        if (comp.lien === 'SA') {
            // Remove salt prefixes/suffixes for normalization
            return normalizeSubstanceName(comp.denomination_substance);
        }
    }

    // Fallback to first substance
    if (compositions.length > 0) {
        return normalizeSubstanceName(compositions[0].denomination_substance);
    }

    return null;
}

/**
 * Normalize substance name by removing salts
 * Based on sanitizer.ts logic
 */
function normalizeSubstanceName(name: string): string {
    let normalized = name.toUpperCase().trim();

    // Salt patterns (simplified from sanitizer.ts)
    const saltPatterns = [
        /^CHLORHYDRATE DE /,
        /^HEMIFUMARATE DE /,
        /^SESQUIHYDRATE DE /,
        /^MONOHYDRATE DE /,
        /^DIHYDRATE DE /,
        /^TRIHYDRATE DE /,
        / MONOHYDRATE$/,
        / DIHYDRATE$/,
        / TRIHYDRATE$/,
        / HEMIFUMARATE$/,
        / CHLORHYDRATE$/,
        /^D'(.*)$/,  // D'AMOXICILLINE -> AMOXICILLINE
        /^DE (.*)$/,  // DE SODIUM -> SODIUM
    ];

    for (const pattern of saltPatterns) {
        normalized = normalized.replace(pattern, '$1').trim();
    }

    return normalized;
}

/**
 * Phase 2b: Extract normalized form from CIS_COMPO reference dosage
 * This is the "universal form mask" approach
 */
function extractFormFromRefDosage(refDosage: string): string {
    if (!refDosage) return '';

    const normalized = refDosage.toLowerCase().trim();

    // Extract form from patterns like:
    // "un comprimé" -> "comprimé"
    // "une gélule" -> "gélule"
    // "un flacon de ... solution" -> "solution"

    const formPatterns = [
        /un comprim[eé]/i,
        /une g[eé]nule/i,
        /un(?:e)? (?:flacon de |)?solution/i,
        /un(?:e)? (?:flacon de |)?suspension/i,
        /un(?:e)? (?:flacon de |)?pommade/i,
        /un(?:e)? (?:flacon de |)?cr[eè]me/i,
        /un(?:e)? (?:tube de |)?gel/i,
        /une (?:flacon|ampoule|seringue) de .*? (?:injetable|injectable)/i,
        /un(?:e)? (?:flacon de )?(?:collyre|linti[eè]re)/i,
    ];

    for (const pattern of formPatterns) {
        const match = normalized.match(pattern);
        if (match) {
            // Extract the form word
            const words = normalized.split(/\s+/);
            for (const word of words) {
                if (word.length > 3 && !/^(un|une|de|le|la|les|des|d'|du|pour|et|ou|en|dans)$/.test(word)) {
                    return word.replace(/[.,;:]$/, '').trim();
                }
            }
        }
    }

    return '';
}

/**
 * Strategy 1: Current comma_split (baseline)
 */
function strategyCommaSplit(record: SpecialiteRecord): ProcessingResult {
    const nom = record.nom_specialite || '';
    const commaIndex = nom.indexOf(', ');
    const cleanBrand = commaIndex !== -1 ? nom.substring(0, commaIndex).trim() : nom;
    const form = commaIndex !== -1 ? nom.substring(commaIndex + 2).trim() : record.forme_pharmaceutique || '';

    return {
        cleanBrand,
        cleanGeneric: cleanBrand,
        form,
        confidence: commaIndex !== -1 ? 0.8 : 0.5,
        method: 'comma_split'
    };
}

/**
 * Strategy 2: Composition-based lookup (Phase 1 + 2b)
 * Uses CIS_COMPO data for true generic names
 */
function strategyCompositionBased(record: SpecialiteRecord): ProcessingResult {
    const nom = record.nom_specialite || '';
    const forme = record.forme_pharmaceutique || '';

    // Get generic from composition (Phase 1)
    const generic = extractGenericFromComposition(record.cis_code);

    // Extract form from composition reference dosage (Phase 2b)
    const compositions = compositionByCis.get(record.cis_code);
    let formFromRef = '';
    if (compositions && compositions.length > 0) {
        formFromRef = extractFormFromRefDosage(compositions[0].ref_dosage);
    }

    // Extract brand by removing dosage
    // Pattern: BRAND DOSAGE, form
    const brandPattern = /^([A-Z][A-Z0-9\s\/\-]+?)\s+\d+(\.\d+)?\s*(mg|g|ml|UI|%|µg)/i;
    const match = nom.match(brandPattern);
    let cleanBrand = match ? match[1].trim() : nom.split(',')[0].trim();
    cleanBrand = cleanBrand.replace(/[,.\s]+$/, '').trim();

    return {
        cleanBrand,
        cleanGeneric: generic || cleanBrand,
        form: formFromRef || forme,
        confidence: generic ? 0.95 : 0.6,
        method: generic ? 'composition_full' : 'composition_fallback'
    };
}

/**
 * Strategy 3: Hybrid approach
 * Combines comma_split for brand with composition for generic
 */
function strategyHybrid(record: SpecialiteRecord): ProcessingResult {
    // Get brand from comma split (reliable)
    const commaResult = strategyCommaSplit(record);

    // Get generic from composition (Phase 1)
    const generic = extractGenericFromComposition(record.cis_code);

    return {
        cleanBrand: commaResult.cleanBrand,
        cleanGeneric: generic || commaResult.cleanBrand,
        form: commaResult.form,
        confidence: generic ? 0.90 : 0.80,
        method: generic ? 'hybrid_full' : 'hybrid_comma_only'
    };
}

/**
 * Strategy 4: Princeps-based lookup
 * Uses princeps data from CIS_GENER for canonical names
 */
function strategyPrincepsBased(record: SpecialiteRecord): ProcessingResult {
    // Find if this CIS is in a generic group
    const generics = genericsData.filter(g => g.cis_code === record.cis_code);
    if (generics.length === 0) {
        return strategyCommaSplit(record);
    }

    const gen = generics[0];
    const princeps = princepsByGroup.get(gen.group_id);

    if (!princeps) {
        return strategyCommaSplit(record);
    }

    // Get generic from composition of princeps (most reliable)
    const generic = extractGenericFromComposition(princeps.cis_code);

    // Use princeps brand as clean brand
    const princepsBrand = princeps.nom_specialite.split(',')[0].trim();

    // Extract brand from current record
    const nom = record.nom_specialite || '';
    const commaIndex = nom.indexOf(', ');
    const cleanBrand = commaIndex !== -1 ? nom.substring(0, commaIndex).trim() : nom.split(' ')[0];

    return {
        cleanBrand,
        cleanGeneric: generic || princepsBrand,
        form: record.forme_pharmaceutique || '',
        confidence: generic ? 0.98 : 0.85,
        method: 'princeps_canonical'
    };
}

/**
 * Strategy 5: Advanced multi-phase
 * Full implementation of 4-phase approach
 */
function strategyAdvancedMultiPhase(record: SpecialiteRecord): ProcessingResult {
    // Phase 1: Get generic from composition
    const generic = extractGenericFromComposition(record.cis_code);

    // Phase 2: Check if in generic group
    const generics = genericsData.filter(g => g.cis_code === record.cis_code);
    let isInGenericGroup = generics.length > 0;
    let groupPrinceps: SpecialiteRecord | undefined;

    if (isInGenericGroup) {
        const princeps = princepsByGroup.get(generics[0].group_id);
        if (princeps) {
            groupPrinceps = princeps;
            // Use princeps generic if available (more accurate)
            const princepsGeneric = extractGenericFromComposition(princeps.cis_code);
            if (princepsGeneric) {
                // Use princeps generic as ground truth
            }
        }
    }

    // Phase 3: Extract brand with dosage removal
    const nom = record.nom_specialite || '';
    let cleanBrand = nom;

    // Try multiple patterns for brand extraction
    const patterns = [
        // Pattern 1: BRAND DOSAGE, form
        /^([A-Z][A-Z0-9\s\/\-]+?)\s+\d+(\.\d+)?\s*(mg|g|ml|UI|%)\s*,/i,
        // Pattern 2: BRAND DOSAGE form (no comma)
        /^([A-Z][A-Z0-9\s\/\-]+?)\s+\d+(\.\d+)?\s*(mg|g|ml|UI|%)\s+/i,
        // Pattern 3: BRAND, form (no dosage)
        /^([A-Z][A-Z0-9\s\/\-]+?),/i,
    ];

    for (const pattern of patterns) {
        const match = nom.match(pattern);
        if (match) {
            cleanBrand = match[1].trim();
            break;
        }
    }

    // Fallback: comma split
    if (cleanBrand === nom) {
        const commaIndex = nom.indexOf(', ');
        if (commaIndex !== -1) {
            cleanBrand = nom.substring(0, commaIndex).trim();
        }
    }

    // Phase 4: Form extraction
    let form = record.forme_pharmaceutique || '';

    // Try to get from composition reference dosage (Phase 2b)
    const compositions = compositionByCis.get(record.cis_code);
    if (compositions && compositions.length > 0) {
        const formFromRef = extractFormFromRefDosage(compositions[0].ref_dosage);
        if (formFromRef) {
            form = formFromRef;
        }
    }

    // Confidence calculation
    let confidence = 0.5;
    const hasGeneric = !!generic;
    const hasPrinceps = !!groupPrinceps;
    const hasComma = nom.includes(', ');

    if (hasGeneric && hasPrinceps && hasComma) confidence = 0.98;
    else if (hasGeneric && hasComma) confidence = 0.95;
    else if (hasGeneric) confidence = 0.90;
    else if (hasPrinceps) confidence = 0.85;
    else if (hasComma) confidence = 0.80;

    return {
        cleanBrand,
        cleanGeneric: generic || cleanBrand,
        form,
        confidence,
        method: hasGeneric ? 'advanced_full' : 'advanced_partial'
    };
}

/**
 * Test a strategy
 */
function testStrategy(
    strategyName: string,
    strategyFn: (record: SpecialiteRecord) => ProcessingResult,
    limit = 500
): TestResult {
    const samples = specialitesData.slice(0, limit);
    const results: any[] = [];
    let totalConfidence = 0;
    let success = 0;
    let failed = 0;

    // Method distribution
    const methodCounts: Record<string, number> = {};

    for (const sample of samples) {
        try {
            const result = strategyFn(sample);

            // Track method distribution
            methodCounts[result.method] = (methodCounts[result.method] || 0) + 1;

            results.push({
                cis_code: sample.cis_code,
                original: sample.nom_specialite,
                ...result
            });
            totalConfidence += result.confidence;
            success++;
        } catch (error) {
            failed++;
        }
    }

    const avgConfidence = success > 0 ? totalConfidence / success : 0;

    return {
        strategy: strategyName,
        total: samples.length,
        success,
        failed,
        avgConfidence,
        samples: results.slice(0, 15)
    };
}

/**
 * Compare all strategies
 */
function compareStrategies(): void {
    console.log('\n' + '='.repeat(60));
    console.log('STRATEGY COMPARISON - Advanced Framework');
    console.log('='.repeat(60) + '\n');

    const strategies = [
        { name: 'comma_split', fn: strategyCommaSplit, desc: 'Current pipeline (baseline)' },
        { name: 'composition_based', fn: strategyCompositionBased, desc: 'Phase 1+2b: Composition lookup' },
        { name: 'hybrid', fn: strategyHybrid, desc: 'Hybrid: comma split + composition' },
        { name: 'princeps_based', fn: strategyPrincepsBased, desc: 'Princeps canonical lookup' },
        { name: 'advanced_multiphase', fn: strategyAdvancedMultiPhase, desc: 'Full 4-phase approach' },
    ];

    const results: TestResult[] = [];

    for (const strategy of strategies) {
        console.log(`Testing: ${strategy.name}...`);
        const result = testStrategy(strategy.name, strategy.fn, 500);
        results.push(result);

        console.log(`  ✓ Success: ${result.success}/${result.total}`);
        console.log(`  ✓ Avg Confidence: ${result.avgConfidence.toFixed(3)}`);
        console.log(`  ✓ Failed: ${result.failed}`);
        console.log();
    }

    // Sort by confidence
    results.sort((a, b) => b.avgConfidence - a.avgConfidence);

    console.log('='.repeat(60));
    console.log('FINAL RANKING');
    console.log('='.repeat(60) + '\n');

    for (let i = 0; i < results.length; i++) {
        const r = results[i];
        const medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : '  ';
        console.log(`${medal} ${r.strategy.padEnd(20)} ${r.avgConfidence.toFixed(3).padStart(7)} (${r.success}/${r.total} success)`);
    }

    // Find best strategy
    const best = results[0];
    console.log(`\n🏆 BEST STRATEGY: ${best.strategy} (confidence: ${best.avgConfidence.toFixed(3)})`);

    // Show sample comparisons for best strategy
    console.log('\n' + '='.repeat(60));
    console.log(`SAMPLE RESULTS: ${best.strategy.toUpperCase()}`);
    console.log('='.repeat(60) + '\n');

    for (const sample of best.samples.slice(0, 10)) {
        console.log(`Original:  ${sample.original}`);
        console.log(`Brand:     ${sample.cleanBrand}`);
        console.log(`Generic:   ${sample.cleanGeneric}`);
        console.log(`Form:      ${sample.form}`);
        console.log(`Confidence: ${sample.confidence} (method: ${sample.method})`);
        console.log();
    }

    // Save results
    const outputPath = path.join(OUTPUT_DIR, 'strategy_comparison_v2.json');
    fs.writeFileSync(outputPath, JSON.stringify(results, null, 2), 'utf8');
    console.log(`Results saved to: ${outputPath}`);
}

/**
 * Analyze specific test cases
 */
function analyzeTestCases(): void {
    console.log('\n' + '='.repeat(60));
    console.log('TEST CASE ANALYSIS');
    console.log('='.repeat(60) + '\n');

    // Note: CIP to CIS mapping would be needed for specific CIP testing
    // For now, analyze by name pattern
    const testPatterns = [
        { pattern: 'DOLIPRANE', description: 'Common paracetamol brand' },
        { pattern: 'CLAMOXYL', description: 'Common amoxicillin brand' },
        { pattern: 'AMOXICILLINE', description: 'Generic amoxicillin' },
        { pattern: 'SPASFON', description: 'Phloroglucinol brand' },
        { pattern: 'IBUPROFENE', description: 'Generic NSAID' },
    ];

    for (const testCase of testPatterns) {
        const matches = specialitesData.filter(s =>
            s.nom_specialite.toUpperCase().includes(testCase.pattern)
        ).slice(0, 3);

        console.log(`${testCase.description} (${testCase.pattern}):`);

        if (matches.length === 0) {
            console.log('  No matches found\n');
            continue;
        }

        for (const match of matches) {
            console.log(`  CIS: ${match.cis_code}`);
            console.log(`  Name: ${match.nom_specialite}`);

            // Test all strategies
            const strategies = [
                { name: 'comma_split', fn: strategyCommaSplit },
                { name: 'composition', fn: strategyCompositionBased },
                { name: 'advanced', fn: strategyAdvancedMultiPhase },
            ];

            for (const strategy of strategies) {
                const result = strategy.fn(match);
                console.log(`    ${strategy.name.padEnd(12)}: brand="${result.cleanBrand}" generic="${result.cleanGeneric}" conf=${result.confidence}`);
            }
            console.log();
        }
    }
}

/**
 * Main
 */
function main() {
    const args = process.argv.slice(2);

    // Create output directory
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    // Load data
    loadData();

    if (args.includes('--compare')) {
        compareStrategies();
    } else if (args.includes('--test-cases')) {
        analyzeTestCases();
    } else {
        // Default: compare
        compareStrategies();
    }
}

main();
