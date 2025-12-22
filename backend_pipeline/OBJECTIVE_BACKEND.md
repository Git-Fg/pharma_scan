# Objectif du Backend Pipeline

## 🎯 Objectif Principal

**Transformer les données réglementaires BDPM en une base de données optimisée pour le rangement des médicaments en officine.**

L'application finale permet aux pharmaciens de :
1. **Scanner** un code-barres (CIP13/CIP7)
2. **Identifier** le "tiroir" (Cluster) où ranger le médicament
3. **Visualiser** tous les médicaments du même concept thérapeutique

---

## 📊 Modèle de Données Cible

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLUSTER (Tiroir)                         │
│                    Ex: "CLAMOXYL" (CLS_ABC123)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │   CIS 60234567      │  │   CIS 60234568      │   ...        │
│  │ CLAMOXYL 500 mg     │  │ CLAMOXYL 1 g        │              │
│  │ gélule              │  │ comprimé dispersible│              │
│  ├─────────────────────┤  ├─────────────────────┤              │
│  │ CIP 3400930000001   │  │ CIP 3400930000010   │              │
│  │ Boîte de 12         │  │ Boîte de 6          │              │
│  ├─────────────────────┤  ├─────────────────────┤              │
│  │ CIP 3400930000002   │  │ CIP 3400930000011   │              │
│  │ Boîte de 24         │  │ Boîte de 14         │              │
│  └─────────────────────┘  └─────────────────────┘              │
│                                                                 │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │   CIS 60234569      │  │   CIS 60234570      │   ...        │
│  │ AMOXICILLINE BIOGARAN │ AMOXICILLINE SANDOZ │              │
│  │ 500 mg gélule       │  │ 500 mg gélule       │              │
│  │ (Générique)         │  │ (Générique)         │              │
│  └─────────────────────┘  └─────────────────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Hiérarchie :**
- **Cluster** (Tiroir) → Concept thérapeutique (ex: "CLAMOXYL" = Amoxicilline)
- **CIS** (Spécialité) → Forme et dosage spécifique (ex: "CLAMOXYL 500 mg gélule")
- **CIP** (Présentation) → Boîte physique scannée (ex: "Boîte de 12 gélules")

---

## 📁 Fichiers Sources BDPM

### Règles de Parsing Strictes

1.  **Encodage Caractères** : `Windows-1252` (CP1252).
    *   **Impératif** : Ne pas télécharger en UTF-8. Les fichiers contiennent des caractères accentués (é, è, à) encodés sur un octet selon la page de code Windows occidentale.
2.  **Format de Fichier** : TSV (Tab Separated Values).
    *   **Séparateur** : Tabulation (`\t`) uniquement.
    *   **Pas de Qualificateurs** : Il n'y a **jamais** de guillemets autour des chaînes de caractères.
3.  **Convention de Numérotation des Colonnes** :
    *   Dans ce document, les colonnes sont numérotées **à partir de 1** (Col 1 = première colonne).
    *   **Attention** : Lors de l'implémentation, les tableaux sont indexés à partir de 0. Il faudra soustraire 1 aux numéros de ce document.
4.  **Normalisation de Texte pour Comparaisons** :
    
    Toutes les opérations de comparaison, masquage et matching doivent être effectuées après normalisation complète. Cette normalisation s'applique aux données **non exposées** (internes) uniquement.
    
    **Pipeline de Normalisation :**
    1.  **Remplacement des slashes** : `/` → espace
        *   Exemple : "AMOXICILLINE/ACIDE CLAVULANIQUE" → "AMOXICILLINE ACIDE CLAVULANIQUE"
    2.  **Suppression des tirets** : `-` et `–` → supprimés
        *   Exemple : "BI-PROFENID" → "BIPROFENID"
    3.  **Mise en majuscules** : tout en uppercase
        *   Exemple : "gélule" → "GELULE"
    4.  **Diacritisation (suppression des accents)** : é→E, à→A, etc.
        *   Exemple : "GÉLULE" → "GELULE"
    5.  **Trim** : suppression des espaces en début/fin
    
    **Résultat Final** : Texte en majuscules, sans accents, sans tirets, slashes convertis en espaces.
    
    *   **Philosophie** : Mieux vaut une perte d'accent qu'une perte de sens. À valider par tests.

### Fichiers Utilisés

| Fichier | Contenu | Utilisation |
|---------|---------|-------------|
| `CIS_bdpm.txt` | Liste des spécialités (CIS) | Nom, forme pharmaceutique, titulaire |
| `CIS_CIP_bdpm.txt` | Présentations (CIP) par CIS | Code-barres, prix, remboursement |
| `CIS_COMPO_bdpm.txt` | Composition (principes actifs) | Substance, dosage par CIS |
| `CIS_GENER_bdpm.txt` | Groupes génériques | Liens Princeps ↔ Génériques |
| `CIS_CPD_bdpm.txt` | Conditions de prescription | Liste I, II, Stupéfiants |

