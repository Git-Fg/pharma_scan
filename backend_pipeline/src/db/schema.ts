import { sqliteTable, text, integer, real, index, primaryKey } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";

// 1. Raw Data Tables

export const specialites = sqliteTable("specialites", {
    cis_code: text("cis_code").primaryKey().notNull(),
    nom_specialite: text("nom_specialite").notNull(),
    forme_pharmaceutique: text("forme_pharmaceutique"),
    voies_administration: text("voies_administration"),
    statut_administratif: text("statut_administratif"),
    procedure_type: text("procedure_type"),
    etat_commercialisation: text("etat_commercialisation"),
    date_amm: text("date_amm"),
    statut_bdm: text("statut_bdm"),
    numero_europeen: text("numero_europeen"),
    titulaire_id: integer("titulaire_id"),
    is_surveillance: integer("is_surveillance", { mode: "number" }).default(0),
    conditions_prescription: text("conditions_prescription"),
    atc_code: text("atc_code")
});

export const medicamentSummary = sqliteTable("medicament_summary", {
    cis_code: text("cis_code").primaryKey().notNull(),
    nom_canonique: text("nom_canonique").notNull(),
    princeps_de_reference: text("princeps_de_reference").notNull(),
    parent_princeps_cis: text("parent_princeps_cis"),
    is_princeps: integer("is_princeps", { mode: "number" }).notNull().default(0),
    cluster_id: text("cluster_id"),
    group_id: text("group_id"),
    principes_actifs_communs: text("principes_actifs_communs"),
    formatted_dosage: text("formatted_dosage"),
    forme_pharmaceutique: text("forme_pharmaceutique"),
    form_id: integer("form_id"),
    is_form_inferred: integer("is_form_inferred", { mode: "number" }).notNull().default(0),
    voies_administration: text("voies_administration"),
    member_type: integer("member_type").notNull().default(0),
    princeps_brand_name: text("princeps_brand_name").notNull(),
    procedure_type: text("procedure_type"),
    titulaire_id: integer("titulaire_id"),
    conditions_prescription: text("conditions_prescription"),
    date_amm: text("date_amm"),
    is_surveillance: integer("is_surveillance", { mode: "number" }).notNull().default(0),
    atc_code: text("atc_code"),
    status: text("status"),
    price_min: real("price_min"),
    price_max: real("price_max"),
    aggregated_conditions: text("aggregated_conditions"),
    ansm_alert_url: text("ansm_alert_url"),
    is_hospital: integer("is_hospital", { mode: "number" }).notNull().default(0),
    is_dental: integer("is_dental", { mode: "number" }).notNull().default(0),
    is_list1: integer("is_list1", { mode: "number" }).notNull().default(0),
    is_list2: integer("is_list2", { mode: "number" }).notNull().default(0),
    is_narcotic: integer("is_narcotic", { mode: "number" }).notNull().default(0),
    is_exception: integer("is_exception", { mode: "number" }).notNull().default(0),
    is_restricted: integer("is_restricted", { mode: "number" }).notNull().default(0),
    is_otc: integer("is_otc", { mode: "number" }).notNull().default(1),
    smr_niveau: text("smr_niveau"),
    smr_date: text("smr_date"),
    asmr_niveau: text("asmr_niveau"),
    asmr_date: text("asmr_date"),
    url_notice: text("url_notice"),
    has_safety_alert: integer("has_safety_alert", { mode: "number" }).default(0),
    representative_cip: text("representative_cip")
});

export const medicaments = sqliteTable("medicaments", {
    cip_code: text("cip_code").primaryKey().notNull(),
    cis_code: text("cis_code").notNull().references(() => medicamentSummary.cis_code, { onDelete: "cascade" }),
    presentation_label: text("presentation_label").notNull().default(''),
    commercialisation_statut: text("commercialisation_statut"),
    taux_remboursement: text("taux_remboursement"),
    prix_public: real("prix_public"),
    agrement_collectivites: text("agrement_collectivites"),
    is_hospital: integer("is_hospital", { mode: "number" }).notNull().default(0)
});

export const principesActifs = sqliteTable("principes_actifs", {
    id: integer("id").primaryKey({ autoIncrement: true }),
    cip_code: text("cip_code").notNull().references(() => medicaments.cip_code, { onDelete: "cascade" }),
    principe: text("principe").notNull(),
    principe_normalized: text("principe_normalized"),
    dosage: text("dosage"),
    dosage_unit: text("dosage_unit")
});

export const generiqueGroups = sqliteTable("generique_groups", {
    group_id: text("group_id").primaryKey().notNull(),
    libelle: text("libelle").notNull(),
    princeps_label: text("princeps_label"),
    molecule_label: text("molecule_label"),
    raw_label: text("raw_label"),
    parsing_method: text("parsing_method")
});

export const groupMembers = sqliteTable("group_members", {
    cip_code: text("cip_code").notNull().references(() => medicaments.cip_code, { onDelete: "cascade" }),
    group_id: text("group_id").notNull().references(() => generiqueGroups.group_id, { onDelete: "cascade" }),
    type: integer("type").notNull(),
    sort_order: integer("sort_order").default(0)
}, (table) => ({
    pk: primaryKey({ columns: [table.cip_code, table.group_id] })
}));

