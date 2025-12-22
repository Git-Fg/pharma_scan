# Pre-Implementation Verification Checklist

Ce document liste de manière **exhaustive** toutes les vérifications, scripts d'investigation, tests et décisions à prendre **AVANT** de procéder à l'implémentation de l'algorithme décrit dans `OBJECTIVE_BACKEND.md`.

---

## 🔬 Section 1 : Scripts d'Investigation à Créer

Ces scripts permettent de répondre aux questions ouvertes et de valider les hypothèses de l'algorithme.

---

### 1.1 Script : Vérification CIS dans CIS_COMPO

**Objectif :** Répondre à la question "Le CIS du Pivot peut-il ne pas exister dans CIS_COMPO ?"

**Fichier à créer :** `scripts/verify_cis_in_compo.ts`

**Algorithme :**
1.  Charger tous les CIS de `CIS_BDPM.txt` (après filtrage homéopathie).
2.  Charger tous les CIS présents dans `CIS_COMPO_bdpm.txt`.
3.  Calculer la différence : CIS présents dans BDPM mais absents de COMPO.
4.  Afficher :
    *   Nombre total de CIS dans BDPM.
    *   Nombre total de CIS avec composition.
    *   Nombre de CIS **sans** composition.
    *   Liste des CIS sans composition (avec leur nom).

**Questions à répondre :**
*   Combien de CIS n'ont pas de composition ?
*   Quels types de produits sont concernés ? (Homéopathie restante ? Dispositifs médicaux ?)
*   Ces CIS peuvent-ils être des Pivots de groupe générique ?

**Output attendu :**
```
CIS total: 14523
CIS avec composition: 14100
CIS sans composition: 423

Exemples de CIS sans composition:
- 12345678: PRODUIT XYZ (Laboratoire ABC)
- ...
```

---

### 1.2 Script : Analyse des Groupes Génériques sans Princeps Actif

**Objectif :** Identifier les groupes où aucun Princeps Type 0 n'existe dans `specialites`.

**Fichier à créer :** `scripts/verify_princeps_existence.ts`

**Algorithme :**
1.  Charger les `specialites` (CIS actifs de CIS_BDPM, après filtres).
2.  Charger `CIS_GENER_bdpm.txt`.
3.  Pour chaque groupe unique :
    *   Filtrer les lignes Type == 0.
    *   Vérifier si au moins un CIS existe dans `specialites`.
    *   Si aucun n'existe : marquer le groupe comme "fallback nécessaire".
4.  Afficher :
    *   Nombre total de groupes.
    *   Nombre de groupes avec au moins un Princeps actif.
    *   Nombre de groupes nécessitant le fallback parsing.
    *   Liste des groupes en fallback avec leur Libellé.

**Questions à répondre :**
*   Quelle proportion de groupes nécessite le fallback ?
*   Les Libellés de ces groupes suivent-ils bien le format "[DCI] - [PRINCEPS]" ?
*   Y a-t-il des cas pathologiques (pas de tiret, format inattendu) ?

**Output attendu :**
```
Groupes total: 1523
Groupes avec Princeps actif: 1480 (97.2%)
Groupes en fallback: 43 (2.8%)

Groupes en fallback:
- ID 440: "METHOTREXATE 2,5 mg/ml - METHOTREXATE NEURAXPHARM..."
- ...

Analyse format:
- Avec tiret " - ": 42
- Avec tiret "–": 1
- Sans tiret: 0
```

---

### 1.3 Script : Analyse des Séparateurs dans CIS_GENER

**Objectif :** Identifier tous les types de séparateurs utilisés dans les Libellés de groupes.

**Fichier à créer :** `scripts/analyze_separators.ts`

**Algorithme :**
1.  Charger tous les Libellés uniques de `CIS_GENER_bdpm.txt`.
2.  Pour chaque Libellé, identifier :
    *   Présence de " - " (espace-tiret-espace)
    *   Présence de " – " (espace-em-dash-espace)
    *   Présence de "-" sans espaces
    *   Présence de "–" sans espaces
    *   Aucun tiret
3.  Compter les occurrences de chaque type.
4.  Lister les cas problématiques (aucun tiret ou tiret sans espaces).

**Questions à répondre :**
*   Quel est le séparateur majoritaire ?
*   Y a-t-il des tirets longs Unicode (U+2013, U+2014) ?
*   Combien de Libellés n'ont aucun tiret ?

