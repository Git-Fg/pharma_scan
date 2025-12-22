import { removeAccentsEnhanced } from "@urbanzoo/remove-accents";
import { z } from "zod";

// --- 1. Branded IDs (Gold Standard Type Safety) ---
export const CisIdSchema = z.string().length(8).brand("CisId");
export type CisId = z.infer<typeof CisIdSchema>;

export const Cip13Schema = z.string().length(13).brand("Cip13");
export type Cip13 = z.infer<typeof Cip13Schema>;

export const GroupIdSchema = z.string().min(1).brand("GroupId");
export type GroupId = z.infer<typeof GroupIdSchema>;

// --- 2. Raw Input Schemas (BDPM Text Files) ---
// Matches expected BDPM file columns (Specialite / Presentation / Group files)
export const RawSpecialiteSchema = z
  .tuple([
    CisIdSchema, // 0: CIS
    z.string(), // 1: Name
    z.string(), // 2: Form
    z.string(), // 3: Route
    z.string(), // 4: Admin Status
    z.string(), // 5: Procedure Type
    z.string(), // 6: Commercial Status
    z.string(), // 7: Date AMM
    z.string(), // 8: Status BDM
    z.string(), // 9: EU Number
    z.string(), // 10: Holder
    z.string() // 11: Surveillance
  ])
  .rest(z.string()); // Ignore extra columns for forward compatibility

export const RawPresentationSchema = z
  .tuple([
    CisIdSchema, // 0: CIS
    z.string(), // 1: CIP7
    z.string(), // 2: Label
    z.string(), // 3: Admin Status
    z.string(), // 4: Market Status
    z.string(), // 5: Date Comm
    Cip13Schema, // 6: CIP13
    z.string(), // 7: Agreement
    z.string(), // 8: Refund Rate
    z.string() // 9: Price
  ])
  .rest(z.string());

export const RawGroupSchema = z
  .tuple([
    GroupIdSchema, // 0: Group ID
    z.string(), // 1: Label
    CisIdSchema, // 2: CIS
    z.string(), // 3: Type (0=Princeps, 1=Generic...)
    z.string() // 4: Sort (historical ordering flag)
  ])
  .rest(z.string());

// Conditions de prescription (CIS_CPD_bdpm.txt)
export const RawConditionsSchema = z
  .tuple([
    CisIdSchema, // 0: CIS
    z.string() // 1: Condition
  ])
  .rest(z.string());

// Availability / Shortages (CIS_CIP_Dispo_Spec.txt)
export const RawAvailabilitySchema = z
  .tuple([
    z.string(), // 0: CIS (may be empty if CIP provided)
    z.string(), // 1: CIP13 (may be empty if CIS provided)
    z.string(), // 2: Status Code
    z.string(), // 3: Status Label
    z.string().optional(), // 4: Start Date
    z.string().optional(), // 5: End Date
    z.string().optional() // 6: Link to ANSM
  ])
  .rest(z.string());

// Composition (CIS_COMPO_bdpm.txt)
export const RawCompositionSchema = z
  .tuple([
    CisIdSchema, // 0: CIS
    z.string(), // 1: Element Label
    z.string(), // 2: Code Substance (string, can be "0045" or empty)
    z.string(), // 3: Substance Name
    z.string(), // 4: Dosage
    z.string(), // 5: Reference
    z.string(), // 6: Nature (SA | FT)
    z.string() // 7: Link ID
  ])
  .rest(z.string());

// Classification thérapeutique (CIS_MITM.txt)
export const RawMitmSchema = z
  .tuple([
    CisIdSchema, // 0: CIS
    z.string(), // 1: ATC code
    z.string(), // 2: ATC label
    z.string() // 3: Link
  ])
  .rest(z.string());

// --- 3. Raw Type Aliases (Tuples) ---
export type RawSpecialite = z.infer<typeof RawSpecialiteSchema>;
export type RawPresentation = z.infer<typeof RawPresentationSchema>;
export type RawGroup = z.infer<typeof RawGroupSchema>;
export type RawConditions = z.infer<typeof RawConditionsSchema>;
export type RawAvailability = z.infer<typeof RawAvailabilitySchema>;
export type RawComposition = z.infer<typeof RawCompositionSchema>;
export type RawMitm = z.infer<typeof RawMitmSchema>;

