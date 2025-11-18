
# data_validation/product_classifier.py
from __future__ import annotations

import math
import os
import re
import sys
from typing import Any, Dict, List, Set, Tuple

import pandas as pd  # pyright: ignore[reportMissingImports]
import requests  # pyright: ignore[reportMissingModuleSource]

BANNED_TRAILING_MEASURE_SUFFIXES = [
    "/24 heures",
    "/ 24 heures",
    "/24h",
    "/dose",
    "/ dose",
]

# --- Configuration ---
DATA_DIR = "data_validation"
REPORT_FILE = os.path.join(DATA_DIR, "classification_report.txt")
MAX_REPORT_COUNT = 50
DATA_FILES_CONFIG = {
    "CIS_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt",
        "columns": [
            "cis", "nom_specialite", "forme_pharmaceutique", "voies_admin",
            "statut_amm", "type_amm", "etat_commercialisation", "date_amm",
            "statut_bdm", "num_autorisation_eu", "titulaires", "surveillance_renforcee"
        ],
        "dtype": {"cis": str},
    },
    "CIS_COMPO_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt",
        "columns": [
            "cis", "designation_element", "code_substance",
            "denomination_substance", "dosage_substance", "reference_dosage",
            "nature_composant", "num_liaison"
        ],
        "dtype": {"cis": str, "code_substance": str},
    },
    "CIS_GENER_bdpm.txt": {
        "url": "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt",
        "columns": [
            "group_id", "libelle_groupe", "cis", "type_generique", "num_tri"
        ],
        "dtype": {"group_id": str, "cis": str},
    }
}

# Canonical parsing constants
FORMULATION_KEYWORDS = [
    "solution pour lavage ophtalmique en récipient unidose",
    "solution pour lavage ophtalmique en récipient-unidose",
    "solution pour bain de bouche",
    "gomme à mâcher médicamenteuse",
    "gomme à sucer",
    "spray buccal",
    "spray nasal",
    "spray pour application buccale",
    "spray pour application nasale",
    "dispositif transdermique",
    "patch transdermique",
    "comprimé sublingual",
    "poudre pour solution à diluer pour perfusion",
    "solution à diluer pour perfusion",
    "système de diffusion vaginal",
    "pastille édulcorée à l'acésulfame potassique",
    "pastille édulcorée à la saccharine sodique",
    "pastille",
    "pansement adhésif cutané",
    "suspension pour pulvérisation nasale",
    "émulsion fluide pour application cutanée",
    "émulsion pour application cutanée",
    "bain de bouche",
    "solution injectable/pour perfusion",
    "solution pour perfusion en poche",
    "solution à diluer pour perfusion",
    "poudre pour suspension buvable en flacon",
    "poudre pour suspension buvable",
    "poudre pour solution injectable (iv)",
    "poudre pour solution injectable",
    "microgranules à libération prolongée en gélule",
    "microgranules en comprimé",
    "gélule gastro-résistante",
    "gélule à libération prolongée",
    "comprimé à libération prolongée",
    "collyre en solution",
    "solution injectable en flacon",
    "solution injectable en poche",
    "solution buvable en flacon",
    "solution pour perfusion",
    "solution pour pulvérisation",
    "solution pour inhalation",
    "suspension pour inhalation",
    "poudre pour solution",
    "poudre pour perfusion",
    "comprimé pelliculé sécable",
    "solution injectable",
    "solution buvable",
    "comprimé orodispersible",
    "comprimé effervescent",
    "comprimé enrobé",
    "suspension buvable",
    "comprimé sécable",
    "comprimé",
    "gélule",
    "capsule molle",
    "capsule",
    "solution",
    "poudre",
    "granulés",
    "lyophilisat",
    "gel",
    "pommade",
    "crème",
    "collyre",
    "ovule",
    "suppositoire",
    "mousse",
]

FORMULATION_KEYWORDS.sort(key=len, reverse=True)

UNIT_REGEX = r"(?:mg|g|µg|mcg|microgrammes|ml|mL|l|ui|unités|%|ch|dh|meq|mmol|gbq|mbq|dose|doses|heure|heures|h)"
DOSAGE_TOKEN_PATTERN = re.compile(
    rf"\d+(?:[.,]\d+)?\s*{UNIT_REGEX}",
    re.IGNORECASE,
)
DOSAGE_SEQUENCE_PATTERN = re.compile(
    rf"(?:\d+(?:[.,]\d+)?\s*{UNIT_REGEX})(?:\s*/\s*(?:\d+(?:[.,]\d+)?\s*)?{UNIT_REGEX})*",
    re.IGNORECASE,
)
UNIT_PATTERN = re.compile(
    rf"(mg|g|µg|mcg|microgrammes|ml|mL|l|ui|unités|%|ch|dh|meq|mmol|gbq|mbq|dose|doses|heure|heures|h)",
    re.IGNORECASE,
)
HAS_DIGIT_PATTERN = re.compile(r"\d")