**Output attendu :**
```
Libellés analysés: 1523

Séparateurs trouvés:
- " - " (tiret court avec espaces): 1518 (99.7%)
- " – " (em-dash avec espaces): 3 (0.2%)
- "-" (tiret sans espaces): 2 (0.1%)
- Aucun tiret: 0

Cas problématiques (sans espaces autour du tiret):
- ID 1234: "SUBSTANCE-MARQUE 50mg, comprimé"
- ID 5678: "AUTRE–PRODUIT, gélule"
```

---

### 1.4 Script : Analyse des Formes dans CIS_COMPO (Col 6)

**Objectif :** Extraire et analyser le Dictionnaire de Formes Normalisées.

**Fichier à créer :** `scripts/extract_normalized_forms.ts`

**Algorithme :**
1.  Charger `CIS_COMPO_bdpm.txt`.
2.  Extraire toutes les valeurs de Col 6 ("Référence dosage").
3.  Normaliser : retirer "un ", "une ", "1 ".
4.  Dédoublonner.
5.  Trier par longueur décroissante.
6.  Afficher le dictionnaire résultant.

**Questions à répondre :**
*   Combien de formes uniques existe-t-il ?
*   Y a-t-il des formes très longues ou très courtes ?
*   Y a-t-il des formes contenant des caractères spéciaux ?

**Output attendu :**
```
Formes brutes extraites: 45678
Formes uniques après normalisation: 127

Dictionnaire (ordre décroissant):
1. "comprimé orodispersible" (24 chars)
2. "comprimé pelliculé" (18 chars)
3. "solution injectable" (19 chars)
...
125. "dose" (4 chars)
126. "ml" (2 chars)
127. "g" (1 char)

Formes potentiellement problématiques:
- "comprimé (avec sécabilité)" → contient parenthèses
- ...
```

---

### 1.5 Script : Analyse des Dosages dans CIS_COMPO

**Objectif :** Extraire et analyser tous les dosages uniques pour constituer le masque de dosages agrégés.

**Fichier à créer :** `scripts/extract_dosages.ts`

**Algorithme :**
1.  Charger `CIS_COMPO_bdpm.txt`.
2.  Extraire toutes les valeurs de Col 5 ("Dosage").
3.  Dédoublonner.
4.  Analyser les patterns :
    *   Dosages numériques simples (ex: "500 mg")
    *   Dosages avec fraction (ex: "5 mg/2 ml")
    *   Dosages avec pourcentage (ex: "2,5 %")
    *   Dosages avec unités spéciales (ex: "1 000 000 UI")
5.  Générer les variantes (avec/sans espace, virgule/point).

**Questions à répondre :**
*   Combien de dosages uniques ?
*   Quels sont les patterns de dosage les plus fréquents ?
*   Y a-t-il des dosages avec des caractères spéciaux non prévus ?

**Output attendu :**
```
Dosages bruts extraits: 89456
Dosages uniques: 4523

Patterns identifiés:
- "X mg": 2345 occurrences
- "X g": 456 occurrences
- "X mg/Y ml": 234 occurrences
- "X %": 123 occurrences
- "X UI": 89 occurrences
- "X MUI": 34 occurrences
- Autres: 12 occurrences

Dosages atypiques:
- "environ 500 mg" → contient texte
- "0,5 à 1 g" → contient plage
- ...
```

---

### 1.6 Script : Analyse du LinkID dans CIS_COMPO (FT vs SA)

**Objectif :** Vérifier le comportement du filtrage FT > SA sur les LinkID.

**Fichier à créer :** `scripts/analyze_linkid.ts`

**Algorithme :**
1.  Charger `CIS_COMPO_bdpm.txt`.
2.  Grouper par (CIS, LinkID).
3.  Pour chaque groupe :
    *   Compter le nombre de lignes.
    *   Si > 1 ligne : vérifier présence de FT et SA.
4.  Statistiques :
    *   Nombre de (CIS, LinkID) avec une seule ligne.
    *   Nombre de (CIS, LinkID) avec FT + SA.
    *   Nombre de (CIS, LinkID) avec plusieurs SA.
    *   Nombre de (CIS, LinkID) avec plusieurs FT (anomalie ?).

**Questions à répondre :**
*   La règle "FT > SA" est-elle toujours applicable ?
*   Y a-t-il des cas avec plusieurs FT pour un même LinkID ?
*   Y a-t-il des LinkID vides (valeur "0" ou "") ?

