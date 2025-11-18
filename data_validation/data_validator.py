# data_validator.py
import os
import csv
import sys
import random
import re
from collections import Counter
from datetime import datetime

import pandas as pd  # pyright: ignore[reportMissingImports]
import requests  # pyright: ignore[reportMissingModuleSource]

# --- Related Princeps Finder Function ---
def find_related_princeps(target_group_id, dfs):
    """
    Finds related princeps (from other groups) that share the same active principle(s)
    as the target group. This validates the logic for finding "princeps associés".
    
    Logic:
    1. Identify common active principle(s) of the target group
    2. Find all princeps (type_generique == 0) that share these principles
    3. Exclude princeps already in the target group
    """
    print("\n" + "="*80)
    print(f"// RELATED PRINCEPS ANALYSIS: Group ID '{target_group_id}'")
    print("="*80)
    
    gener = dfs["CIS_GENER_bdpm.txt"]
    compo = dfs["CIS_COMPO_bdpm.txt"][dfs["CIS_COMPO_bdpm.txt"]["nature_composant"] == 'SA']
    specialites = dfs["CIS_bdpm.txt"]
    
    # Step A: Identify active principles of the target group
    target_group_cis = set(gener[gener['group_id'] == target_group_id]['cis'].unique())
    target_group_compo = compo[compo['cis'].isin(target_group_cis)]
    common_principes = set(target_group_compo['denomination_substance'].dropna().unique())
    
    if len(common_principes) == 0:
        print(f"❌ No active principles found for group {target_group_id}")
        print("="*80)
        return
    
    print(f"\n✅ Common active principle(s) of target group:")
    for principe in sorted(common_principes):
        print(f"  - {principe}")
    
    # Step B: Find all princeps (type 0) in the database
    all_princeps = gener[gener['type_generique'] == 0]
    
    # Step C: Find princeps that share the same active principles
    related_princeps = []
    for _, princeps_row in all_princeps.iterrows():
        princeps_cis = princeps_row['cis']
        princeps_group_id = princeps_row['group_id']
        
        # Skip if already in target group
        if princeps_group_id == target_group_id:
            continue
        
        # Check if this princeps has any of the common principles
        princeps_compo = compo[compo['cis'] == princeps_cis]
        princeps_principes = set(princeps_compo['denomination_substance'].dropna().unique())
        
        # If there's any intersection, it's a related princeps
        if common_principes & princeps_principes:
            # Get medication details
            spec_row = specialites[specialites['cis'] == princeps_cis]
            if len(spec_row) > 0:
                nom = spec_row.iloc[0]['nom_specialite'] if pd.notna(spec_row.iloc[0]['nom_specialite']) else "N/A"
                titulaire = spec_row.iloc[0]['titulaires'] if pd.notna(spec_row.iloc[0]['titulaires']) else "N/A"
                
                # Get dosage info
                dosage_info = princeps_compo['dosage_substance'].dropna().unique()
                dosage_str = ', '.join(dosage_info[:3]) if len(dosage_info) > 0 else "N/A"
                if len(dosage_info) > 3:
                    dosage_str += f" ... (+{len(dosage_info) - 3} autres)"
                
                related_princeps.append({
                    'group_id': princeps_group_id,
                    'cis': princeps_cis,
                    'nom': nom,
                    'titulaire': titulaire,
                    'dosage': dosage_str,
                    'shared_principles': sorted(list(common_principes & princeps_principes))
                })
    
    # Step D: Display results
    print(f"\n✅ Related Princeps Found: {len(related_princeps)}")
    if len(related_princeps) > 0:
        print("\nRelated Princeps (from other groups sharing the same active principle(s)):")
        for i, rp in enumerate(related_princeps[:20], 1):  # Limit to first 20 for readability
            print(f"\n  [{i}] {rp['nom']}")
            print(f"      Group ID: {rp['group_id']}")
            print(f"      CIS: {rp['cis']}")
            print(f"      Laboratory: {rp['titulaire']}")
            print(f"      Dosage: {rp['dosage']}")
            print(f"      Shared Principles: {', '.join(rp['shared_principles'])}")
        
        if len(related_princeps) > 20:
            print(f"\n  ... and {len(related_princeps) - 20} more related princeps")
    else:
        print("  No related princeps found (all princeps with these principles are in the target group)")
    
    print("="*80)
    return related_princeps