KNOWN_LAB_SUFFIXES = {
    "ACCORD",
    "ACCORDHEALTHCARE",
    "ACTAVIS",
    "AGUETTANT",
    "ALMUS",
    "ALTER",
    "ARROW",
    "ARROWGENERIQUE",
    "ARROWLAB",
    "AUTRICHE",
    "BGR",
    "BELGIQUE",
    "BIOGARAN",
    "BIOGARANCONSEIL",
    "BIOGARANSANTE",
    "BOUCHARARECORDATI",
    "CRISTERS",
    "CRISTERSPHARMA",
    "EG",
    "EGLABOLABORATOIRESEUROGENERICS",
    "EGLABOLABORATOIRES",
    "ENFANTS",
    "ESPAGNE",
    "EUROGENERICS",
    "EUGIA",
    "EUGIAPHARMA",
    "EVOLUGEN",
    "EVOLUGENPHARMA",
    "FRESENIUS",
    "FRESENIUSKABI",
    "FRANCE",
    "GNR",
    "RENAUDIN",
    "AGUETTANT",
    "HCS",
    "HEALTHCARE",
    "HOSPIRA",
    "IRLANDE",
    "KABI",
    "KRKA",
    "LAB",
    "LABO",
    "LABOLABORATOIRES",
    "LABORATOIRES",
    "LABORATOIRE",
    "LABS",
    "MALTE",
    "MYLAN",
    "PANPHARMA",
    "PAYSBAS",
    "PHARMA",
    "PHARMACEUTICALS",
    "REF",
    "SANDOZ",
    "SANTE",
    "SUN",
    "SUNPHARMA",
    "TEVA",
    "TEVASANTE",
    "UPSA",
    "VIATRIS",
    "VIATRISPHARMA",
    "ZENTIVA",
    "ZENTIVAFRANCE",
    "ZENTIVALAB",
    "ZYDUS",
}

BANNED_SUFFIX_PHRASES = {
    "SANS CONSERVATEUR",
}

BANNED_PACKAGING_SUFFIXES = {
    "FLACON",
    "FLACONS",
}

BANNED_PRESENTATION_WORDS = {
    "PASTILLE",
    "PASTILLES",
    "POUDRE",
    "POUDRE POUR",
}

MEASUREMENT_SUFFIX_PATTERN = re.compile(
    r"/\s*(?:(?:mg|g|µg|mcg|microgrammes|ml|mL|l|ui|unités)\b|%)",
    re.IGNORECASE,
)
PAR_MEASUREMENT_PATTERN = re.compile(
    r"\b(?:par|per)\s*(?:m[lL]|ml)\b",
    re.IGNORECASE,
)


def _normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


def _normalize_textual_units(value: str) -> str:
    replacements = {
        r"\bPOUR\s+CENT\b": "%",
        r"\bPOUR\s+MILLE\b": "‰",
        r"\bPAR\s+ML\b": "/ml",
        r"\bPAR\s+M[Ll]\b": "/ml",
        r"\bPAR\s+L\b": "/l",
    }
    normalized = value
    for pattern, replacement in replacements.items():
        normalized = re.sub(pattern, replacement, normalized, flags=re.IGNORECASE)
    return normalized


def _extract_unit(token: str) -> str | None:
    match = UNIT_PATTERN.search(token)
    if match:
        return match.group(1).lower()
    return None


def _strip_laboratory_suffix(name: str) -> str:
    if not name:
        return name
    parts = name.split()
    while parts:
        candidate = parts[-1]
        stripped = candidate.strip(",")
        if stripped.startswith("(") and stripped.endswith(")"):
            parts.pop()
            continue
        cleaned_candidate = re.sub(r"[^A-Z]", "", stripped.upper())
        if (
            len(cleaned_candidate) > 1
            and cleaned_candidate in KNOWN_LAB_SUFFIXES
        ):
            parts.pop()
            continue
        break
    canonical = " ".join(parts).strip(" ,+/")
    # Remove laboratory token before LP suffix if present
    tokens = canonical.split()
    if len(tokens) >= 2:
        last_token = tokens[-1].upper().replace(".", "")
        if last_token == "LP":
            second_last = tokens[-2]
            cleaned_second = re.sub(r"[^A-Z]", "", second_last.upper())
            if cleaned_second in KNOWN_LAB_SUFFIXES:
                tokens[-2:-1] = []
            canonical = " ".join(tokens)
    upper_canonical = canonical.upper()
    for phrase in BANNED_SUFFIX_PHRASES:
        if upper_canonical.endswith(phrase):
            canonical = canonical[: -len(phrase)].rstrip(" ,/")
            break
    lower_canonical = canonical.lower()
    for suffix in BANNED_TRAILING_MEASURE_SUFFIXES:
        if lower_canonical.endswith(suffix):
            canonical = canonical[: -len(suffix)].rstrip(" ,/")
            lower_canonical = canonical.lower()
    return _normalize_whitespace(canonical)


