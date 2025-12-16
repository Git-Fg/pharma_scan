/**
 * Port of lib/core/logic/sanitizer.dart
 * Contains canonical normalization logic for search queries, indexes, and clustering keys.
 */
import { removeAccentsEnhanced } from "@urbanzoo/remove-accents";
import { SALT_PREFIXES, SALT_SUFFIXES, MINERAL_TOKENS, GALENIC_FORM_KEYWORDS } from "./constants";

/**
 * Remove accents/diacritics from a string.
 * Uses '@urbanzoo/remove-accents' library as equivalent to 'package:diacritic'.
 */
function removeDiacritics(str: string): string {
    return removeAccentsEnhanced(str);
}

/**
 * "Universal" Search Normalizer for Trigram FTS5.
 * 
 * This is the CANONICAL normalization function that MUST be replicated
 * exactly in Dart (lib/core/logic/sanitizer.dart) for search parity.
 * 
 * Rules:
 * 1. Remove Diacritics (é -> e, ï -> i, etc.)
 * 2. Lowercase (A -> a)
 * 3. Alphanumeric Only - replace [^a-z0-9\s] with space
 * 4. Collapse multiple spaces to single space
 * 5. Trim leading/trailing whitespace
 * 
 * WHY TRIGRAM: The FTS5 trigram tokenizer handles fuzzy matching natively
 * (e.g., "dolipprane" matches "doliprane"). We only need to normalize
 * the input to remove accents and ensure consistent casing.
 * 
 * @example
 * normalizeForSearch("DOLIPRANE®") => "doliprane"
 * normalizeForSearch("Paracétamol 500mg") => "paracetamol 500mg"
 * normalizeForSearch("Amoxicilline/Acide clavulanique") => "amoxicilline acide clavulanique"
 */
export function normalizeForSearch(input: string): string {
    if (!input) return "";

    return removeDiacritics(input)
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, " ")  // Replace non-alphanumeric with space
        .replace(/\s+/g, " ")           // Collapse multiple spaces
        .trim();
}

/**
 * Formats principles string for display by capitalizing the first letter.
 */
export function formatPrinciples(principles: string): string {
    if (!principles) return principles;

    return principles
        .split(",")
        .map((p) => {
            const trimmed = p.trim();
            if (!trimmed) return trimmed;
            if (trimmed.length > 1) {
                return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
            }
            return trimmed.toUpperCase();
        })
        .filter((p) => p.length > 0)
        .join(", ");
}

/**
 * Detects pure electrolytes / mineral salts.
 */
function isPureInorganicName(name: string): boolean {
    const tokens = name.split(" ").filter((t) => t.length > 0);
    if (tokens.length === 0) return false;

    const inorganicCores = new Set([
        "CHLORURE",
        "PHOSPHATE",
        "CARBONATE",
        "BICARBONATE",
        "SULFATE",
        "NITRATE",
        "HYDROXYDE",
        "OXIDE",
    ]);

    const inorganicModifiers = new Set([
        "MONOPOTASSIQUE",
        "DIPOTASSIQUE",
        "MONOSODIQUE",
        "DISODIQUE",
    ]);

    // Case 1: Just a mineral token (e.g. "MAGNESIUM")
    if (tokens.length === 1 && MINERAL_TOKENS.has(tokens[0])) {
        return true;
    }

    // Case 2: <core> DE <mineral> (e.g. "CHLORURE DE SODIUM")
    if (
        tokens.length === 3 &&
        inorganicCores.has(tokens[0]) &&
        (tokens[1] === "DE" || tokens[1] === "D'" || tokens[1] === "D") && // D' usually tokenized separately or attached
        MINERAL_TOKENS.has(tokens[2])
    ) {
        return true;
    }
    // Handling D' attached case if tokenizer kept it? 
    // The Dart code splits by space, so "D'SODIUM" would be one token if no space.
    // We assume standard tokenization where D' might be separate. 
    // Let's strictly follow Dart logic: tokens[1] == "DE" || tokens[1] == "D'" || tokens[1] == "D'"

    // Case 3: <core> <modifier> (e.g. "PHOSPHATE MONOPOTASSIQUE")
    if (
        tokens.length === 2 &&
        inorganicCores.has(tokens[0]) &&
        inorganicModifiers.has(tokens[1])
    ) {
        return true;
    }

    return false;
}