# --- Test Data Lookup Function ---
def find_test_data(query, dfs):
    """
    Searches for a medication and prints its data for integration tests.
    Use this function to find real, current data for building test cases.
    """
    print("\n" + "="*80)
    print(f"// CUSTOM LOOKUP: Searching for test data for query: '{query}'")
    print("="*80)

    # 1. Merge all data sources into a master DataFrame
    specialites = dfs["CIS_bdpm.txt"]
    presentations = dfs["CIS_CIP_bdpm.txt"]
    compositions = dfs["CIS_COMPO_bdpm.txt"][dfs["CIS_COMPO_bdpm.txt"]["nature_composant"] == 'SA']
    generiques = dfs["CIS_GENER_bdpm.txt"]
    
    master_df = pd.merge(specialites, presentations, on='cis', how='left')
    master_df = pd.merge(master_df, compositions, on='cis', how='left')
    master_df = pd.merge(master_df, generiques, on='cis', how='left')

    # 2. Perform the search
    query_lower = str(query).lower()
    mask = (
        master_df['nom_specialite'].str.lower().str.contains(query_lower, na=False) |
        master_df['cip13'].str.contains(query_lower, na=False) |
        master_df['denomination_substance'].str.lower().str.contains(query_lower, na=False)
    )
    results = master_df[mask].drop_duplicates(subset=['cip13'])
    
    if results.empty:
        print("❌ No medication found for the query.")
        print("="*80)
        return

    # 3. Use the first result as the target
    target_row = results.iloc[0]
    target_cip = target_row['cip13']
    target_cis = target_row['cis']
    group_id = target_row['group_id']
    
    print(f"✅ Found best match: '{target_row['nom_specialite']}' (CIP: {target_cip}, CIS: {target_cis})\n")

    # 4. Extract all relevant information
    # Active Principles for the target CIP
    active_principles = master_df[master_df['cip13'] == target_cip]['denomination_substance'].dropna().unique().tolist()
    
    # Laboratory (titulaire)
    titulaire = target_row['titulaires'] if pd.notna(target_row['titulaires']) else "N/A"
    
    # Group Information
    if pd.isna(group_id):
        print("- Type: STANDALONE (No generic group)")
        print(f"- CIP: {target_cip}")
        print(f"- CIS: {target_cis}")
        print(f"- Name: {target_row['nom_specialite']}")
        print(f"- Laboratory: {titulaire}")
        print(f"- Active Principles: {active_principles}")
    else:
        group_df = master_df[master_df['group_id'] == group_id]
        target_type = int(target_row['type_generique']) if pd.notna(target_row['type_generique']) else None

        if target_type in [1, 2, 4]:  # Generic
            princeps_df = group_df[group_df['type_generique'] == 0]
            associated_names = princeps_df['nom_specialite'].dropna().unique().tolist()
            print("- Type: GENERIC")
            print(f"- CIP: {target_cip}")
            print(f"- CIS: {target_cis}")
            print(f"- Name: {target_row['nom_specialite']}")
            print(f"- Laboratory: {titulaire}")
            print(f"- Active Principles: {active_principles}")
            print(f"- Group ID: {group_id}")
            print(f"- Associated Princeps ({len(associated_names)}):")
            for name in associated_names[:5]:  # Limit to first 5 for readability
                print(f"  - {name}")
            if len(associated_names) > 5:
                print(f"  ... and {len(associated_names) - 5} more")

        elif target_type == 0:  # Princeps
            generics_df = group_df[group_df['type_generique'].isin([1, 2, 4])]
            associated_labs = generics_df['titulaires'].dropna().unique().tolist()
            associated_names = generics_df['nom_specialite'].dropna().unique().tolist()
            print("- Type: PRINCEPS")
            print(f"- CIP: {target_cip}")
            print(f"- CIS: {target_cis}")
            print(f"- Name: {target_row['nom_specialite']}")
            print(f"- Laboratory: {titulaire}")
            print(f"- Active Principles: {active_principles}")
            print(f"- Group ID: {group_id}")
            print(f"- Associated Generic Medications ({len(associated_names)}):")
            for name in associated_names[:5]:  # Limit to first 5 for readability
                print(f"  - {name}")
            if len(associated_names) > 5:
                print(f"  ... and {len(associated_names) - 5} more")
            print(f"- Associated Generic Labs ({len(associated_labs)}):")
            for lab in associated_labs[:5]:  # Limit to first 5 for readability
                print(f"  - {lab}")
            if len(associated_labs) > 5:
                print(f"  ... and {len(associated_labs) - 5} more")
    
    print("="*80)

# --- Configuration ---
DATA_DIR = "data_validation"
REPORT_FILE = os.path.join(DATA_DIR, "rapport_final.txt")

# Test Data Lookup Configuration
# Set to None to disable, or provide a search query (medication name, CIP code, or active principle)
TEST_DATA_LOOKUP_QUERY = None  # Example: 'baclofene biogaran 10' or '3400930302613'

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

def sample_random_lines(filepath, num_lines=8):
    """Read random complete lines from a file for visual inspection."""
    try:
        with open(filepath, 'r', encoding='latin-1', errors='ignore') as f:
            lines = [line.rstrip('\n') for line in f if line.strip()]
        
        if len(lines) == 0:
            return []
        
        sample_size = min(num_lines, len(lines))
        return random.sample(lines, sample_size)
    except Exception as e:
        return [f"Erreur lors de la lecture: {e}"]

def check_duplicate_primary_keys(report, dataframes):
    """Check for duplicate primary keys in each file."""
    report.add_header("Détection des Clés Primaires Dupliquées", level=2)
    
    primary_keys = {
        "CIS_bdpm.txt": "cis",
        "CIS_CIP_bdpm.txt": "cip13",
        "CIS_COMPO_bdpm.txt": None,  # No single primary key
        "CIS_GENER_bdpm.txt": None,  # Composite key (group_id, cis)
    }
    
    for filename, pk_column in primary_keys.items():
        if pk_column is None:
            continue
        
        if filename not in dataframes:
            continue
            
        df = dataframes[filename]
        duplicates = df[df[pk_column].duplicated(keep=False)]
        
        if len(duplicates) > 0:
            unique_duplicates = duplicates[pk_column].nunique()
            report.add_line(f"❌ {filename}: {unique_duplicates} valeurs dupliquées dans '{pk_column}' ({len(duplicates)} lignes affectées)")
            # Show first few examples
            example_dups = duplicates[pk_column].value_counts().head(3)
            for dup_val, count in example_dups.items():
                report.add_line(f"    Exemple: '{dup_val}' apparaît {count} fois")
        else:
            report.add_line(f"✅ {filename}: Aucune duplication dans '{pk_column}'")

