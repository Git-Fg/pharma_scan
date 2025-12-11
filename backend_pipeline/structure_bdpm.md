**1. 📁 CIS_bdpm.txt (Fichier Maître Produit)**

Fichier central : existence du médicament.

| # | Nom | Description réelle | Action ETL / Importance |
| :--- | :--- | :--- | :--- |
| **1** | Code CIS | Identifiant unique (8 chiffres). | **Critique**. PK `products.cis`. |
| **2** | Dénomination | Libellé complet. | **Haute**. Fallback affichage + FTS. |
| **3** | Forme pharma | Forme galénique. | **Moyenne**. Distinguer cp/sirop. |
| **4** | Voies admin | Voie d’administration. | **Join**. Propagation `routes` au niveau groupe (union des voies CIS). |
| **5** | Statut AMM | État de l’autorisation. | **Moyenne**. Filtrer retirés. |
| **6** | Type procédure | Type d’AMM. | **Nulle**. |
| **7** | État commercial | Statut commercialisation. | **Haute**. Éviter produits morts. |
| **8** | Date AMM | Date d’autorisation. | **Faible**. |
| **9** | Statut BDM | Ex: « Warning disponibilité ». | **Display**. Icône alerte. |
| **10** | Numéro Europe | Numéro EU. | **Nulle**. |
| **11** | Titulaire | Laboratoire. | **Moyenne**. Tri/filtre secondaire. |
| **12** | Surveillance | Oui/Non. | **Safety**. Triangle noir ⚠️. |

Exemples (données `data/CIS_bdpm.txt`) :

- `61266250` — `A 313 200 000 UI POUR CENT, pommade` — `pommade` — `cutanée` — `Autorisation active` — `Procédure nationale` — `Commercialisée` — `12/03/1998` — `PHARMA DEVELOPPEMENT` — `Non`
- `61876780` — `ABACAVIR ARROW 300 mg, comprimé pelliculé sécable` — `comprimé pelliculé sécable` — `orale` — `Autorisation active` — `Procédure décentralisée` — `Commercialisée` — `22/10/2019` — `ARROW GENERIQUES` — `Non`
- `68257528` — `ABACAVIR/LAMIVUDINE ACCORD 600 mg/300 mg, comprimé pelliculé` — `orale` — `Autorisation active` — `Procédure nationale` — `Non commercialisée` — `16/03/2017` — `Warning disponibilité` — `ACCORD HEALTHCARE FRANCE` — `Non`
- `62401060` — `ABACAVIR VIATRIS 300 mg, comprimé pelliculé sécable` — `comprimé pelliculé sécable` — `orale` — `Autorisation active` — `Procédure décentralisée` — `Commercialisée` — `21/02/2018` — `VIATRIS SANTE` — `Non`
- `63431640` — `ABACAVIR/LAMIVUDINE BIOGARAN 600 mg/300 mg, comprimé pelliculé` — `orale` — `Autorisation active` — `Procédure nationale` — `Commercialisée` — `14/02/2017` — `BIOGARAN` — `Non`
- `68257528` — même CIS avec `Statut BDM` renseigné (« Warning disponibilité ») pour illustrer l’icône alerte.

---

**2. 📁 CIS_CIP_bdpm.txt (Codes barres & Prix)**

13 colonnes (prix détaillés).

| # | Nom | Description réelle | Action ETL |
| :--- | :--- | :--- | :--- |
| **1-6** | Identique analyse précédente | | **Join/Filter** |
| **7** | CIP13 | Datamatrix. | **PK** `presentations`. |
| **8** | Agrément | Collectivités oui/non. | **Ignore**. |
| **9** | Taux Remb | Ex: "65%". | **Display**. |
| **10** | Prix TTC | Ex: "25,45" (médicament seul). | **Display** (virgule→point). |
| **11** | Prix Global | Ex: "26,47" (médicament + honoraire). | **Display** patient (prioritaire). |
| **12** | Honoraire | Ex: "1,02". | **Calcul** (col10 + col12 = col11). |
| **13** | Texte Remb. | Conditions spécifiques ALD… | **Display (détail)**. |

Exemples (données `data/CIS_CIP_bdpm.txt`) :

