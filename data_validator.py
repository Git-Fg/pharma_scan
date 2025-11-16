# data_validator.py
import os
import csv
import sys
from collections import Counter
from datetime import datetime

import pandas as pd  # pyright: ignore[reportMissingImports]
import requests  # pyright: ignore[reportMissingModuleSource]

# --- Configuration ---
DATA_DIR = "data_validation"
REPORT_FILE = os.path.join(DATA_DIR, "rapport_final.txt")

# Define schema and data types for robust parsing
DATA_FILES_CONFIG = {
    "CIS_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt",
        "name": "Spécialités",
        "columns": [
            "cis", "nom_specialite", "forme_pharmaceutique", "voies_admin",
            "statut_amm", "type_amm", "etat_commercialisation", "date_amm",
            "statut_bdm", "num_autorisation_eu", "titulaires", "surveillance_renforcee"
        ],
        "dtype": {"cis": str},
        "date_columns": ["date_amm"]
    },
    "CIS_CIP_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt",
        "name": "Présentations",
        "columns": [
            "cis", "cip7", "libelle_presentation", "statut_admin",
            "etat_commercialisation_declare", "date_declaration", "cip13",
            "agrement_collectivites", "taux_remboursement", "prix_medicament",
            "indications_remboursement", "dummy_1", "dummy_2" # Undocumented columns
        ],
        "dtype": {"cis": str, "cip7": str, "cip13": str}
    },
    "CIS_COMPO_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt",
        "name": "Compositions",
        "columns": [
            "cis", "designation_element", "code_substance",
            "denomination_substance", "dosage_substance", "reference_dosage",
            "nature_composant", "num_liaison"
        ],
        "dtype": {"cis": str, "code_substance": str}
    },
    "CIS_GENER_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt",
        "name": "Groupes Génériques",
        "columns": [
            "group_id", "libelle_groupe", "cis", "type_generique", "num_tri"
        ],
        "dtype": {"group_id": str, "cis": str}
    }
}

# --- Report Generation ---
class Report:
    def __init__(self, filepath):
        self.filepath = filepath
        self.content = []

    def add_header(self, title, level=1):
        if level == 1:
            self.content.append("\n" + "="*80)
            self.content.append(f"// {title.upper()}")
            self.content.append("="*80)
        elif level == 2:
            self.content.append("\n" + "-"*60)
            self.content.append(f"// {title}")
            self.content.append("-"*60)
        else:
            self.content.append(f"\n### {title}")

    def add_line(self, text):
        self.content.append(str(text))

    def add_list(self, items):
        for item in items:
            self.content.append(f"  - {item}")

    def add_df_info(self, df, name):
        self.add_line(f"  - Fichier: {name}")
        self.add_line(f"  - Lignes chargées: {len(df)}")
        if df.empty:
            self.add_line("  - Statut: ÉCHEC - Aucune donnée chargée.")
        else:
            self.add_line("  - Statut: OK")

    def save(self):
        with open(self.filepath, "w", encoding="utf-8") as f:
            f.write("\n".join(self.content))
        print(f"\n✅ Rapport final généré : {self.filepath}")

# --- Data Loading and Validation ---
def download_file(filename, url):
    filepath = os.path.join(DATA_DIR, filename)
    if os.path.exists(filepath):
        print(f"'{filename}' existe déjà. Téléchargement ignoré.")
        return
    print(f"Téléchargement de '{filename}'...")
    try:
        response = requests.get(url, timeout=60)
        response.raise_for_status()
        with open(filepath, 'wb') as f:
            f.write(response.content)
        print(f"'{filename}' téléchargé avec succès.")
    except requests.RequestException as e:
        print(f"❌ Erreur de téléchargement pour '{filename}': {e}", file=sys.stderr)
        sys.exit(1)

