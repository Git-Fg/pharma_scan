# Structure des Fichiers BDPM (Base de Données Publique des Médicaments)

Ce document décrit la structure technique des fichiers bruts fournis par l'ANSM.

## ⚠️ Spécifications Techniques Globales

Pour tout développeur souhaitant parser ces données, ces contraintes sont critiques :

* **Encodage** : `Windows-1252` (CP1252). **Attention**, ce n'est pas de l'UTF-8. Une lecture directe en UTF-8 corrompra les caractères accentués.
* **Format** : TSV (Tab Separated Values). Le séparateur est la tabulation `\t`.
* **En-têtes** : Les fichiers ne contiennent **aucune ligne d'en-tête**. Les données commencent dès la ligne 1.
* **Intégrité** : Certains fichiers peuvent contenir des lignes vides inattendues qu'il faut filtrer.

---

## **1. 📁 CIS_bdpm.txt (Fichier Maître Produit)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt`
**Contenu** : Fichier central définissant l'existence et l'identité du médicament.

### 🛠️ Notes de Parsing

* **Col 4 (Voies admin)** : Contient potentiellement plusieurs valeurs séparées par des points-virgules (ex: `orale;rectale`). Il faut `split` cette chaîne.
* **Col 11 (Titulaire)** : Contient souvent des espaces parasites en début de chaîne (ex: `_SANOFI`). Un `TrimLeft` est nécessaire.

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | Code CIS | Identifiant unique (8 chiffres). Clé primaire. |
| **2** | Dénomination | Libellé complet du médicament. |
| **3** | Forme pharma | Forme galénique (comprimé, sirop...). |
| **4** | Voies admin | Voie d’administration (séparées par `;`). |
| **5** | Statut AMM | État de l’autorisation (Active, Abrogée...). |
| **6** | Type procédure | Type d’AMM (Nationale, Décentralisée...). |
| **7** | État commercial | Statut commercialisation (Commercialisée, Non...). |
| **8** | Date AMM | Date d’autorisation (DD/MM/YYYY). |
| **9** | Statut BDM | Ex: « Warning disponibilité ». |
| **10** | Numéro Europe | Numéro EU. |
| **11** | Titulaire | Laboratoire détendeur de l'AMM. |
| **12** | Surveillance | Oui/Non (Triangle noir ⚠️). |

Astuce : 
*La colonne 3 (forme pharma) permet à tout les coups, lorsqu'utilisé en tant que masque, de clean-up la colonne 2 pour devenir "nom dosage" uniquement sans la formulation. Par exemple, si la colonne 3 est "solution injectable", alors rechercher l'occurence de "solution injectable" puis la supprimer ainsi que tout ce qui suit est efficace.*

**Exemples :**
* `61266250` — `A 313 200 000 UI POUR CENT, pommade` — `pommade` — `cutanée` — `Autorisation active` — `Procédure nationale` — `Commercialisée` — `12/03/1998` — `PHARMA DEVELOPPEMENT` — `Non`
* `61876780` — `ABACAVIR ARROW 300 mg, comprimé pelliculé sécable` — `comprimé pelliculé sécable` — `orale` — `Autorisation active` — `Procédure décentralisée` — `Commercialisée` — `22/10/2019` — `ARROW GENERIQUES` — `Non`
* `68257528` — `ABACAVIR/LAMIVUDINE ACCORD 600 mg/300 mg, comprimé pelliculé` — `orale` — `Autorisation active` — `Procédure nationale` — `Non commercialisée` — `16/03/2017` — `Warning disponibilité` — `ACCORD HEALTHCARE FRANCE` — `Non`
* `62401060` — `ABACAVIR VIATRIS 300 mg, comprimé pelliculé sécable` — `comprimé pelliculé sécable` — `orale` — `Autorisation active` — `Procédure décentralisée` — `Commercialisée` — `21/02/2018` — `VIATRIS SANTE` — `Non`
* `63431640` — `ABACAVIR/LAMIVUDINE BIOGARAN 600 mg/300 mg, comprimé pelliculé` — `orale` — `Autorisation active` — `Procédure nationale` — `Commercialisée` — `14/02/2017` — `BIOGARAN` — `Non`

---

## **2. 📁 CIS_CIP_bdpm.txt (Codes barres & Prix)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt`
**Contenu** : Informations de conditionnement, prix et remboursement.

### 🛠️ Notes de Parsing (Critique : Prix)

