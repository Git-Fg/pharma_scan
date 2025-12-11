# Backend ETL Pipeline

Construit la base SQLite `data/reference.db` consommée par l’app Flutter à partir des fichiers BDPM bruts (TXT win1252). Document de référence pour dev : pipeline, parsers, schéma et outils d’audit/export.

## Prérequis & commandes clés

- Installer les deps : `bun install`
- Générer la base complète (télécharge les fichiers BDPM et reconstruit `data/reference.db`) :
  - `bun run build:db` (alias : `bun run src/index.ts`)
- Export explorer (payload JSON pour le frontend) :
  - `bun run tool/export_preview.ts` → `data/explorer_view.json`
- Audit clustering :
  - `bun run tool/audit_unified.ts` → `data/audit_unified_report.json` (ignore produits arrêtés)
- Tests : `bun test` (exécute aussi `tool/audit_unified.ts`)
- Preflight complet (DB + tests + outils) : `bun run preflight` (génère la base une seule fois puis réutilise `data/reference.db` pour exporter/auditer)

## Fichiers BDPM consommés

Tous sont téléchargés automatiquement dans `data/` :

- `CIS_bdpm.txt` : spécialités (CIS, libellé, forme, **statut commercial col 6**, type_procedure col 5, surveillance_renforcee col 11)
- `CIS_CIP_bdpm.txt` : présentations (CIP13, prix, remboursement)
- `CIS_GENER_bdpm.txt` : groupes génériques (liaison CIS ↔ group_id + generic_type)
- `CIS_CPD_bdpm.txt` : conditions de prescription/dispensation (Listes, stupéfiants…)
- `CIS_CIP_Dispo_Spec.txt` : tensions/ruptures (CIP ou CIS)
- `CIS_COMPO_bdpm.txt` : composition (codes substances, nature SA/FT, dosage)
- `CIS_MITM.txt` : ATC/mitm (chargé dans `dependencyMaps.atc` pour usages futurs)

## Vue d’ensemble du pipeline (`src/index.ts`)

1. **Download** : fetch des TXT BDPM (incl. MITM) vers `data/`.
2. **Pré-matérialisation parallèle** : `CIS_CPD`, `CIS_COMPO`, `CIS_CIP`, `CIS_GENER`, `CIS_CIP_Dispo_Spec`, `CIS_MITM` chargés dans des `Map` typées (`DependencyMaps` + `atc`). Pattern *skip & log* : lignes invalides ignorées sans stopper le pipeline.
3. **Hydratation produits (CIS) via hash join mémoire** :
   - `processStream` lit `CIS_bdpm.txt`, enrichit via Maps (conditions, composition, generics, availability, ATC) + `manufacturerResolver` (clustering heuristique des titulaires).
   - Composition : `buildComposition` (FT > SA) + `resolveComposition` (préférence CIS_COMPO, fallback regex libellé). `composition_codes` triés, `composition_display` prêt pour l’UI.
   - Métadonnées : `parseRegulatoryInfo` (Listes I/II, stup, hospitalier, dentaire), `parseDateToIso`, `generic_type` depuis `CIS_GENER`; `group_id` reste `null` jusqu’à la phase groupes.
4. **Signatures de composition & propagation** :
   - `computeCompositionSignature` reste calculée pour audits/comparaisons (FT > SA, dédupli sel) mais n’est plus la clé primaire du clustering.
   - Propagation intra-groupe BDPM conservée pour stabiliser les signatures et outiller les vérifications.
5. **Groupes & clustering (Tiroir, top-down)** :
   - Canonique groupe : priorité type 0 `CIS_GENER` → libellé CIS princeps nettoyé (`stripFormFromCisLabel` retire forme/dosage après virgule) ; fallback parsing texte `CIS_GENER` (partie droite du dernier “ - ” nettoyée via `cleanPrincepsCandidate`), fallback DCI (partie gauche du premier “ - ”).
   - Champs stockés dans `groups` : `canonical_name`, `historical_princeps_raw`, `generic_label_clean`, `naming_source` (`TYPE_0_LINK` ou `GENER_PARSING`), `princeps_aliases` (tous les type 0), `routes` (union des voies CIS du groupe), `safety_flags` (aggregation CPD : liste I/II, stup, hospitalier, dentaire).
   - `generateClusterId` = `CLS_{NORMALIZED_NAME}` (déterministe). Les clusters prennent `canonical_name` comme `label/princeps_label`.
   - Les groupes homonymes (ex: DOLIPRANE 500/1000) fusionnent dans un cluster unique. Produits sans groupe sont rattachés par nom nettoyé ou créent un cluster s’il n’existe pas. `group_id`, `generic_type`, `is_princeps` propagés via `updateProductGrouping`.
