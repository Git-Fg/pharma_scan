# PharmaScan ETL Pipeline

Ce projet est le moteur de données (Backend/ETL) pour l'application mobile **PharmaScan**.
Son rôle est de convertir les données brutes de l'ANSM (BDPM) en une base de données relationnelle SQLite (`reference.db`) embarquée et optimisée pour deux usages distincts : le **Scan** et l'**Exploration**.

## 🎯 Philosophie & Objectifs

L'architecture de la base de données répond à une double contrainte :

### 1. Mode Scan : Rigueur & Substituabilité (100% Fiable)

Lorsqu'un utilisateur scanne une boîte (CIP), l'application doit identifier le médicament exact et son **Princeps** (médicament de référence) pour valider le rangement ou l'équivalence.

* **Logique :** Basée strictement sur les groupes génériques officiels.
* **Garantie :** Si deux médicaments partagent le même `group_id` (issu de `CIS_GENER`), ils sont officiellement substituables.
* **Identification du Nom (Le "Clamoxyl") :**
    1. **L'Ancre :** On part de l'`id_groupe_generique` (CIS_GENER).
    2. **Le Pivot :** On cherche dans ce groupe la ligne où `type_generique` vaut **`0`** (le Princeps).
    3. **Résolution :**
        * *Cas Nominal :* Le Type 0 existe. On récupère son nom via `CIS_bdpm.txt` et on applique le **Masque Galénique Relationnel** pour nettoyer le nom (ex: `"CLAMOXYL 500 mg, gélule"` → `"CLAMOXYL 500 mg"`).
        * *Cas Orphelin :* Pas de Type 0 (ex: retiré du marché). On parse le `libelle_groupe` (ex: `MOLECULE dos - PRINCEPS dos`) pour extraire la partie droite (le nom historique).

### 2. Mode Explorer : Confort & Regroupement (Cluster "Oral-First")

Dans l'interface de recherche ou de listing, afficher 15 variations d'Amoxicilline pollue la vue. Nous créons donc une surcouche de **Clustering**.

* **Logique :** Regroupement par "Concept Thérapeutique" (ex: "AMOXICILLINE" ou "CLAMOXYL").
* **Stratégie "Oral-First" :**
  * Le clustering est agressif pour simplifier la vue "tiroir à pharmacie".
  * **Pas de distinction stricte des voies d'administration** dans le clustering : la donnée source étant trop hétérogène, nous acceptons de regrouper un sachet et un comprimé sous la même bannière visuelle pour ne pas éclater la liste. L'utilisateur sait que ce regroupement est indicatif.

---

## 🏗️ Architecture du Pipeline

Le pipeline est écrit en TypeScript (exécuté par **Bun**) et procède en étapes linéaires. Voici l'ordre d'exécution complet :

1. **Truncate & Initialisation** : Nettoyage des tables et initialisation du schéma
2. **Ingestion** : Lecture et parsing des fichiers BDPM
3. **Raffinement** : Application du masque galénique relationnel
4. **Clustering** : Calcul des clusters et noms canoniques
5. **Vote Majoritaire (Groupe)** : Harmonisation des compositions au niveau groupe
6. **Aggrégation SQL** : Construction de la table `medicament_summary`
7. **Super-Vote (Cluster)** : Harmonisation des compositions au niveau cluster (substances uniquement)
8. **Index FTS5** : Création de l'index de recherche full-text

### 1. Ingestion & Nettoyage (`parsing.ts`)

Lecture des fichiers plats (Windows-1252) et conversion en objets structurés.

