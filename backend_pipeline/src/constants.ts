/**
 * Centralized chemical constants for salt prefixes, suffixes, and mineral tokens
 * used across sanitizer and ingestion logic.
 * Ported from lib/core/constants/chemical_constants.dart
 */
export class ChemicalConstants {
  private constructor() { }

  /**
   * Salt prefixes that appear at the beginning of molecule names.
   * Example: "CHLORHYDRATE DE METFORMINE" -> "METFORMINE"
   * 
   * NOTE: Use ONLY non-accented versions here. The sanitizer applies
   * removeDiacritics() to input BEFORE prefix matching, so accented 
   * variants like "ACÉTATE DE" become "ACETATE DE" before comparison.
   */
  static readonly saltPrefixes = [
    // Complex compound prefixes (order matters - longer first)
    'FUMARATE ACIDE DE',
    'HEMIFUMARATE DE',
    'CHLORHYDRATE DIHYDRATE DE',
    'DIPROPIONATE DE',
    "DIPROPIONATE D'",
    // Standard salt prefixes (alphabetical)
    'ACETATE DE',
    "ACETATE D'",
    'ASCORBATE DE',
    "ASCORBATE D'",
    'BENZOATE DE',
    "BENZOATE D'",
    'BICARBONATE DE',
    "BICARBONATE D'",
    'BROMHYDRATE DE',
    "BROMHYDRATE D'",
    'CARBONATE DE',
    "CARBONATE D'",
    "CHLORHYDRATE D'",
    'CHLORHYDRATE DE',
    'CITRATE DE',
    "CITRATE D'",
    'FUMARATE DE',
    "FUMARATE D'",
    'GLUCONATE DE',
    "GLUCONATE D'",
    'LACTATE DE',
    "LACTATE D'",
    'MALEATE DE',
    "MALATE D'",
    'MALATE DE',
    'NITRATE DE',
    "NITRATE D'",
    'OXALATE DE',
    "OXALATE D'",
    'PHOSPHATE DE',
    "PHOSPHATE D'",
    'PROPIONATE DE',
    "PROPIONATE D'",
    'SUCCINATE DE',
    "SUCCINATE D'",
    'SULFATE DE',
    "SULFATE D'",
    'TARTRATE DE',
    "TARTRATE D'",
    'TOSILATE DE',
    'TOSYLATE DE',
  ] as const;

  /**
   * Salt suffixes that appear at the end of molecule names.
   * These are removed during normalization to extract the base molecule.
   */
  static readonly saltSuffixes = [
    'MAGNESIQUE DIHYDRATE',
    // Mineral Adjectives (often missing from suffixes list)
    'SODIQUE',
    'POTASSIQUE',
    'CALCIQUE',
    'MAGNESIQUE',
    'LITHIQUE',
    'ZINCIQUE',
    'MONOSODIQUE ANHYDRE',
    'MONOSODIQUE',
    'DISODIQUE',
    'DIPOTASSIQUE',
    'MONOPOTASSIQUE',
    'BASE',
    'DISODIQUE', // Duplicate? Check if needed, but safe
    'DE SODIUM',
    'DE POTASSIUM',
    'DE CALCIUM',
    'DE MAGNESIUM',
    'ARGININE',
    'TERT-BUTYLAMINE',
    'TERT BUTYLAMINE',
    'ERBUMINE',
    'OLAMINE',
    'MAGNESIQUE TRIHYDRATE',
    // Hydrate and solvate markers (valsartan complexes, hydrates, etc.)
    'ANHYDRE', // Critical addition from TF-IDF
    'HEMIPENTAHYDRATE',
    'HEMIPENTAHYDRAT',
    'HEMIHYDRATE',
    'MONOHYDRATE',
    'DIHYDRATE',
    'TRIHYDRATE',
    'PENTAHYDRATE',
    'SESQUIHYDRATE',
    // From bdpm_file_parser.dart (additional salts)
    'TOSILATE',
    'TERTBUTYLAMINE',
    'MALEATE',
    'CHLORHYDRATE',
    'SULFATE',
    'TARTRATE',
    'BESILATE',
    'MESILATE',
    'SUCCINATE',
    'FUMARATE',
    'OXALATE',
    'CITRATE',
    'ACETATE',
    'LACTATE',
    'VALERATE',
    'PROPIONATE',
    'BUTYRATE',
    'PHOSPHATE',
    'NITRATE',
    'BROMHYDRATE',
  ] as const;