* **Format Numérique** : Les colonnes Prix (10, 11, 12) utilisent la virgule `,` à la fois comme séparateur de milliers ET comme séparateur décimal.
  * Exemple brut : `"1,234,56"` (pour 1234,56 €).
  * **Algorithme requis** : Il faut supprimer toutes les virgules sauf la dernière, puis remplacer la dernière virgule par un point avant de parser en float.

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | Code CIS | Identifiant produit (Lien CIS_bdpm). |
| **2** | CIP7 | Code à 7 chiffres (ancien format). |
| **3** | Libellé Présentation | Description du conditionnement (ex: boite de 30). |
| **4** | Statut Admin | État administratif de la présentation. |
| **5** | État Commercial | État commercial de la présentation. |
| **6** | Date Déclaration | Date de commercialisation. |
| **7** | CIP13 | Code Datamatrix (13 chiffres). Clé unique présentation. |
| **8** | Agrément | Agréé aux collectivités (oui/non). |
| **9** | Taux Remb | Taux de remboursement sécu (ex: "65%"). |
| **10** | Prix TTC | Prix du médicament (format complexe, voir note). |
| **11** | Prix Global | Prix TTC + Honoraires de dispensation (ce que paie le patient). |
| **12** | Honoraire | Montant de l'honoraire pharmacien. |
| **13** | Texte Remb. | Conditions spécifiques de remboursement (ALD, etc.). |

**Exemples :**
* `60002283` | `4949729` | `plaquette(s)...30 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `16/03/2011` | `3400949497294` | `oui` | `100%` | `24,34` | `25,36` | `1,02` | (vide)
* `60003620` | `3696350` | `20 récipient(s) unidose(s)...` | `Présentation active` | `Déclaration de commercialisation` | `30/11/2006` | `3400936963504` | `oui` | `65%` | `12,81` | `13,83` | `1,02` | `Ce médicament peut être pris en charge...`
* `60007437` | `4944413` | `plaquette(s) aluminium de 28 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `08/05/2012` | `3400949444137` | `oui` | `65%` | `3,69` | `4,71` | `1,02` | (vide)
* `60004505` | `5507419` | `1 flacon(s)...` | `Déclaration d'arrêt de commercialisation` | `31/12/2023` | `3400955074199` | `non` | (taux vide) | (prix vides)
* `60004932` | `3011679` | `plaquette...60 comprimé(s)` | `Présentation active` | `Déclaration de commercialisation` | `21/11/2022` | `3400930116791` | `oui` | `15 %` | `8,92` | `9,94` | `1,02` | (vide)

---

## **3. 📁 CIS_GENER_bdpm.txt (Groupes Génériques)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt`
**Contenu** : Regroupement des médicaments par groupe thérapeutique.

### 🛠️ Notes de Parsing

* **Types de génériques (Col 4)** :
  * `0` : Princeps (Médicament de référence).
  * `1` : Générique.
  * `2` : Génériques par complémentarité posologique.
  * `3` : Générique substitutable.
* **Redondance** : L'ID Groupe est présent en colonne 1 et souvent répété en colonne 5.

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | ID Groupe | Identifiant du groupe générique. |
| **2** | Libellé Groupe | Nom du groupe (DCI + dosage + princeps). |
| **3** | CIS | Code produit (lien vers CIS_bdpm). |
| **4** | Type | Type de relation (0, 1, 2, 3). |
| **5** | Ordre historique | Ordre de tri. |

**Exemples :**
* `1` | `CIMETIDINE 200 mg - TAGAMET 200 mg, comprimé pelliculé` | `65383183` | `0`
* `1` | `CIMETIDINE 200 mg - TAGAMET 200 mg, comprimé pelliculé` | `67535309` | `1`
* `4` | `CIMETIDINE 800 mg - TAGAMET 800 mg, comprimé pelliculé sécable` | `60089516` | `0`
* `4` | `CIMETIDINE 800 mg - TAGAMET 800 mg, comprimé pelliculé sécable` | `60756034` | `1`
* `7` | `RANITIDINE... 150 mg - AZANTAC 150 mg...` | `65109314` | `0`
* `4` | `CIMETIDINE 800 mg - TAGAMET 800 mg, comprimé pelliculé sécable` | `62844636` | `2`
* `7` | `RANITIDINE...` | `66024386` | `2`

---

## **4. 📁 CIS_CPD_bdpm.txt (Conditions Prescription)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CPD_bdpm.txt`
**Contenu** : Restrictions de délivrance (Hospitalier, Stupéfiant, etc.).

### 🛠️ Notes de Parsing

* **Lignes vides** : Ce fichier contient fréquemment des lignes vides ou mal formées entre les données valides. Il est impératif de vérifier la longueur de la ligne ou le nombre de champs avant de parser.

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | CIS | Clé produit. |
| **2** | Condition | Texte libre (liste I/II, stupéfiant, hospitalier, dentaire). |

**Exemples :**
* `63852237` | `réservé à l'usage professionnel DENTAIRE`
* `65319857` | `réservé à l'usage professionnel DENTAIRE`
* `60004505` | `réservé à l'usage HOSPITALIER`
* `60030699` | `réservé à l'usage HOSPITALIER`
* `60080232` | `réservé à l'usage HOSPITALIER`

