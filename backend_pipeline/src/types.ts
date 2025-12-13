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
// Matches columns in: lib/core/services/ingestion/schema/file_validator.dart
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

// --- 3. Raw Type Aliases ---
export type RawSpecialite = z.infer<typeof RawSpecialiteSchema>;
export type RawPresentation = z.infer<typeof RawPresentationSchema>;
export type RawGroup = z.infer<typeof RawGroupSchema>;
export type RawConditions = z.infer<typeof RawConditionsSchema>;
export type RawAvailability = z.infer<typeof RawAvailabilitySchema>;
export type RawComposition = z.infer<typeof RawCompositionSchema>;
export type RawMitm = z.infer<typeof RawMitmSchema>;

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

// New interfaces matching Flutter app schema
export interface Specialite {
  cisCode: string;
  nomSpecialite: string;
  procedureType: string;
  statutAdministratif?: string;
  formePharmaceutique?: string;
  voiesAdministration?: string;
  etatCommercialisation?: string;
  titulaireId?: number;
  conditionsPrescription?: string;
  dateAmm?: string;
  atcCode?: string;
  isSurveillance?: boolean;
}

export interface Medicament {
  codeCip: string;
  cisCode: string;
  presentationLabel?: string;
  commercialisationStatut?: string;
  tauxRemboursement?: string;
  prixPublic?: number;
  agrementCollectivites?: string;
}

export interface MedicamentAvailability {
  codeCip: string;
  statut: string;
  dateDebut?: string;
  dateFin?: string;
  lien?: string;
}

// Info Importante (CIS_InfoImportante.txt)
export interface SafetyAlert {
  cisCode: string;
  dateDebut: string;
  dateFin: string;
  texte: string;
}

// SMR/ASMR (CIS_HAS_SMR_bdpm.txt, CIS_HAS_ASMR_bdpm.txt)
export interface HasEvaluation {
  cisCode: string;
  niveau: string; // SMR: "Important", "Modéré", "Faible", "Insuffisant" | ASMR: "I", "II", "III", "IV", "V"
  motif?: string;
  dateAvis?: string;
}

export interface PrincipeActif {
  id?: number;
  codeCip: string;
  principe: string;
  principeNormalized?: string;
  dosage?: string;
  dosageUnit?: string;
}

export interface GeneriqueGroup {
  groupId: string;
  libelle: string;
  princepsLabel?: string;
  moleculeLabel?: string;
  rawLabel?: string;
  parsingMethod?: string;
}

export interface GroupMember {
  codeCip: string;
  groupId: string;
  type: number; // 0 princeps, 1 standard, 2 complémentarité, 4 substituable
  sortOrder?: number; // Colonne 5 de CIS_GENER : ordre de tri (plus élevé = plus récent/primaire)
}

export interface MedicamentSummary {
  cisCode: string;
  nomCanonique: string;
  isPrinceps: boolean;
  groupId?: string; // nullable for medications without groups
  memberType?: number; // raw BDPM generic type
  principesActifsCommuns?: string | Uint8Array; // JSONB array of common active ingredients
  princepsDeReference: string; // reference princeps name for group
  formePharmaceutique?: string; // for filtering
  voiesAdministration?: string; // semicolon routes
  princepsBrandName: string;
  procedureType?: string;
  titulaireId?: number;
  conditionsPrescription?: string;
  dateAmm?: string;
  isSurveillance?: boolean;
  formattedDosage?: string;
  atcCode?: string;
  status?: string;
  priceMin?: number;
  priceMax?: number;
  aggregatedConditions?: string;
  ansmAlertUrl?: string;
  isHospitalOnly?: boolean;
  isDental?: boolean;
  isList1?: boolean;
  isList2?: boolean;
  isNarcotic?: boolean;
  isException?: boolean;
  isRestricted?: boolean;
  isOtc?: boolean;
  representativeCip?: string;
  clusterId?: string; // NEW - for clustering
  smrNiveau?: string; // Service Médical Rendu (ex: "Important", "Modéré", "Faible", "Insuffisant")
  smrDate?: string; // Date de l'avis SMR (format YYYYMMDD)
  asmrNiveau?: string; // Amélioration du Service Médical Rendu (ex: "I", "II", "III", "IV", "V")
  asmrDate?: string; // Date de l'avis ASMR (format YYYYMMDD)
  urlNotice?: string; // Lien vers PDF Notice officielle
  hasSafetyAlert?: boolean; // Flag rapide pour UI (présence d'alerte de sécurité active)
  rowid?: number; // For FTS content_rowid
}

export interface Laboratory {
  id?: number;
  name: string;
}

// Additional interfaces from Flutter app
export interface RestockItem {
  id?: number;
  cisCode: string;
  cipCode: string;
  nomCanonique: string;
  isPrinceps: boolean;
  princepsDeReference: string;
  formePharmaceutique?: string;
  voiesAdministration?: string;
  formattedDosage?: string;
  representativeCip?: string;
  expiryDate?: string;
  stockCount: number;
  location?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ScannedBox {
  id?: number;
  boxLabel: string;
  cisCode?: string;
  cipCode?: string;
  scanTimestamp: string;
}

export interface AppSettings {
  key: string;
  value: Uint8Array;
}

// Cluster-First Architecture Interface
export interface ClusterData {
  id: string;              // Ex: "CLS_IBUPROFENE_400"
  display_title: string;   // Ex: "Ibuprofène 400mg" (Substance Clean)
  display_subtitle: string;// Ex: "Réf: Advil" (Princeps Principal)
  search_vector: string;   // Ex: "IBUPROFENE ADVIL NUROFEN SPEDIFEN ANTARENE"
}

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