**Output attendu :**
```
Total (CIS, LinkID) uniques: 45678

Distribution:
- 1 ligne: 40000 (87.6%)
- 2 lignes (FT + SA): 5600 (12.3%)
- 3+ lignes: 78 (0.1%)

Cas à 3+ lignes:
- CIS 12345678, LinkID 1: 3 lignes (2 SA, 1 FT)
- ...

LinkID vides ou "0":
- CIS 87654321: LinkID = "0" (2 lignes)
- ...
```

---

### 1.7 Script : Analyse des Caractères Spéciaux dans les Noms

**Objectif :** Identifier tous les caractères spéciaux présents dans les noms de médicaments.

**Fichier à créer :** `scripts/analyze_special_chars.ts`

**Algorithme :**
1.  Charger tous les noms de `CIS_BDPM.txt` (Col 2).
2.  Pour chaque nom, extraire les caractères qui ne sont pas alphanumériques ou espaces.
3.  Compter les occurrences de chaque caractère spécial.
4.  Lister les 20 caractères les plus fréquents.

**Questions à répondre :**
*   Quels caractères spéciaux sont utilisés ?
*   La règle "/" → espace est-elle suffisante ?
*   Y a-t-il des caractères Unicode inattendus ?

**Output attendu :**
```
Caractères spéciaux trouvés:

Rang | Char | Unicode | Occurrences | Exemple
-----|------|---------|-------------|--------
1    | ,    | U+002C  | 14523      | "DOLIPRANE 500 mg, comprimé"
2    | -    | U+002D  | 3456       | "BI-PROFENID"
3    | /    | U+002F  | 1234       | "AMOXICILLINE/ACIDE CLAVULANIQUE"
4    | (    | U+0028  | 890        | "VITAMINE D3 (cholécalciférol)"
5    | )    | U+0029  | 890        | idem
6    | %    | U+0025  | 234        | "CHLORHEXIDINE 0,5 %"
7    | +    | U+002B  | 56         | "CALCIUM + VITAMINE D3"
...

Caractères Unicode rares:
- U+2019 (apostrophe courbe): 3 occurrences
- U+00B5 (µ): 12 occurrences (µg)
```

---

### 1.8 Script : Analyse des Laboratoires pour Homéopathie

**Objectif :** Valider la détection homéopathie par laboratoire.

**Fichier à créer :** `scripts/analyze_homeopathy_labs.ts`

**Algorithme :**
1.  Charger `CIS_BDPM.txt`.
2.  Extraire Col 11 (Laboratoire).
3.  Filtrer les laboratoires contenant "BOIRON", "LEHNING", "WELEDA".
4.  Compter les produits par laboratoire.
5.  Vérifier si ces produits ont des noms "normaux" (sans termes homéopathiques).

**Questions à répondre :**
*   Combien de produits sont exclus par la règle laboratoire ?
*   Y a-t-il des faux positifs ? (ex: un labo partenaire avec BOIRON dans le nom mais produit allopathique)
*   Combien de produits additionnels sont exclus par la règle mots-clés ?

**Output attendu :**
```
Produits par laboratoire homéopathique:

Laboratoire                    | Produits
-------------------------------|----------
BOIRON                         | 2345
LABORATOIRES BOIRON            | 1234
LEHNING                        | 456
WELEDA                         | 234
WELEDA FRANCE                  | 123

Total exclus par règle labo: 4392

Exclusions additionnelles par mots-clés (après labo):
- Produits non-BOIRON/LEHNING/WELEDA avec "homéopathique": 23
- Produits avec "degré de dilution": 5

Total exclusions homéopathie: 4420
```

---

### 1.9 Script : Analyse des Orphelins (avant implémentation)

**Objectif :** Identifier et analyser les CIS qui seront orphelins.

**Fichier à créer :** `scripts/analyze_orphans.ts`

**Algorithme :**
1.  Charger les CIS de `CIS_BDPM.txt` (après filtres).
2.  Charger les CIS présents dans `CIS_GENER_bdpm.txt`.
3.  Calculer les orphelins : CIS BDPM - CIS GENER.
4.  Pour chaque orphelin :
    *   Extraire le nom.
    *   Identifier le "premier mot" (potentiel nom de marque).
5.  Grouper les orphelins par premier mot.
6.  Identifier les clusters potentiels d'orphelins.

**Questions à répondre :**
*   Combien d'orphelins ?
*   Les orphelins ont-ils des noms similaires qui pourraient être regroupés ?
*   Y a-t-il des orphelins qui devraient être rattachés à des groupes génériques existants ?

