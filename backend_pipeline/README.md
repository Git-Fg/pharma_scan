# PharmaScan Backend Pipeline (ETL)

Le moteur de données (Backend/ETL) pour l'application mobile **PharmaScan**.
Ce projet convertit les données brutes de l'ANSM (BDPM) en une base de données relationnelle SQLite (`reference.db`) embarquée, optimisée pour le **Scan** (Identification précise) et l'**Explorer** (Recherche par concept).

---

## 🎯 Philosophie & Objectifs

### 1. Mode Scan : Rigueur absolue (100% Fiable)
Lorsqu'un utilisateur scanne un code barre (CIP), l'application doit identifier le médicament exact et son **Princeps** (référence) pour valider la substitution.

* **Source de vérité :** Groupes Génériques officiels (`CIS_GENER`).
* **Garantie :** Si deux médicaments partagent le même `group_id`, ils sont légalement substituables.
* **Résolution du Princeps :**
    * Basée sur le "Type 0" dans le groupe générique.
    * Fallback sur parsing du libellé pour les orphelins.

### 2. Mode Explorer : Clustering "Concept-First"
Pour la recherche et le listing, l'utilisateur veut voir "AMOXICILLINE" et non 50 lignes de variations.

* **Clustering :** Regroupement par "Concept Thérapeutique" (Substance ou Marque).
* **Stratégie Hybride :** Utilise le groupe générique quand il existe, sinon un clustering par substance active + dosage.
* **Affichage Simplifié :** Le cluster présente une "Composition Canonique" (vote majoritaire des substances) pour éviter la pollution visuelle des variations mineures de sels (ex: "Amoxicilline trihydratée" → "AMOXICILLINE").

---

## 🏗️ Architecture du Code (`src/`)

Le code a été refactorisé pour être modulaire, fortement typé et séquentiel.

| Fichier | Rôle | Description |
| :--- | :--- | :--- |
| **`index.ts`** | **Orchestrateur** | Coordonne les étapes du pipeline. ~900 lignes. Séquentiel. Logging clair. |
| **`db.ts`** | **Database Layer** | Gestion SQLite via `bun:sqlite`. Contient toutes les requêtes SQL et la logique d'agrégation (`medicament_summary`). Typage strict (pas de `any`). |
| **`parsing.ts`** | **Ingestion** | Parse les fichiers plats BDPM (Windows-1252). Gère les incohérences de format. Extrait les formes et voies. |
| **`sanitizer.ts`** | **Nettoyage** | Logique métier de normalisation : retrait des accents, stripping des sels ("Chlorhydrate de..."), masquage galénique. |
| **`clustering.ts`** | **Intelligence** | Algorithmes de regroupement (LCP - Longest Common Prefix) et construction des vecteurs de recherche. |
| **`utils.ts`** | **Utilitaires** | Helpers I/O, parsing prix/dates. |
| **`types.ts`** | **Modèles** | Définitions TypeScript et Zod schemas pour la validation des données. |

---

## 🔄 Le Pipeline (Étape par Étape)

L'exécution de `bun run build` lance les étapes suivantes :

### 1. Ingestion & Parsing (`parsing.ts`)
* Lecture des fichiers sources (`data/*.txt`).
* Parsing tolérant aux fautes de formatage de la BDPM.
* **Intelligence Composition** : Sélection du meilleur composant (Fraction Thérapeutique > Substance Active) pour chaque lien de composition, évitant les doublons.

### 2. Sanitization (`sanitizer.ts`)
* **Normalisation Chimique** : `computeCanonicalSubstance` nettoie les noms de substances (ex: "MÉMANTINE (CHLORHYDRATE DE)" → "MEMANTINE").
* **Masque Galénique** : Extraction propre du nom de marque (ex: "DOLIPRANE 1000 mg, comprimé" - "comprimé" = "DOLIPRANE 1000 mg").

### 3. Clustering & Aggregation (`db.ts` & `clustering.ts`)
* **Calcul des Clusters** : Regroupement des génériques et orphelins.
* **Construction de `medicament_summary`** : Vue matérialisée optimisée pour le mobile. Contient toutes les infos nécessaires à l'affichage (évite les jointures coûteuses sur le téléphone).
* **Harmonisation** :
    * **Vote Majoritaire** : Détermine la composition la plus fréquente d'un groupe.
    * **Super-Vote** : Harmonisation au niveau cluster pour une liste "Substance Only" propre.

### 4. Indexation Recherche (`fts`)
Création de la table virtuelle `search_index` (FTS5).

---

## 🔎 Logique de Recherche (Dual Search)

Le système de recherche est conçu pour être tolérant aux fautes et exhaustif.

### 1. Vecteur de Recherche Hybride
La fonction `buildSearchVector` (`clustering.ts`) construit un document indexé contenant :
* **Marques** : "CLAMOXYL", "Doliprane", "Advil".
* **Substances** : "Amoxicilline", "Paracétamol", "Ibuprofène".
* **Princeps** : Références historiques.

Cela permet à l'utilisateur de trouver un médicament en cherchant soit son nom commercial, soit sa substance active.

### 2. Tokenizer Trigram (FTS5)
Utilisation du tokenizer `trigram` de SQLite.
* Découpe les mots en segments de 3 lettres.
* Permet la recherche **Fuzzy** (approximative) nativement.
* Exemple : Une recherche "dolipprane" (faute de frappe) matchera "DOLIPRANE" car ils partagent une majorité de trigrammes.

---

## 🛠️ Commandes & Scripts

Le projet utilise **Bun** pour la rapidité d'exécution.

### Principales
```bash
# Pipeline Complet (Téléchargement + Build + Export Schema + Audit)
bun run preflight

# Build uniquement (Génération de reference.db + Tests)
bun run build

# Lancer les tests
bun test
```

### Utilitaires
```bash
# Télécharger les fichiers BDPM à jour
bun run download

# Exporter le schéma SQL pour Drift (Flutter)
bun run export

# Lancer l'audit de données (génère data/audit/*.json)
bun run tool
```

### Audit (`tool/audit_data.ts`)
Génère des rapports JSON dans `data/audit/` pour vérifier la qualité des données :
* `1_clusters_catalog.json` : Liste des clusters et leurs noms canoniques.
* `2_group_catalog.json` : Stats sur les groupes génériques.
* `3_samples_detailed.json` : Échantillon pour validation humaine.

---

## 📦 Structure de la Base (`reference.db`)

Le schéma est aligné avec le code Dart (`lib/core/database/database.dart`).

* **`medicament_summary`** : Table pivot. Contient `cis_code`, `cluster_id`, `group_id`, et les données JSON pré-calculées (compositions, labo, etc.).
* **`search_index`** : Table virtuelle FTS5 (Unindexed `cluster_id`, Indexed `search_vector`).
* **`cluster_names`** : Table de mapping `cluster_id` → `label` (Nom canonique d'affichage).
* **`ref_substances`** : Référentiel des substances uniques.
* **`generique_groups`** : Données officielles des groupes de substitution.

---

## ⚠️ Notes Techniques

1. **Fiabilité BDPM** : Le parser est défensif. Il rejette les lignes corrompues mais loggue les erreurs.
2. **Synchronisation** : Après chaque modification de schéma (`src/db.ts`), lancez `bun run export` pour mettre à jour `reference_schema.drift` pour l'app mobile.
3. **Performance** : L'utilisation de `bun:sqlite` et des Transactions/Prepared Statements rend la génération très rapide (< 10s pour ~20k médicaments).