def load_data(report):
    report.add_header("1. Chargement et Validation Structurelle des Données")
    dataframes = {}
    all_files_ok = True

    for filename, config in DATA_FILES_CONFIG.items():
        filepath = os.path.join(DATA_DIR, filename)
        try:
            df = pd.read_csv(
                filepath,
                sep='\t',
                header=None,
                names=config["columns"],
                dtype=config.get("dtype", None),
                encoding='latin-1',
                quoting=csv.QUOTE_NONE
            )
            dataframes[filename] = df
            report.add_df_info(df, filename)
        except Exception as e:
            report.add_line(f"❌ Échec du chargement de {filename}: {e}")
            all_files_ok = False

    if not all_files_ok:
        report.add_line("\nCRITIQUE: Un ou plusieurs fichiers n'ont pas pu être chargés. L'analyse ne peut continuer.")
        report.save()
        sys.exit(1)
        
    return dataframes

def analyze_column_values(report, dataframes):
    report.add_header("2. Analyse des Valeurs Uniques et des Formats")
    for filename, df in dataframes.items():
        config = DATA_FILES_CONFIG[filename]
        report.add_header(f"Fichier : {filename}", level=2)

        # Date validation
        if "date_columns" in config:
            for col in config["date_columns"]:
                errors = pd.to_datetime(df[col], format='%d/%m/%Y', errors='coerce').isna().sum()
                total = len(df)
                report.add_line(f"Validation colonne date '{col}': {total - errors}/{total} lignes valides (format JJ/MM/AAAA).")

        # Generic types
        if filename == "CIS_GENER_bdpm.txt":
            unique_types = df["type_generique"].unique()
            report.add_line(f"Types de génériques trouvés : {sorted([t for t in unique_types if pd.notna(t)])}")
            if not {0, 1, 2, 4}.issubset(set(unique_types)):
                report.add_line("  - AVERTISSEMENT: Tous les types attendus (0, 1, 2, 4) ne sont pas présents.")

        # Component nature
        if filename == "CIS_COMPO_bdpm.txt":
            unique_natures = df["nature_composant"].unique()
            report.add_line(f"Natures de composant trouvées : {sorted([n for n in unique_natures if pd.notna(n)])}")
            if 'SA' not in unique_natures:
                report.add_line("  - AVERTISSEMENT: La nature 'SA' (Substance Active) est manquante.")
            
            # Dosage unit analysis
            dosages = df['dosage_substance'].dropna().astype(str)
            units = dosages.str.extract(r'\s([a-zA-Z%].*)').iloc[:, 0].dropna().unique()
            report.add_line(f"Unités de dosage uniques trouvées : {sorted(list(units))}")

def verify_relational_integrity(report, dfs):
    report.add_header("3. Vérification de l'Intégrité Relationnelle")

    # CIS_CIP -> CIS
    cis_set = set(dfs["CIS_bdpm.txt"]["cis"])
    orphans_cip = dfs["CIS_CIP_bdpm.txt"][~dfs["CIS_CIP_bdpm.txt"]["cis"].isin(cis_set)]
    report.add_line(f"CIS_CIP_bdpm -> CIS_bdpm: {len(orphans_cip)} CIS orphelins sur {len(dfs['CIS_CIP_bdpm.txt'])} ({len(orphans_cip)/len(dfs['CIS_CIP_bdpm.txt']):.2%})")

    # CIS_COMPO -> CIS
    orphans_compo = dfs["CIS_COMPO_bdpm.txt"][~dfs["CIS_COMPO_bdpm.txt"]["cis"].isin(cis_set)]
    report.add_line(f"CIS_COMPO_bdpm -> CIS_bdpm: {len(orphans_compo)} CIS orphelins sur {len(dfs['CIS_COMPO_bdpm.txt'])} ({len(orphans_compo)/len(dfs['CIS_COMPO_bdpm.txt']):.2%})")

    # CIS_GENER -> CIS
    orphans_gener = dfs["CIS_GENER_bdpm.txt"][~dfs["CIS_GENER_bdpm.txt"]["cis"].isin(cis_set)]
    report.add_line(f"CIS_GENER_bdpm -> CIS_bdpm: {len(orphans_gener)} CIS orphelins sur {len(dfs['CIS_GENER_bdpm.txt'])} ({len(orphans_gener)/len(dfs['CIS_GENER_bdpm.txt']):.2%})")