- `60002283` | `4949729` | `plaquette(s)...30 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `16/03/2011` | `3400949497294` | `oui` | `100%` | `24,34` | `25,36` | `1,02` | (vide)
- `60003620` | `3696350` | `20 récipient(s) unidose(s)...` | `Présentation active` | `Déclaration de commercialisation` | `30/11/2006` | `3400936963504` | `oui` | `65%` | `12,81` | `13,83` | `1,02` | `Ce médicament peut être pris en charge...`
- `60007437` | `4944413` | `plaquette(s) aluminium de 28 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `08/05/2012` | `3400949444137` | `oui` | `65%` | `3,69` | `4,71` | `1,02` | (vide)
- `60004505` | `5507419` | `1 flacon(s)...` | `Déclaration d'arrêt de commercialisation` | `31/12/2023` | `3400955074199` | `non` | (taux vide) | (prix vides)
- `60004932` | `3011679` | `plaquette...60 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `21/11/2022` | `3400930116791` | `oui` | `15 %` | `8,92` | `9,94` | `1,02` | (vide)
- `60007437` | `4944494` | `plaquette(s) aluminium de 90 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `08/05/2012` | `3400949444946` | `oui` | `65%` | `11,41` | `14,17` | `2,76` | (vide)
- `60005856` | `3551025` | `plaquette(s) ... 30 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `25/03/2004` | `3400935510259` | `oui` | `15%` | `7,82` | `8,84` | `1,02` | (vide)
- `60008724` | `3016859` | `plaquette(s) ... 30 capsule(s)` | `Présentation active` | `Déclaration de commercialisation` | `25/08/2021` | `3400930168592` | `oui` | `30 %` | `8,82` | `9,84` | `1,02` | (vide)
- `60009573` | `3016729` | `plaquettes PVC-Aluminium de 16 comprimés` | `Présentation active` | `Déclaration d'arrêt de commercialisation` | `04/10/2024` | `3400930167298` | `non` | `65 %` | `1,72` | `2,74` | `1,02` | (vide) — illustre agrément « non » avec prix présents.
- `60007960` | `3637755` | `tube PEBD 15 ml` | `Présentation active` | `Déclaration de commercialisation` | `04/04/2005` | `3400936377554` | `non` | (taux vide) | (prix vides) — agrément « non » + prix manquants.

---

**3. 📁 CIS_GENER_bdpm.txt (Groupes / Tiroirs)**

| # | Nom | Description réelle | Action ETL |
| :--- | :--- | :--- | :--- |
| **1** | ID Groupe | Identifiant tiroir. | **Group By**. |
| **2** | Libellé | DCI + dosage + princeps. | **Display** + fallback naming (`historical_princeps_raw`, `generic_label_clean`). |
| **3** | CIS | Lien produit. | **Join**. |
| **4** | Type | 0=Princeps, 1=Générique, 2=Complémentaire, 4=Substituable. | **Logic**. 0 = chef visuel; 1/2/4 rangés sous le 0. |
| **5** | Ordre historique |incrémenté à chaque valeur, la valeur 1 est canonique |

Exemples (données `data/CIS_GENER_bdpm.txt`) :

- `1` | `CIMETIDINE 200 mg - TAGAMET 200 mg, comprimé pelliculé` | `65383183` | `0`
- `1` | `CIMETIDINE 200 mg - TAGAMET 200 mg, comprimé pelliculé` | `67535309` | `1`
- `4` | `CIMETIDINE 800 mg - TAGAMET 800 mg, comprimé pelliculé sécable` | `60089516` | `0`
- `4` | `CIMETIDINE 800 mg - TAGAMET 800 mg, comprimé pelliculé sécable` | `60756034` | `1`
- `7` | `RANITIDINE... 150 mg - AZANTAC 150 mg...` | `65109314` | `0`
- `7` | `RANITIDINE... 150 mg - AZANTAC 150 mg...` | `66024386` | `0`
- `4` | `CIMETIDINE 800 mg - TAGAMET 800 mg, comprimé pelliculé sécable` | `62844636` | `2` (complémentaire)
- `7` | `RANITIDINE...` | `66024386` | `2` (autre type non-princeps)

