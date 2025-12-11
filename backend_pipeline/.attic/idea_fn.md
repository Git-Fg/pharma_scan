# Documentation Technique : Parsing Optimisé BDPM & Architecture de Données

## 1. Objectif Fondamental

Construire une base de données relationnelle robuste permettant, à partir d'un scan de boîte (CIP) ou d'un nom générique (CIS), de remonter systématiquement au **Princeps (Médicament de référence)** et de regrouper les médicaments par équivalence thérapeutique stricte.

**Exemple cible :**

* Input : *Amoxicilline Sandoz 500 mg*
* Output visuel/logique : *Clamoxyl* (Nom Canonique)

## 2. Architecture Hiérarchique Cible

Le parsing doit alimenter 4 niveaux logiques distincts :

1. **CLUSTER (Molécule / Combinaison)**
    * *Définition :* La substance active ou l'association de substances, indépendamment du dosage.
    * *Exemple :* Amoxicilline (seul) ou Bisoprolol + Perindopril.
2. **GROUP (Tiroir / Dosage-Forme)**
    * *Définition :* Un dosage et une forme spécifique pour un Cluster donné.
    * *Source clé :* `CIS_GENER_bdpm.txt` (ID de groupe).
    * *Exemple :* Amoxicilline 500 mg Gélules.
3. **CIS (Produit Commercial)**
    * *Définition :* La marque ou le générique spécifique d'un laboratoire.
    * *Source clé :* `CIS_bdpm.txt`.
    * *Exemple :* Amoxicilline Biogaran 500 mg.
4. **CIP (Présentation Logistique)**
    * *Définition :* La boîte physique (Code barre).
    * *Source clé :* `CIS_CIP_bdpm.txt`.
    * *Exemple :* Boîte de 12 gélules.

---

## 3. Stratégie de Nommage et Consolidation (Le "Nom Canonique")

Cette section est critique. Elle définit comment on attribue le nom "Clamoxyl" à tout le groupe générique.

### A. Algorithme de Détermination du Nom Canonique

Pour chaque `ID Groupe` dans `CIS_GENER_bdpm.txt`, appliquer la logique en cascade suivante :

#### Priorité 1 : Le Princeps Actif (Type 0)

Si le groupe contient un enregistrement où `Type = 0` (colonne 4) :

1. Récupérer le `Code CIS` de ce Type 0.
2. Aller dans `CIS_bdpm.txt` (Fichier Maître) avec ce CIS.
3. Récupérer la **Dénomination** (colonne 2).
4. **Application du Masque (Cleaning) :**
    * Récupérer la **Forme Pharma** (colonne 3 de `CIS_bdpm`).
    * *Action :* Soustraire la chaîne de caractères de la forme et du dosage de la Dénomination ainsi que tout ce qui suit après ce "masque" pour ne garder que le nom de marque + dosage pur.
    * *Regex suggérée :* Supprimer ce qui suit la virgule ou les mots clés de forme (ex: ", comprimé...").
5. Récupérer les autres noms de princeps de type 0, et les garder. Peuvent être utile pour les noms alternatifs de princeps et doit être intégré dans le tableau. 

#### Priorité 2 : Le Princeps Historique (Parsing CIS_GENER)

Si aucun Type 0 n'est présent (princeps retiré du marché ou groupe générique pur) :

1. Lire la colonne 2 (`Libellé`) de `CIS_GENER_bdpm.txt`.
    * *Format standard :* `[DCI + Dosage] - [PRINCEPS HISTORIQUE + Dosage], [Forme]`