def _extract_formulation_segment(name: str) -> tuple[str, str | None]:
    working = name
    detected: List[str] = []

    def _remove_span(start: int, end: int):
        nonlocal working
        before = working[:start].rstrip(" ,")
        after = working[end:].lstrip(" ,")
        if before and after:
            working = f"{before} {after}"
        elif before:
            working = before
        else:
            working = after
        working = _normalize_whitespace(working)

    while True:
        match = None
        for keyword in FORMULATION_KEYWORDS:
            pattern = re.compile(
                r"(?:,\s*)(" + re.escape(keyword) + r"(?:\b[^,]*)?)",
                re.IGNORECASE,
            )
            matches = list(pattern.finditer(working))
            if matches:
                match = matches[-1]
                detected.append(match.group(1).strip(" ,"))
                _remove_span(match.start(), match.end())
                break
        if not match:
            break

    working = working.strip(" ,")
    for suffix in BANNED_PACKAGING_SUFFIXES:
        patterns = [
            re.compile(r"(?:,\s*)" + re.escape(suffix) + r"$", re.IGNORECASE),
            re.compile(r"\s+" + re.escape(suffix) + r"$", re.IGNORECASE),
        ]
        for pattern in patterns:
            if pattern.search(working):
                working = pattern.sub("", working).rstrip(" ,")

    if detected:
        for part in detected:
            clean_part = part.strip()
            if not clean_part:
                continue
            pattern = re.compile(
                r"(?:,\s*)?" + re.escape(clean_part) + r"$",
                re.IGNORECASE,
            )
            working = pattern.sub("", working).strip(" ,")

    for word in BANNED_PRESENTATION_WORDS:
        pattern = re.compile(
            r"(?:,\s*)?" + re.escape(word) + r"(?:\s[^,]+)?$",
            re.IGNORECASE,
        )
        working = pattern.sub("", working).strip(" ,")

    formulation = ", ".join(reversed(detected)) if detected else None
    return working, formulation


def _extract_dosages_segment(name: str) -> tuple[str, List[str]]:
    dosages: List[str] = []
    name = _normalize_textual_units(name)

    def _replace_sequence(match: re.Match[str]):
        raw_sequence = match.group(0)
        parts = re.split(r"\s*/\s*", raw_sequence)
        if len(parts) == 2:
            units = [_extract_unit(part) for part in parts]
            unit_a, unit_b = units[0], units[1]
            if unit_b is None or (unit_a and unit_b and unit_a != unit_b):
                normalized_ratio = _normalize_whitespace(raw_sequence)
                normalized_ratio = normalized_ratio.replace(" /", "/").replace("/ ", "/")
                dosages.append(normalized_ratio)
                return " "
        tokens = DOSAGE_TOKEN_PATTERN.findall(raw_sequence)
        for token in tokens:
            normalized_token = _normalize_whitespace(token)
            normalized_token = normalized_token.replace(" /", "/").replace("/ ", "/")
            dosages.append(normalized_token)
        micronise_matches = re.findall(
            r"(\d+(?:[.,]\d+)?)\s+(?:mg\s*)?micronis[ée]",
            raw_sequence,
            re.IGNORECASE,
        )
        for value_str in micronise_matches:
            value_clean = value_str.replace(",", ".")
            try:
                float(value_clean)
                dosages.append(f"{value_str} mg")
            except ValueError:
                continue
        return " "

    cleaned = DOSAGE_SEQUENCE_PATTERN.sub(_replace_sequence, name)
    normalized = _normalize_whitespace(_remove_measurement_artifacts(cleaned))
    unique_dosages = list(dict.fromkeys(dosages))
    extra_micronise = re.findall(
        r"(\d+(?:[.,]\d+)?)\s+(?:mg\s*)?micronis[ée]",
        name,
        re.IGNORECASE,
    )
    for value_str in extra_micronise:
        formatted = f"{value_str} mg"
        if formatted not in unique_dosages:
            unique_dosages.append(formatted)
    return normalized, unique_dosages