Notes ETL :

- `TYPE 0` prioritaire pour le nom canonique : `CIS_bdpm` princeps nettoyé (form/dosage retirés) → `canonical_name` + `princeps_aliases`.
- Fallback parsing texte : partie droite du dernier “ - ” nettoyée → `historical_princeps_raw` + `naming_source=GENER_PARSING`; partie gauche du premier “ - ” → `generic_label_clean`.
- Agrégation groupe : `routes` = union des voies CIS du groupe, `safety_flags` = OR des badges CPD.

---

**4. 📁 CIS_CPD_bdpm.txt (Conditions Prescription)**

Relation one-to-many.

| # | Nom | Description réelle | Action ETL |
| :--- | :--- | :--- | :--- |
| **1** | CIS | Clé produit. | **Join**. |
| **2** | Condition | Texte libre (liste I/II, stupéfiant, hospitalier, dentaire). | **Scan & Tag** (badges rouge/vert/bleu/hôpital/dentaire) + agrégation `safety_flags` par groupe. |

Exemples (données `data/CIS_CPD_bdpm.txt`) :

- `63852237` | `réservé à l'usage professionnel DENTAIRE`
- `65319857` | `réservé à l'usage professionnel DENTAIRE`
- `60004505` | `réservé à l'usage HOSPITALIER`
- `60030699` | `réservé à l'usage HOSPITALIER`
- `60080232` | `réservé à l'usage HOSPITALIER`
- (Chercher aussi des lignes contenant « STUPEFIANT » ou « LISTE I/II » pour couvrir les badges stup/listes)

---

**5. 📁 CIS_COMPO_bdpm.txt (Composition)**

Join-first : désignation (col 2) + lien (col 8) pour SA/FT.

| # | Nom | Description réelle | Action ETL |
| :--- | :--- | :--- | :--- |
| **1** | CIS | | **Join**. |
| **2** | Désignation élément | Ex: « comprimé jour/nuit ». | **Group** multi-formes. |
| **3** | Code Substance | ID molécule. | **Critique**. |
| **4** | Dénomination | Nom substance. | **Display**. |
| **5** | Dosage | Valeur dosage. | **Display**. |
| **6** | Réf Dosage | Unité/portée. | **Contexte**. |
| **7** | Nature | SA vs FT. | **Logic** (FT > SA). |
| **8** | Lien | Lie SA/FT. | **Dedup**. |

Exemples (données `data/CIS_COMPO_bdpm.txt`) :

- `60002283` | `comprimé` | `42215` | `ANASTROZOLE` | `1,00 mg` | `un comprimé` | `SA` | `1`
- `60003620` | `suspension` | `04179` | `DIPROPIONATE DE BECLOMETASONE` | `800 microgrammes` | `2 ml de suspension` | `SA` | `1`
- `60004277` | `gélule` | `03902` | `FENOFIBRATE` | `100,00 mg` | `une gélule` | `SA` | `1`
- `60004487` | `comprimé` | `86571` | `CHLORHYDRATE DE TRAMADOL` | `200 mg` | `un comprimé` | `SA` | `1`
- `60004932` | `comprimé` | `04442` | `METFORMINE` | `780 mg` | `un comprimé` | `FT` | `1`
- `60004932` | `comprimé` | `24321` | `CHLORHYDRATE DE METFORMINE` | `1000 mg` | `un comprimé` | `SA` | `1`
- `60004932` | `comprimé` | `40035` | `VILDAGLIPTINE` | `50 mg` | `un comprimé` | `SA` | `2`

---

**6. 📁 CIS_CIP_Dispo_Spec.txt (Ruptures / Tensions)**

Colonnes réelles corrigées.

| # | Nom | Description réelle | Action ETL |
| :--- | :--- | :--- | :--- |
| **1** | CIS | Code produit. | **Join**. |
| **2** | CIP13 | Présentation (souvent vide = tout le CIS). | **Logic**. |
| **3** | Code Statut | 1=Rupture, 2=Tension, 3=Arrêt, 4=Remise dispo. | **Logic** (stocké en `availability_status` préfixe code). |
| **4** | Libellé Statut | Ex: « Tension d’approvisionnement ». | **Display** (suffixe `availability_status`). |
| **5** | Date Début | Début problème. | **Display**. |
| **6** | Date Fin Prev | Retour prévu. | **Display**. |
| **8** | Lien ANSM | URL PDF officiel. | **Link**. |

