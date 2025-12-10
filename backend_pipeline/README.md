# Backend ETL Pipeline

Construit la base SQLite `reference.db` consommée par l’app Flutter à partir des fichiers BDPM bruts (TXT win1252). Document de référence pour dev : pipeline, parsers, schéma et outils d’audit/export.

## Prérequis & commandes clés

- Installer les deps : `bun install`
- Générer la base complète (télécharge les fichiers BDPM et reconstruit `reference.db`) :
  - `bun run build:db` (alias : `bun run src/index.ts`)
- Export explorer (payload JSON pour le frontend) :
  - `bun run tool/export_preview.ts` → `data/explorer_view.json`
- Audits clustering :
  - `bun run tool/audit_unified.ts` → `data/audit_unified_report.json`
- Tests : `bun test` (exécute aussi `tool/audit_unified.ts`)

## Fichiers BDPM consommés

Tous sont téléchargés automatiquement dans `data/` :

- `CIS_bdpm.txt` : spécialités (CIS, libellé, forme, statut commercial…) + colonnes 5 (`type_procedure`) et 11 (`surveillance_renforcee`)
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
   - Métadonnées : `parseRegulatoryInfo`, `parseDateToIso`, `generic_type` depuis `CIS_GENER`; `group_id` reste `null` jusqu’à la phase groupes.
4. **Signatures de composition & propagation** :
   - `computeCompositionSignature` construit une signature déterministe (codes FT/SA ou noms normalisés).
   - Propagation intra-groupe BDPM : si un groupe possède une signature unique non vide, elle est appliquée aux membres sans données ; union des tokens par groupe puis par libellé pour stabiliser les signatures.
5. **Groupes & clustering** :
   - `parseGroupMetadata` (stratégie 3-tier) : préférer le libellé princeps connu, sinon split molecule/marque ; `text_brand_label` capturée si la marque textuelle diverge.
   - Clustering **signature-first** : bucket par signature de composition (`CLS_SIG_*`), princeps prioritaire comme label. Fallback : `generateClusterId(normalizeString(label))` si aucune signature.
   - Liaison groupes → clusters : reuse cluster d’un membre, sinon fallback création; rescousse des groupes sans CIS via parsing de libellé princeps.
   - `group_id`, `generic_type`, `is_princeps` propagés via `updateProductGrouping`.
6. **Présentations (CIP13)** :
   - Insertion uniquement si CIS connu ; prix via `parsePriceToCents`.
   - Ruptures/tensions : résolution `shortageMap` par CIP13 prioritaire puis CIS, stockée en `availability_status` + `ansm_link`.
   - `date_commercialisation` normalisée via `parseDateToIso`.
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

- **`normalizeString`** : upper, déaccentuation, corrections typos ciblées, hints de forme (CREME, COLLYRE, INJECTABLE…), suppression sels (`SALT_PREFIXES/SALT_SUFFIXES`), formes orales (`ORAL_FORM_TOKENS`), dosage/unité, bag-of-words, dédup tokens.
- **`normalizeManufacturerName` + `createManufacturerResolver`** : nettoyage titulaire + clustering heuristique (tokens inclusifs, préfixe commun, Levenshtein < 3), retourne id stable + label le plus court.
- **`parsePriceToCents`** : dernière virgule comme décimale, espaces/points supprimés, centimes arrondis ou `null`.
- **`parseRegulatoryInfo`** : flags `list1`, `list2`, `narcotic`, `hospital` depuis CPD.
- **`parseDateToIso`** : `DD/MM/YYYY` → `YYYY-MM-DD` ou `null`.
- **`buildComposition`** : agrège SA/FT, FT prime, codes substances triés (exclut `0`), noms normalisés (`normalizeIngredientName`).
- **`computeCompositionSignature`** : signature déterministe (codes FT sinon noms normalisés) pour clustering.
- **`resolveDrawerLabel`** : préférence marque princeps du groupe, fallback libellé normalisé.
- **`parseGroupMetadata`** : split molecule/marque (glued dash tolérant) avec tier princeps > split > fallback.

## Schéma SQLite généré (`src/db.ts`)

- `clusters(id, label, princeps_label, substance_code, text_brand_label)`
- `groups(id, cluster_id → clusters.id, label)`
- `manufacturers(id, label UNIQUE)`
- `products(cis, label, is_princeps, generic_type, group_id → groups.id, form, routes, type_procedure, surveillance_renforcee INTEGER, manufacturer_id → manufacturers.id, marketing_status, date_amm, regulatory_info JSON, composition JSON, composition_codes JSON, composition_display TEXT, drawer_label TEXT)`
- `presentations(cip13, cis → products.cis, price_cents, reimbursement_rate, availability_status, ansm_link, date_commercialisation)`
- `search_index(label, normalized_text, cis UNINDEXED)` — FTS5 trigram pour recherche instantanée.

## Artefacts générés

- `reference.db` : base finale.
- `data/explorer_view.json` : vue agrégée (clusters → groups → products) pour le frontend, badges génériques/réglementaires, prix min CIP13 par CIS, manufacturer joint, première `date_commercialisation` par CIS.
- `data/audit_unified_report.json` : audit combiné (split brands, permutations, fuzzy filtré, redondances composition).
- `data/clustering_audit*.json` : audits spécialisés (permutations TF-IDF/Jaccard).

## Outils d’audit & export

- `tool/export_preview.ts` : construit `data/explorer_view.json` (dédoublonne princeps, badges génériques/réglementaires, nettoie composition, joint `manufacturers`, min prix/date).
- `tool/audit_unified.ts` : regroupe split brands, princeps fusionnés, permutations, fuzzies (seuil 0.82, filtrage bruit/splits légitimes), redondances composition ; écrit `data/audit_unified_report.json`.
- `tool/audit_clustering.ts` : permutations princeps via trigrammes.
- `tool/audit_clustering_tfidf.ts` : splits proches via TF-IDF + Levenshtein (stop-words dynamiques + overrides métier).
- `tool/extract_manufacturers.ts` : liste brute des titulaires (`data/manufacturers_list.txt`) pour contrôle qualité.

## Tests (bun test)

- `test/logic.test.ts` : normalisation chimique, parsing prix, stratégie princeps 3-tier, `generic_type` (complémentaires/substituables), `surveillance_renforcee`, `date_commercialisation`, clustering titulaires.
- `test/clustering.test.ts` : intégration clustering (fusion/séparation via codes/signatures vs labels).
- `test/audit_unified.test.ts` : bruit vs vrais doublons, permutations.
- `test/dependency_loading.test.ts` : pré-matérialisation Maps (conditions, composition, présentations, availability, generics) + résolutions CIP/CIS.

## Notes d’exploitation

- Pipeline idempotent : `reference.db` supprimée puis reconstruite à chaque run.
- Traitement par batch (5000 lignes) pour limiter la RAM ; streaming win1252 obligatoire.
- Présentations orphelines (CIP sans CIS) ignorées pour éviter les FK cassées ; données satellites chargées avant produits pour cohérence référentielle.
- Manufacturer resolver conserve le label le plus court rencontré pour un titulaire (cohérence UI).