6. **Présentations (CIP13)** :
   - Insertion uniquement si CIS connu ; prix via `parsePriceToCents`.
   - Ruptures/tensions : résolution `shortageMap` par CIP13 prioritaire puis CIS, stockée en `availability_status` sous la forme `code:label` + `ansm_link`.
   - `market_status` capturé depuis `CIS_CIP` (col 5) et forcé à “Non commercialisée” si le CIS l’est ; `date_commercialisation` normalisée via `parseDateToIso`.
7. **Finalisation** :
   - FTS trigramme (`search_index`) prérempli depuis `products.label` (normalized_text identique).
   - `VACUUM; ANALYZE;` pour compacter/optimiser.

### Hybrid Join (BDPM > Regex)

- `composition_display` : priorité aux données BDPM (`CIS_COMPO_bdpm.txt`), fallback regex sur libellé brut.
- `composition` : JSON structuré par `element` avec fusion SA/FT (FT supprime SA). Multi-formes conservées.
- `drawer_label` : princeps du groupe (type 0) en priorité, fallback `normalizeString` du libellé produit.
- Maps `compoMap`, `genericsMap`, `groupMasterMap` chargées avant produits pour garantir la priorité “données officielles > regex”.

### Règle d’architecture

Toutes les dépendances (composition, conditions, présentations, disponibilité, generics, ATC) sont chargées avant les produits. Aucune insertion produit si les maps satellites ne sont pas complètes, filtrant CIP/CIS orphelins.

## Parsers et règles métier (`src/logic.ts`)

- **`normalizeString`** : upper, déaccentuation, corrections typos ciblées, hints de forme (CREME, COLLYRE, INJECTABLE…), suppression sels (`SALT_PREFIXES/SALT_SUFFIXES`), formes orales (`ORAL_FORM_TOKENS`), dosage/unité, bag-of-words, dédup tokens. Nettoie aussi les adjectifs bruités (FAIBLE/FORT/MITIE/ENFANT/ADULTE/NOURRISSON…) sans impacter les mots composés (FORTZAAR préservé).
- **`normalizeManufacturerName` + `createManufacturerResolver`** : nettoyage titulaire + clustering heuristique (tokens inclusifs, préfixe commun, Levenshtein < 3), retourne id stable + label le plus court.
- **`isHomeopathic`** : heuristique unique (labos, codes L/COMPLEXE, motifs CH/DH/LM/CK, marques Lehning/Boiron) partagée par pipeline et outils d’audit.
- **`parsePriceToCents`** : dernière virgule comme décimale, espaces/points supprimés, centimes arrondis ou `null`.
- **`parseRegulatoryInfo`** : flags `list1`, `list2`, `narcotic`, `hospital`, `dental` depuis CPD (agrégés au niveau groupe dans `safety_flags`).
- **`parseDateToIso`** : `DD/MM/YYYY` → `YYYY-MM-DD` ou `null`.
- **`buildComposition`** : agrège SA/FT, FT prime, codes substances triés (exclut `0`), noms normalisés (`normalizeIngredientName`).
- **`computeCompositionSignature`** : signature déterministe dédupliquée par base moléculaire (sels supprimés) en utilisant d’abord le nom de substance normalisé comme token (`N:`), codes substances uniquement en secours ; tri alphabétique des tokens pour stabilité.
- **`cleanProductLabel`** : supprime dosage/formes pour garder la marque brute.
- **`parseGroupLabel` / `splitGroupLabelFirst|Loose`** : split tolérant sur “ - ” (dernier pour reference princeps, premier pour DCI) pour alimenter `canonical_name`/fallbacks.
- **`resolveDrawerLabel`** : préférence marque princeps du groupe, fallback libellé normalisé.

## Schéma SQLite généré (`src/db.ts`)

- `clusters(id, label, princeps_label, substance_code, text_brand_label)` — `id` dérivé du nom canonique (pas de suffixe signature).
- `groups(id, cluster_id → clusters.id, label, canonical_name, historical_princeps_raw, generic_label_clean, naming_source, princeps_aliases JSON, safety_flags JSON, routes JSON)`
- `manufacturers(id, label UNIQUE)`
- `products(cis, label, is_princeps, generic_type, group_id → groups.id, form, routes, type_procedure, surveillance_renforcee INTEGER, manufacturer_id → manufacturers.id, marketing_status, date_amm, regulatory_info JSON, composition JSON, composition_codes JSON, composition_display TEXT, drawer_label TEXT)`
- `presentations(cip13, cis → products.cis, price_cents, reimbursement_rate, market_status, availability_status, ansm_link, date_commercialisation)`
- `search_index(label, normalized_text, cis UNINDEXED)` — FTS5 trigram pour recherche instantanée.

## Artefacts générés

- `data/reference.db` : base finale.
- `data/explorer_view.json` : vue agrégée (clusters → groups → products) pour le frontend, badges génériques/réglementaires, prix min CIP13 par CIS, manufacturer joint, première `date_commercialisation` par CIS.
- `data/audit_unified_report.json` : audit combiné (split brands, permutations, fuzzy filtré, redondances composition).
- `data/clustering_audit*.json` : audits spécialisés (permutations TF-IDF/Jaccard).