Exemples (données `data/CIS_CIP_Dispo_Spec.txt`) :

- `69622218` | (CIP vide) | `2` | `Tension d'approvisionnement` | `04/12/2025` | `08/12/2025` | (lien ANSM présent)
- `69497711` | (CIP vide) | `2` | `Tension d'approvisionnement` | `20/10/2025` | `05/12/2025` | (lien ANSM présent)
- `68106558` | (CIP vide) | `2` | `Tension d'approvisionnement` | `04/12/2025` | `04/12/2025` | (lien ANSM présent)
- `60685046` | (CIP vide) | `2` | `Tension d'approvisionnement` | `04/12/2025` | `04/12/2025` | (lien ANSM présent)
- `64305057` | (CIP vide) | `2` | `Tension d'approvisionnement` | `04/12/2025` | `04/12/2025` | (lien ANSM présent)
- `67947540` | (CIP vide) | `4` | `Remise à disposition` | `01/12/2025` | `04/12/2025` | `01/12/2025` | (lien ANSM présent)
- `64550843` | (CIP vide) | `4` | `Remise à disposition` | `02/04/2025` | `02/04/2025` | `02/04/2025` | (lien ANSM présent)
- `62119207` | (CIP vide) | `1` | `Rupture de stock` | `25/11/2025` | `02/12/2025` | (lien ANSM présent)
- `60998977` | (CIP vide) | `3` | `Arrêt de commercialisation` | `30/09/2025` | `07/11/2025` | (lien ANSM présent)
- `64590923` | `3400955090250` | `2` | `Tension d'approvisionnement` | `08/11/2023` | `04/12/2025` | (lien ANSM présent) — exemple avec CIP13 rempli.

---

**7. 📁 CIS_MITM.txt (Classification Thérapeutique)**

| # | Nom | Description réelle | Importance |
| :--- | :--- | :--- | :--- |
| **1** | CIS | Code produit. | **Critique** (join). |
| **2** | Code ATC | Ex: J01AA02. | **Haute**. Catégorie (icônes/filtre). |
| **3** | Libellé ATC | Nom classe. | **Faible**. |
| **4** | Lien Page | URL info gouv. | **Faible**. |

Exemples (données `data/CIS_MITM.txt`) :

- `68053454` | `A02BA01` | `CIMETIDINE ARROW 200 mg, comprimé effervescent` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=68053454`
- `69606819` | `A02BC01` | `MOPRAL 10 mg, gélule gastro-résistante` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=69606819`
- `67450136` | `A02BC01` | `OMEPRAZOLE BIOGARAN 10 mg, gélule gastro-résistante` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=67450136`
- `69380042` | `J02AC04` | `NOXAFIL 100 mg, comprimé gastro-résistant` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=69380042`
- `65731654` | `J02AC03` | `VORICONAZOLE TEVA 200 mg, comprimé pelliculé` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=65731654`
- `66136969` | `J02AC03` | `VORICONAZOLE STRAGEN 200 mg, poudre pour solution pour perfusion` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=66136969`
- `68368941` | `A04AA01` | `ONDANSETRON ZENTIVA 8 mg, comprimé pelliculé` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=68368941`
- `67029888` | `A04AA01` | `SETOFILM 8 mg, film orodispersible` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=67029888`
- `65991171` | `A04AA01` | `ZOPHREN 2 mg/ml, solution injectable en ampoule (IV)` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=65991171`
- `67592694` | `A04AA02` | `KYTRIL 1 mg, comprimé pelliculé` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=67592694`
- `69335481` | `A02BC01` | `OMEPRAZOLE ARROW LAB 20 mg, gélule gastro-résistante` | `https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=69335481`
- `4000+` lignes montrent variété ATC : antiacides (A), antiémétiques (A04), antifongiques (J02), etc. (voir données brutes pour autres classes).