/**
 * Strictly reserved for FTS5 search index normalization.
 * Do NOT use for UI display strings or parsing heuristics.
 */
export function normalizeForSearchIndex(principe: string): string {
    if (!principe || !principe.trim()) return "";

    // Uppercase after diacritic removal
    let normalized = removeDiacritics(principe.toUpperCase().trim()).toUpperCase();

    normalized = normalized.replace(/^ACIDE\s+/, "");

    // Stereo-isomers: ( R ) - ...
    const stereoMatch = /^\(\s*([RS])\s*\)\s*-\s*(.+)$/.exec(normalized);
    if (stereoMatch) {
        const core = stereoMatch[2]?.trim() ?? "";
        if (core) {
            normalized = core;
        }
    }

    // Inverse: "SODIUM (CHLORURE DE)"
    const inverseMatch = /^([A-Z0-9\-]+)\s*\(\s*([^()]+?)\s+DE\s*\)$/.exec(normalized);
    if (inverseMatch) {
        const group1 = (inverseMatch[1] ?? "").trim();
        const group2 = (inverseMatch[2] ?? "").trim();

        const mineralElectrolytes = new Set([
            "SODIUM",
            "POTASSIUM",
            "CALCIUM",
            "MAGNESIUM",
            "LITHIUM",
            "ZINC",
            "FER",
            "CUIVRE",
        ]);

        if (mineralElectrolytes.has(group1)) {
            const inner = group2.replace(/\s+(DE|D[''])\s*$/, "").trim();
            if (inner) {
                normalized = inner;
            }
        } else {
            normalized = group1;
        }
    }

    if (isPureInorganicName(normalized)) {
        return normalized.replace(/\s+/g, " ").trim();
    }

    const noisePrefixes = [
        "SOLUTION DE",
        "CONCENTRAT DE",
    ];
    for (const prefix of noisePrefixes) {
        if (normalized.startsWith(prefix + " ")) {
            normalized = normalized.substring(prefix.length).trimStart();
        }
    }

    const noiseSuffixes = [
        "FORME PULVERULENTE",
        "FORME PULVERULENTE,",
        "FORME PULVERULENTE .",
        "LIQUIDE",
    ];

    // Regex escape helper
    const escaped = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

    for (const suffix of noiseSuffixes) {
        const suffixPattern = new RegExp(`\\s*,?\\s*${escaped(suffix)}$`, "i");
        normalized = normalized.replace(suffixPattern, "").trim();
    }

    normalized = normalized.replace(/CONCENTRAT DE\s+/, "");
    normalized = normalized.replace(/,\s*FORME PULV[EÉ]RULENTE\s*$/, "");
    normalized = normalized.replace(/^SOLUTION DE\s+/, "");
    normalized = normalized.replace(/,\s*SOLUTION DE\s*$/, "");
    normalized = normalized.replace(/\s+BETADEX-CLATHRATE\s*$/, "");
    normalized = normalized.replace(/\s+PROPYLENE GLYCOLATE\s*$/, "");

    // Remove trailing parens (...)
    normalized = normalized.replace(/\s*\([^)]*\)\s*$/, "");

    let result = normalized;

    // Salt Prefixes
    for (const prefix of SALT_PREFIXES) {
        if (result.startsWith(prefix)) {
            const rest = result.substring(prefix.length);
            if (prefix.endsWith("'") || prefix.endsWith("’")) {
                result = rest.trimStart();
                break;
            }
            if (!rest || rest.startsWith(" ")) {
                result = rest.trimStart();
                break;
            }
        }
    }

    // Mineral tokens suffix removal
    for (const mineral of MINERAL_TOKENS) {
        const mineralEscaped = escaped(mineral);
        // suffix: DE <MINERAL>$
        const suffixPattern = new RegExp(`\\s+(DE\\s+|D[''])` + mineralEscaped + `$`, "i");
        result = result.replace(suffixPattern, "").trim();

        // prefix: <MINERAL> DE at start? Dart code says:
        // final prefixPattern = '^$mineralEscaped' r'\s+(DE\s+|D[' '])';
        // result = result.replaceAll(...)
        const prefixPattern = new RegExp(`^${mineralEscaped}\\s+(DE\\s+|D[''])`, "i");
        result = result.replace(prefixPattern, "").trim();
    }

    // Salt Suffixes
    for (const suffix of SALT_SUFFIXES) {
        if (result.endsWith(" " + suffix)) {
            result = result.substring(0, result.length - suffix.length).trimEnd().trim();
        }
    }

    // Remove salt parens like (CHLORURE DE)
    result = result.replace(/\s*\([A-Z]+\s+D[E\u0027\u2019].*\)$/, "");

    // Specific salt suffixes in parens
    for (const salt of SALT_SUFFIXES) {
        const saltEscaped = escaped(salt);
        result = result.replace(new RegExp(`\\s*\\(${saltEscaped}\\)`), "");
    }

    // OMEGA-3
    if (result.includes("OMEGA-3") || result.includes("OMEGA 3")) {
        const omegaMatch = /OMEGA[- ]?3/i.exec(result);
        if (omegaMatch) {
            result = omegaMatch[0].toUpperCase().replace(" ", "-");
        }
    }

    // CALCITONINE
    if (result.includes("CALCITONINE")) {
        if (
            result.includes("SAUMON") ||
            result.includes("SALMINE") ||
            result.includes("SYNTHETIQUE")
        ) {
            result = "CALCITONINE";
        }
    }

    // Specific Replacements
    result = result.replace(/CARBOCYSTEINE/i, "CARBOCISTEINE");
    result = result.replace(/SEVORANE/i, "SEVOFLURANE");
    result = result.replace(/^COLECALCIFEROL$/i, "CHOLECALCIFEROL");
    result = result.replace(/CHOLÉCALCIFÉROL/i, "CHOLECALCIFEROL");
    result = result.replace(/COLÉCALCIFÉROL/i, "CHOLECALCIFEROL");
    result = result.replace(/URSODÉOXYCHOLIQUE/i, "URSODEOXYCHOLIQUE");
    result = result.replace(/URSODÉSOXYCHOLIQUE/i, "URSODEOXYCHOLIQUE");
    result = result.replace(/URSODESOXYCHOLIQUE/i, "URSODEOXYCHOLIQUE");
    result = result.replace(/ISÉTIONATE/i, "ISETHIONATE");
    result = result.replace(/ISÉTHIONATE/i, "ISETHIONATE");
    result = result.replace(/DIISÉTHIONATE/i, "DIISETHIONATE");

    // CLAVULANATE
    if (result.includes("CLAVULAN")) {
        result = result.replace(/CLAVULANATE/i, "CLAVULANIQUE");
        result = result.replace(/\s+DE\s+POTASSIUM\s+DILUE\s*$/, "");
        if (result.startsWith("CLAVULANIQUE")) {
            result = "CLAVULANIQUE";
        }
    }

    result = result.replace(/CYAMEPROMAZINE/i, "CYAMEMAZINE");
    result = result.replace(/REMIFENTANYL/i, "REMIFENTANIL");
    result = result.replace(/VALPROIQUE/i, "VALPROATE");

    // TRYPTOPHANE
    if (result.includes("TRYPTOPHANE")) {
        result = result.replace(/\s+L\s*$/, "");
        if (result.startsWith("TRYPTOPHANE")) {
            result = "TRYPTOPHANE";
        }
    }

    // ALCOOL DICHLOROBENZYLIQUE
    if (result.includes("DICHLORO") && result.includes("BENZYLIQUE")) {
        result = result.replace(/DICHLORO-2,4/i, "DICHLORO");
        result = result.replace(/DICHLORO\s+BENZYLIQUE/i, "DICHLOROBENZYLIQUE");
    }

    if (result === "PHOSPHATE MONOSODIQUE") {
        result = "PHOSPHATE";
    }

    for (const prefix of noisePrefixes) {
        if (result.startsWith(prefix + " ")) {
            result = result.substring(prefix.length).trimLeft();
        }
    }

    for (const suffix of noiseSuffixes) {
        const suffixEscaped = escaped(suffix);
        const suffixPattern = new RegExp(`\\s*,?\\s*${suffixEscaped}\\s*$`, "i");
        result = result.replace(suffixPattern, "").trim();
    }

    result = result.replace(/\(CONCENTRAT\s+DE\)/i, "").trim();
    result = result.replace(/[,\s]+$/, "").trim();

    return result.replace(/\s+/g, " ").trim();
}