def _remove_measurement_artifacts(text: str) -> str:
    cleaned = MEASUREMENT_SUFFIX_PATTERN.sub(" ", text)
    cleaned = PAR_MEASUREMENT_PATTERN.sub(" ", cleaned)
    cleaned = re.sub(
        r"\b(?:par|per)\s+(?:enfants|adultes)\b",
        " ",
        cleaned,
        flags=re.IGNORECASE,
    )
    cleaned = re.sub(r"\s+[+/]\s*$", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def _parsing_issue_reason(original: str, parsed: Dict[str, Any]) -> str | None:
    canonical = parsed.get("canonical_name")
    if not canonical:
        return "canonical name is missing"
    if HAS_DIGIT_PATTERN.search(original) and not parsed.get("dosages"):
        return "numeric data detected but no dosage extracted"
    if "," in original and parsed.get("formulation") is None:
        return "comma present but formulation missing"
    return None


def _parsing_row_has_issue(original: str, parsed: Dict[str, Any]) -> bool:
    return _parsing_issue_reason(original, parsed) is not None


def parse_medicament_name(name: str) -> Dict[str, Any]:
    """
    Prototyping helper mirroring the future petitparser grammar.
    Returns a structured view of the canonical name, extracted dosages,
    and final formulation segment.
    """
    if not isinstance(name, str):
        return {
            "original": name,
            "canonical_name": None,
            "dosages": [],
            "formulation": None,
        }

    original_name = name.strip()
    if not original_name:
        return {
            "original": name,
            "canonical_name": None,
            "dosages": [],
            "formulation": None,
        }

    working_name = original_name
    working_name, formulation = _extract_formulation_segment(working_name)
    working_name, dosages = _extract_dosages_segment(working_name)

    canonical = _strip_laboratory_suffix(working_name).strip()
    canonical = canonical.rstrip(",")

    return {
        "original": original_name,
        "canonical_name": canonical or None,
        "dosages": dosages,
        "formulation": formulation,
}

# --- Utility Functions ---

def download_file(filename: str, url: str):
    filepath = os.path.join(DATA_DIR, filename)
    if os.path.exists(filepath):
        return
    print(f"Downloading '{filename}'...")
    try:
        response = requests.get(url, timeout=60)
        response.raise_for_status()
        with open(filepath, 'wb') as f:
            f.write(response.content)
    except requests.RequestException as e:
        print(f"Error downloading '{filename}': {e}", file=sys.stderr)
        sys.exit(1)

def load_data() -> Dict[str, pd.DataFrame]:
    dataframes = {}
    print("\n--- 1. Loading Data ---")
    for filename, config in DATA_FILES_CONFIG.items():
        download_file(filename, config['url'])
        filepath = os.path.join(DATA_DIR, filename)
        try:
            df = pd.read_csv(
                filepath, sep='\t', header=None, names=config["columns"],
                dtype=config.get("dtype", None), encoding='latin-1',
            )
            dataframes[filename] = df
            print(f"  - Loaded {filename} ({len(df)} rows)")
        except Exception as e:
            print(f"Failed to load {filename}: {e}", file=sys.stderr)
            sys.exit(1)
    return dataframes

def find_common_princeps_name_py(names: List[str]) -> str:
    if not names: return "N/A"
    if len(names) == 1: return names[0]
    prefix_words = names[0].split(' ')
    for i in range(1, len(names)):
        current_words = names[i].split(' ')
        common_length = 0
        while (common_length < len(prefix_words) and 
               common_length < len(current_words) and 
               prefix_words[common_length] == current_words[common_length]):
            common_length += 1
        if common_length < len(prefix_words):
            prefix_words = prefix_words[:common_length]
    if not prefix_words: return min(names, key=len)
    return ' '.join(prefix_words).strip().rstrip(',.')

def derive_brand_name(name: str) -> str:
    if not isinstance(name, str) or not name.strip(): return "N/A"
    raw_name = name.strip()
    # Remove everything after the first comma to avoid dosage suffixes like ", 100 mg"
    if "," in raw_name:
        raw_name = raw_name.split(",", 1)[0].strip()
    parts = raw_name.split(' ')
    stop_index = -1
    for i, part in enumerate(parts):
        if re.match(r"^\d+([,./]\d+)*$", part):
            stop_index = i
            break
    if stop_index != -1 and stop_index > 0:
        cleaned = " ".join(parts[:stop_index]).rstrip(",")
        return cleaned.strip() or raw_name
    return raw_name

def parse_dosage(dosage_str: str) -> Tuple[float | None, str | None, int]:
    if not isinstance(dosage_str, str) or not dosage_str.strip():
        return None, None, 0
    match = re.match(r"^\s*([\d,.]+)\s*(.*)$", dosage_str.strip())
    if not match:
        return None, dosage_str.strip(), 0
    value_str, unit_str = match.groups()
    try:
        value = float(value_str.replace(",", "."))
        unit = unit_str.strip() if unit_str else None
        precision = _count_decimal_places(value_str)
        return value, unit, precision
    except ValueError:
        return None, dosage_str.strip(), 0

def normalize_dosage_value(value: float) -> float:
    """Rounds dosage values to group them semantically."""
    if value >= 1:
        # For values >= 1, round to 2 decimal places
        return round(value, 2)
    # For values < 1, keep more precision (e.g., for micrograms)
    return round(value, 4)

def categorize_formulation(formulation: str) -> str:
    if not isinstance(formulation, str): return "Inconnue"
    f_lower = formulation.lower()
    if "comprimé" in f_lower: return "Comprimé"
    if "gélule" in f_lower: return "Gélule"
    if "sirop" in f_lower or "suspension buvable" in f_lower: return "Sirop / Suspension"
    if "injectable" in f_lower or "perfusion" in f_lower: return "Injectable"
    if "solution" in f_lower and "buvable" in f_lower: return "Solution buvable"
    if "collyre" in f_lower: return "Collyre"
    if any(k in f_lower for k in ["crème", "pommade", "gel"]): return "Usage externe"
    return formulation.split(',')[0].strip()
    
def _extract_pa_from_libelle(libelle: str) -> List[str]:
    """Fallback to extract active principle from the group label."""
    # Takes the part before the first dosage number
    base_name = derive_brand_name(libelle)
    # This often contains multiple substances separated by '+' or ','
    substances = re.split(r'\s*\+\s*|\s*,\s*', base_name)
    cleaned_substances = []
    for substance in substances:
        if not substance.strip():
            continue
        normalized = re.sub(r"\s*\(.*?\)", "", substance).strip()
        if normalized:
            cleaned_substances.append(normalized)
    return sorted(cleaned_substances)

def _values_overlap(entry_a: Dict[str, Any], entry_b: Dict[str, Any]) -> bool:
    min_precision = min(entry_a["precision"], entry_b["precision"])
    for precision in range(min_precision, -1, -1):
        if _round_half_up(entry_a["value"], precision) == _round_half_up(entry_b["value"], precision):
            return True
        if _truncate_to_precision(entry_a["value"], precision) == _truncate_to_precision(entry_b["value"], precision):
            return True
    diff = abs(entry_a["value"] - entry_b["value"])
    base = max(entry_a["value"], entry_b["value"], 1e-6)
    return diff / base <= 0.005

def _determine_canonical_value(entries: List[Dict[str, Any]]) -> Tuple[int, float]:
    min_precision = min(entry["precision"] for entry in entries)
    for precision in range(min_precision, -1, -1):
        rounded = {_round_half_up(entry["value"], precision) for entry in entries}
        if len(rounded) == 1:
            return precision, rounded.pop()
        truncated = {_truncate_to_precision(entry["value"], precision) for entry in entries}
        if len(truncated) == 1:
            return precision, truncated.pop()
    fallback_entry = min(entries, key=lambda e: (e["precision"], e["value"]))
    return fallback_entry["precision"], _round_half_up(fallback_entry["value"], fallback_entry["precision"])

def _cluster_unit_entries(unit_entries: List[Dict[str, Any]]) -> Tuple[Dict[Tuple[float, str | None, int], Tuple[float, str | None]], List[Tuple[float, str | None]]]:
    if not unit_entries:
        return {}, []
    n = len(unit_entries)
    parent = list(range(n))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a: int, b: int):
        root_a, root_b = find(a), find(b)
        if root_a == root_b:
            return
        parent[root_b] = root_a

    for i in range(n):
        for j in range(i + 1, n):
            if _values_overlap(unit_entries[i], unit_entries[j]):
                union(i, j)

    clusters: Dict[int, List[int]] = {}
    for idx in range(n):
        root = find(idx)
        clusters.setdefault(root, []).append(idx)

    assignment: Dict[Tuple[float, str | None, int], Tuple[float, str | None]] = {}
    canonical_values: List[Tuple[float, str | None]] = []

    for indices in clusters.values():
        cluster_entries = [unit_entries[i] for i in indices]
        precision, canonical_value = _determine_canonical_value(cluster_entries)
        canonical_unit = cluster_entries[0]["unit"]
        canonical_value = normalize_dosage_value(canonical_value)
        canonical_tuple = (canonical_value, canonical_unit)
        canonical_values.append(canonical_tuple)
        for i in indices:
            entry = unit_entries[i]
            assignment[_dosage_key(entry["value"], entry["unit"], entry["precision"])] = canonical_tuple

    return assignment, canonical_values