  /**
   * Mineral tokens used for detecting pure inorganic compounds.
   * These are preserved when they constitute the entire molecule name.
   */
  static readonly mineralTokens = new Set([
    'MAGNESIUM',
    'MAGNESIQUE',
    'SODIUM',
    'POTASSIUM',
    'CALCIUM',
    'MONOSODIQUE',
    'DISODIQUE',
    'ZINC',
  ]);
}

// Export constants for backward compatibility
export const SALT_PREFIXES = ChemicalConstants.saltPrefixes;
export const SALT_SUFFIXES = ChemicalConstants.saltSuffixes;
export const MINERAL_TOKENS = ChemicalConstants.mineralTokens;

// Noise words to remove from medication labels
export const NOISE_WORDS = [
  "RESERVE",
  "RESERVE A L'ORDONNANCE",
  "RESERVE A L'HOPITAL",
  "RESERVE HOSPITALIER",
  "MEDICAMENT",
  "EQUIVALENT",
  "EQUIVALENTE",
  "GENERIQUE",
  "PRINCEPS",
  "AUTORISE",
  "AUTORISEE",
  "AVENIR",
  "INSERT",
  "NOTICE",
  "BOITE",
  "CONDITIONNEMENT",
  "UNITE",
  "UNITE(S)",
  "DOSE",
  "DOSES",
  "FLACON",
  "FLACONS",
  "TUBE",
  "TUBES",
  "SACHET",
  "SACHETS",
  "PLAQUETTE",
  "PLAQUETTES",
  "STYLO",
  "STYLOS",
  "INJECTEUR",
  "INJECTEURS",
  "DISPOSITIF",
  "DISPOSITIFS",
  "APPLICATEUR",
  "APPLICATEURS",
  "SERINGUE",
  "SERINGUES",
  "AMP",
  "AMPOULE",
  "AMPOULES",
  "CARTOUCHE",
  "CARTOUCHES",
  "COMPTE",
  "COMPRIMES",
  "GELULES",
  "CAPSULES",
  "POUR CENT",
  "%"
];

// Prefix stop words to remove from the beginning of medication names
export const PREFIX_STOP_WORDS = [
  "RESERVE",
  "MEDICAMENT",
  "SPECIALITE",
  "SUBSTANCE",
  "EQUIVALENT",
  "GENERIQUE",
  "PRINCEPS",
  "AUTORISE",
  "AUTORISEE"
];

// Tokens that differ only by oral solid form (tablet/capsule) and should not split clusters.
export const ORAL_FORM_TOKENS = [
  "COMPRIME",
  "COMPRIMES",
  "COMPRIME PELLICULE",
  "COMPRIMES PELLICULES",
  "PELlicule".toUpperCase(),
  "SECABLE",
  "SECABLES",
  "GELULE",
  "GELULES",
  "CAPSULE",
  "CAPSULES",
  "LIBERATION PROLONGEE",
  "A LIBERATION PROLONGEE",
  "L P",
  "LP",
  "RETARD"
];

/**
 * Comprehensive list of galenic form keywords used to detect pure pharmaceutical forms.
 * Used for filtering out pharmaceutical form descriptions that are mistakenly identified
 * as brand names (e.g., "COMPRIME SECABLE" should not appear as a brand name).
 * 
 * This list is more comprehensive than ORAL_FORM_TOKENS and includes all pharmaceutical forms
 * (oral, injectable, topical, etc.) for use in sanitization and audit logic.
 */
export const GALENIC_FORM_KEYWORDS = [
  'comprimé', 'gélule', 'solution', 'injectable', 'poudre', 'sirop', 'suspension',
  'crème', 'pommade', 'gel', 'collyre', 'inhalation', 'orodispersible', 'sublingual',
  'transdermique', 'gingival', 'pelliculé', 'effervescent', 'buvable', 'enrobé',
  'dispersible', 'sécable', 'gastro-résistant', 'lyophilisat', 'capsule', 'pastille',
  'bain', 'bouche', 'granulés', 'sachet', 'dose', 'ampoule', 'flacon', 'perfusion',
  'vaginal', 'rectal', 'ovule', 'suppositoire'
] as const;

export const TARGET_POPULATION_TOKENS = [
  "ADULTE",
  "ADULTES",
  "ENFANT",
  "ENFANTS",
  "NOURRISSON",
  "NOURRISSONS",
  "BEBE",
  "BEBES"
];