**Output attendu :**
```
CIS total (après filtres): 14100
CIS avec groupe générique: 12500
Orphelins: 1600 (11.3%)

Top 20 premiers mots d'orphelins:
1. "DOLIPRANE" - 45 orphelins
2. "ADVIL" - 23 orphelins
3. "EFFERALGAN" - 18 orphelins
...

Clusters potentiels d'orphelins (≥3 orphelins avec même préfixe):
- "DOLIPRANE": 45 orphelins → cluster potentiel
- "ADVIL": 23 orphelins → cluster potentiel
...
```

---

### 1.10 Script : Analyse des Noms de Substances (Normalisation)

**Objectif :** Valider l'algorithme de normalisation des substances (plus court nom par code).

**Fichier à créer :** `scripts/analyze_substance_normalization.ts`

**Algorithme :**
1.  Charger `CIS_COMPO_bdpm.txt`.
2.  Grouper par Code Substance (Col 3).
3.  Pour chaque code :
    *   Collecter toutes les variantes de Nom Substance (Col 4).
    *   Identifier le plus court.
    *   Vérifier si le plus court est un préfixe des autres (validation sémantique).
4.  Identifier les cas problématiques.

**Questions à répondre :**
*   Le plus court est-il toujours le bon choix ?
*   Y a-t-il des cas où des noms courts sont des abréviations incorrectes ?
*   Faut-il un dictionnaire de corrections manuelles ?

**Output attendu :**
```
Codes substance analysés: 2345

Distribution des variantes:
- 1 variante: 1800 (76.8%)
- 2 variantes: 400 (17.0%)
- 3+ variantes: 145 (6.2%)

Exemples de normalisation:
Code 12345:
  Variantes: ["AMOXICILLINE TRIHYDRATÉE", "AMOXICILLINE SODIQUE", "AMOXICILLINE"]
  Choix: "AMOXICILLINE" ✓

Cas potentiellement problématiques (plus court n'est pas préfixe):
Code 67890:
  Variantes: ["VIT. D3", "CHOLÉCALCIFÉROL", "VITAMINE D3"]
  Plus court: "VIT. D3"
  → ATTENTION: "VIT. D3" n'est pas un préfixe de "CHOLÉCALCIFÉROL"
```

---

## 🧪 Section 2 : Tests Unitaires à Écrire

Ces tests valident les fonctions individuelles de l'algorithme.

---

### 2.1 Tests : Fonction de Normalisation de Texte

**Fichier :** `tests/normalization.test.ts`

**Cas à tester :**

| Input | Expected Output |
|-------|-----------------|
| "AMOXICILLINE/ACIDE CLAVULANIQUE" | "AMOXICILLINE ACIDE CLAVULANIQUE" |
| "BI-PROFENID" | "BIPROFENID" |
| "gélule" | "GELULE" |
| "GÉLULE" | "GELULE" |
| "comprimé pelliculé" | "COMPRIME PELLICULE" |
| "  DOLIPRANE  " | "DOLIPRANE" |
| "MONO–TILDIEM" | "MONOTILDIEM" |
| "CALCIUM+VITAMINE D3" | "CALCIUM+VITAMINE D3" | (+ conservé ?)

**Questions ouvertes pour les tests :**
*   Le "+" doit-il être remplacé par un espace ou conservé ?
*   Que faire des parenthèses () ?

---

### 2.2 Tests : Fonction de Soustraction de Forme

**Fichier :** `tests/form_subtraction.test.ts`

**Cas à tester :**

| Nom Brut | Forme | Expected Nom Complet |
|----------|-------|----------------------|
| "CLAMOXYL 500 mg, gélule" | "gélule" | "CLAMOXYL 500 mg" |
| "DOLIPRANE 1000 mg, comprimé pelliculé" | "comprimé pelliculé" | "DOLIPRANE 1000 mg" |
| "PRODUIT, solution injectable" | "solution injectable" | "PRODUIT" |
| "MEDICAMENT, gélule" | "gélule" | "MEDICAMENT" |
| "NOM AVEC VIRGULE, SUITE, comprimé" | "comprimé" | "NOM AVEC VIRGULE, SUITE" |

**Cas limites :**
*   Forme au milieu du nom (ne devrait pas arriver).
*   Forme non trouvée dans le nom.
*   Multiples occurrences de la forme.