def _cluster_dosages(dosage_strings: List[str]) -> Tuple[List[Tuple[float, str | None]], Dict[Tuple[float, str | None, int], Tuple[float, str | None]]]:
    entries_by_unit: Dict[str | None, List[Dict[str, Any]]] = {}
    for dosage in dosage_strings:
        value, unit, precision = parse_dosage(dosage)
        if value is None:
            continue
        normalized_unit = unit.strip().lower() if isinstance(unit, str) else None
        entries_by_unit.setdefault(normalized_unit, []).append({
            "value": value,
            "unit": normalized_unit,
            "precision": precision
        })

    assignment: Dict[Tuple[float, str | None, int], Tuple[float, str | None]] = {}
    canonical_values: Set[Tuple[float, str | None]] = set()

    for unit_entries in entries_by_unit.values():
        unit_assignment, unit_canonicals = _cluster_unit_entries(unit_entries)
        assignment.update(unit_assignment)
        canonical_values.update(unit_canonicals)

    sorted_canonicals = sorted(
        canonical_values,
        key=lambda item: (item[1] or "", item[0])
    )
    return sorted_canonicals, assignment

def _map_dosages_to_canonical(dosage_strings: List[str], assignment: Dict[Tuple[float, str | None, int], Tuple[float, str | None]]) -> List[Tuple[float, str | None]]:
    mapped: List[Tuple[float, str | None]] = []
    seen: Set[Tuple[float, str | None]] = set()
    for dosage in dosage_strings:
        value, unit, precision = parse_dosage(dosage)
        if value is None:
            continue
        normalized_unit = unit.strip().lower() if isinstance(unit, str) else None
        key = _dosage_key(value, normalized_unit, precision)
        canonical = assignment.get(key, (normalize_dosage_value(value), normalized_unit))
        if canonical not in seen:
            mapped.append(canonical)
            seen.add(canonical)
    return mapped


def _fallback_dosages_from_names(names: List[str]) -> List[Tuple[float, str | None]]:
    collected: List[str] = []
    for name in names:
        parsed = parse_medicament_name(name)
        collected.extend(parsed.get("dosages") or [])
    unique_strings = list(dict.fromkeys(collected))
    return _dosage_pairs_from_strings(unique_strings)


def _fallback_formulations_from_names(names: List[str]) -> List[str]:
    collected: List[str] = []
    for name in names:
        parsed = parse_medicament_name(name)
        formulation = parsed.get("formulation")
        if formulation:
            collected.append(formulation)
    unique = list(dict.fromkeys(collected))
    return unique


def _dosage_pairs_from_strings(dosage_strings: List[str]) -> List[Tuple[float, str | None]]:
    pairs: List[Tuple[float, str | None]] = []
    for dosage_str in dosage_strings:
        value, unit, _ = parse_dosage(dosage_str)
        normalized_unit = unit.strip().lower() if isinstance(unit, str) else None
        if value is None:
            micronise_match = re.search(
                r"(\d+(?:[.,]\d+)?)\s*(?:mg)?\s+micronis", dosage_str, re.IGNORECASE
            )
            if micronise_match:
                value = float(micronise_match.group(1).replace(",", "."))
                normalized_unit = "mg"
        if value is None:
            continue
        pairs.append((normalize_dosage_value(value), normalized_unit))
    return pairs

