# Guide des Scripts du Pipeline

Ce document détaille les scripts techniques utilisés pour la maintenance et le développement du pipeline.

## 📂 Organisation

* **`src/`** : Code source du pipeline (Logique métier).
* **`scripts/`** : Scripts shell et TS pour les opérations de maintenance (Download, Export).
* **`tool/`** : Outils d'audit et de validation de la qualité des données.

## 🛠️ Scripts de Maintenance

### 1. Téléchargement BDPM (`scripts/download_bdpm.ts`)
* **Commande** : `bun run download`
* **Rôle** : Télécharge les fichiers officiels depuis `base-donnees-publique.medicaments.gouv.fr`.
* **Détail** :
    * Utilise `fetch` pour récupérer les fichiers `.txt`.
    * Convertit l'encodage Windows-1252 (original) en mémoire lors du parsing (géré par `parsing.ts` ensuite).
    * Sauvegarde dans `data/`.

### 2. Export du Schéma (`scripts/dump_schema.sh`)
* **Commande** : `bun run export`
* **Rôle** : Synchronise le schéma de la base de données avec l'application Flutter.
* **Fonctionnement** :
    * SQLite n'a pas de typage fort natif, mais l'app Flutter utilise **Drift**.
    * Ce script extrait le schéma `CREATE TABLE` de `reference.db`.
    * Il génère/met à jour un fichier `.drift` (si configuré) ou simplement prépare les définitions pour l'intégration mobile.

## 🔍 Outils d'Audit (`tool/`)

### 1. Audit Général (`tool/audit_data.ts`)
* **Commande** : `bun run tool`
* **Rôle** : Génère les artefacts de validation dans `data/audit/`.
* **Sorties** :
    * `1_clusters_catalog.json` : La "Carte d'identité" de chaque cluster (Nom, Princeps, Nombre de produits).
    * `2_group_catalog.json` : Analyse des groupes génériques (Taux de conversion, Noms orphelins).
    * `3_samples_detailed.json` : Échatillon de 200 produits pour vérification manuelle "Spot Check".

### 2. Audit Qualité Cluster (`tool/audit_LCP_quality.ts`)
* **Exécution** : `bun run tool/audit_LCP_quality.ts`
* **Rôle** : Détecte les anomalies de clustering.
* **Vérifications** :
    * **Short Names** : Alerte si un cluster a un nom < 4 caractères (ex: risque de mauvais découpage LCP).
    * **Split Clusters** : Alerte si une même substance (ex: "PARACETAMOL") est éclatée en plusieurs clusters sans raison apparente (hors dosages différents).

### 3. Inspecteur (`tool/inspect_cluster.ts`)
* **Exécution** : `bun run tool/inspect_cluster.ts`
* **Rôle** : Script manuel pour investiguer des clusters spécifiques.
* **Usage** : Modifier le tableau `targetClusters` dans le fichier pour cibler des IDs (ex: `CLS_xxxx`) et voir le contenu exact (membres, princeps, etc.).

## 🚀 Workflow de Release (CI/CD)

Le workflow typique pour mettre à jour la base de données :

1. `bun run download` : Récupérer les nouvelles données.
2. `bun run build` : Reconstruire `reference.db` et lancer les tests.
3. `bun run tool` / `bun run tool/audit_LCP_quality.ts` : Vérifier qu'aucune régression de data n'est apparue (Split clusters, Noms bizarres).
4. `bun run export` : Préparer le schéma si la structure a changé.
5. Commit & Push.