def audit_character_encoding(report, dataframes):
    """Audit text columns for non-standard characters."""
    report.add_header("Audit d'Encodage des Caractères", level=2)
    
    text_columns = {
        "CIS_bdpm.txt": ["nom_specialite", "titulaires"],
        "CIS_CIP_bdpm.txt": ["libelle_presentation"],
        "CIS_COMPO_bdpm.txt": ["denomination_substance"],
        "CIS_GENER_bdpm.txt": ["libelle_groupe"],
    }
    
    for filename, columns in text_columns.items():
        if filename not in dataframes:
            continue
            
        df = dataframes[filename]
        report.add_line(f"\nFichier: {filename}")
        
        for col in columns:
            if col not in df.columns:
                continue
            
            # Sample 1000 rows for analysis
            sample = df[col].dropna().astype(str).head(1000)
            non_ascii_count = 0
            non_latin1_count = 0
            
            for text in sample:
                try:
                    text.encode('ascii')
                except UnicodeEncodeError:
                    non_ascii_count += 1
                    try:
                        text.encode('latin-1')
                    except UnicodeEncodeError:
                        non_latin1_count += 1
            
            report.add_line(f"  Colonne '{col}':")
            report.add_line(f"    - Échantillon analysé: {len(sample)} lignes")
            report.add_line(f"    - Caractères non-ASCII: {non_ascii_count} ({non_ascii_count/len(sample)*100:.1f}%)")
            report.add_line(f"    - Caractères non-latin1: {non_latin1_count} ({non_latin1_count/len(sample)*100:.1f}%)")
            
            if non_latin1_count > 0:
                report.add_line(f"    ⚠️  AVERTISSEMENT: Des caractères non-latin1 détectés. Le fallback UTF-8 peut être nécessaire.")

def parse_dosage_dart_logic(dosage_str):
    """
    Simulate the exact Dart parsing logic from DataInitializationService:
    dosageParts = dosageStr.split(' ')
    dosageValue = double.tryParse(dosageParts[0].replaceAll(',', '.'))
    """
    if pd.isna(dosage_str) or not dosage_str or str(dosage_str).strip() == '':
        return None, None
    
    dosage_str = str(dosage_str).strip()
    dosage_parts = dosage_str.split(' ')
    
    if len(dosage_parts) == 0:
        return None, None
    
    # Simulate: dosageParts[0].replaceAll(',', '.')
    numeric_part = dosage_parts[0].replace(',', '.')
    
    # Simulate: double.tryParse(...)
    try:
        dosage_value = float(numeric_part)
    except (ValueError, TypeError):
        return None, None
    
    # Extract unit if present
    dosage_unit = ' '.join(dosage_parts[1:]) if len(dosage_parts) > 1 else None
    
    return dosage_value, dosage_unit

def stress_test_dosage_parsing(report, dataframes):
    """Stress test the Dart dosage parsing logic against all data."""
    report.add_header("Test de Stress: Parsing des Dosages (Logique Dart)", level=2)
    
    if "CIS_COMPO_bdpm.txt" not in dataframes:
        return
    
    df = dataframes["CIS_COMPO_bdpm.txt"]
    dosages = df['dosage_substance'].dropna()
    
    total = len(dosages)
    successful = 0
    failed = []
    
    for dosage_str in dosages:
        dosage_value, _ = parse_dosage_dart_logic(dosage_str)
        if dosage_value is not None:
            successful += 1
        else:
            failed.append(dosage_str)
    
    success_rate = (successful / total * 100) if total > 0 else 0
    report.add_line(f"Total des dosages analysés: {total}")
    report.add_line(f"Parsing réussi: {successful} ({success_rate:.2f}%)")
    report.add_line(f"Parsing échoué: {len(failed)} ({100-success_rate:.2f}%)")
    
    if len(failed) > 0:
        # Get unique failed examples
        unique_failed = list(set(failed))[:20]  # Top 20 unique failures
        report.add_line(f"\nExemples de dosages qui ont échoué (échantillon de {len(unique_failed)}):")
        for example in sorted(unique_failed):
            report.add_line(f"  - '{example}'")
        
        if len(unique_failed) < len(set(failed)):
            report.add_line(f"  ... et {len(set(failed)) - len(unique_failed)} autres formats uniques")

def analyze_titulaire_cleanliness(report, dataframes):
    """Analyze the titulaires column for data quality issues."""
    report.add_header("Analyse de Propreté: Colonne Titulaires", level=2)
    
    if "CIS_bdpm.txt" not in dataframes:
        return
    
    df = dataframes["CIS_bdpm.txt"]
    titulaires = df['titulaires']
    
    total = len(titulaires)
    empty = titulaires.isna().sum() + (titulaires == '').sum()
    non_empty = total - empty
    
    report.add_line(f"Total des lignes: {total}")
    report.add_line(f"Titulaires vides/null: {empty} ({empty/total*100:.2f}%)")
    report.add_line(f"Titulaires renseignés: {non_empty} ({non_empty/total*100:.2f}%)")
    
    # Check for potential separators indicating multiple holders
    potential_separators = [';', '/', '|', ',', ' et ', ' ET ']
    separator_counts = {}
    
    for sep in potential_separators:
        count = titulaires.astype(str).str.contains(sep, regex=False, na=False).sum()
        if count > 0:
            separator_counts[sep] = count
    
    if separator_counts:
        report.add_line(f"\n⚠️  Caractères séparateurs potentiels détectés:")
        for sep, count in sorted(separator_counts.items(), key=lambda x: x[1], reverse=True):
            report.add_line(f"  - '{sep}': {count} occurrences ({count/non_empty*100:.2f}% des titulaires renseignés)")
            # Show examples
            examples = titulaires[titulaires.astype(str).str.contains(sep, regex=False, na=False)].head(3)
            for ex in examples:
                report.add_line(f"    Exemple: '{ex}'")
    else:
        report.add_line(f"\n✅ Aucun séparateur suspect détecté. Les données semblent propres.")