def _format_dosage_key(entries: List[Tuple[float, str | None]]) -> str:
    if not entries:
        return "N/A"
    formatted = []
    for value, unit in entries:
        unit_part = unit if unit else ""
        formatted.append(f"{value:g} {unit_part}".strip())
    return "; ".join(formatted)

def _count_decimal_places(number_str: str) -> int:
    cleaned = number_str.strip()
    if not cleaned:
        return 0
    cleaned = cleaned.replace(" ", "")
    separator = "." if "." in cleaned else ","
    if separator not in cleaned:
        return 0
    decimals = cleaned.split(separator, 1)[1]
    decimals_digits = "".join(ch for ch in decimals if ch.isdigit())
    return len(decimals_digits)

def _round_half_up(value: float, precision: int) -> float:
    factor = 10 ** precision
    return math.floor(value * factor + 0.5) / factor

def _truncate_to_precision(value: float, precision: int) -> float:
    if precision < 0:
        return value
    factor = 10 ** precision
    return math.floor(value * factor) / factor

def _dosage_key(value: float, unit: str | None, precision: int) -> Tuple[float, str | None, int]:
    return (round(value, 6), unit, precision)

def _build_synthetic_group_title(result: Dict[str, Any]) -> str:
    base_name = result.get("princeps_brand_name", "N/A") or "N/A"
    if base_name == "N/A":
        base_name = " / ".join(result.get("common_active_ingredients", []))
    base_name = base_name or "Groupe non identifié"

    dosage_parts = [
        f"{val:g} {unit if unit else ''}".strip()
        for val, unit in result.get("distinct_dosages", [])
    ]
    dosages_segment = ", ".join([part for part in dosage_parts if part])

    formulations_segment = ", ".join(
        [form for form in result.get("distinct_formulations", []) if form]
    )

    segments = [seg for seg in [base_name, dosages_segment, formulations_segment] if seg]
    if result.get("group_type") == "Complémentarité posologique":
        segments.insert(0, "[POSO. COMPL.]")
    return " | ".join(segments)

def classify_product_group(group_id: str, dfs: Dict[str, pd.DataFrame]) -> Dict[str, Any]:
    gener = dfs["CIS_GENER_bdpm.txt"]
    compo = dfs["CIS_COMPO_bdpm.txt"]
    specialites = dfs["CIS_bdpm.txt"]
    group_rows = gener[gener['group_id'] == group_id]
    group_members_cis = set(group_rows['cis'].unique())
    if not group_members_cis: return {"error": "Group ID not found"}
    member_details = specialites[specialites['cis'].isin(group_members_cis)]
    princeps_cis = set(group_rows[group_rows['type_generique'] == 0]['cis'])
    princeps_names = member_details[member_details['cis'].isin(princeps_cis)]['nom_specialite'].tolist()
    common_name = find_common_princeps_name_py(princeps_names)
    princeps_brand_name = derive_brand_name(common_name) if common_name != "N/A" else "N/A"
    has_poso_compl = (group_rows['type_generique'] == 2).any()
    group_type = "Complémentarité posologique" if has_poso_compl else "standard"

    active_compositions = compo[(compo['cis'].isin(group_members_cis)) & (compo['nature_composant'] == 'SA')]
    substances_by_cis = active_compositions.groupby('cis')['denomination_substance'].apply(set)
    
    common_ingredients: List[str] = []
    fallback_used = False
    total_members = len(group_members_cis)
    members_without_pa = group_members_cis - set(substances_by_cis.index)
    missing_data_ratio = (len(members_without_pa) / total_members) if total_members else 0
    valid_sets = [s for s in substances_by_cis if s]
    if valid_sets:
        ranked = {}
        total_valid = len(valid_sets)
        for subset in valid_sets:
            for ingredient in subset:
                ranked[ingredient] = ranked.get(ingredient, 0) + 1
        common_ingredients = [
            ingredient for ingredient, count in ranked.items()
            if count / total_valid >= 0.6  # keep ingredients present in >=60% of valid members
        ]
    
    # **FALLBACK LOGIC**
    if not common_ingredients and missing_data_ratio > 0.2:
        group_libelle = gener[gener['group_id'] == group_id]['libelle_groupe'].iloc[0]
        extracted = _extract_pa_from_libelle(group_libelle)
        if extracted:
            common_ingredients = extracted
            fallback_used = True

    relevant_dosages = active_compositions[active_compositions['denomination_substance'].isin(common_ingredients)]
    structured_dosages, dosage_assignment = _cluster_dosages(relevant_dosages['dosage_substance'].dropna().tolist())
    primary_dosage = None
    member_names = member_details['nom_specialite'].dropna().tolist()
    fallback_dosages = _fallback_dosages_from_names(member_names)
    has_ratio_fallback = any(
        (unit or "").find("/") != -1 for _, unit in fallback_dosages
    )
    has_ratio_structured = any(
        (unit or "").find("/") != -1 for _, unit in structured_dosages
    )
    if fallback_dosages:
        if (not structured_dosages) or (has_ratio_fallback and not has_ratio_structured):
            structured_dosages = fallback_dosages
    if not has_poso_compl and structured_dosages:
        first_val, first_unit = structured_dosages[0]
        primary_dosage = f"{first_val:g} {first_unit if first_unit else ''}".strip()
    
    raw_formulations = set(member_details['forme_pharmaceutique'].dropna().unique())
    unique_formulations = sorted({categorize_formulation(f) for f in raw_formulations})
    if not unique_formulations:
        fallback_formulations = _fallback_formulations_from_names(member_names)
        if fallback_formulations:
            unique_formulations = fallback_formulations

    grouped_generics = {}
    generic_cis = group_members_cis - princeps_cis
    generic_details = member_details[member_details['cis'].isin(generic_cis)]
    
    generic_base_name = " / ".join(sorted(list(common_ingredients)))
    
    for _, row in generic_details.iterrows():
        cis = row['cis']
        full_name = row['nom_specialite']
        base_name_to_use = generic_base_name if generic_base_name else derive_brand_name(full_name)
        
        cis_dosages = active_compositions[active_compositions['cis'] == cis]['dosage_substance'].dropna().tolist()
        normalized_entries = _map_dosages_to_canonical(cis_dosages, dosage_assignment)
        fallback_pairs = _dosage_pairs_from_strings(
            parse_medicament_name(full_name).get("dosages") or []
        )
        has_ratio_fallback = any((unit or "").find("/") != -1 for _, unit in fallback_pairs)
        has_ratio_normalized = any((unit or "").find("/") != -1 for _, unit in normalized_entries)
        if fallback_pairs and (not normalized_entries or (has_ratio_fallback and not has_ratio_normalized)):
            normalized_entries = fallback_pairs
        dosage_key = _format_dosage_key(normalized_entries)
        canonical_dosage_signature = tuple(normalized_entries) if normalized_entries else (("N/A", None),)
        product_key = (base_name_to_use, canonical_dosage_signature)
        
        if product_key not in grouped_generics:
            grouped_generics[product_key] = {
                "base_name": base_name_to_use,
                "dosage": dosage_key,
                "laboratories": set(),
                "presentations": []
            }
        
        lab_string = row['titulaires']
        if lab_string and isinstance(lab_string, str):
            labs = [lab.strip() for lab in lab_string.split(';') if lab.strip()]
            grouped_generics[product_key]["laboratories"].update(labs)
        grouped_generics[product_key]["presentations"].append(full_name)
    
    normalized_grouped_generics = {}
    for key, info in grouped_generics.items():
        normalized_key = f"{info['base_name']} | {info['dosage']}"
        normalized_grouped_generics[normalized_key] = {
            "base_name": info["base_name"],
            "dosage": info["dosage"],
            "laboratories": sorted(list(info["laboratories"])),
            "presentations": info["presentations"]
        }

    result = {
        "group_id": group_id, "princeps_brand_name": princeps_brand_name,
        "common_active_ingredients": sorted(list(common_ingredients)),
        "distinct_dosages": structured_dosages, "distinct_formulations": unique_formulations,
        "grouped_generics": normalized_grouped_generics, "member_count": len(group_members_cis),
        "princeps_count": len(princeps_cis), "members_without_pa": len(members_without_pa),
        "members_without_pa_list": sorted(list(members_without_pa)),
        "is_fallback_used": fallback_used,
        "conditions_prescription": None,
        "statut_disponibilite": None,
        "group_type": group_type,
        "primary_dosage": primary_dosage
    }
    result["synthetic_group_title"] = _build_synthetic_group_title(result)
    return result