---

## **5. 📁 CIS_COMPO_bdpm.txt (Composition)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt`
**Contenu** : Composition qualitative et quantitative (Substances Actives et fractions thérapeutiques).

### 🛠️ Notes de Parsing

* **Relation One-to-Many** : Un même CIS apparaît sur plusieurs lignes, une fois pour chaque substance le composant.
* **Nature (Col 7)** :
  * `SA` : Substance Active.
  * `FT` : Fraction Thérapeutique.

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | CIS | Identifiant produit. |
| **2** | Désignation élément | Partie du produit (ex: « comprimé », « gélule »). |
| **3** | Code Substance | ID unique de la molécule. |
| **4** | Dénomination | Nom de la substance. |
| **5** | Dosage | Valeur quantitative (ex: "100 mg"). |
| **6** | Réf Dosage | Unité de prise (ex: "un comprimé"). |
| **7** | Nature | SA (Substance Active) ou FT. |
| **8** | Lien | Numéro de lien SA/FT. |

**Exemples :**
* `60002283` | `comprimé` | `42215` | `ANASTROZOLE` | `1,00 mg` | `un comprimé` | `SA` | `1`
* `60003620` | `suspension` | `04179` | `DIPROPIONATE DE BECLOMETASONE` | `800 microgrammes` | `2 ml de suspension` | `SA` | `1`
* `60004277` | `gélule` | `03902` | `FENOFIBRATE` | `100,00 mg` | `une gélule` | `SA` | `1`
* `60004487` | `comprimé` | `86571` | `CHLORHYDRATE DE TRAMADOL` | `200 mg` | `un comprimé` | `SA` | `1`
* `60004932` | `comprimé` | `04442` | `METFORMINE` | `780 mg` | `un comprimé` | `FT` | `1`
* `60004932` | `comprimé` | `24321` | `CHLORHYDRATE DE METFORMINE` | `1000 mg` | `un comprimé` | `SA` | `1`

---

## **6. 📁 CIS_CIP_Dispo_Spec.txt (Ruptures / Tensions)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_Dispo_Spec.txt`
**Contenu** : Informations sur la disponibilité des stocks.

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | CIS | Code produit. |
| **2** | CIP13 | Présentation concernée (souvent vide = concerne tout le CIS). |
| **3** | Code Statut | 1=Rupture, 2=Tension, 3=Arrêt, 4=Remise dispo. |
| **4** | Libellé Statut | Ex: « Tension d’approvisionnement ». |
| **5** | Date Début | Date de début du problème. |
| **6** | Date Fin Prev | Date de retour prévue. |
| **7** | Date Retour | Date réelle de remise à disposition (si applicable). |
| **8** | Lien ANSM | URL vers le PDF officiel d'information. |

**Exemples :**
* `69622218` | (CIP vide) | `2` | `Tension d'approvisionnement` | `04/12/2025` | `08/12/2025` | | (lien ANSM)
* `69497711` | (CIP vide) | `2` | `Tension d'approvisionnement` | `20/10/2025` | `05/12/2025` | | (lien ANSM)
* `67947540` | (CIP vide) | `4` | `Remise à disposition` | `01/12/2025` | `04/12/2025` | `01/12/2025` | (lien ANSM)
* `62119207` | (CIP vide) | `1` | `Rupture de stock` | `25/11/2025` | `02/12/2025` | | (lien ANSM)
* `64590923` | `3400955090250` | `2` | `Tension d'approvisionnement` | `08/11/2023` | `04/12/2025` | | (lien ANSM)

---

## **7. 📁 CIS_MITM.txt (Classification Thérapeutique)**

**Source** : `https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_MITM.txt`
**Contenu** : Lien vers la classification ATC (Anatomique, Thérapeutique et Chimique).

| # | Nom | Description réelle |
| :--- | :--- | :--- |
| **1** | CIS | Code produit. |
| **2** | Code ATC | Code de classification (ex: J01AA02). |
| **3** | Libellé ATC | Libellé de la classe. |
| **4** | Lien Page | URL vers la fiche info gouv. |

**Exemples :**
* `68053454` | `A02BA01` | `CIMETIDINE ARROW 200 mg, comprimé effervescent` | `https://base-...`
* `69606819` | `A02BC01` | `MOPRAL 10 mg, gélule gastro-résistante` | `https://base-...`
* `69380042` | `J02AC04` | `NOXAFIL 100 mg, comprimé gastro-résistant` | `https://base-...`
* `65731654` | `J02AC03` | `VORICONAZOLE TEVA 200 mg, comprimé pelliculé` | `https://base-...`
* `68368941` | `A04AA01` | `ONDANSETRON ZENTIVA 8 mg, comprimé pelliculé` | `https://base-...`