2. **Parsing par séparateur "Em Dash" / Tiret :**
    * Identifier le **dernier** séparateur " - " (tiret entouré d'espaces). S'il n'y a qu'un seul em dash, identifier le sans nécessité d'être entouré d'espace pour fallback
    * La partie à **droite** est le candidat "Princeps Historique".
3. **Nettoyage :** Appliquer une regex pour retirer le dosage et la forme de cette chaîne extraite afin d'obtenir le nom propre (ex: "TAGAMET").

#### Priorité 3 : Le Nom Générique "Clean" (Fallback)

Pour affichage secondaire ou validation :

1. Lire la colonne 2 (`Libellé`) de `CIS_GENER_bdpm.txt`.
2. La partie à **gauche** du premier séparateur " - " est le nom générique DCI propre (sans laboratoire, sans commencer par la mention du sel, bien qu'il le contienne entre parenthèse souvent dans le nom).

### B. Stockage des Données de Nommage

Dans la table `Groups`, stocker impérativement :

* `canonical_name` : Résultat de Priorité 1 ou 2.
* `historical_princeps_raw` : Résultat brut du parsing de droite (Priorité 2).
* `generic_label_clean` : Résultat du parsing de gauche (Priorité 3).
* `naming_source` : Enum (`TYPE_0_LINK`, `GENER_PARSING`).

---

## 4. Extraction Détaillée des Attributs

### A. Composition et Dosage (Source : `CIS_COMPO_bdpm.txt`)

* **Jointure :** Sur `Code CIS`.
* **Logique SA vs FT :**
  * Vérifier la colonne 7 (`Nature`). + 8 (numéro)
  * Prendre le premier numéro : si FT, utiliser celui ci. Sinon FA
  * Prendre le second numéro : si FT, utiliser celui ci. Sinon FA
  ...
* **Agrégation Cluster :** Utiliser les codes substances (col 3) pour valider l'appartenance au Cluster. Tous les CIS d'un même Groupe doivent avoir les mêmes codes substances (sauf sels différents gérés par le lien FT/SA).

### B. Voie d'administration (Source : `CIS_bdpm.txt`)

* **Source :** Colonne 4.
* **Propagation :** Attribuer la voie d'administration au niveau **GROUP**.
* **Validation :** Vérifier que tous les CIS d'un même Groupe partagent la même voie (ou des voies compatibles, ex: Orale vs Orale/Sublinguale).

### C. Indicateurs de Sécurité et Réglementaires (Source : `CIS_CPD_bdpm.txt`)

* **Scanning des mots-clés :** Analyser la colonne 2 (Texte libre) pour chaque CIS.
* **Tags à extraire :**
  * `DENTAIRE`
  * `HOSPITALIER` (ou "Réservé à l'usage hospitalier")
  * `STUPEFIANT`
  * `LISTE I` / `LISTE II`
* **Logique de propagation :** Si *un seul* CIS actif d'un Groupe possède le tag "STUPEFIANT", le Groupe entier doit être flaggé (Alerte de sécurité conservatrice).

### D. Classification Thérapeutique (Source : `CIS_MITM.txt`)

* **Donnée :** Code ATC (col 2) et Libellé (col 3).
* **Usage :**
  * Utiliser le Code ATC pour catégoriser le Cluster (ex: Antibiotique, Antidépresseur).
  * Le Libellé ATC contient souvent le nom du princeps. **Action :** Utiliser ce champ comme source de validation croisée pour le Nom Canonique (Priorité 1/2).

---

## 5. Gestion des Métadonnées Commerciales (CIP)

### A. Prix et Remboursement (Source : `CIS_CIP_bdpm.txt`)

* **Niveau :** CIP (Présentation).
* **Données :**
  * `Prix Global` (col 11) : Prioritaire pour l'affichage patient.
  * `Taux Remb` (col 9).
* **Gestion des NULL :** Accepter les valeurs nulles (médicaments non remboursés ou hospitaliers). Ne pas filtrer ces lignes.

### B. Ruptures et Tensions (Source : `CIS_CIP_Dispo_Spec.txt`)

* **Jointure :** Par `Code CIS` (col 1) ET `CIP13` (col 2).
  * *Note :* Si `CIP13` est vide, la rupture s'applique à **tous** les CIP du CIS.
* **Statuts (col 3) :**
  * `1` (Rupture), `2` (Tension), `3` (Arrêt) -> **Flag Rouge/Orange**.
  * `4` (Remise à dispo) -> **Flag Vert** (avec date).
* **Historisation :** Garder les dates de début/fin pour afficher une timeline de disponibilité.

---

## 6. Stratégie de Validation et Tests (Backend)

Pour assurer la robustesse du parsing, implémenter les tests automatisés suivants :

### A. Tests de Cohérence de Groupe (ID Colocalization)

* **Logique :** Les ID de groupes dans `CIS_GENER` sont souvent séquentiels pour une même molécule (ex: Grp 57 = 50mg, Grp 58 = 75mg).
* **Test :** Vérifier si des Groupes aux ID proches partagent les mêmes substances (via `CIS_COMPO`). Si oui, ils appartiennent au même Cluster.

### B. Validation du Nom Canonique

* Comparer le `canonical_name` extrait (via méthode Type 0 ou Parsing Gener) avec le nom présent dans le libellé de `CIS_MITM`.
* *Alerte :* Si distance de Levenshtein élevée entre les deux résultats -> Flaguer pour révision manuelle.

### C. Validation Mono-composant

* Pour les médicaments n'ayant qu'une seule ligne dans `CIS_COMPO`, vérifier que le nom de la substance (col 4 `CIS_COMPO`) est contenu dans la partie gauche (Générique DCI) extraite de `CIS_GENER`.

### D. Validation des Voies

* Scanner tous les CIS d'un Groupe. Lever une erreur si on trouve un mélange de voies incompatibles (ex: Injectable et Oral dans le même Groupe générique).

### E. Validation du Statut Commercial

* Croiser `Etat commercial` (`CIS_bdpm` col 7) avec `CIS_CIP_Dispo_Spec`.
* *Règle :* Un produit marqué "Non commercialisé" dans BDPM ne doit pas être affiché comme "Disponible" même si aucune rupture n'est signalée.

---

## 7. Résumé des Flux de Données (Data Flow)

1. **Ingestion :** Charger tous les fichiers TXT bruts.
2. **Cleaning Base :**
    * Parsing des dates (DD/MM/YYYY).
    * Conversion virgules -> points pour les prix/dosages.
    * Trim des espaces inutiles.
3. **Construction Groupes & Noms :**
    * Pivot sur `CIS_GENER`.
    * Extraction du Princeps (Type 0 ou Regex).
    * Création des objets `Group`.
4. **Enrichissement CIS :**
    * Attachement des CIS aux Groupes.
    * Ajout info Voie, Labo, Statut AMM.
    * Scan des Conditions (Stup, Hosp).
5. **Enrichissement CIP :**
    * Attachement des CIP aux CIS.
    * Ajout Prix, Taux Remb.
    * Application des status de Rupture (Dispo_Spec).
6. **Composition :**
    * Liaison `CIS_COMPO` -> Création liens `Substance` -> Validation `Cluster`.
7. **Final Check :** Exécution de la suite de tests de cohérence.