def _collect_parsing_diagnostics(
    group_id: str,
    dfs: Dict[str, pd.DataFrame],
    missing_pa_cis: Set[str] | None = None,
):
    gener = dfs["CIS_GENER_bdpm.txt"]
    specialites = dfs["CIS_bdpm.txt"]
    member_rows = gener[gener["group_id"] == group_id]
    member_cis = member_rows["cis"].unique().tolist()
    members = specialites[specialites["cis"].isin(member_cis)][["cis", "nom_specialite"]]
    name_by_cis = dict(zip(specialites["cis"], specialites["nom_specialite"]))

    if member_cis and members.empty:
        return ["    Aucun membre présent dans CIS_bdpm pour ce groupe.\n"], False, 0, False
    if not member_cis:
        return ["    Aucun membre trouvé pour ce groupe.\n"], False, 0, False

    lines = ["\n  --- Analyse de Parsing des Noms ---\n"]
    parsing_issue = False
    missing_pa_cis = set(missing_pa_cis or set())
    missing_with_name = {cis for cis in missing_pa_cis if cis in name_by_cis}

    seen_cis: Set[str] = set()
    for _, row in members.iterrows():
        seen_cis.add(row["cis"])
        parsed = parse_medicament_name(row["nom_specialite"])
        lines.append(f"\n    -> Original: {parsed['original']}\n")
        lines.append(f"       - Nom Canonique: {parsed.get('canonical_name') or 'N/A'}\n")
        dosages_display = parsed.get("dosages") or []
        lines.append(
            f"       - Dosages: {dosages_display if dosages_display else 'N/A'}\n"
        )
        lines.append(
            f"       - Formulation: {parsed.get('formulation') or 'N/A'}\n"
        )
        reason = _parsing_issue_reason(row["nom_specialite"], parsed)
        if reason:
            parsing_issue = True
            lines.append(f"       - ISSUE: {reason}\n")
        if row["cis"] in missing_with_name:
            parsing_issue = True
            lines.append("       - ISSUE: no composition data (SA) for this CIS\n")

    unresolved_missing = sorted(missing_with_name - seen_cis)
    for cis in unresolved_missing:
        raw_name = name_by_cis.get(cis, "").strip()
        display_name = raw_name if raw_name else f"[CIS {cis} - nom indisponible]"
        lines.append(f"\n    -> Original: {display_name}\n")
        lines.append("       - Nom Canonique: N/A\n")
        lines.append("       - Dosages: N/A\n")
        lines.append("       - Formulation: N/A\n")
        lines.append("       - ISSUE: no composition data (SA) and raw record unavailable\n")
        parsing_issue = True

    return lines, parsing_issue, len(missing_with_name), True