## Outils d’audit & export

- `tool/export_preview.ts` : construit `data/explorer_view.json` (dédoublonne princeps, badges génériques/réglementaires, nettoie composition, joint `manufacturers`, min prix/date, ajoute `dosage` + `has_shortage` au cluster, **masque les produits arrêtés** tout en gardant les CIP pour le scan). Quand plusieurs groupes fusionnent, les références princeps extraites du libellé `CIS_GENER` alimentent `secondary_princeps_brands`.
- `tool/audit_unified.ts` : regroupe split brands, princeps fusionnés, permutations, fuzzies (seuil 0.82, filtrage bruit/splits légitimes), redondances composition ; écrit `data/audit_unified_report.json` en **ignorant les produits arrêtés**.
- `tool/verify_clusters.ts`, `tool/eval_princeps.ts`, `tool/diff_fuzzy.ts` : audits complémentaires (fuzzy delta attendu en fournissant `data/audit_unified_report.json` deux fois par défaut dans `preflight` pour éviter un fichier précédent manquant).

### Détection des produits non commercialisés (logique technique)

Objectif : conserver tous les CIP détectables pour le scan, mais exclure les produits arrêtés des exports/rapports.

Sources :

- **Produit (CIS)** : `marketing_status` (col 6 de `CIS_bdpm.txt`) stocké dans `products.marketing_status`.
- **Présentation (CIP13)** : `market_status` (col 5 de `CIS_CIP_bdpm.txt`) stocké dans `presentations.market_status`.
- **Alerte ANSM** : `availability_status` (code 3 = arrêt) et `ansm_link` depuis `CIS_CIP_Dispo_Spec.txt`.

Règle de classement « arrêté » appliquée dans `export_preview.ts` et `audit_unified.ts` :

1) Signal ANSM d’arrêt (`availability_status` contient “arrêt”) sur CIP ou CIS.
2) OU toutes les présentations d’un CIS sont en statut arrêt (`market_status` ou `availability_status` contient “arrêt”).
3) OU le CIS est “Non commercialisée” et aucune présentation active.

Propagation :

- `index.ts` force `presentations.market_status` à “Non commercialisée” si le CIS l’est.
- `export_preview.ts` compte `stopped_presentations`/`active_presentations` par CIS et exclut les produits arrêtés des clusters/stats, tout en laissant les CIP en base.
- `audit_unified.ts` applique la même logique pour ignorer les produits/cluster arrêtés dans les audits.

Effet : les CIP restent scannables, mais les produits arrêtés disparaissent des vues agrégées et des audits.

## Tests (bun test)

- `test/logic.test.ts` : normalisation chimique, parsing prix, stratégie princeps 3-tier, `generic_type` (complémentaires/substituables), `surveillance_renforcee`, `date_commercialisation`, clustering titulaires.
- `test/clustering.test.ts` : intégration clustering (fusion/séparation via codes/signatures vs labels).
- `test/audit_unified.test.ts` : bruit vs vrais doublons, permutations.
- `test/dependency_loading.test.ts` : pré-matérialisation Maps (conditions, composition, présentations, availability, generics) + résolutions CIP/CIS.

## Notes d’exploitation

- Pipeline idempotent : `data/reference.db` supprimée puis reconstruite à chaque run.
- Traitement par batch (5000 lignes) pour limiter la RAM ; streaming win1252 obligatoire.
- Présentations orphelines (CIP sans CIS) ignorées pour éviter les FK cassées ; données satellites chargées avant produits pour cohérence référentielle.
- Manufacturer resolver conserve le label le plus court rencontré pour un titulaire (cohérence UI).

---

### Règle Tiroir (Brand-first)

- Princeps (type 0) du groupe = nom canonique (après nettoyage forme/dosage via `stripFormFromCisLabel`).
- Si plusieurs candidats, scoring : +10 si type 0, +20 si golden (sort=1), -50 si le libellé commence par la molécule normalisée (pénalise les auto-génériques style “FLUCONAZOLE PFIZER”). Égalité départagée par le libellé le plus court.
- Sinon partie droite du dernier “ - ” du libellé groupe (`CIS_GENER`) nettoyée via `cleanPrincepsCandidate` ; DCI (partie gauche du premier “ - ”) conservée en `generic_label_clean`.
- `naming_source` consigne la provenance (`TYPE_0_LINK`, `GOLDEN_PRINCEPS` ou `GENER_PARSING`), `princeps_aliases` stocke tous les type 0 pour audit/affichage secondaire.

### Métadonnées (rappels)

- Shortage reste au niveau présentation (`availability_status = code:label`) ; listes/stup/hospitalier/dentaire agrégés au niveau groupe si au moins un membre le porte (`safety_flags`).
- Dose/FT homogène dans un groupe princeps/générique ; prix restent par présentation (souvent `null`).