export const MANUFACTURER_STOP_WORDS = new Set([
  "LABORATOIRES",
  "LABORATOIRE",
  "ROCHE",
  "BAYER",
  "JANSSEN",
  "GSK",
  "SANOFI",
  "PFIZER",
  "BRISTOL",
  "MYERS",
  "SQUIBB",
  "MSD",
  "ASTRAZENECA",
  "PHARMA",
  "PHARMACEUTICALS",
  "HEALTHCARE",
  "GROUP",
  "FRANCE",
  "EUROPE",
  "INTERNATIONAL",
  "DEUTSCHLAND",
  "GMBH",
  "SAS",
  "SA",
  "LTD",
  "AB",
  "OY",
  "S.P.A",
  "SPA",
  "INC",
  "NV",
  "BV",
  "LIMITED",
  "THERAPEUTICS",
  "SCIENCES",
  "HOLDING",
  "HOLDINGS"
]);

export const MANUFACTURER_IGNORE_PAIRS = new Set<string>([
  "basilea pharmaceutica deutschland|idorsia pharmaceuticals deutschland",
  "bene - arzneimittel|betapharm arzneimittel",
  "bene - arzneimittel|biosyn arzneimittel",
  "bene - arzneimittel|cesra arzneimittel",
  "bene - arzneimittel|desitin arzneimittel",
  "betapharm arzneimittel|cesra arzneimittel",
  "betapharm arzneimittel|dipharma arzneimittel",
  "biosyn arzneimittel|cesra arzneimittel",
  "biosyn arzneimittel|desitin arzneimittel",
  "biosyn arzneimittel|dipharma arzneimittel",
  "cesra arzneimittel|desitin arzneimittel",
  "cesra arzneimittel|dipharma arzneimittel",
  "desitin arzneimittel|dipharma arzneimittel",
  "fairmed healthcare|siemens healthcare",
  "kowa pharmaceutical europe|towa pharmaceutical europe",
  "laboratorios lesvi|laboratorios lorien",
  "basilea pharmaceutica deutschland|idorsia pharmaceuticals deutschland"
]);

// Alias map to force merge clusters known to share identical compositions/routes
export const CLUSTER_ALIAS_NORMALIZATION: Record<string, string> = {
  CLS_ZITHROMAX: "CLS_MONO_ZITHROMAX",
  CLS_BUDESONIDE_EVOLUGEN: "CLS_BUDESONIDE",
  CLS_LIPIDE_PERINUTRIFLEX: "CLS_LIPIDE_MEDNUTRIFLEX",
  CLS_VIDAZA: "CLS_AZACITIDINE",
  // Mixed-route aciclovir: keep systemic as princeps cluster, collapse others
  CLS_ACICLOVIR: "CLS_ACICLOVIR_SYSTEMIC",
  // Princeps-driven canonicalization for gold standard set
  CLS_PARACETAMOL: "CLS_DOLIPRANE",
  CLS_PHLOROGLUCINOL: "CLS_SPASFON",
  CLS_ACIDE_AMOXICILLINE_CIBLOR_CLAVULANIQUE_ML_PAR_RAPPORT: "CLS_AUGMENTIN",
  CLS_A_CROQUER_TAHOR: "CLS_TAHOR",
  CLS_SOPROL: "CLS_CARDENSIEL",
  CLS_ESOMEPRAZOLE: "CLS_INEXIUM",
  CLS_RESISTANTE_ZOLTUM: "CLS_MOPRAL",
  CLS_ZALDIAR: "CLS_IXPRIM",
  CLS_EN_FLACON_GAVISCON: "CLS_GAVISCON",
  CLS_ALVERINE_SIMETICONE: "CLS_METEOSPASMYL",
  CLS_MAG: "CLS_MAGNESIUM",
  CLS_A_TEGRETOL: "CLS_TEGRETOL",
  CLS_CHLORURE_ML_PROAMP: "CLS_CHLORURE",
  CLS_BUVABLE_CLAMOXYL_EN: "CLS_CLAMOXYL",
  // Imodium family unification
  CLS_IMODIUM_ML: "CLS_IMODIUMCAPS",
  CLS_IMODIUMDUO: "CLS_IMODIUMCAPS",
  CLS_IMODIUMLINGUAL: "CLS_IMODIUMCAPS",
  CLS_IMODIUMLIQUICAPS: "CLS_IMODIUMCAPS",
  // Bactrim family
  CLS_BACTRIM_FORTE: "CLS_BACTRIM",
  CLS_BACTRIM_ML: "CLS_BACTRIM",
  // Doliprane family
  CLS_DOLIPRANECAPS: "CLS_DOLIPRANE",
  CLS_DOLIPRANELIQUIZ: "CLS_DOLIPRANE",
  CLS_DOLIPRANEORODOZ: "CLS_DOLIPRANE",
  CLS_DOLIPRANETABS: "CLS_DOLIPRANE",
  CLS_DOLIPRANE_EFFERVESCENT: "CLS_DOLIPRANE",
  CLS_CENT_DOLIPRANE_POUR: "CLS_DOLIPRANE",
  CLS_DOLIPRANEVITAMINEC: "CLS_DOLIPRANE"
};