// --- 3a. Parsed Data Models (Ingestion Output) ---
export const ParsedCISSchema = z.object({
  cis: CisIdSchema,
  originalName: z.string(),
  shape: z.string(),
  cleanName: z.string(),
  lab: z.string(),
  isHomeo: z.boolean(),
  homeoReason: z.string().nullable(),
  status: z.string(),
  commercialStatus: z.string(),
  // Enhanced fields
  voies: z.string(),
  procedure: z.string(),
  dateAmm: z.string(),
  isSurveillance: z.boolean(),
  titulaireId: z.number().default(0)
});
export type ParsedCIS = z.infer<typeof ParsedCISSchema>;

export const ParsedGenerSchema = z.object({
  groupId: GroupIdSchema,
  groupLabel: z.string(),
  cis: CisIdSchema,
  type: z.string(),
  sortOrder: z.string()
});
export type ParsedGener = z.infer<typeof ParsedGenerSchema>;

export const ParsedCIPSchema = z.object({
  cis: CisIdSchema,
  cip7: z.string(),
  presentationLabel: z.string(),
  status: z.string(),
  commercialisationStatus: z.string(),
  dateCommercialisation: z.string(),
  cip13: Cip13Schema,
  agrement: z.string(),
  tauxRemboursement: z.string(),
  prix: z.string(),
  priceFormatted: z.number().nullable()
});
export type ParsedCIP = z.infer<typeof ParsedCIPSchema>;

// --- 3b. Reference Maps (Join-first BDPM rows) ---
export type RefComposition = {
  cis: CisId;
  elementLabel: string;
  codeSubstance: string;
  substanceName: string;
  dosage: string;
  reference: string;
  nature: string;
  linkId: string;
};

export type RefGenerique = {
  groupId: GroupId;
  label: string;
  cis: CisId;
  type: number;
  sort: string;
};

// --- 4. Dependency Maps (Pre-materialized Relations) ---
export type GenericInfo = {
  groupId: string;
  type: string;
  label: string;
  sort: string;
};

export type DependencyMaps = {
  conditions: Map<CisId, string[]>;
  compositions: Map<CisId, RawComposition[]>;
  presentations: Map<CisId, RawPresentation[]>;
  generics: Map<CisId, GenericInfo>;
  atc: Map<CisId, RawMitm[]>;
};

// --- 4. Galenic ontology & dosage structures ---
export enum GalenicCategory {
  ORAL_SOLID = "ORAL_SOLID",
  ORAL_LIQUID = "ORAL_LIQUID",
  INJECTABLE = "INJECTABLE",
  RADIOPHARMACEUTIQUE = "RADIOPHARMACEUTIQUE",
  DERMAL = "DERMAL",
  OPHTHALMIC = "OPHTHALMIC",
  RESPIRATORY = "RESPIRATORY",
  NASAL = "NASAL",
  RECTAL_VAGINAL = "RECTAL_VAGINAL",
  TRANSDERMAL = "TRANSDERMAL",
  OTHER = "OTHER"
}

const GALENIC_KEYWORDS: Array<{ key: GalenicCategory; tokens: string[] }> = [
  {
    key: GalenicCategory.ORAL_SOLID,
    tokens: ["COMPRIME", "COMPRIMÉ", "GELULE", "GÉLULE", "CAPSULE", "PASTILLE", "LYOPHILISAT", "GRANULE", "POUDRE"]
  },
  {
    key: GalenicCategory.ORAL_LIQUID,
    tokens: ["SIROP", "SOL BUV", "SOLUTION BUVABLE", "GOUTTE", "GOUTTES", "SUSPENSION BUVABLE"]
  },
  {
    key: GalenicCategory.INJECTABLE,
    tokens: ["INJECTABLE", "PERFUSION", "SERINGUE", "IV", "IM", "SC", "INJECTION"]
  },
  {
    key: GalenicCategory.RADIOPHARMACEUTIQUE,
    tokens: ["PREPARATION RADIOPHARMACEUTIQUE", "PRÉPARATION RADIOPHARMACEUTIQUE"]
  },
  {
    key: GalenicCategory.DERMAL,
    tokens: ["CREME", "CRÈME", "POMMADE", "GEL DERMIQUE", "DERMIQUE", "TOPIQUE", "LOTION", "SHAMPOOING"]
  },
  {
    key: GalenicCategory.OPHTHALMIC,
    tokens: ["COLLYRE", "OPHTALMIQUE", "OPH"]
  },
  {
    key: GalenicCategory.RESPIRATORY,
    tokens: ["INHALATION", "INHAL", "AEROSOL", "SPRAY", "POUDRE INHAL", "DISPOSITIF INHALATION"]
  },
  {
    key: GalenicCategory.NASAL,
    tokens: ["NASAL", "SPRAY NASAL", "GOUTTES NASALES"]
  },
  {
    key: GalenicCategory.RECTAL_VAGINAL,
    tokens: ["SUPPOSITOIRE", "OVULE", "RECTAL", "VAGINAL"]
  },
  {
    key: GalenicCategory.TRANSDERMAL,
    tokens: ["TIMBRE", "PATCH", "TRANSDERMIQUE"]
  }
];