/**
 * Normalizes input principle with optimal strategy (alias for search index norm).
 */
export function normalizePrincipleOptimal(principe: string): string {
    return normalizeForSearchIndex(principe);
}

/**
 * Computes the canonical substance name by stripping salt prefixes and suffixes.
 * This is used to populate ref_substances.canonical_name in the database.
 * 
 * Rules:
 * 1. Strip salt prefixes (e.g., "CHLORHYDRATE DE" -> "")
 * 2. Strip salt suffixes (e.g., " SULFATE" -> "")
 * 3. Preserve pure inorganic names (e.g., "SODIUM" remains "SODIUM")
 * 4. Return uppercase canonical name
 * 
 * @example
 * computeCanonicalSubstance("CHLORHYDRATE DE MORPHINE") => "MORPHINE"
 * computeCanonicalSubstance("AMOXICILLINE TRIHYDRATE") => "AMOXICILLINE"
 * computeCanonicalSubstance("SODIUM") => "SODIUM"
 */
export function computeCanonicalSubstance(rawLabel: string): string {
    if (!rawLabel || !rawLabel.trim()) return "";

    // Uppercase and remove diacritics
    let canonical = removeDiacritics(rawLabel.toUpperCase().trim()).toUpperCase();

    // Strip "équivalant à" or "équivalent à" and everything after
    const equivalentMatch = /EQUIVALANT A|EQUIVALENT A/i.exec(canonical);
    if (equivalentMatch) {
        canonical = canonical.substring(0, equivalentMatch.index).trim();
    }

    // Strip trailing parenthetical content containing salts (e.g., "(CHLORHYDRATE DE)")
    canonical = canonical.replace(/\s*\([^)]*(?:CHLORHYDRATE|SULFATE|MALEATE|TARTRATE|BESILATE|MESILATE|SUCCINATE|FUMARATE|OXALATE|CITRATE|ACETATE|LACTATE|VALERATE|PROPIONATE|BUTYRATE|PHOSPHATE|NITRATE|BROMHYDRATE|DE|D')[^)]*\)\s*$/gi, "");

    // Check if it's a pure inorganic name (preserve as-is)
    if (isPureInorganicName(canonical)) {
        return canonical.replace(/\s+/g, " ").trim();
    }

    // Strip salt prefixes
    for (const prefix of SALT_PREFIXES) {
        if (canonical.startsWith(prefix)) {
            const rest = canonical.substring(prefix.length);
            if (prefix.endsWith("'") || prefix.endsWith("'")) {
                canonical = rest.trimStart();
                break;
            }
            if (!rest || rest.startsWith(" ")) {
                canonical = rest.trimStart();
                break;
            }
        }
    }

    // Strip salt suffixes (iterate until no more changes to handle multiple suffixes)
    let changed = true;
    while (changed) {
        changed = false;
        for (const suffix of SALT_SUFFIXES) {
            if (canonical.endsWith(" " + suffix)) {
                canonical = canonical.substring(0, canonical.length - suffix.length).trimEnd().trim();
                changed = true;
                break; // Restart from beginning after a change
            }
        }
    }

    // Strip mineral suffixes (e.g., "DE SODIUM")
    for (const mineral of MINERAL_TOKENS) {
        // Pattern: " DE <MINERAL>" or " D' <MINERAL>" at end
        const suffixPattern = new RegExp(`\\s+(DE\\s+|D[''])${mineral}$`, "i");
        canonical = canonical.replace(suffixPattern, "").trim();
    }

    // Strip additional mineral-related modifiers (MONOSODIQUE, DISODIQUE, etc.)
    const mineralModifiers = ["MONOSODIQUE", "DISODIQUE", "MONOPOTASSIQUE", "DIPOTASSIQUE", "MAGNESIQUE", "CALCIQUE"];
    for (const modifier of mineralModifiers) {
        if (canonical.endsWith(" " + modifier)) {
            canonical = canonical.substring(0, canonical.length - modifier.length).trimEnd().trim();
        }
    }

    return canonical.replace(/\s+/g, " ").trim();
}




/**
 * Extracts princeps label from raw label.
 * Port of extractPrincepsLabel from sanitizer.dart
 */
export function extractPrincepsLabel(rawLabel: string): string {
    const trimmed = rawLabel.trim();
    if (!trimmed) return trimmed;

    if (trimmed.includes(" - ")) {
        const parts = trimmed.split(" - ");
        return parts[parts.length - 1].trim();
    }

    return trimmed;
}

/**
 * Gets display title for a medicament summary.
 * Port of getDisplayTitle from sanitizer.dart
 * Note: This function expects a MedicamentSummary-like object
 */
export function getDisplayTitle(summary: {
    isPrinceps: boolean;
    groupId: string | null | undefined;
    princepsDeReference: string;
    nomCanonique: string;
}): string {
    if (summary.isPrinceps) {
        return extractPrincepsLabel(summary.princepsDeReference);
    }

    if (!summary.isPrinceps && summary.groupId) {
        const parts = summary.nomCanonique.split(" - ");
        return parts[0]?.trim() || summary.nomCanonique;
    }

    return summary.nomCanonique;
}

/**
 * Applique le "Masque Galénique" pour extraire le nom commercial pur.
 * Stratégie relationnelle : On soustrait la forme connue (Col 3) du libellé complet (Col 2).
 * 
 * Exemples:
 * - Label: "CLAMOXYL 500 mg, gélule"
 *   Form: "gélule"
 *   Result: "CLAMOXYL 500 mg"
 * 
 * - Label: "DOLIPRANE 1000 mg, comprimé"
 *   Form: "comprimé"
 *   Result: "DOLIPRANE 1000 mg"
 */
export function applyPharmacologicalMask(fullLabel: string, formLabel: string | null): string {
    if (!fullLabel) return "";
    if (!formLabel) return fullLabel.trim();

    const normLabel = fullLabel.toLowerCase();
    const normForm = formLabel.toLowerCase();

    // 1. Recherche directe de la forme dans le libellé
    const index = normLabel.lastIndexOf(normForm);

    if (index > -1) {
        // On coupe tout ce qui est à partir de la forme
        let clean = fullLabel.substring(0, index);

        // Nettoyage des résidus de ponctuation en fin de chaîne (virgules, espaces, parenthèses, deux-points)
        // Ex: "DOLIPRANE 1000 mg, " -> "DOLIPRANE 1000 mg"
        // Ex: "DOLIPRANE (comprimé)" -> "DOLIPRANE (" -> "DOLIPRANE"
        // Ex: "TRUC : solution" -> "TRUC :" -> "TRUC"
        clean = clean.replace(/[\s,;:\(\)-]+$/, "");

        return clean.trim();
    }

    // Fallback : Si la forme exacte n'est pas trouvée (cas rares de fautes de frappe ANSM),
    // on renvoie le libellé complet ou on tente un split sur la virgule.

    // 2. Fallback avec liste de mots-clés (heuristique "Dumb Split")
    const FALLBACK_FORM_TERMS = [
        "comprim", "solution", "poudre", "degr", "suspension",
        "collyre", "gel", "capsule", "granul", "dispositif",
        "sirop", "pommade", "suppositoire", "gaz", "lyophilisat",
        "pastille", "dispersion", "ovule", "gomme", "vernis",
        "trousse", "liquide", "granules", "empl", "shampooing",
        "film", "microgranules"
    ];

    for (const term of FALLBACK_FORM_TERMS) {
        // On cherche ", <term>" pour éviter les faux positifs au milieu d'un mot
        const fallbackIndex = normLabel.indexOf(", " + term);
        if (fallbackIndex > -1) {
            let clean = fullLabel.substring(0, fallbackIndex);
            clean = clean.replace(/[\s,;:\(\)-]+$/, "");
            return clean.trim();
        }
    }

    return fullLabel.split(",")[0].trim();
}

/**
 * Generates a grouping key by extracting the canonical base name.
 * Port of generateGroupingKey from sanitizer.dart
 */
export function generateGroupingKey(input: string): string {
    if (!input) return input;

    let baseName = input;
    if (input.includes(" - ")) {
        baseName = input.split(" - ")[0].trim();
    } else {
        baseName = input.trim();
    }

    let normalized = baseName;

    // Remove parenthesis content
    normalized = normalized.replace(/\s*\([^)]*\)/g, "");

    // Remove "équivalant à"
    const equivalentMatch = /équivalant à|équivalent à/i.exec(normalized);
    if (equivalentMatch) {
        normalized = normalized.substring(0, equivalentMatch.index).trim();
    }

    // Remove "pour" patterns
    normalized = normalized.replace(/\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\s+pour\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\b/gi, "");
    normalized = normalized.replace(/\s+\d+([.,]\d+)?\s+pour\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\b/gi, "");
    normalized = normalized.replace(/\s+pour\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\b/gi, "");
    normalized = normalized.replace(/\s+pour\s+\d+([.,]\d+)?\b/gi, "");
    normalized = normalized.replace(/\s+pour\s*$/gi, "");

    // Remove dosages
    normalized = normalized.replace(/\b\d+([.,]\d+)?\s+(mg|g|ml|mL|µg|mcg|ui|UI|U\.I\.|M\.U\.I\.|%|meq|mol|gbq|mbq|CH|DH|microgrammes?|milligrammes?)\b/gi, "");
    normalized = normalized.replace(/\b\d+([.,]\d+)?(mg|g|ml|mL|µg|mcg|ui|UI|U\.I\.|M\.U\.I\.|%|meq|mol|gbq|mbq|CH|DH)\b/gi, "");
    normalized = normalized.replace(/\b\d+([.,]\d+)?\b/g, "");

    // Remove percentages and slashes
    normalized = normalized.replace(/\s*%\s*/gi, "");
    normalized = normalized.replace(/\s+POUR\s+CENT\b/gi, "");
    normalized = normalized.replace(/\s+POURCENT\b/gi, "");
    normalized = normalized.replace(/\s*\/\s*\w+/gi, "");
    normalized = normalized.replace(/\s*\/\s*/g, "");

    const formulationKeywords = [
        'comprimé', 'gélule', 'solution', 'injectable', 'poudre', 'sirop', 'suspension',
        'crème', 'pommade', 'gel', 'collyre', 'inhalation', 'orodispersible', 'sublingual',
        'transdermique', 'gingival', 'pelliculé', 'effervescent', 'buvable',
    ];

    for (const keyword of formulationKeywords) {
        // Escape keyword regex special chars if any (none in this list really)
        const pattern = new RegExp(`(^|\\s)${keyword}(\\s|$)`, "gi");
        normalized = normalized.replace(pattern, " ");
    }

    normalized = normalized.trim().replace(/\s+/g, " ").toUpperCase();

    if (!normalized || normalized.length < 3) {
        // If we stripped everything, checking if it was just a dosage or noise
        // If the original input starts with a digit, it's likely a standalone dosage/strength that was stripped
        // e.g. "0,03 mg" -> "" -> fallback to "0,03 mg" (BAD)
        if (/^\d/.test(baseName)) {
            return "";
        }

        const baseOnly = baseName.replace(/\s+\d+.*$/i, "").trim();
        return !baseOnly ? input.toUpperCase().trim() : baseOnly.toUpperCase().trim();
    }

    return normalized;
}

/**
 * Vérifie si une chaîne de caractères ne contient QUE des termes de forme galénique.
 * Utile pour filtrer les faux positifs dans les noms de marque (ex: "COMPRIME SECABLE").
 * 
 * @param text - Le texte à vérifier
 * @returns true si le texte ne contient que des mots-clés de forme galénique
 */
export function isPureGalenicDescription(text: string): boolean {
    if (!text) return false;
    const lower = text.toLowerCase();
    // Split plus robuste : espaces, virgules, points, tirets
    const words = lower.split(/[\s,.-]+/).filter(w => w.length > 0);

    if (words.length === 0) return false;

    // Si tous les mots de la chaîne sont des mots-clés galéniques (ou des lettres isolées)
    return words.every(word =>
        word.length < 2 || // ignore les lettres isolées
        GALENIC_FORM_KEYWORDS.some(k => word.includes(k))
    );
}

/**
 * Détecte si une chaîne est une description de formulation plutôt qu'un nom de marque.
 * Les descriptions de formulation contiennent souvent des mots comme "édulcorée", "au maltitol", etc.
 * 
 * @param text - Le texte à vérifier
 * @returns true si le texte ressemble à une description de formulation
 */
export function isFormulationDescription(text: string): boolean {
    if (!text) return false;
    const lower = text.toLowerCase().trim();

    // Si la chaîne est une forme galénique pure, c'est une description
    if (isPureGalenicDescription(text)) return true;

    // Mots-clés typiques des descriptions de formulation
    const formulationKeywords = [
        'édulcorée', 'édulcoré', 'édulcorer',
        'maltitol', 'saccharine', 'saccharose', 'sucralose',
        'sans sucre', 'sans lactose', 'sans gluten',
        'au goût de', 'arôme', 'aromatisée',
        'liquide', 'en poudre', 'en solution',
        'rapport', 'ratio', 'proportion',
        'pour', 'à', 'et', 'ou',
        'en sachet', 'en flacon', 'en ampoule',
        'adultes', 'enfants', 'nourrissons',
        'suspension buvable', 'poudre pour', 'solution pour',
        'molle', 'sécable', 'pelliculé', 'enrobé', // Adjectifs de forme
        'dispositif', 'système', 'présentation' // Autres descripteurs
    ];

    // Si la chaîne contient plusieurs de ces mots-clés, c'est probablement une description
    const keywordCount = formulationKeywords.filter(kw => lower.includes(kw)).length;
    if (keywordCount >= 2) return true;

    // Si la chaîne est très longue (> 60 caractères) et contient des mots descriptifs
    if (text.length > 60 && keywordCount >= 1) return true;

    // Si la chaîne commence par une minuscule et ne contient QUE des mots descriptifs/formes
    if (text.length > 0 && text[0] === text[0].toLowerCase()) {
        // Vérifier si tous les mots sont des formes galéniques ou des mots descriptifs
        const words = lower.split(/\s+/);
        const allDescriptive = words.every(word =>
            word.length < 2 ||
            GALENIC_FORM_KEYWORDS.some(k => word.includes(k)) ||
            formulationKeywords.some(k => word.includes(k))
        );
        if (allDescriptive && words.length > 0) return true;
    }

    return false;
}

/**
 * Normalizes commonPrincipes for comparison using optimal normalization.
 * Port of normalizeCommonPrincipes from grouping_algorithms.dart
 */
export function normalizeCommonPrincipes(commonPrincipes: string): string {
    if (!commonPrincipes) return "";

    // Associations are delimited by "+", otherwise by comma.
    const rawList = commonPrincipes.includes("+")
        ? commonPrincipes.split("+")
        : commonPrincipes.split(",");

    // Normalize principles, deduplicate, then sort for stable comparison.
    const normalizedSet = new Set<string>();
    for (const p of rawList) {
        const trimmed = p.trim();
        if (trimmed) {
            const normalized = normalizePrincipleOptimal(trimmed);
            if (normalized) {
                normalizedSet.add(normalized);
            }
        }
    }

    const normalizedList = Array.from(normalizedSet).sort();
    return normalizedList.join(" ");
}

/**
 * Detects if a product is homeopathic based on its label, dosage, or manufacturer.
 * Consolidates all heuristics (build + tooling) into a single source of truth.
 */
export function isHomeopathic(label: string, dosage: string = "", manufacturer: string = ""): boolean {
    const combinedText = `${label} ${dosage} ${manufacturer}`.toUpperCase();

    // 1. Laboratory-based detection (highest priority)
    if (
        combinedText.includes("LEHNING") ||
        combinedText.includes("BOIRON") ||
        combinedText.includes("HEEL") ||
        combinedText.includes("WELEDA") ||
        combinedText.includes("RECKEWEG") ||
        combinedText.includes("UNDA") ||
        combinedText.includes("LABORATOIRES HOMEOPATHIQU") ||
        combinedText.includes("LABORATOIRES HOMEOPATHES")
    ) {
        return true;
    }

    // 2. Explicit homeopathic terms and common label hints
    if (
        combinedText.includes("HOMÉOPATHIQU") ||
        combinedText.includes("HOMEOPATH") ||
        combinedText.includes("POUR PRÉPARATIONS") ||
        combinedText.includes("GRANULES") ||
        combinedText.includes("GLOBULES") ||
        combinedText.includes("TRITURATION") ||
        combinedText.includes("MOTHER TINCTURE") ||
        combinedText.includes("TEINTURE MÈRE")
    ) {
        return true;
    }

    // 3. Specific labelling codes (L-codes, COMPLEXE) used by Boiron/Lehning ranges
    const hasLCode = /\bL\s?\d{2,3}\b/.test(combinedText) && combinedText.includes("SOLUTION BUVABLE");
    const hasComplexe = /COMPLEXE\s*N[°O]?\s*\d*/.test(combinedText);
    if (hasLCode || hasComplexe) {
        return true;
    }

    // 4. Dilution pattern detection (most specific)
    const dilutionPatterns = [
        /\d+(?:CH|DH|K)\s*(?:À|A|ET)\s*\d+(?:CH|DH|K)/i, // Range: "2CH à 30CH"
        /\d+(?:CH|DH|K)\s*(?:À|A|ET)\s*\d+(?:CH|DH|K)\s*(?:ET|OU)\s*\d+(?:CH|DH|K)/i, // Complex range
        /\d+(?:CH|DH|K)(?:\s*[,;]\s*\d+(?:CH|DH|K))*/i, // Multiple dilutions
        /\b(?:CH|DH|K)\s*\d+\b/i, // Reverse pattern
        /\b\d+LM\b/i,
        /\b\d+M\b(?![GL])/i, // M followed by non-G/L to avoid MG
        /\b\d+X\b/i,
        /\b\d+CK\b/i,
        /\b\d+Q\b/i
    ];

    for (const pattern of dilutionPatterns) {
        if (pattern.test(combinedText)) {
            return true;
        }
    }

    // 5. Single dilution (with strict context checks to avoid false positives)
    const singleDilutionPattern = /\b\d+(?:CH|DH|K|LM|CK|Q|X)\b/i; // Removed M to avoid MG conflicts
    if (singleDilutionPattern.test(combinedText)) {
        if (
            combinedText.includes("DEGRÉ DE DILUTION") ||
            combinedText.includes("DILUTION COMPRISE ENTRE") ||
            combinedText.includes("POUR PRÉPARATIONS") ||
            combinedText.includes("HOMÉOPATHIQU") ||
            combinedText.includes("HOMEOPATH") ||
            (combinedText.includes("SOLUTION BUVABLE") && combinedText.includes("GOUTTES")) ||
            (combinedText.includes("GOUTTES") && combinedText.length > 80)
        ) {
            return true;
        }
    }

    return false;
}

/**
 * Cleans a product label for general display or processing.
 * Removes common noise and normalizes spacing.
 */
export function cleanProductLabel(label: string): string {
    if (!label) return "";
    let clean = label.trim();
    // Remove potential "cis_code" prefix if present in label (legacy artifact)
    clean = clean.replace(/^\d{8}\s+/, "");

    // Remove trailing commas or hyphens
    clean = clean.replace(/[,.-]+$/, "").trim();

    return clean;
}

/**
 * Extracts generic brand name from a label.
 * Heuristic: Take first part before dosage or form.
 */
export function extractBrand(label: string): string {
    if (!label) return "";
    let clean = label.trim();

    // Split by comma (often separates name+dosage from form)
    // "ABILIFY 1 mg/mL, solution buvable" -> "ABILIFY 1 mg/mL"
    if (clean.includes(',')) {
        clean = clean.split(',')[0].trim();
    }

    // Remove dosage
    // "ABILIFY 1 mg/mL" -> "ABILIFY"
    clean = clean.replace(/\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\s*(\/|PAR)\s*(ml|mL|dose|g)?/gi, "")
        .replace(/\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)/gi, "")
        .trim();

    return clean;
}

/**
 * Normalizes manufacturer name for consistent grouping.
 */
export function normalizeManufacturerName(name: string): string {
    if (!name) return "";
    return name.toUpperCase().trim()
        .replace(/^LABORATOIRES?\s+/, "")
        .replace(/^LABO\s+/, "")
        .replace(/\s+SAS$/, "")
        .replace(/\s+SA$/, "")
        .trim();
}

/**
 * Determines if a product is considered 'stopped' (non-commercialisée)
 * based on its marketing status and presentation counters.
 */
export function isStoppedProduct(metadata: {
    marketing_status: string;
    stopped_presentations: number;
    active_presentations: number;
    [key: string]: any;
}): boolean {
    const status = (metadata.marketing_status || "").toUpperCase();

    // 1. If explicit status is 'NON COMMERCIALISÉE', it is stopped.
    if (status.includes("NON COMMERCIALISÉE") || status.includes("NON COMMERCIALISEE")) {
        return true;
    }

    // 2. If no active presentations match logic but we rely on status mostly.
    if (metadata.active_presentations === 0 && metadata.stopped_presentations > 0) {
        return true;
    }

    return false;
}