export const productScanCache = sqliteTable("product_scan_cache", {
    cip_code: text("cip_code").primaryKey().notNull(),
    cip7: text("cip7"),
    cis_code: text("cis_code"),
    nom_canonique: text("nom_canonique"),
    princeps_de_reference: text("princeps_de_reference"),
    princeps_brand_name: text("princeps_brand_name").notNull().default(''),
    is_princeps: integer("is_princeps", { mode: "number" }).notNull().default(0),
    forme_pharmaceutique: text("forme_pharmaceutique"),
    voies_administration: text("voies_administration"),
    formatted_dosage: text("formatted_dosage"),
    titulaire_id: integer("titulaire_id"),
    conditions_prescription: text("conditions_prescription"),
    is_surveillance: integer("is_surveillance", { mode: "number" }).notNull().default(0),
    atc_code: text("atc_code"),
    representative_cip: text("representative_cip"),
    is_hospital: integer("is_hospital", { mode: "number" }).notNull().default(0),
    is_narcotic: integer("is_narcotic", { mode: "number" }).notNull().default(0),
    lab_name: text("lab_name"),
    cluster_id: text("cluster_id"),
    group_id: text("group_id"),
    prix_public: real("prix_public"),
    taux_remboursement: text("taux_remboursement"),
    commercialisation_statut: text("commercialisation_statut"),
    availability_status: text("availability_status")
}, (table) => ({
    idx_product_scan_cache_cip7: index("idx_product_scan_cache_cip7").on(table.cip7)
}));

export const laboratories = sqliteTable("laboratories", {
    id: integer("id").primaryKey({ autoIncrement: true }),
    name: text("name").notNull().unique()
});

// 2. Clustering & Indexing Tables

export const clusterNames = sqliteTable("cluster_names", {
    cluster_id: text("cluster_id").primaryKey().notNull(),
    cluster_name: text("cluster_name").notNull(),
    substance_code: text("substance_code"),
    cluster_princeps: text("cluster_princeps"),
    secondary_princeps: text("secondary_princeps")
});

export const clusterIndex = sqliteTable("cluster_index", {
    cluster_id: text("cluster_id").primaryKey(),
    title: text("title").notNull(),
    subtitle: text("subtitle"),
    count_products: integer("count_products").default(0),
    search_vector: text("search_vector")
});

export const medicamentDetail = sqliteTable("medicament_detail", {
    cis_code: text("cis_code").primaryKey(),
    cluster_id: text("cluster_id").references(() => clusterIndex.cluster_id),
    nom_complet: text("nom_complet"),
    is_princeps: integer("is_princeps", { mode: "number" })
});

// Virtual Table search_index is not fully supported by standard Drizzle definitions yet without special handling or raw SQL.
// We will manage search_index creation via raw SQL in initSchema, but we can define a table for typing if needed,
// though for FTS5 raw SQL is often best. We'll skip defining it here for migration generation but might use a placeholder if we want types.

// 4. UI Tables & Views

export const uiGroupDetails = sqliteTable("ui_group_details", {
    group_id: text("group_id").notNull(),
    cip_code: text("cip_code").notNull(),
    cis_code: text("cis_code").notNull(),
    nom_canonique: text("nom_canonique").notNull(),
    princeps_de_reference: text("princeps_de_reference").notNull(),
    princeps_brand_name: text("princeps_brand_name").notNull(),
    is_princeps: integer("is_princeps", { mode: "number" }).default(0),
    status: text("status"),
    forme_pharmaceutique: text("forme_pharmaceutique"),
    voies_administration: text("voies_administration"),
    principes_actifs_communs: text("principes_actifs_communs"),
    formatted_dosage: text("formatted_dosage"),
    summary_titulaire: text("summary_titulaire"),
    official_titulaire: text("official_titulaire"),
    nom_specialite: text("nom_specialite"),
    procedure_type: text("procedure_type"),
    conditions_prescription: text("conditions_prescription"),
    is_surveillance: integer("is_surveillance", { mode: "number" }).default(0),
    atc_code: text("atc_code"),
    member_type: integer("member_type").default(0),
    prix_public: real("prix_public"),
    taux_remboursement: text("taux_remboursement"),
    ansm_alert_url: text("ansm_alert_url"),
    is_hospital_only: integer("is_hospital_only", { mode: "number" }).default(0),
    is_dental: integer("is_dental", { mode: "number" }).default(0),
    is_list1: integer("is_list1", { mode: "number" }).default(0),
    is_list2: integer("is_list2", { mode: "number" }).default(0),
    is_narcotic: integer("is_narcotic", { mode: "number" }).default(0),
    is_exception: integer("is_exception", { mode: "number" }).default(0),
    is_restricted: integer("is_restricted", { mode: "number" }).default(0),
    is_otc: integer("is_otc", { mode: "number" }).default(1),
    availability_status: text("availability_status"),
    smr_niveau: text("smr_niveau"),
    smr_date: text("smr_date"),
    asmr_niveau: text("asmr_niveau"),
    asmr_date: text("asmr_date"),
    url_notice: text("url_notice"),
    has_safety_alert: integer("has_safety_alert", { mode: "number" }).default(0),
    raw_label: text("raw_label"),
    parsing_method: text("parsing_method"),
    princeps_cis_reference: text("princeps_cis_reference")
}, (table) => ({
    pk: primaryKey({ columns: [table.group_id, table.cip_code] })
}));

export const uiStats = sqliteTable("ui_stats", {
    id: integer("id").primaryKey(), // Check constraint id=1 is harder to express purely in Drizzle standard, best left to raw or ignored if app logic handles it.
    total_princeps: integer("total_princeps").default(0),
    total_generiques: integer("total_generiques").default(0),
    total_principes: integer("total_principes").default(0),
    last_updated: text("last_updated").default(sql`CURRENT_TIMESTAMP`)
});

export const uiExplorerList = sqliteTable("ui_explorer_list", {
    cluster_id: text("cluster_id").primaryKey().notNull(),
    title: text("title").notNull(),
    subtitle: text("subtitle"),
    secondary_princeps: text("secondary_princeps"),
    is_narcotic: integer("is_narcotic", { mode: "number" }).default(0),
    variant_count: integer("variant_count").default(0),
    representative_cis: text("representative_cis")
});