def detect_chameleon_medications(report, dataframes):
    """Detect medications listed as both princeps and generic in different groups."""
    report.add_header("Détection des Médicaments 'Caméléon'", level=2)
    
    if "CIS_GENER_bdpm.txt" not in dataframes:
        return
    
    gener = dataframes["CIS_GENER_bdpm.txt"]
    
    # Group by CIS and collect all types
    cis_types = gener.groupby('cis')['type_generique'].apply(set).reset_index()
    
    chameleons = []
    for _, row in cis_types.iterrows():
        cis = row['cis']
        types = row['type_generique']
        
        # Check if CIS is both princeps (0) and generic (1, 2, or 4)
        is_princeps = 0 in types
        is_generic = bool(types & {1, 2, 4})
        
        if is_princeps and is_generic:
            chameleons.append({
                'cis': cis,
                'types': sorted(list(types)),
                'groups': gener[gener['cis'] == cis]['group_id'].unique().tolist()
            })
    
    if len(chameleons) > 0:
        report.add_line(f"❌ CRITIQUE: {len(chameleons)} médicament(s) listé(s) comme princeps ET générique dans différents groupes:")
        for chameleon in chameleons[:10]:  # Show first 10
            report.add_line(f"  - CIS {chameleon['cis']}: types {chameleon['types']} dans {len(chameleon['groups'])} groupe(s)")
            report.add_line(f"    Groupes: {', '.join(chameleon['groups'][:5])}")
            if len(chameleon['groups']) > 5:
                report.add_line(f"    ... et {len(chameleon['groups']) - 5} autres")
        
        if len(chameleons) > 10:
            report.add_line(f"  ... et {len(chameleons) - 10} autres médicaments caméléons")
    else:
        report.add_line(f"✅ Aucun médicament caméléon détecté. Chaque médicament a un rôle unique dans le système générique.")

def analyze_orphan_groups(report, dataframes):
    """Enhanced analysis: groups where ALL members are orphans."""
    report.add_header("Analyse Avancée: Groupes Orphelins", level=2)
    
    if "CIS_GENER_bdpm.txt" not in dataframes or "CIS_bdpm.txt" not in dataframes:
        return
    
    gener = dataframes["CIS_GENER_bdpm.txt"]
    cis_set = set(dataframes["CIS_bdpm.txt"]["cis"])
    
    # Find orphan CIS codes
    orphan_cis = set(gener[~gener['cis'].isin(cis_set)]['cis'])
    
    # Group by group_id and check if ALL members are orphans
    group_members = gener.groupby('group_id')['cis'].apply(set).reset_index()
    
    fully_orphan_groups = []
    partially_orphan_groups = []
    
    for _, row in group_members.iterrows():
        group_id = row['group_id']
        members = row['cis']
        
        orphan_members = members & orphan_cis
        valid_members = members - orphan_cis
        
        if len(orphan_members) == len(members) and len(members) > 0:
            # All members are orphans
            fully_orphan_groups.append({
                'group_id': group_id,
                'member_count': len(members)
            })
        elif len(orphan_members) > 0:
            # Some members are orphans
            partially_orphan_groups.append({
                'group_id': group_id,
                'orphan_count': len(orphan_members),
                'valid_count': len(valid_members),
                'total': len(members)
            })
    
    report.add_line(f"Groupes où TOUS les membres sont orphelins: {len(fully_orphan_groups)}")
    if len(fully_orphan_groups) > 0:
        total_ghost_members = sum(g['member_count'] for g in fully_orphan_groups)
        report.add_line(f"  - Total de membres 'fantômes': {total_ghost_members}")
        report.add_line(f"  - Exemples de groupes fantômes (premiers 5):")
        for group in fully_orphan_groups[:5]:
            report.add_line(f"    - Groupe {group['group_id']}: {group['member_count']} membre(s) orphelin(s)")
    
    report.add_line(f"\nGroupes avec des membres partiellement orphelins: {len(partially_orphan_groups)}")
    if len(partially_orphan_groups) > 0:
        total_partial_orphans = sum(g['orphan_count'] for g in partially_orphan_groups)
        report.add_line(f"  - Total de membres orphelins dans ces groupes: {total_partial_orphans}")
        report.add_line(f"  - Exemples (premiers 5):")
        for group in partially_orphan_groups[:5]:
            report.add_line(f"    - Groupe {group['group_id']}: {group['orphan_count']}/{group['total']} orphelins, {group['valid_count']} valides")

def load_data(report):
    report.add_header("1. Chargement et Validation Structurelle des Données")
    dataframes = {}
    all_files_ok = True

    for filename, config in DATA_FILES_CONFIG.items():
        filepath = os.path.join(DATA_DIR, filename)
        try:
            # Sample random lines before loading
            report.add_header(f"Échantillon de Lignes: {filename}", level=3)
            sample_lines = sample_random_lines(filepath, num_lines=8)
            if sample_lines:
                report.add_line(f"  {len(sample_lines)} lignes aléatoires (pour inspection visuelle):")
                for i, line in enumerate(sample_lines[:8], 1):
                    # Truncate very long lines for readability
                    display_line = line[:200] + "..." if len(line) > 200 else line
                    report.add_line(f"    [{i}] {display_line}")
            else:
                report.add_line(f"  Impossible de lire des échantillons de lignes.")
            
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
    
    # Enhanced orphan groups analysis
    analyze_orphan_groups(report, dfs)

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