---

### 2.3 Tests : Détection Homéopathie

**Fichier :** `tests/homeopathy_detection.test.ts`

**Cas à tester :**

| Nom | Laboratoire | Expected |
|-----|-------------|----------|
| "ARNICA MONTANA 9CH" | "BOIRON" | true |
| "DOLIPRANE 500 mg" | "SANOFI" | false |
| "OSCILLOCOCCINUM" | "LABORATOIRES BOIRON" | true |
| "CALENDULA" | "WELEDA FRANCE" | true |
| "PRODUIT homéopathique" | "AUTRE LABO" | true |
| "GRANULES XY, degré de dilution 12" | "AUTRE LABO" | true |
| "HOMEOPATHIE NATURELLE" | "NATUREL LABO" | true |

---

### 2.4 Tests : Parsing du Libellé Groupe (Fallback)

**Fichier :** `tests/group_label_parsing.test.ts`

**Cas à tester :**

| Libellé | Expected Princeps Extrait |
|---------|---------------------------|
| "AMOXICILLINE 500 mg - CLAMOXYL 500 mg, gélule" | "CLAMOXYL 500 mg, gélule" |
| "DCI 10 mg – MARQUE 10 mg, comprimé" | "MARQUE 10 mg, comprimé" |
| "SUBSTANCE-PRODUIT 50mg, comprimé" | "PRODUIT 50mg, comprimé" |
| "LABEL SANS TIRET" | "LABEL SANS TIRET" (+ warning) |
| "DCI - MARQUE A - MARQUE B" | "MARQUE B" (dernier tiret) |

---

### 2.5 Tests : Comparaison de Sets de Substances

**Fichier :** `tests/substance_set_comparison.test.ts`

**Cas à tester :**

| Set A | Set B | Expected |
|-------|-------|----------|
| {1, 2} | {1, 2} | true (identiques) |
| {1, 2} | {2, 1} | true (ordre indifférent) |
| {1, 2} | {1, 2, 3} | false (différents) |
| {1} | {1, 2} | false (différents) |
| {} | {} | true (vides identiques) |

---

### 2.6 Tests : Fuzzy Matching (Jaro-Winkler)

**Fichier :** `tests/fuzzy_matching.test.ts`

**Cas à tester avec scores attendus (approximatifs) :**

| String A | String B | Expected Score Range |
|----------|----------|----------------------|
| "CLAMOXYL" | "CLAMOXYL" | 1.0 |
| "CLAMOXYL" | "CLAMOXYL 500 mg" | 0.85-0.95 |
| "ABILIFY" | "ABILIFY MAINTENA" | 0.75-0.85 |
| "DOLIPRANE" | "EFFERALGAN" | < 0.5 |
| "AMOXICILLINE" | "AMOXICILLINE BIOGARAN" | 0.80-0.90 |

---

## ⚙️ Section 3 : Décisions de Paramétrage à Prendre

Ces décisions doivent être validées par expérimentation.

---

### 3.1 Seuil de Fuzzy Matching pour Orphelins

**Valeurs à tester :** 75%, 80%, 85%, 90%, 95%

**Méthode de validation :**
1.  Prendre un échantillon de 100 orphelins.
2.  Pour chaque seuil, compter :
    *   Orphelins correctement rattachés (vrais positifs).
    *   Orphelins incorrectement rattachés (faux positifs).
    *   Orphelins qui auraient dû être rattachés mais ne l'ont pas été (faux négatifs).
3.  Calculer précision et rappel.
4.  Choisir le seuil avec le meilleur F1-score.

**Critères de décision :**
*   Privilégier la précision (éviter les faux positifs) → seuil élevé (90%+).
*   Privilégier le rappel (rattacher le maximum) → seuil bas (80%).

---

### 3.2 Algorithme de Sélection du Représentant (Phase 4.3)

**Options à tester :**
*   **Option A** : Nom le plus fréquent.
*   **Option B** : Nom du groupe le plus grand.
*   **Option C** : Nom du Pivot Principal du premier groupe.

**Méthode de validation :**
1.  Identifier les clusters avec plusieurs sous-clusters ayant des noms différents.
2.  Pour chaque option, vérifier si le nom choisi est "correct" (jugement humain).
3.  Comparer les résultats.

---

### 3.3 Approche de Matching Orphelins (A vs B)

**Approches à comparer :**
*   **Approche A** : Matching par Nom uniquement.
*   **Approche B** : Matching par Nom + Forme (70/30).