* **`CIS_bdpm`** : Fiche d'identité (Nom, Labo, Statut).
* **`CIS_CIP_bdpm`** : Codes barres (CIP13), Prix, Taux de remboursement.
* **`CIS_COMPO`** : Composition avec logique relationnelle améliorée :
  * **Groupement par `linkId`** : Les composants liés (ex: METFORMINE + CHLORHYDRATE DE METFORMINE) sont groupés par leur numéro de lien (colonne 8).
  * **Sélection optimale** : Pour chaque groupe de liens, sélection du meilleur composant selon la priorité FT (Fraction Thérapeutique) > SA (Substance Active).
  * **Garantie Atomique** : Le composant gagnant détermine **tout** (nom + dosage + unité). Si le FT gagne, on utilise strictement le dosage du FT. Cela évite les incohérences comme "Amlodipine 6.94 mg" (nom FT + dosage SA) au lieu de "Amlodipine 5 mg" (nom FT + dosage FT).
  * **Évite les doublons** : Cette approche relationnelle garantit qu'une seule entrée par groupe de liens est conservée, évitant les incohérences entre SA et FT liés.
  * **Vote Majoritaire** : Pour les groupes génériques, la composition canonique est déterminée par vote majoritaire. Si un groupe contient 50 génériques avec "Amoxicilline 1g" et 1 générique avec "Amoxicilline 1000 mg", c'est la composition majoritaire ("Amoxicilline 1g") qui est utilisée pour tous les membres du groupe, garantissant un affichage propre et cohérent dans l'Explorer.
* **`CIS_GENER`** : Le cœur du réacteur. Création des liens de substitution.

### 2. Normalisation & "Sanitization" (`sanitizer.ts`)

Nettoyage des chaînes de caractères pour la recherche et l'affichage.

#### 🎯 Protocole de Normalisation "Universelle" pour Trigram FTS5

La fonction `normalizeForSearch` implémente un protocole de normalisation **strictement linguistique** qui doit être répliqué **à l'identique** côté Flutter (`lib/core/logic/sanitizer.dart`).

**Règles :**
1. **Suppression des diacritiques** : `é` → `e`, `ï` → `i`, etc.
2. **Conversion en minuscules** : `DOLIPRANE` → `doliprane`
3. **Alphanumériques uniquement** : Remplacement de `[^a-z0-9\s]` par un espace
4. **Collapse des espaces** : Espaces multiples → espace unique
5. **Trim** : Suppression des espaces de début/fin

**Exemples :**
```
normalizeForSearch("DOLIPRANE®")       → "doliprane"
normalizeForSearch("Paracétamol 500mg") → "paracetamol 500mg"
normalizeForSearch("Amoxicilline/Acide clavulanique") → "amoxicilline acide clavulanique"
```

**Pourquoi Trigram ?** Le tokenizer FTS5 `trigram` découpe le texte en segments de 3 caractères (`dol`, `oli`, `lip`...), permettant une recherche **fuzzy native** : taper `dolipprane` (avec 2 p) trouvera quand même `DOLIPRANE` car de nombreux trigrammes se chevauchent.

#### Autres normalisations

* **`normalizeForSearchIndex`** : Normalisation chimique avancée pour l'indexation (suppression des sels, stéréo-isomères, etc.). Utilisée lors de la construction de l'index, pas lors des requêtes de recherche.
* **Masque Galénique Relationnel** (`applyPharmacologicalMask`) : Extraction du nom commercial pur en soustrayant la forme pharmaceutique connue (Colonne 3) du libellé complet (Colonne 2). Cette approche relationnelle évite les regex fragiles en exploitant directement la structure de la BDPM.
  * Exemple : `"CLAMOXYL 500 mg, gélule"` + forme `"gélule"` → `"CLAMOXYL 500 mg"`
  * Appliqué automatiquement lors du raffinement des métadonnées de groupe (Step 4) et lors du clustering (Step 5).
* **Détection des Formes Galéniques Pures** (`isPureGalenicDescription`) : Fonction utilitaire pour identifier si une chaîne de caractères ne contient que des termes de forme pharmaceutique (ex: "comprimé sécable", "solution injectable"). Utilisée pour filtrer les faux positifs dans les noms de marque lors de l'audit et de l'affichage. La liste exhaustive des mots-clés est centralisée dans `constants.ts` (`GALENIC_FORM_KEYWORDS`) pour garantir la cohérence entre le pipeline et l'application mobile.

### 3. Clustering (`clustering.ts`)

Algorithme de regroupement pour le mode Explorer.

