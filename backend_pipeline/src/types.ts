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

// --- 5. Normalized Domain Models (Database Rows) ---
export enum GenericType {
  PRINCEPS = 0,
  GENERIC = 1,
  COMPLEMENTARY = 2,
  SUBSTITUTABLE = 3,
  AUTO_SUBSTITUTABLE = 4,
  UNKNOWN = 99
}

export type Product = {
  cis: CisId;
  label: string;
  is_princeps: boolean; // 0 or 1 in SQLite
  generic_type: GenericType;
  group_id: GroupId | null;
  form: string;
  routes: string;
  type_procedure: string;
  surveillance_renforcee: boolean;
  manufacturer_id: number;
  marketing_status: string;
  date_amm: string | null; // ISO YYYY-MM-DD
  regulatory_info: string; // JSON blob for safety flags (Narcotic, Hospital...)
  composition: string; // JSON array of composition entries (element + substances)
  composition_codes: string; // JSON array of substance codes (e.g., ["1234","5678"])
  composition_display: string;
  drawer_label: string;
};

export type Presentation = {
  cip13: Cip13;
  cis: CisId;
  price_cents: number | null;
  reimbursement_rate: string | null;
  market_status: string | null;
  availability_status: string | null;
  ansm_link: string | null;
  date_commercialisation: string | null;
};

export type Cluster = {
  id: string; // Deterministic Hash
  label: string; // "Paracétamol"
  princeps_label: string; // "Doliprane"
  substance_code: string; // Normalized key
  text_brand_label?: string | null;
};

export type GroupRow = {
  id: string;
  cluster_id: string;
  label: string;
  canonical_name: string;
  historical_princeps_raw: string | null;
  generic_label_clean: string | null;
  naming_source: NamingSource;
  princeps_aliases: string;
  routes: string;
  safety_flags: string;
};

export type ProductGroupingUpdate = {
  cis: CisId;
  group_id: string;
  is_princeps: boolean;
  generic_type: GenericType;
};

export type RegulatoryInfo = {
  list1: boolean;
  list2: boolean;
  narcotic: boolean;
  hospital: boolean;
  dental: boolean;
};

export type NamingSource = "GOLDEN_PRINCEPS" | "TYPE_0_LINK" | "GENER_PARSING";