export function mapGalenicCategory(rawForm: string): GalenicCategory {
  const upper = rawForm.toUpperCase();
  const accentFree = removeAccentsEnhanced(upper);

  // Hard override: any explicit injectable hint wins over oral defaults
  if (upper.includes("INJECT")) {
    return GalenicCategory.INJECTABLE;
  }

  if (accentFree.includes("PREPARATION RADIOPHARMACEUTIQUE")) {
    return GalenicCategory.RADIOPHARMACEUTIQUE;
  }

  for (const entry of GALENIC_KEYWORDS) {
    if (entry.tokens.some((token) => upper.includes(token))) {
      return entry.key;
    }
  }
  return GalenicCategory.OTHER;
}

export type StructuredDosage = {
  raw_value: number;
  unit: string;
  base_normalized_value: number;
};

export function normalizeDosageUnit(value: number, unit: string): number {
  const upper = unit.toUpperCase();
  if (upper === "G") return value * 1000;
  if (upper === "MG") return value;
  if (upper === "UG" || upper === "µG" || upper === "MCG") return value / 1000;
  if (upper === "KG") return value * 1_000_000;
  // Fallback: return as-is so we do not drop information
  return value;
}

// --- 5. Normalized Domain Models (Database Rows) ---
export enum GenericType {
  PRINCEPS = 0,
  GENERIC = 1,
  COMPLEMENTARY = 2,
  SUBSTITUTABLE = 3,
  AUTO_SUBSTITUTABLE = 4,
  UNKNOWN = 99
}

// --- Database Row Schemas (Zod-first approach) ---

export const SpecialiteSchema = z.object({
  cisCode: z.string(),
  nomSpecialite: z.string(),
  procedureType: z.string(),
  statutAdministratif: z.string().optional(),
  formePharmaceutique: z.string().optional(),
  voiesAdministration: z.string().optional(),
  etatCommercialisation: z.string().optional(),
  titulaireId: z.number().optional(),
  conditionsPrescription: z.string().optional(),
  dateAmm: z.string().optional(),
  atcCode: z.string().optional(),
  isSurveillance: z.boolean().optional()
}).strict();
export type Specialite = z.infer<typeof SpecialiteSchema>;

export const MedicamentSchema = z.object({
  codeCip: z.string(),
  cisCode: z.string(),
  presentationLabel: z.string().optional(),
  commercialisationStatut: z.string().optional(),
  tauxRemboursement: z.string().optional(),
  prixPublic: z.number().optional(),
  agrementCollectivites: z.string().optional()
}).strict();
export type Medicament = z.infer<typeof MedicamentSchema>;

export const MedicamentAvailabilitySchema = z.object({
  codeCip: z.string(),
  statut: z.string(),
  dateDebut: z.string().optional(),
  dateFin: z.string().optional(),
  lien: z.string().optional()
}).strict();
export type MedicamentAvailability = z.infer<typeof MedicamentAvailabilitySchema>;

export const SafetyAlertSchema = z.object({
  cisCode: z.string(),
  dateDebut: z.string(),
  dateFin: z.string(),
  texte: z.string()
}).strict();
export type SafetyAlert = z.infer<typeof SafetyAlertSchema>;

export const HasEvaluationSchema = z.object({
  cisCode: z.string(),
  niveau: z.string(),
  motif: z.string().optional(),
  dateAvis: z.string().optional()
}).strict();
export type HasEvaluation = z.infer<typeof HasEvaluationSchema>;

export const PrincipeActifSchema = z.object({
  id: z.number().optional(),
  codeCip: z.string(),
  principe: z.string(),
  principeNormalized: z.string().optional(),
  dosage: z.string().optional(),
  dosageUnit: z.string().optional()
}).strict();
export type PrincipeActif = z.infer<typeof PrincipeActifSchema>;

export const GeneriqueGroupSchema = z.object({
  groupId: z.string(),
  libelle: z.string(),
  princepsLabel: z.string().optional(),
  moleculeLabel: z.string().optional(),
  rawLabel: z.string().optional(),
  parsingMethod: z.string().optional()
}).strict();
export type GeneriqueGroup = z.infer<typeof GeneriqueGroupSchema>;