def analyze_pharmaceutical_forms(report, dataframes):
    """Analyze pharmaceutical forms and validate the Dart categorization logic."""
    report.add_header("Analyse et Validation de la Catégorisation des Formes Pharmaceutiques", level=2)
    
    if "CIS_bdpm.txt" not in dataframes:
        report.add_line("❌ Fichier CIS_bdpm.txt manquant. Impossible d'analyser les formes.")
        return
    
    df = dataframes["CIS_bdpm.txt"]
    unique_forms = df['forme_pharmaceutique'].dropna().unique()

    report.add_line(f"Total des formes pharmaceutiques uniques trouvées : {len(unique_forms)}")

    # --- REPLICATE DART LOGIC ---
    # 1. Define Categories and Keywords exactly as in the app
    categories = {
        'injectable': ['injectable', 'injection', 'perfusion', 'solution pour perfusion', 'poudre pour solution injectable', 'solution pour injection', 'dispersion pour perfusion', 'usage parentéral', 'parentéral', 'poudre et solvant', 'générateur radiopharmaceutique', 'précurseur radiopharmaceutique', 'solution pour dialyse', 'solution pour hémofiltration', 'solution pour instillation', 'solution cardioplégique', 'solution pour administration intravésicale', 'suspension pour instillation'],
        'gynecological': ['ovule', 'pessaire', 'comprimé vaginal', 'crème vaginale', 'gel vaginal', 'capsule vaginale', 'tampon vaginal', 'anneau vaginal'],
        'externalUse': ['crème', 'pommade', 'gel', 'lotion', 'pâte', 'cutanée', 'cutané', 'application locale', 'application cutanée', 'dispositif transdermique', 'patch', 'patchs', 'emplâtre', 'compresse', 'bâton pour application', 'mousse pour application', 'mousse', 'pansement', 'implant', 'shampooing', 'solution filmogène pour application', 'dispositif pour application', 'solution pour application', 'solution moussant', 'solution pour lavage', 'suppositoire'],
        'sachet': ['sachet', 'poudre pour solution buvable', 'poudre pour suspension buvable', 'granulé', 'granules', 'granulés', 'poudre'],
        'oral': ['comprimé', 'gélule', 'capsule', 'lyophilisat', 'comprimé orodispersible', 'film orodispersible', 'gomme', 'gomme à mâcher', 'pastille', 'pastille à sucer', 'plante pour tisane', 'plantes pour tisane', 'plante(s) pour tisane', 'mélange de plantes pour tisane', 'plante en vrac'],
        'syrup': ['sirop', 'suspension buvable'],
        'drinkableDrops': ['solution buvable', 'gouttes buvables', 'solution en gouttes', 'solution gouttes'],
        'ophthalmic': ['collyre', 'ophtalmique', 'solution ophtalmique', 'pommade ophtalmique', 'gel ophtalmique', 'solution pour irrigation oculaire'],
        'nasalOrl': ['nasale', 'auriculaire', 'buccale', 'aérosol', 'spray nasal', 'gouttes nasales', 'gouttes auriculaires', 'bain de bouche', 'collutoire', 'gaz pour inhalation', 'gaz', 'cartouche pour inhalation', 'dispersion pour inhalation', 'inhalation', 'insert', 'solution pour pulvérisation'],
    }

    exclusions = {
        'injectable': [],
        'gynecological': [],
        'externalUse': ['vaginal', 'vaginale'],
        'sachet': ['injectable', 'injection', 'parentéral', 'solvant'],
        'oral': ['buvable', 'solution', 'suspension'],
        'syrup': [],
        'drinkableDrops': [],
        'ophthalmic': [],
        'nasalOrl': [],
    }

    # 2. Classification Logic with Priority
    categorized_forms = {cat: [] for cat in categories}
    unclassified_forms = []
    ambiguous_forms = []
    
    for form in unique_forms:
        # Normalize multiple spaces to single space for matching
        form_lower = ' '.join(form.lower().split())
        assigned_category = None

        # Priority-based assignment
        # The order here must match the conceptual priority in the app
        # Most specific first: injectable, gynecological, ophthalmic, nasalOrl, externalUse, sachet, syrup, drinkableDrops, oral
        priority_order = ['injectable', 'gynecological', 'ophthalmic', 'nasalOrl', 'externalUse', 'sachet', 'syrup', 'drinkableDrops', 'oral']

        for cat in priority_order:
            # Check for keyword match
            if any(kw in form_lower for kw in categories[cat]):
                # Check for exclusion match
                if not any(excl in form_lower for excl in exclusions.get(cat, [])):
                    assigned_category = cat
                    break  # Stop on first match due to priority
        
        if assigned_category:
            categorized_forms[assigned_category].append(form)
        else:
            unclassified_forms.append(form)
    
        # Check for ambiguity (contains keywords from multiple categories)
        found_cats = {cat for cat, keywords in categories.items() if any(kw in form_lower for kw in keywords)}
        if len(found_cats) > 1:
            ambiguous_forms.append({'form': form, 'categories': sorted(list(found_cats)), 'assigned': assigned_category})

    # --- GENERATE REPORT ---
    report.add_header("1. Couverture de la Catégorisation", level=3)
    total_categorized = sum(len(forms) for forms in categorized_forms.values())
    coverage = (total_categorized / len(unique_forms)) * 100 if len(unique_forms) > 0 else 0
    report.add_line(f"Formes catégorisées : {total_categorized} / {len(unique_forms)} ({coverage:.2f}%)")
    report.add_line(f"Formes non catégorisées : {len(unclassified_forms)}")

    report.add_header("2. Formes Non Catégorisées (Échantillon)", level=3)
    if unclassified_forms:
        report.add_line("  ACTION : Analyser cette liste pour trouver de nouveaux mots-clés à ajouter.")
        for form in sorted(unclassified_forms)[:30]:  # Show first 30
            report.add_line(f"  - {form}")
        if len(unclassified_forms) > 30:
            report.add_line(f"  ... et {len(unclassified_forms) - 30} autres.")
    else:
        report.add_line("✅ Excellente couverture ! Toutes les formes ont été catégorisées.")

    report.add_header("3. Détection d'Ambiguïté (Potentiels Conflits)", level=3)
    if ambiguous_forms:
        report.add_line("  ACTION : Vérifier que la priorité et les exclusions gèrent bien ces cas.")
        for item in ambiguous_forms[:20]:
            report.add_line(f"  - Forme : '{item['form']}'")
            report.add_line(f"    > Mots-clés détectés pour : {item['categories']}")
            report.add_line(f"    > Catégorie assignée (par priorité) : {item['assigned']}")
    else:
        report.add_line("✅ Aucune ambiguïté détectée. Les règles de priorité et d'exclusion sont efficaces.")

    report.add_header("4. Répartition par Catégorie (Échantillon)", level=3)
    for cat, forms in sorted(categorized_forms.items()):
        report.add_line(f"\n--- {cat.upper()} ({len(forms)} formes) ---")
        for form in sorted(forms)[:5]:
            report.add_line(f"  - {form}")
        if len(forms) > 5:
            report.add_line(f"  ... et {len(forms) - 5} autres.")