---

## 🔄 Pipeline Algorithmique de Transformation

---

### Étape 1 : Ingestion & Prétraitement (Sanitization)

**Entrée :** `CIS_bdpm.txt` (Séparateur : `Tabulation \t`)

**Structure du fichier :**
```text
Col 0: CIS (Code Identifiant Spécialité)
Col 1: Dénomination complète (ex: "CLAMOXYL 500 mg, gélule")
Col 2: Forme pharmaceutique (ex: "gélule")
Col 3: Voie d'administration (ex: "orale")
Col 4: Statut AMM
...
```

**Exemple ligne brute :**
```text
60234567	CLAMOXYL 500 mg, gélule	gélule	orale	Actif	...
```

**Algorithme de Nettoyage :**

1.  **Parsing** : Lecture ligne par ligne, split sur `\t`.

2.  **Nettoyage Forme (Soustraction Col 3 de Col 2)** :
    *   On prend le `Nom Brut` (Col 2) : "CLAMOXYL 500 mg, gélule"
    *   On prend la `Forme` (Col 3) : "gélule"
    *   On soustrait exactement la Forme du Nom Brut.
    *   On retire également la virgule et les espaces résiduels à la fin.
    *   **Résultat** : `Nom Complet` = "CLAMOXYL 500 mg"
    *   **IMPORTANT** : À ce stade, le nom contient encore le dosage. Le dosage sera retiré plus tard lors de l'étape 3.
    *   **Note** : La difficulté du parsing vient parfois de la présence de plusieurs virgules dans l'intitulé. La forme est toujours après la **dernière** virgule.

3.  **Filtrage Homéopathie (Détection en 2 Niveaux)** :
    
    **Niveau 1 - Par Laboratoire (Prioritaire)** :
    *   Lire la colonne 11 (Titulaire/Laboratoire).
    *   Considérer comme **homéopathique** tout produit dont le laboratoire contient (en début, milieu ou fin, insensible à la casse) :
        *   `BOIRON`
        *   `LEHNING`
        *   `WELEDA`
    *   Exemples matchés : "LABORATOIRES BOIRON", "BOIRON SA", "WELEDA FRANCE"
    
    **Niveau 2 - Par Mots-clés (Fallback)** :
    *   Si le Niveau 1 ne matche pas, appliquer une détection par mots-clés dans le nom du produit (Col 2).
    *   Après **diacritisation** (suppression des accents), chercher :
        *   `homeopathie` ou `homeopathique`
        *   `degre de dilution`
    *   Exemples : "ARNICA MONTANA 9CH, granules homéopathiques" → Match sur "homeopathiques"

**Données Clés Extraites (Objets Spécialité) :**

Pour chaque ligne valide, on crée un objet avec :
*   `CIS` : Identifiant unique (Col 1)
*   `Nom Original` : Tel quel depuis le fichier (Col 2, ex: "CLAMOXYL 500 mg, gélule")
*   `Nom Complet` : Après soustraction de la forme (ex: "CLAMOXYL 500 mg")
*   `Forme` : Source de vérité pour la forme pharmaceutique (Col 3, ex: "gélule")

---

### Étape 2 : Chargement des Groupes Génériques & Choix du Pivot

**Entrée :** `CIS_GENER_bdpm.txt` (Séparateur : `Tabulation \t`)

**Structure du fichier :**
```text
Col 1: Identifiant du groupe générique (Group_ID)
Col 2: Libellé du groupe (format: "[DCI + Dosage] - [PRINCEPS + Dosage, forme]")
Col 3: Code CIS du médicament membre
Col 4: Type du membre (0=Princeps, 1=Générique, 2=Substituable, 4=Référent)
Col 5: Numéro de tri (ordre de priorité) — C'est la DERNIÈRE colonne du fichier
```

