-- Minimal test database for integration tests
-- Matches the Server-Side ETL schema

-- Create tables
CREATE TABLE IF NOT EXISTS laboratories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS cluster_names (
    cluster_id TEXT PRIMARY KEY NOT NULL,
    cluster_name TEXT NOT NULL,
    substance_code TEXT,
    cluster_princeps TEXT,
    secondary_princeps TEXT
);

CREATE TABLE IF NOT EXISTS medicament_summary (
    cis_code TEXT PRIMARY KEY NOT NULL,
    -- Identification
    nom_canonique TEXT NOT NULL,
    princeps_de_reference TEXT NOT NULL,
    is_princeps BOOLEAN NOT NULL DEFAULT 0,

    -- Clustering & Grouping
    cluster_id TEXT,
    group_id TEXT,

    -- Composition & Galénique
    principes_actifs_communs TEXT,
    formatted_dosage TEXT,
    forme_pharmaceutique TEXT,
    voies_administration TEXT,

    -- Métadonnées
    member_type INTEGER NOT NULL DEFAULT 0,
    princeps_brand_name TEXT NOT NULL,
    procedure_type TEXT,
    titulaire_id INTEGER,
    conditions_prescription TEXT,
    date_amm TEXT,
    is_surveillance BOOLEAN NOT NULL DEFAULT 0,
    atc_code TEXT,
    status TEXT,
    price_min REAL,
    price_max REAL,
    aggregated_conditions TEXT,
    ansm_alert_url TEXT,

    -- Flags
    is_hospital BOOLEAN NOT NULL DEFAULT 0,
    is_dental BOOLEAN NOT NULL DEFAULT 0,
    is_list1 BOOLEAN NOT NULL DEFAULT 0,
    is_list2 BOOLEAN NOT NULL DEFAULT 0,
    is_narcotic BOOLEAN NOT NULL DEFAULT 0,
    is_exception BOOLEAN NOT NULL DEFAULT 0,
    is_restricted BOOLEAN NOT NULL DEFAULT 0,
    is_otc BOOLEAN NOT NULL DEFAULT 1,

    -- SMR & ASMR & Safety
    smr_niveau TEXT,
    smr_date TEXT,
    asmr_niveau TEXT,
    asmr_date TEXT,
    url_notice TEXT,
    has_safety_alert BOOLEAN DEFAULT 0,

    representative_cip TEXT,

    FOREIGN KEY(titulaire_id) REFERENCES laboratories(id),
    FOREIGN KEY(cluster_id) REFERENCES cluster_names(cluster_id)
);

-- Create FTS5 search index
CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
    cis_code UNINDEXED,
    molecule_name,
    brand_name,
    tokenize='unicode61 remove_diacritics 2'
);

-- Triggers to maintain search index
CREATE TRIGGER IF NOT EXISTS search_index_ai AFTER INSERT ON medicament_summary BEGIN
    INSERT INTO search_index(
        cis_code,
        molecule_name,
        brand_name
    ) VALUES (
        new.cis_code,
        new.nom_canonique,
        new.princeps_de_reference
    );
END;

CREATE TRIGGER IF NOT EXISTS search_index_ad AFTER DELETE ON medicament_summary BEGIN
    INSERT INTO search_index(
        cis_code,
        molecule_name,
        brand_name
    ) VALUES (
        old.cis_code,
        old.nom_canonique,
        old.princeps_de_reference
    );
END;

CREATE TRIGGER IF NOT EXISTS search_index_au AFTER UPDATE ON medicament_summary BEGIN
    INSERT INTO search_index(
        cis_code,
        molecule_name,
        brand_name
    ) VALUES (
        new.cis_code,
        new.nom_canonique,
        new.princeps_de_reference
    );
END;

-- Insert test data
-- Laboratories
INSERT OR IGNORE INTO laboratories (id, name) VALUES
    (1, 'SANOFI'),
    (2, 'BIOGARAN'),
    (3, 'PFIZER'),
    (4, 'MERCK');

-- Clusters
INSERT OR IGNORE INTO cluster_names (cluster_id, cluster_name, substance_code) VALUES
    ('PARACETAMOL', 'Paracétamol', 'Paracétamol'),
    ('IBUPROFEN', 'Ibuprofène', 'Ibuprofène');

-- Medicament summaries
INSERT OR REPLACE INTO medicament_summary (
    cis_code,
    nom_canonique,
    princeps_de_reference,
    is_princeps,
    cluster_id,
    principes_actifs_communs,
    formatted_dosage,
    forme_pharmaceutique,
    member_type,
    princeps_brand_name,
    procedure_type,
    titulaire_id,
    is_otc,
    representative_cip
) VALUES
    (
        'CIS_DOLIPRANE_500',
        'Doliprane 500mg',
        'Doliprane 500mg',
        1,
        'PARACETAMOL',
        '["Paracétamol"]',
        '500 mg',
        'Comprimé',
        0,
        'Doliprane 500mg',
        'Autorisation',
        1,
        1,
        '3400930012345'
    ),
    (
        'CIS_PARA_BIO_500',
        'Paracétamol Biogaran 500mg',
        'Doliprane 500mg',
        0,
        'PARACETAMOL',
        '["Paracétamol"]',
        '500 mg',
        'Comprimé',
        1,
        'Doliprane 500mg',
        'Autorisation',
        2,
        1,
        '3400935432109'
    ),
    (
        'CIS_ADVIL_200',
        'Advil 200mg',
        'Advil 200mg',
        1,
        'IBUPROFEN',
        '["Ibuprofène"]',
        '200 mg',
        'Gélule',
        0,
        'Advil 200mg',
        'Autorisation',
        3,
        1,
        '3400931111111'
    ),
    (
        'CIS_VITAMIN_C',
        'Vitamine C 500mg',
        'Vitamine C 500mg',
        1,
        NULL,
        '["Acide ascorbique"]',
        '500 mg',
        'Comprimé à croquer',
        0,
        'Vitamine C 500mg',
        'Autorisation',
        4,
        1,
        '3400937777777'
    );