/**
 * Golden Master Test Suite for Salt Sanitization
 * 
 * These test cases were derived from empirical analysis of CIS_COMPO_bdpm.txt
 * using the salt sanitization tournament methodology.
 * 
 * Run: bun test test/golden_salts.test.ts
 */

import { describe, expect, test } from 'bun:test';
import { computeCanonicalSubstance, normalizeForSearchIndex } from '../src/sanitizer';

/**
 * Verified edge cases from human review of the salt_review_report.json
 * Each case represents a real substance from BDPM data.
 */
const GOLDEN_SAMPLES = [
    // ==========================================================================
    // STANDARD SALT PREFIX STRIPPING
    // ==========================================================================
    {
        input: 'CHLORHYDRATE DE TRAMADOL',
        expected: 'TRAMADOL',
        category: 'prefix_chlorhydrate',
    },
    {
        input: 'CHLORHYDRATE DE METFORMINE',
        expected: 'METFORMINE',
        category: 'prefix_chlorhydrate',
    },
    {
        input: "CHLORHYDRATE D'AMBROXOL",
        expected: 'AMBROXOL',
        category: 'prefix_chlorhydrate_apostrophe',
    },
    {
        input: 'SULFATE DE ZINC',
        expected: 'SULFATE DE ZINC', // Preserved: pure inorganic compound
        category: 'inorganic_preserve',
    },
    {
        input: 'CITRATE DE FENTANYL',
        expected: 'FENTANYL',
        category: 'prefix_citrate',
    },
    {
        input: 'GLUCONATE DE CHLORHEXIDINE',
        expected: 'CHLORHEXIDINE',
        category: 'prefix_gluconate',
    },
    {
        input: 'PHOSPHATE DE CODÉINE HÉMIHYDRATÉ',
        expected: 'CODEINE', // HEMIHYDRATE suffix is now properly stripped
        category: 'prefix_phosphate_with_suffix',
    },
    {
        input: 'TARTRATE DE NORADRÉNALINE',
        expected: 'NORADRENALINE',
        category: 'prefix_tartrate',
    },
    {
        input: "ACÉTATE D'ULIPRISTAL",
        expected: 'ULIPRISTAL',
        category: 'prefix_acetate_accented',
    },
    {
        input: 'FUMARATE DE BISOPROLOL',
        expected: 'BISOPROLOL',
        category: 'prefix_fumarate',
    },
    {
        input: 'DIPROPIONATE DE BÉCLOMÉTASONE',
        expected: 'BECLOMETASONE',
        category: 'prefix_dipropionate',
    },

    // ==========================================================================
    // SALT SUFFIX STRIPPING
    // ==========================================================================
    {
        input: 'ATORVASTATINE CALCIQUE',
        expected: 'ATORVASTATINE',
        category: 'suffix_calcique',
    },
    {
        input: 'AMOXICILLINE TRIHYDRATE',
        expected: 'AMOXICILLINE',
        category: 'suffix_trihydrate',
    },
    {
        input: 'PERINDOPRIL ARGININE',
        expected: 'PERINDOPRIL',
        category: 'suffix_arginine',
    },

    // ==========================================================================
    // PURE INORGANIC SUBSTANCES (Preserved as-is)
    // ==========================================================================
    {
        input: 'CHLORURE DE SODIUM',
        expected: 'CHLORURE DE SODIUM',
        category: 'inorganic_preserve',
    },
    {
        input: 'PHOSPHATE MONOPOTASSIQUE',
        expected: 'PHOSPHATE MONOPOTASSIQUE',
        category: 'inorganic_preserve',
    },
    {
        input: 'CARBONATE DE CALCIUM',
        expected: 'CARBONATE DE CALCIUM', // Preserved: pure inorganic compound
        category: 'inorganic_preserve',
    },

    // ==========================================================================
    // COMPLEX MULTI-COMPONENT SUBSTANCES
    // ==========================================================================
    {
        input: 'FUMARATE DE FORMOTÉROL DIHYDRATÉ',
        expected: 'FORMOTEROL', // Both prefix and DIHYDRATE suffix stripped
        category: 'complex_prefix_suffix',
    },
    {
        input: 'PHOSPHATE DE SITAGLIPTINE MONOHYDRATÉ',
        expected: 'SITAGLIPTINE', // Both prefix and MONOHYDRATE suffix stripped
        category: 'complex_prefix_suffix',
    },

    // ==========================================================================
    // EDGE CASES WITH ACCENTS (Diacritic normalization)
    // ==========================================================================
    {
        input: 'SUCCINATE DE SOLIFÉNACINE',
        expected: 'SOLIFENACINE',
        category: 'accented_input',
    },
    {
        input: 'BROMHYDRATE DE GALANTAMINE',
        expected: 'GALANTAMINE',
        category: 'prefix_bromhydrate',
    },
];