**Exemple ligne brute :**
```text
440	METHOTREXATE 2,5 mg/ml - METHOTREXATE NEURAXPHARM 5mg/2mL, solution injectable.	67961853	0	1
```
*Note : Dans cet exemple, Col 5 = "1" (l'ordre de tri).*

**Algorithme de Détermination du "Pivot" (Source du Nom de Cluster) :**

Pour **chaque groupe générique** unique (identifié par `Group_ID`) :

1.  **Récupération des Candidats Princeps** :
    *   Filtrer toutes les lignes du groupe où `Type == 0` (ce sont les Princeps déclarés).
    *   Il peut y avoir plusieurs Princeps pour un même groupe (cas rares mais existants).

2.  **Tri Prioritaire** :
    *   Trier ces candidats Princeps par la valeur de la colonne `Ordre` (Col 4, la dernière) en ordre **croissant**.
    *   Le Princeps avec l'ordre le plus bas (1) est considéré comme le plus "prioritaire".

3.  **Sélection Active (Boucle de Validation)** :
    *   Parcourir la liste triée des candidats Princeps.
    *   Pour **chaque** candidat :
        *   Vérifier si le CIS du candidat **existe** dans la table/collection `specialites` (chargée à l'Étape 1).
        *   Si le CIS existe :
            *   Le **Premier** trouvé devient le **Pivot Principal**.
            *   **Continuer la boucle** : Les candidats suivants (s'ils existent aussi dans `specialites`) sont stockés comme **Princeps Secondaires**. Ces noms seront utiles pour la consolidation ultérieure.
    *   **Note Cruciale** : On utilise ici le `Nom Complet` (Marque + Dosage, ex: "CLAMOXYL 500 mg") issu du nettoyage de l'Étape 1.

4.  **Fallback (Recours si aucun Princeps actif trouvé)** :
    
    Si, après avoir parcouru tous les candidats Type 0, **aucun n'existe** dans `specialites`, on doit extraire le nom du Princeps depuis le `Libellé Groupe` (après le dernier tiret) (Col 2).
    
    **Exemple de Libellé :**
    ```
    "METHOTREXATE 2,5 mg/ml - METHOTREXATE NEURAXPHARM 5mg/2mL, solution injectable."
    ```
    
    **Stratégie de Parsing en Cascade :**
    
    **Étape F1 - Extraction après le dernier tiret (Cascade de séparateurs)** :
    
    Essayer les séparateurs dans cet ordre de priorité :
    1.  **Em-dash avec espaces** : " – " (espace + tiret long Unicode U+2013 + espace)
    2.  **Tiret court avec espaces** : " - " (espace + tiret ASCII + espace)
    3.  **Tiret sans espaces** : "-" ou "–" (tiret court ou long, sans espaces)
    
    Pour chaque séparateur, chercher la **dernière** occurrence dans le Libellé.
    Si trouvé, prendre la partie **droite**.
    
    *   Exemple avec " - " : "METHOTREXATE 2,5 mg/ml - METHOTREXATE NEURAXPHARM 5mg/2mL, solution injectable."
        *   → "METHOTREXATE NEURAXPHARM 5mg/2mL, solution injectable."
    
    **⚠️ Si aucun tiret trouvé (aucune des 3 variantes)** :
    *   **Lever une erreur/warning** : Ce cas ne devrait pas arriver avec des données BDPM conformes.
    *   Logguer le Group_ID et le Libellé pour investigation.
    *   En fallback ultime : prendre le Libellé entier et passer aux étapes suivantes.
    
    **Étape F2 - Soustraction des Formes Normalisées :**
    *   Utiliser le **Dictionnaire de Formes Normalisées** (constitué en Phase 2b de l'Étape 3).
    *   Tenter de soustraire chaque forme de la fin de la chaîne.
    *   Exemple : "METHOTREXATE NEURAXPHARM 5mg/2mL, solution injectable."
        *   Dictionnaire contient "solution injectable" → Match !
        *   Résultat : "METHOTREXATE NEURAXPHARM 5mg/2mL,"
    *   Retirer la virgule et espaces résiduels.
    
    **Étape F3 - Détection de la dernière virgule :**
    *   Si la chaîne contient encore une virgule :
        *   Trouver la **dernière virgule**.
        *   Supprimer la virgule et tout ce qui suit.
    *   Exemple : "METHOTREXATE NEURAXPHARM 5mg/2mL," → "METHOTREXATE NEURAXPHARM 5mg/2mL"
    
    **Étape F4 - Nettoyage du dosage (si nécessaire)** :
    *   À ce stade, le nom peut encore contenir un dosage ("5mg/2mL").
    *   On conserve le dosage pour l'instant (sera traité en Phase 3 de l'Étape 3).
    
    **Résultat** : Le **Pivot Textuel** (String brute, ex: "METHOTREXATE NEURAXPHARM 5mg/2mL").

**Données Clés Extraites (Objets Groupe) :**

Pour chaque groupe générique, on crée un objet avec :
*   `Groupe ID` : Identifiant unique du groupe
*   `Pivot Principal` : Soit un **Objet Spécialité** (lien vers CIS de l'étape 1), soit une **String** (Pivot Textuel brut si fallback)
*   `Princeps Secondaires` : Liste d'**Objets Spécialité** (les autres Type 0 actifs trouvés)
*   `Liste des Membres` : Tous les CIS appartenant à ce groupe (quel que soit leur type)

**Résultat attendu à la fin de cette étape :**
*   On a réuni les CIS par groupe générique.
*   Chaque groupe est nommé en fonction de son Pivot Principal.
*   Le nom du Pivot est sous la forme "MARQUE DOSAGE" (ex: "CLAMOXYL 500 mg").

---

### Étape 3 : Création des Clusters (Logique Avancée - 4 Phases + Orphelins)

**Objectif Global :** Construire des Clusters basés sur la **substance chimique** et la **forme pharmaceutique**, et déterminer le **nom propre de marque** (sans dosage) pour chaque cluster.

---

#### Phase 1 : Analyse de la Composition (Le "Profil Chimique")

**But :** Pour chaque Groupe Générique, déterminer sa signature chimique à partir du CIS du Pivot Principal.

**Entrée :** `CIS_COMPO_bdpm.txt` (Séparateur : `Tabulation \t`)

**Structure du fichier CIS_COMPO_bdpm.txt :**
```text
Col 0: Code CIS
Col 1: Désignation de l'élément (ex: "principe actif")
Col 2: Code de la substance
Col 3: Dénomination de la substance (ex: "AMOXICILLINE TRIHYDRATÉE")
Col 4: Dosage (ex: "500 mg")
Col 5: Référence dosage (ex: "un comprimé")
Col 6: Nature du composant (SA = Substance Active, FT = Fraction Thérapeutique)
Col 7: Numéro de liaison (LinkID) - relie SA et FT d'une même molécule
```

**Algorithme :**

1.  **Lookup** :
    *   Prendre le CIS du **Pivot Principal** (déterminé à l'Étape 2).
    *   Aller chercher **toutes les lignes** de `CIS_COMPO_bdpm.txt` correspondant à ce CIS.

2.  **Filtrage FT/SA (Dédoublonnage par LinkID)** :
    *   Pour chaque ligne récupérée, lire la colonne 7 (`LinkID`).
    *   **Regrouper** les lignes par `LinkID`.
    *   Pour chaque groupe de `LinkID` :
        *   S'il y a **plusieurs lignes** avec le même `LinkID` (ce qui signifie qu'on a à la fois une SA et une FT pour la même molécule) :
            *   Garder **uniquement** la ligne où Col 6 == "FT" (Fraction Thérapeutique).
            *   Ignorer la ligne SA.
        *   S'il n'y a qu'**une seule ligne** pour ce `LinkID` :
            *   La garder (qu'elle soit SA ou FT).
    *   **Pourquoi ?** La FT représente la forme réellement active/mesurée et son dosage est plus précis que la SA (qui peut être un sel ou une forme hydratée avec un dosage équivalent différent).
    *   **Résultat attendu** : À ce stade, chaque `LinkID` est unique.

3.  **Extraction des Données** :
    *   Pour chaque ligne retenue après filtrage, extraire :
        *   `Code Substance` (Col 2) : Identifiant unique de la molécule
        *   `Nom Substance` (Col 3) : Dénomination (ex: "AMOXICILLINE TRIHYDRATÉE")
        *   `Dosage` (Col 4) : Valeur et unité (ex: "500 mg")

**Données Clés Extraites (Profil Chimique du Groupe) :**
*   Liste de tuples `(Code Substance, Nom Substance, Dosage)`
*   Ces données seront utilisées pour le regroupement et le nettoyage.

---

#### Phase 2 : Normalisation des Substances

**But :** Nettoyer les noms de molécules pour obtenir une forme canonique, indépendante des sels et formes d'hydratation.

**Problème à résoudre :**
*   Un même `Code Substance` peut être associé à plusieurs variantes de noms selon les médicaments.
*   Exemple : Code X peut être lié à :
    *   "MONTELUKAST ACIDE"
    *   "MONTELUKAST SODIQUE"
    *   "MONTELUKAST"
*   On veut unifier ces variantes pour n'avoir qu'**un seul nom canonique** par code.

**Algorithme :**

1.  **Agrégation Globale** :
    *   Pour chaque `Code Substance` unique rencontré **dans toute la base** (pas juste un groupe) :
        *   Récupérer toutes les variantes de `Nom Substance` associées à ce code (depuis tous les CIS).

2.  **Sélection du Nom Canonique** :
    *   Parmi toutes les variantes, garder la **plus courte**.
    *   **Raisonnement** : La forme courte est généralement la DCI pure, sans suffixe de sel (sodique, potassique) ou d'hydratation (monohydrate, etc.).
    *   **Alternative à tester** : Utiliser une logique de **Plus Long Préfixe Commun (LPC)** si la forme courte n'est pas satisfaisante.
    *   Exemple :
        *   Variantes : ["MONTELUKAST ACIDE", "MONTELUKAST SODIQUE", "MONTELUKAST"]
        *   Résultat : "MONTELUKAST" (le plus court)

3.  **Table de Mapping** :
    *   Créer une Map `Code Substance` → `Nom Canonique`.
    *   Cette table sera réutilisée pour standardiser les noms de substances partout.

---

#### Phase 2b : Extraction des Formes Normalisées (Ressource Réutilisable)

**But :** Constituer une liste de **formes pharmaceutiques normalisées et courtes** issues de `CIS_COMPO`, utilisables comme masque universel de nettoyage.

**Observation Clé :**
*   Les formes extraites de `CIS_COMPO` (Col 5 : "Référence dosage") sont généralement **courtes** et **standardisées**.
*   Exemples : "un comprimé", "une gélule", "une dose", "un sachet".
*   Ces formes normalisées correspondent très souvent aux **premiers mots** qui apparaissent après la virgule dans les noms bruts.
*   Que ce soit dans `CIS_BDPM` (Col 1 après virgule : "gélule") ou dans le parsing du nom Princeps après le dernier tiret (ex: "CLAMOXYL 500 mg, gélule").

**Algorithme d'Extraction :**

1.  **Collecte Globale** :
    *   Parcourir **toutes** les lignes de `CIS_COMPO_bdpm.txt`.
    *   Extraire la valeur de la colonne 5 ("Référence dosage").
    *   Normaliser : retirer les préfixes génériques ("un ", "une ", "1 ").
    *   Exemples :
        *   "un comprimé" → "comprimé"
        *   "une gélule" → "gélule"
        *   "1 sachet" → "sachet"

2.  **Dédoublonnage** :
    *   Garder uniquement les valeurs **uniques**.
    *   Trier par longueur **décroissante** (les plus longues d'abord).
    *   **Raison** : Éviter les faux positifs. Si on teste "comprimé" avant "comprimé pelliculé", on risque de matcher incorrectement. En testant les formes longues d'abord, on garantit un match plus précis.

3.  **Constitution de la Liste de Masques Universels** :
    *   Cette liste ordonnée devient le **Dictionnaire de Formes Normalisées**.
    *   Exemples (ordre décroissant) : ["comprimé orodispersible", "comprimé pelliculé", "comprimé", "gélule", "sachet", "dose", ...].

**Utilisation Future (Masque Universel Fallback)** :

*   Ce dictionnaire sera utilisé comme **stratégie de nettoyage de fallback** lorsque les masques spécifiques au groupe ne sont pas disponibles.
*   **Cas d'usage 1 - Orphelins** : Quand on nettoie un nom orphelin, avant d'appliquer la Regex générique de dosage, on peut d'abord tenter de soustraire chaque forme du dictionnaire.
*   **Cas d'usage 2 - Fallback Parsing (Étape 2)** : Quand le Pivot Textuel est extrait du Libellé Groupe (après le dernier tiret), il contient souvent la forme. On peut tenter de soustraire les formes du dictionnaire pour obtenir un nom plus propre.
*   **Avantage** : Les formes du dictionnaire sont connues et fiables contrairement à une Regex qui peut être trop agressive ou trop permissive.

---

#### Phase 3 : Groupement par Forme & Nettoyage du Dosage

**But :** Obtenir des sous-clusters distincts par combinaison (Substance + Forme) et nettoyer le nom de marque pour retirer le dosage.

**Étape 3.1 : Regroupement par Substance + Forme**

1.  **Critère de regroupement** :
    *   Deux Groupes Génériques sont dans le **même sous-cluster** s'ils partagent :
        *   Le **même set de Codes Substance** (l'ordre n'importe pas : {A, B} == {B, A}).
        *   La **même Forme** (Col 2 de `CIS_BDPM`, ex: "gélule", "comprimé pelliculé").

2.  **Pourquoi distinguer par forme ?**
    *   Certaines molécules ont des Princeps différents selon la forme.
    *   Exemple : Tamsulosine gélule LP et Tamsulosine comprimé n'ont pas le même Princeps de référence.
    *   Cette information de forme est **essentielle** pour l'UI de l'application, même si les clusters finaux peuvent les réunir.

3.  **Résultat** :
    *   Des sous-clusters homogènes : même(s) substance(s), même forme.
    *   Chaque sous-cluster peut contenir plusieurs Princeps (Principal + Secondaires).

**Étape 3.2 : Constitution du Masque de Dosage**

1.  **Récupération des dosages connus** :
    *   Prendre toutes les valeurs uniques de `Dosage` extraites en Phase 1 pour **tous** les membres du sous-cluster.
    *   Exemple pour un sous-cluster Amoxicilline gélule : ["500 mg", "250 mg", "1 g"]

2.  **Génération de variantes** :
    *   Pour chaque dosage unique, générer des variantes avec/sans espace, virgule vs point :
        *   "500 mg" → ["500 mg", "500mg", "500,0 mg", "500.0 mg"]
        *   "1 g" → ["1 g", "1g", "1,0 g", "1.0 g"]
    *   Cela permet de matcher des variations mineures de formatting dans les noms de produits.

**Étape 3.3 : Nettoyage du Nom de Marque (Soustraction Dosage)**

1.  **Entrée** :
    *   Les noms des Princeps du sous-cluster (Pivot Principal + Secondaires).
    *   Chaque nom est au format "MARQUE DOSAGE" (ex: "CLAMOXYL 500 mg").

2.  **Algorithme de soustraction** :
    *   Pour chaque nom de Princeps :
        *   Parcourir les variantes de dosage du masque (générées à l'étape 3.2).
        *   Tenter de **trouver un match exact** à la fin de la chaîne.
        *   Exemple : "CLAMOXYL 500 mg" avec masque "500 mg" :
            *   La chaîne se termine par "500 mg" → **Match !**
            *   On supprime "500 mg" de la fin.
            *   On supprime également les espaces résiduels à la fin.
        *   Exemple : "MODARONE 50 mg" avec masque ["49,8 mg", "50 mg", "51 mg"] :
            *   On tente "49,8 mg" → Pas de match.
            *   On tente "50 mg" → La chaîne se termine par "50 mg" → **Match !**
            *   Résultat : "MODARONE"

3.  **Résultat** :
    *   Un **nom propre** (sans dosage) pour chaque Princeps du sous-cluster.
    *   Exemple : "CLAMOXYL 500 mg" → "CLAMOXYL"

---

#### Phase 4 : Consolidation Globale (Le Cluster Final)

**But :** Réunir tous les sous-clusters (différentes formes) d'une même substance sous un seul Cluster et déterminer le nom représentatif.

**Étape 4.1 : Regroupement par Substance Uniquement**

1.  **Critère** :
    *   Récupérer tous les sous-clusters (issus de Phase 3) qui partagent les **mêmes Codes Substance**.
    *   Les sous-clusters {A, B} et {A, B, C} sont considérés comme **différents** (les sets doivent être identiques).

2.  **Exemple** :
    *   Sous-cluster A : Amoxicilline / gélule → Princeps nettoyé : "CLAMOXYL"
    *   Sous-cluster B : Amoxicilline / suspension buvable → Princeps nettoyé : "CLAMOXYL"
    *   Sous-cluster C : Amoxicilline / comprimé dispersible → Princeps nettoyé : "CLAMOXYL"
    *   → Ces trois sous-clusters sont fusionnés en un seul Cluster.

**Étape 4.2 : Validation des Princeps Réunis (Règle Critique)**

**⚠️ Règle de Non-Fusion si Princeps Différents :**

Si les sous-clusters à fusionner ont des **Princeps nettoyés différents**, ils ne doivent **PAS** être fusionnés en un seul Cluster.

1.  **Algorithme** :
    *   Avant de fusionner des sous-clusters partageant les mêmes Codes Substance :
    *   Comparer les **noms de Princeps nettoyés** de chaque sous-cluster.
    *   Si **tous identiques** → Fusionner en un seul Cluster.
    *   Si **différents** → Créer des Clusters **séparés**.

2.  **Exemple de Non-Fusion** :
    *   Sous-cluster A : Tamsulosine / gélule LP → Princeps nettoyé : "OMIX"
    *   Sous-cluster B : Tamsulosine / comprimé → Princeps nettoyé : "MECIR"
    *   → **Ne pas fusionner** : Créer Cluster "OMIX" et Cluster "MECIR" séparés.

3.  **Résultat** :
    *   Chaque cluster a un nom cohérent avec ses membres.

**Étape 4.3 : Déduction du Princeps Représentatif**

1.  **Agrégation des noms nettoyés** :
    *   Récupérer tous les noms propres de Princeps de chaque sous-cluster fusionné.
    *   Exemple : ["CLAMOXYL", "CLAMOXYL", "CLAMOXYL"] → Évident.
    *   Cas complexe : ["CLAMOXYL", "AMOXICILLINE BIOGARAN"] → Nécessite une logique de choix.

2.  **Algorithme de sélection (⚠️ À TESTER)** :
    *   **Option A (Simple)** : Prendre le nom le **plus fréquent**.
    *   **Option B (Pondéré)** : Prendre le nom du groupe le **plus grand** (le plus de CIS).
    *   **Option C (Priorité Princeps)** : Prendre systématiquement le nom du Pivot Principal du plus ancien groupe.
    *   *La meilleure option sera déterminée par expérimentation.*

3.  **Résultat** : Le **Princeps Représentatif** du Cluster (ex: "CLAMOXYL").

**Étape 4.3 : Création du Cluster**

1.  **Données du Cluster** :
    *   `Nom du Cluster` : Le Princeps Représentatif déterminé ci-dessus.
    *   `Membres` : Tous les CIS de tous les sous-clusters fusionnés.
    *   `Métadonnées` :
        *   Conserver l'information de forme pour chaque CIS (pour l'affichage UI).
        *   Conserver les Codes Substance (pour validation et recherche).

---

#### Phase 5 : Intégration des Orphelins (Post-Process)

**But :** Traiter les CIS qui n'appartiennent à aucun Groupe Générique.

**Définition d'un Orphelin :**
*   Un CIS présent dans `specialites` (Étape 1) mais absent de `CIS_GENER_bdpm.txt`.
*   Ce sont souvent des médicaments sans générique ou des produits spéciaux.

**Algorithme Simplifié (Fuzzy Matching Direct) :**

1.  **Identification** :
    *   Lister tous les CIS chargés à l'Étape 1.
    *   Soustraire les CIS déjà assignés à un Cluster via les Groupes Génériques.
    *   Les CIS restants sont des **Orphelins**.

2.  **Rattachement par Fuzzy Matching Direct (Sans Pré-Nettoyage)** :

    **Philosophie** : Au lieu de nettoyer laborieusement les noms d'orphelins avant matching, on compare **directement** l'orphelin aux sous-clusters existants en utilisant le fuzzy matching.
    
    **Algorithme (⚠️ Deux approches à tester)** :
    
    **Approche A - Matching par Nom uniquement :**
    *   Prendre le `Nom Complet` de l'orphelin (issu de l'Étape 1, ex: "ABILIFY 10 mg").
    *   Pour chaque **Sous-Cluster** existant (issus de Phase 3) :
        *   Récupérer le **nom du Princeps nettoyé** du sous-cluster (ex: "ABILIFY").
        *   Calculer un **score de similarité** entre le nom orphelin et le nom princeps :
            *   Algorithmes : Jaro-Winkler, Levenshtein, ou ratio de sous-chaîne commune.
        *   Garder le meilleur score.
    *   Si le **meilleur score** dépasse le **seuil** :
        *   Rattacher l'orphelin au Cluster contenant ce sous-cluster.
    *   Sinon :
        *   Créer un **nouveau Cluster Orphelin**.
    
    **Approche B - Matching par Nom + Forme :**
    *   Comme l'approche A, mais ajouter un **critère de forme** :
        *   Comparer aussi la `Forme` de l'orphelin (Col 3 de CIS_BDPM) avec les formes du sous-cluster.
        *   Scoring combiné : `score_final = score_nom * 0.7 + score_forme * 0.3` (pondération à ajuster).
    *   **Avantage** : Plus précis pour éviter les faux positifs.
    *   **Inconvénient** : Peut créer trop de clusters si les formes ne matchent pas parfaitement.
    
    **⚠️ À TESTER** : Les deux approches doivent être évaluées sur un échantillon représentatif pour déterminer laquelle donne les meilleurs résultats.

3.  **Paramètres à Calibrer par Expérimentation** :
    *   **Seuil de correspondance** (ex: 85%, 90%, 95%) à déterminer empiriquement.
    *   **Algorithme de similarité** : Jaro-Winkler recommandé initialement (favorise les correspondances en début de chaîne).
    *   **Pondération Nom/Forme** (pour approche B) : 70/30 comme point de départ.

4.  **Résultat** :
    *   Tous les CIS (groupés ou orphelins) sont désormais assignés à un Cluster.

---

### Étape 4 : Association des Présentations (CIP)

**Entrée :** `CIS_CIP_bdpm.txt` (Séparateur : `Tabulation \t`)

**Structure du fichier :**
```text
Col 1: Code CIS
Col 2: Code CIP (7 chiffres historique)
Col 3: Libellé de la présentation (ex: "plaquette(s) thermoformée(s) PVC PVDC aluminium de 30 comprimé(s)")
Col 4: Statut administratif
Col 5: État de commercialisation
Col 6: Date de déclaration
Col 7: Code CIP13 (13 chiffres, code-barres moderne)
Col 8: Agrément collectivités
Col 9: Taux de remboursement
Col 10: Prix (en euros)
...
```

**Condition :** Cette étape ne se lance qu'**après** la création complète des Clusters (Étape 3).

**Algorithme :**
1.  Parser chaque ligne de `CIS_CIP_bdpm.txt`.
2.  Lier chaque CIP à son CIS parent (via Col 1).
3.  Par transitivité, le CIP est maintenant lié à son **Cluster** (via l'assignation du CIS).

**Données Clés Extraites (Objets Présentation) :**
*   `CIP7` / `CIP13` : Codes-barres scannables
*   `CIS Parent` : Lien vers l'objet Spécialité
*   `Prix`, `Remboursement`, `Statut Commercial`

---

### Étape 5 : Consolidation & Validation Finale

**Objectif :** Générer la vue finale enrichie et valider l'intégrité des données.

**Validation Chimique (Cluster Integrity)** :
*   Utiliser `CIS_COMPO_bdpm.txt`.
*   Vérifier que tous les membres d'un Cluster partagent les mêmes **Codes Substance** (active).
*   Si une incohérence est détectée, lever un warning pour audit manuel.

**Propagation Sécurité** :
*   Scanner les conditions de prescription (`CIS_CPD_bdpm.txt`) de **tous** les membres de chaque Cluster.
*   **Règle Conservatrice** : Si *au moins un* CIS du Cluster est marqué "Stupéfiant", "Liste I" ou "Hospitalier", le flag est activé pour **tout le Cluster**.

**Traceability (Suivi des Méthodologies)** :

Pour chaque Cluster, stocker la **méthodologie de nommage** utilisée afin de faciliter les audits et l'analyse qualité.

**Table `naming_methodology` :**

| Code | Méthodologie | Description |
|------|--------------|-------------|
| 1 | ACTIVE_PRINCEPS | Princeps Type 0 trouvé actif dans `specialites` |
| 2 | SECONDARY_PRINCEPS | Princeps secondaire utilisé |
| 3 | FALLBACK_DASH_PARSING | Parsing après le dernier tiret du Libellé Groupe |
| 4 | FALLBACK_FORM_SUBTRACTION | Soustraction de forme du Dictionnaire Normalisé |
| 5 | FALLBACK_COMMA_DETECTION | Détection/suppression dernière virgule |
| 6 | ORPHAN_FORM_MASK | Orphelin nettoyé par masque de formes |
| 7 | ORPHAN_DOSAGE_MASK | Orphelin nettoyé par masque de dosages agrégés |
| 8 | ORPHAN_REGEX | Orphelin nettoyé par Regex générique |
| 9 | ORPHAN_FUZZY_MATCH | Orphelin rattaché par fuzzy matching |
| 10 | ORPHAN_NEW_CLUSTER | Nouvel orphelin (aucun match) |

**Stockage** :
*   Créer une table séparée `cluster_naming_trace` avec :
    *   `cluster_id` (FK vers `cluster_names`)
    *   `methodology_code` (FK vers `naming_methodology`)
    *   `step_order` (ordre d'application des méthodes, 1 = première tentée)
*   Cela permet de tracer les **combinaisons** de méthodologies utilisées.

**Contrainte de Non-Multi-Appartenance** :
*   Un CIS ne doit appartenir qu'à **un seul Cluster**.
*   Si des cas limites sont détectés (orphelin matchant plusieurs clusters), les logguer pour analyse manuelle.

---

### Étape 6 : Index de Recherche (FTS5)

**Objectif :** Permettre la recherche textuelle rapide.

**Index Dual :**
1. **Par Marque** : "CLAMOXYL", "AUGMENTIN", "ORELOX"
2. **Par Substance** : "Amoxicilline", "Acide clavulanique", "Céfpodoxime"

**Requête :**
```sql
SELECT * FROM search_index WHERE search_index MATCH 'amoxicilline';
-- Retourne: CLAMOXYL, AUGMENTIN (tous les clusters contenant de l'amoxicilline)
```

---

## 📋 Résumé des Tables Finales

| Table | Rôle | Clé Primaire |
|-------|------|--------------|
| `cluster_names` | Définition des tiroirs | `cluster_id` |
| `medicament_summary` | Détails par spécialité | `cis_code` |
| `medicaments` | Présentations scannables | `cip_code` |
| `search_index` | Index FTS pour recherche | - |
| `naming_methodology` | Codes des méthodologies de nommage | `code` |
| `cluster_naming_trace` | Traçabilité nommage par cluster | `cluster_id`, `step_order` |

---

## 🔧 Commandes Pipeline

```bash
# Télécharger les fichiers BDPM
bun run download

# Construire la base de données
bun run build

# Générer les fichiers d'audit
bun run tool

# Générer et exporter
bun run generate

# Générer, exporter et tool
bun run preflight
```