def investigate_unspecified_groups(report, dataframes):
    """Investigate groups with no specified active principles (Principe non spécifié)."""
    report.add_header("Analyse des Groupes 'Principe non spécifié'", level=2)
    
    if "CIS_GENER_bdpm.txt" not in dataframes or "CIS_COMPO_bdpm.txt" not in dataframes or "CIS_bdpm.txt" not in dataframes:
        return
    
    gener = dataframes["CIS_GENER_bdpm.txt"]
    compo = dataframes["CIS_COMPO_bdpm.txt"][dataframes["CIS_COMPO_bdpm.txt"]["nature_composant"] == 'SA']
    specialites = dataframes["CIS_bdpm.txt"]
    
    # Replicate Flutter SQL logic: find groups where no member has active principles
    # This simulates: SELECT gg.group_id, (SELECT GROUP_CONCAT...) as common_principes
    
    # Get all groups
    all_groups = gener['group_id'].unique()
    
    # For each group, check if it has any active principles
    unspecified_groups = []
    
    for group_id in all_groups:
        # Get all CIS codes in this group
        group_cis = set(gener[gener['group_id'] == group_id]['cis'].unique())
        
        # Check if any of these CIS codes have active principles
        group_cis_with_pa = set(compo[compo['cis'].isin(group_cis)]['cis'].unique())
        
        # If no CIS in the group has active principles, this is an unspecified group
        if len(group_cis_with_pa) == 0:
            unspecified_groups.append({
                'group_id': group_id,
                'member_cis': list(group_cis),
                'member_count': len(group_cis)
            })
    
    report.add_line(f"Trouvé {len(unspecified_groups)} groupes avec aucun principe actif spécifié.")
    
    if len(unspecified_groups) > 0:
        # Perform forensic analysis on first 10 groups
        report.add_line(f"\nAnalyse approfondie des {min(10, len(unspecified_groups))} premiers groupes:")
        
        for i, group_info in enumerate(unspecified_groups[:10]):
            group_id = group_info['group_id']
            member_cis = group_info['member_cis']
            
            report.add_line(f"\nGroupe ID {group_id} ({group_info['member_count']} membre(s)):")
            
            # Analyze first few members
            sample_members = member_cis[:5]
            homeopathic_count = 0
            discontinued_count = 0
            other_count = 0
            
            for cis in sample_members:
                cis_row = specialites[specialites['cis'] == cis]
                if len(cis_row) > 0:
                    nom = cis_row.iloc[0]['nom_specialite'] if pd.notna(cis_row.iloc[0]['nom_specialite']) else "N/A"
                    procedure_type = cis_row.iloc[0]['type_amm'] if pd.notna(cis_row.iloc[0]['type_amm']) else "N/A"
                    etat = cis_row.iloc[0]['etat_commercialisation'] if pd.notna(cis_row.iloc[0]['etat_commercialisation']) else "N/A"
                    
                    # Check if homeopathic
                    if 'homéo' in str(procedure_type).lower():
                        homeopathic_count += 1
                        report.add_line(f"  - CIS {cis}: '{nom}'")
                        report.add_line(f"    Procédure: {procedure_type} (HOMÉOPATHIQUE)")
                    # Check if discontinued
                    elif 'arrêt' in str(etat).lower() or 'retrait' in str(etat).lower():
                        discontinued_count += 1
                        report.add_line(f"  - CIS {cis}: '{nom}'")
                        report.add_line(f"    État: {etat} (ARRÊTÉ)")
                    else:
                        other_count += 1
                        report.add_line(f"  - CIS {cis}: '{nom}'")
                        report.add_line(f"    Procédure: {procedure_type}, État: {etat}")
            
            if len(member_cis) > 5:
                report.add_line(f"  ... et {len(member_cis) - 5} autres membres")
            
            # Summary
            total_analyzed = min(5, len(member_cis))
            if homeopathic_count == total_analyzed:
                report.add_line(f"  Conclusion: Groupe composé exclusivement de produits homéopathiques. Sécurisé de filtrer.")
            elif discontinued_count == total_analyzed:
                report.add_line(f"  Conclusion: Groupe composé exclusivement de produits arrêtés. Sécurisé de filtrer.")
            elif homeopathic_count + discontinued_count == total_analyzed:
                report.add_line(f"  Conclusion: Groupe composé de produits homéopathiques/arrêtés. Sécurisé de filtrer.")
            else:
                report.add_line(f"  Conclusion: Groupe mixte (analyser davantage si nécessaire).")
        
        if len(unspecified_groups) > 10:
            report.add_line(f"\n... et {len(unspecified_groups) - 10} autres groupes non spécifiés")
        
        # Overall summary
        report.add_line(f"\nRésumé global:")
        report.add_line(f"  - Total groupes non spécifiés: {len(unspecified_groups)}")
        report.add_line(f"  - Total membres dans ces groupes: {sum(g['member_count'] for g in unspecified_groups)}")
        report.add_line(f"  - Recommandation: Filtrer ces groupes (HAVING common_principes IS NOT NULL AND common_principes != '')")
    else:
        report.add_line("✅ Tous les groupes ont au moins un principe actif spécifié.")