* Calcule un `cluster_id` partagé par tous les médicaments ayant la même substance active principale et/ou liés au même princeps historique.
* Génère un nom canonique lisible pour le groupe avec stratégie hybride :
  * **Plus Long Préfixe Commun (LCP)** : Si plusieurs groupes partagent un préfixe commun (ex: "CLAMOXYL 125 mg", "CLAMOXYL 500 mg"), le nom de marque seul est extrait ("CLAMOXYL"). Cette approche mot par mot garantit un préfixe sémantiquement cohérent.
  * **Vote Pondéré** : Si le préfixe commun n'est pas significatif (< 3 caractères) ou s'il n'y a qu'un seul candidat, fallback sur un vote pondéré (poids x100 pour les princeps).
* Applique le **Masque Galénique Relationnel** sur les labels princeps avant le calcul du préfixe pour garantir des noms propres sans forme pharmaceutique (ex: `"DOLIPRANE 1000 mg, comprimé"` → `"DOLIPRANE 1000 mg"`).
* **Résultat** : Précision quand nécessaire (mono-dosage), généralisation quand possible (multi-dosages). Exemple : `["CLAMOXYL 125 mg", "CLAMOXYL 500 mg"]` → **"CLAMOXYL"**.

### 4. Vote Majoritaire pour Compositions Canoniques (`index.ts` - Étape 5bis)

Algorithme de vote majoritaire pour déterminer la composition canonique d'un groupe générique.

* **Stratégie** : Pour chaque groupe, toutes les compositions des CIS membres sont collectées, signées (triées alphabétiquement), puis comptées. La composition la plus fréquente devient la composition canonique du groupe.
* **Avantage** : Évite les incohérences d'affichage causées par des génériques mal parsés ou avec des formats différents (ex: "1g" vs "1000 mg").
* **Performance** : Calcul linéaire en mémoire (O(N)) au lieu de N sous-requêtes SQL corrélées.

### 5. Super-Vote au Niveau Cluster (`index.ts` - Étape 5ter)

Harmonisation des compositions au niveau cluster pour une expérience utilisateur unifiée dans l'Explorer.