def validate_business_logic(report, dfs):
    report.add_header("4. Validation de la Logique Métier et Cas Limites")

    # Merge data for comprehensive analysis
    compo = dfs["CIS_COMPO_bdpm.txt"][dfs["CIS_COMPO_bdpm.txt"]["nature_composant"] == 'SA']
    gener = dfs["CIS_GENER_bdpm.txt"]
    
    merged_df = pd.merge(gener, compo, on="cis", how="left")

    # Test 1: Active ingredient consistency within groups
    report.add_header("Cohérence des principes actifs dans les groupes génériques", level=2)
    
    group_pa_sets = merged_df.groupby('group_id')['denomination_substance'].apply(lambda x: frozenset(x.dropna())).reset_index()
    inconsistent_groups = group_pa_sets.groupby('group_id')['denomination_substance'].nunique().pipe(lambda s: s[s > 1])
    
    report.add_line(f"Nombre de groupes avec des principes actifs inconsistants : {len(inconsistent_groups)}")
    if not inconsistent_groups.empty:
        report.add_line("  - AVERTISSEMENT: Des groupes contiennent des médicaments avec des compositions différentes.")
        report.add_list(inconsistent_groups.head().index.tolist())

    # Test 2: Groups without princeps or generics
    report.add_header("Analyse de la composition des groupes", level=2)
    group_types = gener.groupby('group_id')['type_generique'].apply(set).reset_index()
    
    groups_no_princeps = group_types[~group_types['type_generique'].apply(lambda x: 0 in x)]
    report.add_line(f"Groupes sans aucun princeps (type 0) : {len(groups_no_princeps)}")
    
    groups_only_princeps = group_types[group_types['type_generique'].apply(lambda x: x == {0})]
    report.add_line(f"Groupes avec uniquement des princeps : {len(groups_only_princeps)}")

    # Test 3: Medications without active principles
    report.add_header("Couverture des principes actifs", level=2)
    cip_with_pa = set(compo["cis"])
    all_cis = set(dfs["CIS_bdpm.txt"]["cis"])
    cis_without_pa = all_cis - cip_with_pa
    report.add_line(f"Spécialités (CIS) sans principe actif ('SA') listé : {len(cis_without_pa)} / {len(all_cis)} ({len(cis_without_pa)/len(all_cis):.2%})")

    # Test 4: Analysis of multi-component medications
    report.add_header("Analyse des médicaments composés", level=2)
    pa_counts = compo.groupby('cis')['denomination_substance'].nunique().value_counts().sort_index()
    report.add_line("Distribution des spécialités par nombre de principes actifs :")
    for count, num_meds in pa_counts.items():
        report.add_line(f"  - {count} principe(s) actif(s) : {num_meds} médicaments")

# --- Main Execution ---
def main():
    print("--- Script de Validation des Données PharmaScan (Avancé) ---")
    
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)

    report = Report(REPORT_FILE)
    report.add_header(f"Rapport de Validation des Données - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    print("\nÉtape 1: Téléchargement des fichiers de données...")
    for filename, config in DATA_FILES_CONFIG.items():
        download_file(filename, config['url'])

    print("\nÉtape 2: Chargement des données en mémoire...")
    dataframes = load_data(report)

    print("Étape 3: Analyse des colonnes et formats...")
    analyze_column_values(report, dataframes)

    print("Étape 4: Vérification de l'intégrité relationnelle...")
    verify_relational_integrity(report, dataframes)
    
    print("Étape 5: Validation de la logique métier...")
    validate_business_logic(report, dataframes)

    report.save()

if __name__ == "__main__":
    main()