describe('Golden Master: Salt Sanitization', () => {
    describe('computeCanonicalSubstance', () => {
        for (const sample of GOLDEN_SAMPLES) {
            test(`[${sample.category}] ${sample.input} → ${sample.expected}`, () => {
                const result = computeCanonicalSubstance(sample.input);
                expect(result).toBe(sample.expected);
            });
        }
    });

    describe('Salt prefix coverage', () => {
        const prefixTestCases = [
            { prefix: 'CHLORHYDRATE DE', input: 'CHLORHYDRATE DE MORPHINE', expected: 'MORPHINE' },
            { prefix: "CHLORHYDRATE D'", input: "CHLORHYDRATE D'ÉPIRUBICINE", expected: 'EPIRUBICINE' },
            { prefix: 'SULFATE DE', input: 'SULFATE DE BLÉOMYCINE', expected: 'BLEOMYCINE' },
            { prefix: 'CITRATE DE', input: 'CITRATE DE TAMOXIFÈNE', expected: 'TAMOXIFENE' },
            { prefix: 'NITRATE DE', input: 'NITRATE DE FENTICONAZOLE', expected: 'FENTICONAZOLE' },
            { prefix: 'PHOSPHATE DE', input: 'PHOSPHATE DE RUXOLITINIB', expected: 'RUXOLITINIB' },
            { prefix: 'TARTRATE DE', input: 'TARTRATE DE RASAGILINE', expected: 'RASAGILINE' },
            { prefix: 'GLUCONATE DE', input: 'GLUCONATE DE COBALT', expected: 'COBALT' },
            { prefix: 'BENZOATE DE', input: 'BENZOATE DE RIZATRIPTAN', expected: 'RIZATRIPTAN' },
            { prefix: 'PROPIONATE DE', input: 'PROPIONATE DE CLOBÉTASOL', expected: 'CLOBETASOL' },
        ];

        for (const { prefix, input, expected } of prefixTestCases) {
            test(`prefix "${prefix}" strips correctly`, () => {
                expect(computeCanonicalSubstance(input)).toBe(expected);
            });
        }
    });

    describe('Salt suffix coverage', () => {
        const suffixTestCases = [
            { suffix: 'CHLORHYDRATE', input: 'LIDOCAÏNE CHLORHYDRATE', expected: 'LIDOCAINE' },
            { suffix: 'SULFATE', input: 'GENTAMICINE SULFATE', expected: 'GENTAMICINE' },
            { suffix: 'MONOHYDRATE', input: 'CÉFUROXIME MONOHYDRATE', expected: 'CEFUROXIME' },
            { suffix: 'DIHYDRATE', input: 'AZITHROMYCINE DIHYDRATE', expected: 'AZITHROMYCINE' },
            { suffix: 'DE SODIUM', input: 'DICLOFÉNAC DE SODIUM', expected: 'DICLOFENAC' },
        ];

        for (const { suffix, input, expected } of suffixTestCases) {
            test(`suffix "${suffix}" strips correctly`, () => {
                expect(computeCanonicalSubstance(input)).toBe(expected);
            });
        }
    });
});
