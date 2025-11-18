# data_validation/generate_smart_test_data.py

import pandas as pd  # pyright: ignore[reportMissingImports]
import os
import requests  # pyright: ignore[reportMissingModuleSource]
import re

# --- Configuration ---
DATA_DIR = "data_validation"
OUTPUT_FILE = os.path.join(DATA_DIR, "smart_parsing_challenges.csv")

FILES = {
    "CIS_bdpm.txt": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt",
    "CIS_COMPO_bdpm.txt": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt",
}

# Complex patterns we want to test
# Using non-capturing groups (?:...) to avoid Pandas warnings since we only use str.contains()
PATTERNS = {
    "Ratios": r"\d+\s*[a-zA-Zµ]+\s*/\s*\d+\s*[a-zA-Zµ]+",
    "Context": r"(?:ENFANT|ADULTE|NOURRISSON|SANS SUCRE)",
    "Equivalency": r"équivalant à",
    "Complex Units": r"\d+\s*(?:UI|M\.U\.I\.|mmol|mEq)",
}


def download_data():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)

    for filename, url in FILES.items():
        filepath = os.path.join(DATA_DIR, filename)
        if not os.path.exists(filepath):
            print(f"Downloading {filename}...")
            r = requests.get(url)
            with open(filepath, "wb") as f:
                f.write(r.content)


def main():
    download_data()

    print("Loading data...")

    # 1. Load Specialties (Name, Form, Lab)
    # Col 0: CIS, Col 1: Name, Col 2: Form, Col 10: Lab
    cis = pd.read_csv(
        os.path.join(DATA_DIR, "CIS_bdpm.txt"),
        sep="\t",
        header=None,
        encoding="latin-1",
        usecols=[0, 1, 2, 10],
        names=["cis", "raw_name", "official_form", "official_lab"],
    )

    # 2. Load Compositions (Dosage)
    # Col 0: CIS, Col 4: Dosage
    compo = pd.read_csv(
        os.path.join(DATA_DIR, "CIS_COMPO_bdpm.txt"),
        sep="\t",
        header=None,
        encoding="latin-1",
        usecols=[0, 4],
        names=["cis", "official_dosage"],
    )

    # 3. Join them to get a complete picture
    # We group compo by CIS because one drug might have multiple active ingredients (and thus multiple dosages)
    compo_grouped = (
        compo.groupby("cis")["official_dosage"]
        .apply(lambda x: " + ".join(x.dropna().astype(str)))
        .reset_index()
    )

    df = pd.merge(cis, compo_grouped, on="cis", how="left")

    print("Filtering for interesting cases...")

    selected_rows = []

    # 4. Select rows that match our "Tricky Patterns"
    # Select 15 items per category (4 categories * 15 = 60 items)
    for label, pattern in PATTERNS.items():
        # Find matches
        matches = df[df["raw_name"].str.contains(pattern, case=False, regex=True, na=False)].head(15)
        for _, row in matches.iterrows():
            row["category"] = label
            selected_rows.append(row)

    # 5. Add some random rows for general stability
    # Add 40 random items to reach ~100 total (60 + 40 = 100)
    random_sample = df.sample(40, random_state=42)
    for _, row in random_sample.iterrows():
        row["category"] = "Random Sample"
        selected_rows.append(row)

    # Create final DataFrame
    result_df = pd.DataFrame(selected_rows)

    # Clean up data for CSV export (replace tabs/newlines if any)
    result_df = result_df.replace({r"\t": " ", r"\n": " "}, regex=True)

    # Fill NaN values with empty strings
    result_df = result_df.fillna("")

    # 6. Export
    # We export: Category, Raw Name, Official Form, Official Lab, Official Dosage
    result_df.to_csv(
        OUTPUT_FILE,
        index=False,
        sep=";",  # Semicolon separator to avoid issues with commas in names
        columns=["category", "raw_name", "official_form", "official_lab", "official_dosage"],
    )

    print(f"✅ Generated {len(result_df)} smart test cases in {OUTPUT_FILE}")


if __name__ == "__main__":
    main()