export const ROUTE_GROUP = {
  SYSTEMIC: new Set(["ORALE", "SUBLINGUALE", "PER OS", "INTRAVEINEUSE", "INTRAMUSCULAIRE", "SOUS-CUTANEE", "RECTALE"]),
  LOCAL: new Set(["CUTANEE", "DERMIQUE", "NASALE", "OPHTALMIQUE", "OTIQUE", "RECTALE", "VAGINALE"]),
  EXTERNAL: new Set(["INHALATION", "TRANSDERMIQUE"])
} as const;

export const ROUTE_COMPATIBILITY = new Set<string>([
  "SYSTEMIC|SYSTEMIC",
  "LOCAL|LOCAL",
  "EXTERNAL|EXTERNAL",
  "SYSTEMIC|LOCAL",
  "LOCAL|SYSTEMIC",
  "EXTERNAL|LOCAL"
]);

/**
 * Keywords to detect prescription conditions and safety flags
 * from CIS_CPD_bdpm.txt
 */
export const PRESCRIPTION_FLAGS = {
  LIST_1: /liste\s+i\b/i,
  LIST_2: /liste\s+ii\b/i,
  NARCOTIC: /stupéfiant/i,
  HOSPITAL: /hospitalier/i,
  DENTAL: /dentaire/i,
  EXCEPTION: /d'exception/i, // Médicament d'exception
  RESTRICTED: /restreinte/i // Prescription restreinte
} as const;

/**
 * Availability status mapping from CIS_CIP_Dispo_Spec.txt
 */
export const AVAILABILITY_STATUS = {
  "1": "Rupture de stock",
  "2": "Tension d'approvisionnement",
  "3": "Arrêt de commercialisation",
  "4": "Remise à disposition"
} as const;

/**
 * Clusters allowed to bridge multiple ATC roots (therapeutic polymorphism).
 * Keys are normalized substance/cluster labels (uppercase, accent-stripped).
 */
export const ATC_POLYMORPHIC_CLUSTERS: Record<string, string[]> = {
  ATROPINE: ["A03", "S01"],
  BETADINE: ["D08", "S01", "G01"],
  OFLOCET: ["J01", "S01", "S02", "S03"],
  OFLOXACINE: ["J01", "S01", "S02", "S03"],
  LIDOCAINE: ["N01", "C01", "D04", "R02"],
  KETOCONAZOLE: ["D01", "H02", "J02"],
  FUNGIZONE: ["A07", "J02"],
  FLAGYL: ["P01", "J01", "G01", "D06"],
  METRONIDAZOLE: ["P01", "J01", "G01", "D06"],
  METHOTREXATE: ["L01", "L04"],
  AFINITOR: ["L01", "L04"],
  EVEROLIMUS: ["L01", "L04"],
  SPECIAFOLDINE: ["B03", "A11"],
  "ACIDE FOLIQUE": ["B03", "A11"],
  FENTANYL: ["N01", "N02"],
  ABSTRAL: ["N01", "N02"],
  SALBUTAMOL: ["R03"],
  TERBUTALINE: ["R03"],
  BRICANYL: ["R03"],
  VENTOLINE: ["R03"],
  BRUFEN: ["M01", "C01"],
  IBUPROFENE: ["M01", "C01"],
  ACICLOVIR: ["D06", "S01", "J05"],
  AMMONAPS: ["A06", "A16", "B05", "V03"],
  BICAVERA: ["B05"],
  "CHLORURE DE SODIUM": ["B05", "A12"],
  BUPRENORPHINE: ["N07", "N02"],
  HYDROCORTISONE: ["A07", "H02"]
};