**Méthode de validation :**
1.  Sur un échantillon d'orphelins, appliquer les deux approches.
2.  Comparer les résultats.
3.  Évaluer quel approche donne les meilleurs rattachements.

---

### 3.4 Pondération Nom/Forme pour Approche B

**Pondérations à tester :**
*   90/10 (priorité nom)
*   80/20
*   70/30 (par défaut)
*   60/40
*   50/50 (égalité)

---

## 📊 Section 4 : Rapports d'Audit à Générer

Ces rapports permettent de valider la qualité des données après chaque étape.

---

### 4.1 Rapport : Statistiques Générales par Étape

**Contenu :**
```
=== ÉTAPE 1 : INGESTION ===
CIS total dans fichier: 15000
CIS exclus (homéopathie labo): 4200
CIS exclus (homéopathie mots-clés): 28
CIS retenus: 10772

=== ÉTAPE 2 : GROUPES GÉNÉRIQUES ===
Groupes chargés: 1523
Groupes avec Princeps actif: 1480
Groupes en fallback: 43
  - Fallback tiret réussi: 42
  - Fallback sans tiret (warning): 1

=== ÉTAPE 3 : CRÉATION CLUSTERS ===
Sous-clusters créés: 2345
Clusters finaux: 1890
  - Clusters par fusion: 1500
  - Clusters séparés (princeps différents): 390

=== PHASE 5 : ORPHELINS ===
Orphelins identifiés: 1600
  - Rattachés par fuzzy match: 1200
  - Nouveaux clusters orphelins: 400

=== TOTAUX ===
CIS assignés: 10772
Clusters finaux: 2290
Ratio compression: 4.7 CIS/cluster
```

---

### 4.2 Rapport : Clusters Problématiques

**Critères de "problème" :**
*   Cluster avec 1 seul CIS.
*   Cluster avec incohérence de substances.
*   Cluster nommé par fallback (moins fiable).
*   Cluster d'orphelins avec >10 membres (anomalie ?).

---

### 4.3 Rapport : Traçabilité des Méthodologies

**Contenu :**
```
Distribution des méthodologies de nommage:

Méthodologie                    | Clusters | %
--------------------------------|----------|------
ACTIVE_PRINCEPS                 | 1480     | 64.6%
SECONDARY_PRINCEPS              | 120      | 5.2%
FALLBACK_DASH_PARSING           | 42       | 1.8%
FALLBACK_FORM_SUBTRACTION       | 15       | 0.7%
FALLBACK_COMMA_DETECTION        | 3        | 0.1%
ORPHAN_FUZZY_MATCH              | 230      | 10.0%
ORPHAN_NEW_CLUSTER              | 400      | 17.5%
```

---

## 🔄 Section 5 : Ordre d'Exécution des Scripts

**Phase 1 : Investigation (avant toute implémentation)**
1.  `verify_cis_in_compo.ts`
2.  `verify_princeps_existence.ts`
3.  `analyze_separators.ts`
4.  `extract_normalized_forms.ts`
5.  `extract_dosages.ts`
6.  `analyze_linkid.ts`
7.  `analyze_special_chars.ts`
8.  `analyze_homeopathy_labs.ts`
9.  `analyze_orphans.ts`
10. `analyze_substance_normalization.ts`

**Phase 2 : Validation des résultats**
*   Analyser les outputs de chaque script.
*   Identifier les anomalies.
*   Prendre les décisions nécessaires.

**Phase 3 : Implémentation**
*   Implémenter l'algorithme en suivant `OBJECTIVE_BACKEND.md`.
*   Écrire les tests unitaires (Section 2).

**Phase 4 : Calibration**
*   Exécuter les tests de paramétrage (Section 3).
*   Valider les choix de seuils et algorithmes.

**Phase 5 : Audit**
*   Générer les rapports (Section 4).
*   Valider la qualité des données.

---

## ✅ Checklist de Validation Finale

Avant de considérer l'implémentation comme terminée :

- [ ] Tous les scripts d'investigation ont été exécutés et analysés.
- [ ] Aucune anomalie bloquante n'a été identifiée.
- [ ] Tous les tests unitaires passent.
- [ ] Les paramètres (seuils, pondérations) ont été calibrés.
- [ ] Les rapports d'audit montrent des métriques acceptables.
- [ ] La traçabilité est en place pour chaque cluster.
- [ ] Les cas limites ont été documentés et gérés.
