import { describe, test, expect } from "bun:test";
import { normalizeForSearch, normalizeForSearchIndex } from "../src/sanitizer";

/**
 * Tests for the "Universal" Search Normalizer.
 *
 * These tests verify that normalizeForSearch implements the standard
 * linguistic normalization protocol that is replicated in Dart.
 *
 * The normalization rules are:
 * 1. Remove Diacritics (é -> e, ï -> i, etc.)
 * 2. Lowercase (A -> a)
 * 3. Replace non-alphanumeric (except spaces) with space
 * 4. Collapse multiple spaces to single space
 * 5. Trim leading/trailing whitespace
 */
describe("normalizeForSearch - Universal Trigram FTS Normalization", () => {
    describe("Basic cases", () => {
        test("empty string returns empty", () => {
            expect(normalizeForSearch("")).toBe("");
        });

        test("simple lowercase", () => {
            expect(normalizeForSearch("DOLIPRANE")).toBe("doliprane");
            expect(normalizeForSearch("Paracetamol")).toBe("paracetamol");
        });

        test("accents removed", () => {
            expect(normalizeForSearch("Paracétamol")).toBe("paracetamol");
            expect(normalizeForSearch("ÉPHÉDRINE")).toBe("ephedrine");
            expect(normalizeForSearch("Caféine")).toBe("cafeine");
            expect(normalizeForSearch("Naïf")).toBe("naif");
            expect(normalizeForSearch("Façade")).toBe("facade");
        });

        test("numbers preserved", () => {
            expect(normalizeForSearch("Doliprane 500")).toBe("doliprane 500");
            expect(normalizeForSearch("PARACETAMOL 1000MG")).toBe(
                "paracetamol 1000mg"
            );
        });
    });

    describe("Special characters replaced with space", () => {
        test("punctuation replaced", () => {
            expect(normalizeForSearch("anti-inflammatoire")).toBe(
                "anti inflammatoire"
            );
            // Note: ® is replaced with space, then trailing space is trimmed
            expect(normalizeForSearch("Doliprane®")).toBe("doliprane");
            expect(normalizeForSearch("L'aspirine")).toBe("l aspirine");
            expect(normalizeForSearch("test.dot")).toBe("test dot");
            expect(normalizeForSearch("test:colon")).toBe("test colon");
            expect(normalizeForSearch('test"quote')).toBe("test quote");
        });

        test("slashes replaced", () => {
            expect(normalizeForSearch("Amoxicilline/Acide clavulanique")).toBe(
                "amoxicilline acide clavulanique"
            );
        });

        test("parentheses replaced", () => {
            expect(normalizeForSearch("Sodium (chlorure)")).toBe("sodium chlorure");
        });
    });

    describe("Whitespace handling", () => {
        test("multiple spaces collapsed", () => {
            expect(normalizeForSearch("hello   world")).toBe("hello world");
            expect(normalizeForSearch("  leading")).toBe("leading");
            expect(normalizeForSearch("trailing  ")).toBe("trailing");
        });

        test("mixed special chars and spaces", () => {
            expect(normalizeForSearch("test - with - dashes")).toBe(
                "test with dashes"
            );
            expect(normalizeForSearch("test/with/slashes")).toBe("test with slashes");
        });
    });

    describe("Real-world medication names", () => {
        test("Doliprane variants", () => {
            expect(normalizeForSearch("DOLIPRANE®")).toBe("doliprane");
            expect(normalizeForSearch("DOLIPRANE 1000 mg, comprimé")).toBe(
                "doliprane 1000 mg comprime"
            );
        });

        test("Amoxicilline with salts", () => {
            expect(normalizeForSearch("AMOXICILLINE ACIDE CLAVULANIQUE")).toBe(
                "amoxicilline acide clavulanique"
            );
            expect(normalizeForSearch("Amoxicilline (trihydraté)")).toBe(
                "amoxicilline trihydrate"
            );
        });

        test("Complex names", () => {
            expect(normalizeForSearch("IBUPROFÈNE LYSINE")).toBe("ibuprofene lysine");
            expect(normalizeForSearch("PHOSPHATE DE CODÉINE HÉMIHYDRATÉ")).toBe(
                "phosphate de codeine hemihydrate"
            );
        });
    });

    describe("Edge cases for typo tolerance testing", () => {
        // These test that the normalization is predictable and symmetric
        // so that typos in queries can still match via trigram similarity
        test("typos produce similar normalized forms", () => {
            // "dolipprane" (common typo) normalizes cleanly
            expect(normalizeForSearch("dolipprane")).toBe("dolipprane");
            expect(normalizeForSearch("doliprane")).toBe("doliprane");

            // The trigram tokenizer will match these because they share many trigrams:
            // "dol", "oli", "lip", "pra", "ran", "ane" overlap between both

            // "amoxicylline" (common typo with y instead of i)
            expect(normalizeForSearch("amoxicylline")).toBe("amoxicylline");
            expect(normalizeForSearch("amoxicilline")).toBe("amoxicilline");
        });
    });
});

describe("normalizeForSearchIndex - Chemical Name Normalization", () => {
    test("basic functionality", () => {
        expect(normalizeForSearchIndex("PARACETAMOL")).toBe("PARACETAMOL");
    });

    test("removes ACIDE prefix", () => {
        expect(normalizeForSearchIndex("ACIDE ACETYLSALICYLIQUE")).toBe(
            "ACETYLSALICYLIQUE"
        );
    });

    test("handles stereo-isomers", () => {
        expect(normalizeForSearchIndex("( R ) - AMLODIPINE")).toBe("AMLODIPINE");
        expect(normalizeForSearchIndex("( S ) - OMEPRAZOLE")).toBe("OMEPRAZOLE");
    });
});

/**
 * Cross-platform parity test.
 *
 * This documents the expected output for the EXACT same inputs
 * that are tested in the Dart test file. Both should produce
 * identical results to ensure search parity.
 */
describe("Cross-Platform Parity", () => {
    const testCases: [string, string][] = [
        ["", ""],
        ["DOLIPRANE", "doliprane"],
        ["Paracétamol", "paracetamol"],
        ["ÉPHÉDRINE", "ephedrine"],
        ["Doliprane 500", "doliprane 500"],
        ["anti-inflammatoire", "anti inflammatoire"],
        ["DOLIPRANE®", "doliprane"],
        ["L'aspirine", "l aspirine"],
        ["Amoxicilline/Acide clavulanique", "amoxicilline acide clavulanique"],
        ["Sodium (chlorure)", "sodium chlorure"],
        ["hello   world", "hello world"],
        ["DOLIPRANE 1000 mg, comprimé", "doliprane 1000 mg comprime"],
        ["IBUPROFÈNE LYSINE", "ibuprofene lysine"],
        ["PHOSPHATE DE CODÉINE HÉMIHYDRATÉ", "phosphate de codeine hemihydrate"],
    ];

    test.each(testCases)("'%s' normalizes to '%s'", (input, expected) => {
        expect(normalizeForSearch(input)).toBe(expected);
    });
});