def clean_group_label_python(label):
    """
    A Python replication of the Dart `cleanGroupLabel` heuristic logic.
    This function extracts the active principle name from a group label by removing
    everything after the first dosage number.
    """
    if pd.isna(label) or not label:
        return ""
    
    parts = str(label).split(' ')
    stop_index = -1
    
    for i, part in enumerate(parts):
        try:
            # Attempt to parse a number, handling commas as decimal points
            # This replicates: double.tryParse(part.replaceAll(',', '.'))
            float(part.replace(',', '.'))
            stop_index = i
            break
        except ValueError:
            continue
    
    if stop_index != -1:
        # Replicate: parts.sublist(0, stopIndex).join(' ').replaceAll(RegExp(r'\s*,$'), '')
        result = ' '.join(parts[:stop_index])
        # Remove trailing commas
        result = re.sub(r'\s*,+$', '', result)
        return result.strip()
    
    # Fallback for labels without a clear dosage number
    # Replicate: label.split(',').first.trim()
    return str(label).split(',')[0].strip()

def validate_active_principle_logic(report, dataframes):
    """
    Compares the heuristic `cleanGroupLabel` logic against a deterministic
    database join and adds a quality check to ensure the deterministic result
    is free of dosage or formulation keywords.
    """
    report.add_header("5. VALIDATION: LOGIQUE D'EXTRACTION DES PRINCIPES ACTIFS", level=1)
    
    if "CIS_GENER_bdpm.txt" not in dataframes or "CIS_COMPO_bdpm.txt" not in dataframes:
        report.add_line("❌ Fichiers nécessaires manquants pour la validation.")
        return
    
    gener = dataframes["CIS_GENER_bdpm.txt"]
    compo = dataframes["CIS_COMPO_bdpm.txt"][dataframes["CIS_COMPO_bdpm.txt"]["nature_composant"] == 'SA']
    
    # --- Define keywords that should NOT appear in a clean active principle name ---
    # Note: We use more precise patterns to avoid false positives
    # For units, we look for patterns like "X mg", "X g" where X is a number
    DOSAGE_UNIT_PATTERNS = [
        re.compile(r'\b\d+([.,]\d+)?\s*mg\b', re.IGNORECASE),  # "100 mg" or "2.5 mg"
        re.compile(r'\b\d+([.,]\d+)?\s*g\b', re.IGNORECASE),  # "10 g" or "0.5 g"
        re.compile(r'\b\d+([.,]\d+)?\s*ml\b', re.IGNORECASE),  # "5 ml"
        re.compile(r'\b\d+([.,]\d+)?\s*ui\b', re.IGNORECASE),  # "1000 ui"
        re.compile(r'\b\d+([.,]\d+)?\s*%\b'),  # "0.5 %"
        re.compile(r'\b\d+([.,]\d+)?\s*ch\b', re.IGNORECASE),  # "5CH" or "5 ch"
        re.compile(r'\b\d+([.,]\d+)?\s*dh\b', re.IGNORECASE),  # "9DH" or "9 dh"
        re.compile(r'\b\d+([.,]\d+)?\s*gbq\b', re.IGNORECASE),  # "100 GBq"
        re.compile(r'\b\d+([.,]\d+)?\s*mbq\b', re.IGNORECASE),  # "100 MBq"
    ]
    
    # Formulation keywords that should not appear (but be careful with false positives)
    # These are checked as whole words to avoid matching parts of molecule names
    FORMULATION_KEYWORDS = {
        'comprimé', 'gélule', 'solution', 'injectable', 'poudre', 'sirop',
        'suspension', 'crème', 'pommade', 'gel', 'collyre', 'inhalation'
    }
    FORMULATION_EXCEPTIONS = {
        'solution': [re.compile(r'\bsolution\s+de\b', re.IGNORECASE)],
    }
    
    # Pattern to match standalone numbers (but exclude known molecule names with numbers)
    # Known molecules with numbers in their names (legitimate)
    KNOWN_NUMBERED_MOLECULES = {'4000', '3350', '980', '940', '6000', '2,4'}
    NUMBER_PATTERN = re.compile(r'\b(\d+([.,]\d+)?)\b')  # Matches numbers
    
    all_group_ids = gener['group_id'].dropna().unique()
    total_groups_analyzed = 0
    contaminated_groups = []
    
    for group_id in all_group_ids:
        group_rows = gener[gener['group_id'] == group_id]
        if group_rows.empty:
            continue
            
        total_groups_analyzed += 1
        
        # --- Methodology: Deterministic (Proposed Logic) ---
        group_cis = set(group_rows['cis'].unique())
        group_compo = compo[compo['cis'].isin(group_cis)]
        
        deterministic_result = ""
        if not group_compo.empty:
            principles_per_cis = group_compo.groupby('cis')['denomination_substance'].apply(set)
            if not principles_per_cis.empty:
                common_principles = set.intersection(*principles_per_cis)
                if common_principles:
                    deterministic_result = ', '.join(sorted(list(common_principles)))
        
        if not deterministic_result:
            continue  # Skip groups with no common principles
        
        # --- Quality Check: Scan for contamination ---
        contamination_reasons = []
        result_lower = deterministic_result.lower()
        
        # Check for dosage units with numbers (e.g., "100 mg", "5 g")
        for pattern in DOSAGE_UNIT_PATTERNS:
            if pattern.search(deterministic_result):
                contamination_reasons.append("unité de dosage avec nombre")
                break  # Only report once
        
        # Check for standalone numbers (excluding known molecule names)
        for match in NUMBER_PATTERN.finditer(deterministic_result):
            number_token = match.group(1)
            preceding_char = deterministic_result[match.start() - 1] if match.start() > 0 else ''
            snippet_start = max(0, match.start() - 2)
            snippet_end = min(len(deterministic_result), match.end() + 2)
            snippet_upper = deterministic_result[snippet_start:snippet_end].upper()
            is_known_molecule = (
                preceding_char == '-' or
                any(known in snippet_upper for known in KNOWN_NUMBERED_MOLECULES)
            )
            if is_known_molecule:
                continue
            
            number_with_context = re.search(
                rf'\b{re.escape(number_token)}\s+[a-zA-Z]',
                deterministic_result,
                re.IGNORECASE
            )
            if number_with_context:
                contamination_reasons.append("chiffre(s) suspect(s)")
                break  # Only report once
        
        # Check for formulation keywords as whole words (to avoid false positives)
        # Use word boundaries to avoid matching parts of molecule names
        for keyword in FORMULATION_KEYWORDS:
            pattern = re.compile(rf'\b{re.escape(keyword)}\b', re.IGNORECASE)
            if pattern.search(deterministic_result):
                exception_patterns = FORMULATION_EXCEPTIONS.get(keyword, [])
                if any(
                    exception_pattern.search(deterministic_result)
                    for exception_pattern in exception_patterns
                ):
                    continue
                contamination_reasons.append(keyword)
        
        if contamination_reasons:
            contaminated_groups.append({
                'group_id': group_id,
                'libelle': group_rows['libelle_groupe'].iloc[0],
                'result': deterministic_result,
                'reasons': sorted(list(set(contamination_reasons)))
            })
    
    # --- Generate Report Section ---
    report.add_header("Analyse de Propreté des Résultats Déterministes", level=2)
    
    clean_count = total_groups_analyzed - len(contaminated_groups)
    report.add_line(f"Total des groupes avec principes actifs communs analysés : {total_groups_analyzed}")
    report.add_line(f"  - ✅ Groupes avec résultat propre : {clean_count}")
    report.add_line(f"  - ⚠️  Groupes avec résultat contaminé : {len(contaminated_groups)}")
    
    if not contaminated_groups:
        report.add_line("\n✅ EXCELLENT: Aucun résultat déterministe ne contient de posologie ou de formulation superflue.")
    else:
        report.add_line("\n--- DÉTAIL DES RÉSULTATS CONTAMINÉS ---")
        for item in contaminated_groups:
            report.add_line(f"\nGroupe ID: {item['group_id']}")
            report.add_line(f"  - Libellé Original : '{item['libelle']}'")
            report.add_line(f"  - Résultat Obtenu  : '{item['result']}'")
            report.add_line(f"  - Contaminants     : {', '.join(item['reasons'])}")