* **Stratégie "Substance-Only"** : Vote uniquement sur les substances actives (sans dosages) pour créer des clusters conceptuels abstraits. Chaque groupe vote une fois (peu importe le nombre de CIS qu'il contient) en proposant sa liste de substances normalisées. La composition partagée par le plus grand nombre de groupes devient la composition officielle du cluster entier.
* **Avantage** : Permet de regrouper toutes les formes d'un même médicament sous le même cluster conceptuel. Par exemple, le cluster "CLAMOXYL" affichera `["AMOXICILLINE"]` pour toutes les formes (500mg, 1g, poudre, injectable), créant un véritable "tiroir à pharmacie virtuel" propre et lisible.
* **Résolution d'égalité** : En cas d'égalité parfaite, préférence pour la liste la plus courte (principe de parcimonie / rasoir d'Ockham).
* **Note de sécurité** : Cette harmonisation est purement cosmétique pour l'affichage dans `medicament_summary`. Les données brutes dans `principes_actifs` et `CIS_COMPO` restent inchangées. Les dosages spécifiques restent visibles sur la boîte physique ou le détail, mais ne polluent pas la liste principale de l'Explorer.

### 6. Construction SQL (`db.ts`)

Génération du fichier `reference.db` (SQLite).

* **Tables brutes** : `medicaments`, `specialites`, `generique_groups`.
* **Table optimisée (`medicament_summary`)** : Une vue matérialisée contenant *tout* ce dont le mobile a besoin pour afficher une ligne (Nom, dosage, forme, prix, alertes, ID cluster). Les compositions sont injectées via vote majoritaire pour les groupes, et calculées directement pour les médicaments standalone. Évite les jointures coûteuses sur mobile.
* **Index FTS5** : Table virtuelle pour la recherche instantanée.

---

## 🛠️ Utilisation

### Prérequis

* [Bun](https://bun.sh/) (Runtime JS/TS rapide)
* Les fichiers bruts BDPM dans le dossier `data/` (fichiers `.txt`)

### Commandes

```bash
# Installer les dépendances
bun install

# Lancer le pipeline complet (Génération de la DB)
bun run build

# Générer les fichiers d'audit et de prévisualisation
bun run tool

# Pipeline complet avec tests et audit (recommandé avant commit)
bun run preflight

# Pipeline sans tests (plus rapide)
bun run preflight:bp

# Exécuter les tests unitaires
bun test

# Télécharger les fichiers BDPM (manuellement ou via CI)
bun run download:bdpm

# Note: The pipeline does not download BDPM files automatically anymore. Run `bun run download:bdpm` locally or configure your CI to run it before the pipeline.
```

### Outils d'Audit (`tool/`)

Le dossier `tool/` contient des scripts d'analyse et de validation :

* **`audit_data.ts`** : Génère trois fichiers JSON dans `data/audit/` :
  * `1_clusters_catalog.json` : Catalogue complet des clusters avec métadonnées (noms canoniques, princeps, marques)
  * `2_group_catalog.json` : Catalogue des groupes génériques avec statistiques détaillées
  * `3_samples_detailed.json` : 200 exemples stratifiés pour validation manuelle
* **`export_preview.ts`** : Génère un aperçu JSON des clusters pour validation rapide

Ces outils utilisent la logique centralisée de `src/` (notamment `isPureGalenicDescription` pour filtrer les formes galéniques) garantissant la cohérence avec le pipeline principal.

### Structure de la Base de Données (`reference.db`)

Le schéma est strictement aligné sur le code Dart de l'application Flutter (`lib/core/database/database.dart`).

**Tables principales :**

* `medicament_summary` : Table principale optimisée. Contient la colonne `group_id` (Substitution légale) ET `cluster_id` (Regroupement visuel). Les compositions sont harmonisées via vote majoritaire (groupe) puis super-vote (cluster).
* `cluster_names` : Table de mapping `cluster_id` → nom canonique calculé par LCP.
* `search_index` : Index Full-Text Search (FTS5) avec tokenizer **trigram** pour recherche fuzzy native. Permet de trouver "Doliprane" en tapant "dolipprane" (typo). **Requiert SQLite 3.34+** (bundlé via `sqlite3_flutter_libs` sur mobile).
* `scanned_boxes` / `restock_items` : Tables locales utilisateur (vides à la génération, gérées par l'app).

**Tables de référence :**

* `specialites` : Fiches d'identité des médicaments (CIS).
* `medicaments` : Codes barres (CIP13) et disponibilité.
* `principes_actifs` : Substances actives normalisées (sans dosages dans `principe_normalized`).
* `generique_groups` : Groupes génériques avec métadonnées raffinées (masque galénique appliqué).
* `group_members` : Liens entre groupes et médicaments.

---

## ⚠️ Notes Techniques Importantes

1. **Fiabilité des données :** L'ANSM fournit des fichiers parfois incohérents (lignes vides, formatage date variable). Le parser (`parsing.ts`) inclut des protections contre ces cas. La logique de groupement par `linkId` garantit une meilleure cohérence dans le traitement des compositions (évite les doublons SA/FT liés).

2. **Dosages :** Les dosages sont parsés mais peuvent être complexes (ex: "1000 UI" vs "1 mg"). Le clustering tente de lisser ces différences, mais le `group_id` reste la source de vérité absolue pour la substitution. Au niveau cluster, seules les substances sont conservées (sans dosages) pour créer des concepts abstraits.

3. **Centralisation de la logique métier :** La connaissance métier (formes galéniques, normalisation, masquage) est centralisée dans `src/constants.ts` et `src/sanitizer.ts`. Les outils d'audit (`tool/`) consomment cette logique pour garantir la cohérence entre le pipeline et l'application mobile.

4. **Non-Contractuel :** L'application fournit une aide au rangement. Le clustering "Explorer" ne doit pas être utilisé pour une décision médicale stricte (ex: substitution d'une forme IV par une forme Orale), c'est pourquoi les informations critiques (Voie, Forme) restent affichées individuellement sur la fiche détail.

5. **Ordre d'exécution critique :** Le Super-Vote au niveau cluster (Étape 5ter) doit s'exécuter **après** l'assignation du `cluster_id` dans `medicament_summary`. C'est pourquoi il est placé après l'agrégation SQL et la création de la table `cluster_names`.