export const GroupMemberSchema = z.object({
  codeCip: z.string(),
  groupId: z.string(),
  type: z.number(),
  sortOrder: z.number().optional()
}).strict();
export type GroupMember = z.infer<typeof GroupMemberSchema>;

export const MedicamentSummarySchema = z.object({
  cisCode: z.string(),
  nomCanonique: z.string(),
  isPrinceps: z.boolean(),
  groupId: z.string().optional(),
  memberType: z.number().optional(),
  principesActifsCommuns: z.union([z.string(), z.instanceof(Uint8Array)]).optional(),
  princepsDeReference: z.string(),
  parentPrincepsCis: z.string().optional(),
  formePharmaceutique: z.string().optional(),
  formId: z.number().optional(),
  isFormInferred: z.boolean().optional(),
  voiesAdministration: z.string().optional(),
  princepsBrandName: z.string(),
  procedureType: z.string().optional(),
  titulaireId: z.number().optional(),
  conditionsPrescription: z.string().optional(),
  dateAmm: z.string().optional(),
  isSurveillance: z.boolean().optional(),
  formattedDosage: z.string().optional(),
  atcCode: z.string().optional(),
  status: z.string().optional(),
  priceMin: z.number().optional(),
  priceMax: z.number().optional(),
  aggregatedConditions: z.string().optional(),
  ansmAlertUrl: z.string().optional(),
  isHospitalOnly: z.boolean().optional(),
  isDental: z.boolean().optional(),
  isList1: z.boolean().optional(),
  isList2: z.boolean().optional(),
  isNarcotic: z.boolean().optional(),
  isException: z.boolean().optional(),
  isRestricted: z.boolean().optional(),
  isOtc: z.boolean().optional(),
  representativeCip: z.string().optional(),
  clusterId: z.string().optional(),
  smrNiveau: z.string().optional(),
  smrDate: z.string().optional(),
  asmrNiveau: z.string().optional(),
  asmrDate: z.string().optional(),
  urlNotice: z.string().optional(),
  hasSafetyAlert: z.boolean().optional(),
  rowid: z.number().optional()
}).strict();
export type MedicamentSummary = z.infer<typeof MedicamentSummarySchema>;

export const LaboratorySchema = z.object({
  id: z.number().optional(),
  name: z.string()
}).strict();
export type Laboratory = z.infer<typeof LaboratorySchema>;

export const RestockItemSchema = z.object({
  id: z.number().optional(),
  cisCode: z.string(),
  cipCode: z.string(),
  nomCanonique: z.string(),
  isPrinceps: z.boolean(),
  princepsDeReference: z.string(),
  formePharmaceutique: z.string().optional(),
  voiesAdministration: z.string().optional(),
  formattedDosage: z.string().optional(),
  representativeCip: z.string().optional(),
  expiryDate: z.string().optional(),
  stockCount: z.number(),
  location: z.string().optional(),
  notes: z.string().optional(),
  createdAt: z.string(),
  updatedAt: z.string()
}).strict();
export type RestockItem = z.infer<typeof RestockItemSchema>;

export const ScannedBoxSchema = z.object({
  id: z.number().optional(),
  boxLabel: z.string(),
  cisCode: z.string().optional(),
  cipCode: z.string().optional(),
  scanTimestamp: z.string()
}).strict();
export type ScannedBox = z.infer<typeof ScannedBoxSchema>;

export const AppSettingsSchema = z.object({
  key: z.string(),
  value: z.instanceof(Uint8Array)
}).strict();
export type AppSettings = z.infer<typeof AppSettingsSchema>;

export const ClusterDataSchema = z.object({
  id: z.string(),
  display_title: z.string(),
  display_subtitle: z.string(),
  search_vector: z.string()
}).strict();
export type ClusterData = z.infer<typeof ClusterDataSchema>;

export type RegulatoryInfo = {
  list1: boolean;
  list2: boolean;
  narcotic: boolean;
  hospital: boolean;
  dental: boolean;
};

export type NamingSource =
  | "GOLDEN_PRINCEPS"
  | "TYPE_0_LINK"
  | "GENER_PARSING"
  | "STANDALONE";

export const ClusterMetadataSchema = z.object({
  clusterId: z.string(),
  substanceCode: z.string(),
  princepsLabel: z.string(),
  secondaryPrinceps: z.array(z.string())
}).strict();
export type ClusterMetadata = z.infer<typeof ClusterMetadataSchema>;