# --- Main Execution ---
def main():
    print("--- Script de Validation des Données PharmaScan (Forensic Auditor) ---")
    
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)

    report = Report(REPORT_FILE)
    report.add_header(f"Rapport de Validation des Données - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    print("\nÉtape 1: Téléchargement des fichiers de données...")
    for filename, config in DATA_FILES_CONFIG.items():
        download_file(filename, config['url'])

    print("\nÉtape 2: Chargement des données en mémoire (avec échantillonnage de lignes)...")
    dataframes = load_data(report)

    print("\nÉtape 3: Vérification des clés primaires dupliquées...")
    check_duplicate_primary_keys(report, dataframes)

    print("\nÉtape 4: Audit d'encodage des caractères...")
    audit_character_encoding(report, dataframes)

    print("\nÉtape 5: Analyse des colonnes et formats...")
    analyze_column_values(report, dataframes)

    print("\nÉtape 6: Test de stress - Parsing des dosages (logique Dart)...")
    stress_test_dosage_parsing(report, dataframes)

    print("\nÉtape 7: Analyse de propreté - Colonne Titulaires...")
    analyze_titulaire_cleanliness(report, dataframes)

    print("\nÉtape 8: Vérification de l'intégrité relationnelle...")
    verify_relational_integrity(report, dataframes)
    
    print("\nÉtape 9: Détection des médicaments caméléon...")
    detect_chameleon_medications(report, dataframes)
    
    print("\nÉtape 10: Validation de la logique métier...")
    validate_business_logic(report, dataframes)
    
    print("\nÉtape 11: Analyse des formes pharmaceutiques...")
    analyze_pharmaceutical_forms(report, dataframes)
    
    print("\nÉtape 12: Investigation des groupes 'Principe non spécifié'...")
    investigate_unspecified_groups(report, dataframes)

    print("\nÉtape 13: Validation de la logique des principes actifs communs...")
    validate_active_principle_logic(report, dataframes)

    # Optional: Test Data Lookup (enable by setting TEST_DATA_LOOKUP_QUERY above)
    if TEST_DATA_LOOKUP_QUERY:
        find_test_data(TEST_DATA_LOOKUP_QUERY, dataframes)
    
    # Optional: Related Princeps Analysis (enable by setting TARGET_GROUP_ID below)
    # Example: Find related princeps for LIORESAL 10 mg group
    TARGET_GROUP_ID = None  # Example: '12345' (set to a real group_id to test)
    if TARGET_GROUP_ID:
        find_related_princeps(TARGET_GROUP_ID, dataframes)

    print("\nGénération du rapport final...")
    report.save()
    print("\n✅ Analyse complète terminée!")

if __name__ == "__main__":
    main()