def _has_group_issues(
    result: Dict[str, Any],
    missing_composition_count: int = 0,
    parsing_issue: bool = False,
    has_visible_members: bool = True,
) -> bool:
    if missing_composition_count > 0:
        return True
    if parsing_issue:
        return True
    if not result.get("common_active_ingredients") and has_visible_members:
        return True
    if result.get("is_fallback_used") and has_visible_members:
        needs_attention = (
            not result.get("distinct_dosages")
            or not result.get("distinct_formulations")
            or not result.get("grouped_generics")
        )
        if needs_attention:
            return True
    if not result.get("distinct_dosages") and has_visible_members:
        return True
    if not result.get("distinct_formulations") and has_visible_members:
        return True
    grouped = result.get("grouped_generics", {})
    if not grouped and result.get("member_count", 0) > 1:
        return True
    return False


def generate_classification_report(dfs: Dict[str, pd.DataFrame]):
    gener = dfs["CIS_GENER_bdpm.txt"]
    all_group_ids = sorted(gener["group_id"].unique())
    
    print("\n--- 2. Scanning groups for potential issues (max 50) ---")
    
    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write(f"// RAPPORT DE CLASSIFICATION FINAL - {pd.Timestamp.now()}\n")
        f.write("// Limité à 50 groupes présentant des anomalies potentielles\n")

        written = 0
        for group_id in all_group_ids:
            result = classify_product_group(group_id, dfs)
            (
                parsing_lines,
                parsing_issue,
                missing_with_name_count,
                has_visible_members,
            ) = _collect_parsing_diagnostics(
                group_id,
                dfs,
                missing_pa_cis=set(result.get("members_without_pa_list", [])),
            )
            if not has_visible_members:
                continue
            group_issue = _has_group_issues(
                result,
                missing_with_name_count,
                parsing_issue=parsing_issue,
                has_visible_members=has_visible_members,
            )
            if not group_issue:
                continue

            written += 1
            f.write("\n" + "="*80 + "\n")
            f.write(f"// GROUPE {written}: ANALYSE DU GROUPE ID: {group_id}\n")
            f.write("="*80 + "\n")

            if "error" in result:
                f.write(f"  ERROR: {result['error']}\n")
            else:
                f.write(f"  - Titre Canonique du Groupe: {result['synthetic_group_title']}\n")
                f.write(f"  - Nom de Marque Princeps: {result['princeps_brand_name']}\n")
                f.write(f"  - Type de Groupe: {result.get('group_type', 'standard')}\n")
                pa_source = "(Source: Intersection stricte)"
                if result.get("is_fallback_used"):
                    pa_source = "(Source: Déduit du libellé - Fallback)"
                f.write(f"  - Principes Actifs Communs: {', '.join(result['common_active_ingredients']) or 'N/A'} {pa_source}\n")
                
                dosages_str = [f"{val:g} {unit if unit else ''}".strip() for val, unit in result['distinct_dosages']]
                f.write(f"  - Dosages Distincts (Normalisés): {', '.join(dosages_str) or 'N/A'}\n")
                if result.get("primary_dosage"):
                    f.write(f"  - Dosage Principal: {result['primary_dosage']}\n")
                f.write(f"  - Formulations Catégorisées: {', '.join(result['distinct_formulations']) or 'N/A'}\n")

                if missing_with_name_count > 0:
                    f.write(
                        f"  - AVERTISSEMENT: {missing_with_name_count} membre(s) sans données de composition 'SA'.\n"
                    )

                f.write("\n  --- Génériques Groupés par Produit et Dosage Normalisé ---\n")
                if not result['grouped_generics']:
                    f.write("    Aucun générique trouvé dans ce groupe.\n")
                else:
                    for key, group_info in sorted(result['grouped_generics'].items()):
                        f.write(f"\n    -> Produit Canonique: {group_info['base_name']} ({group_info['dosage']})\n")
                        f.write(f"       - Présentations Commerciales: {len(group_info['presentations'])}\n")
                        f.write(f"       - Laboratoires: {', '.join(group_info['laboratories'])}\n")
                
                f.write(f"\n  - Résumé: {result['member_count']} membres ({result['princeps_count']} princeps)\n")
                for line in parsing_lines:
                    f.write(line)
            f.write("="*80 + "\n")
            if written >= MAX_REPORT_COUNT:
                break

        if written == 0:
            f.write("\nAucune anomalie potentielle détectée dans les groupes analysés.\n")

    print(f"\n✅ Rapport de classification final généré ({written} groupe(s)) : {REPORT_FILE}")
    print(f"\n✅ Rapport de classification final généré : {REPORT_FILE}")

def main():
    dfs = load_data()
    generate_classification_report(dfs)

if __name__ == "__main__":
    main()