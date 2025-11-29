# PharmaScan

**L'outil professionnel pour la réception de commande et la recherche d'équivalences médicamentaires**

PharmaScan est une application mobile conçue spécifiquement pour les pharmaciens. Elle permet de scanner rapidement et efficacement les codes Data Matrix GS1 des boîtes de médicaments lors de la réception de commande, tout en offrant un accès immédiat aux équivalences entre médicaments princeps et génériques.

## Pourquoi PharmaScan ?

Lors de la réception d'une commande, vous devez scanner de nombreuses boîtes rapidement. Les applications classiques vous obligent à rouvrir le scanner pour chaque boîte, ce qui ralentit considérablement votre travail. PharmaScan résout ce problème avec un **scanner à activation permanente** qui reste ouvert, vous permettant de scanner en rafale sans interruption.

De plus, PharmaScan vous donne accès instantanément aux équivalences **Princeps ↔ Générique** grâce à une base de données issue de la base officielle française (BDPM), garantissant une fiabilité totale pour vos décisions professionnelles.

## Fonctionnalité Clé : Scanner à Activation Permanente

### La différence qui change tout

Contrairement aux applications standard qui ferment le scanner après chaque scan, **PharmaScan maintient la caméra active en permanence**. Cette approche révolutionne votre productivité :

- **Pas de rechargement** : La caméra reste ouverte, prête à scanner la boîte suivante instantanément
- **Scan en rafale** : Scannez des dizaines de boîtes consécutivement sans jamais rouvrir le scanner
- **Historique visuel** : Chaque scan apparaît sous forme de bulle empilée, vous permettant de voir rapidement les dernières boîtes scannées
- **Productivité maximale** : Idéal pour la réception de commande où vous devez traiter rapidement de nombreux médicaments

### Comment ça fonctionne

1. Activez le scanner une seule fois
2. Scannez votre première boîte → le résultat s'affiche
3. Scannez immédiatement la suivante → une nouvelle bulle s'ajoute à l'historique
4. Continuez ainsi sans interruption → la caméra reste active, les résultats s'empilent visuellement

Cette approche élimine les frictions inutiles et vous fait gagner un temps précieux lors de vos réceptions de commande.

## Explorer : Regroupement Intelligent

### Une vue épurée pour une meilleure compréhension

Les bases de données officielles listent chaque médicament individuellement, créant un bruit visuel important. PharmaScan résout ce problème avec un **regroupement intelligent** qui organise les médicaments de manière logique et professionnelle.

### Regroupement Product-Centric

PharmaScan groupe les médicaments selon une hiérarchie claire :

1. **Molécule** : Le principe actif de base (ex: "PARACETAMOL")
2. **Dosage** : La quantité de principe actif (ex: "500 mg")
3. **Forme pharmaceutique** : La présentation (ex: "comprimé")

Au lieu de voir une liste interminable de boîtes individuelles, vous voyez des **groupes cohérents** qui représentent un concept produit unique. Par exemple, au lieu de voir 15 entrées différentes pour "PARACETAMOL 500 mg comprimé", vous voyez un seul groupe qui contient toutes les alternatives (princeps et génériques).

### Équivalences Princeps ↔ Générique

PharmaScan distingue clairement :

- **Princeps** : Le médicament original, développé et commercialisé en premier
- **Génériques** : Les médicaments équivalents thérapeutiques, généralement moins chers

L'Explorer vous montre automatiquement les princeps associés à chaque groupe générique, et inversement, vous permettant de trouver rapidement les alternatives disponibles.

### Recherche Intelligente

La recherche dans PharmaScan est tolérante aux fautes de frappe et aux requêtes partielles. Vous pouvez rechercher "paracetamol", "paracétamol", ou même "paracet" et trouver les résultats pertinents. Les résultats sont également regroupés, évitant les listes interminables.

## Données & Fiabilité

### Source Officielle : BDPM

PharmaScan utilise exclusivement les données de la **Base de Données Publique des Médicaments (BDPM)**, la base officielle française gérée par l'ANSM (Agence Nationale de Sécurité du Médicament). Cette source garantit :

- **Fiabilité totale** : Données officielles, mises à jour régulièrement
- **Exhaustivité** : Tous les médicaments autorisés en France
- **Conformité réglementaire** : Données conformes à la réglementation française

### Parsing Déterministe

Contrairement à d'autres solutions qui utilisent des approximations heuristiques (suppositions basées sur des règles), PharmaScan utilise un **parsing déterministe** basé sur les relations structurelles des données BDPM :

- **Relations explicites** : Les liens entre substances actives, fractions thérapeutiques, et groupes génériques sont extraits directement des fichiers officiels
- **Pas de suppositions** : Aucune règle de regex fragile, aucune approximation
- **Précision scientifique** : Les noms de molécules et dosages sont extraits avec précision grâce aux relations FT (Fraction Thérapeutique) > SA (Substance Active)

### Qualité des Données

Le pipeline d'ingestion applique un **filtrage strict** : seuls les médicaments avec un statut administratif "Autorisation active" sont inclus dans la base. Les médicaments révoqués ou archivés sont automatiquement exclus, garantissant que vous ne voyez que des médicaments actuellement commercialisés.

### Synchronisation Automatique

PharmaScan peut synchroniser automatiquement les données BDPM selon une fréquence que vous définissez (aucune, quotidienne, hebdomadaire, mensuelle). La synchronisation se fait en arrière-plan et ne nécessite aucune intervention de votre part.

## Accessibilité

PharmaScan s'engage à fournir une expérience accessible à tous les utilisateurs. L'application implémente des fonctionnalités d'accessibilité complètes suivant les meilleures pratiques Flutter et les guidelines WCAG 2.1 Level AA :

- **Support des lecteurs d'écran** : Tous les éléments interactifs ont des labels sémantiques annoncés par TalkBack (Android) et VoiceOver (iOS)
- **Navigation au clavier** : Tous les éléments sont accessibles au clavier avec une gestion appropriée du focus
- **Labels sémantiques** : Boutons, tuiles, champs de formulaire utilisent des labels descriptifs
- **Gestion du focus** : Les sections de formulaire utilisent `FocusTraversalGroup` pour une navigation logique au clavier

---

## Sous le Capot

*Cette section s'adresse aux développeurs souhaitant comprendre l'architecture technique de PharmaScan.*

### Stack Technique

- **Framework** : Flutter
- **UI Toolkit** : [shadcn_ui](https://pub.dev/packages/shadcn_ui) - Design system moderne et accessible
- **Scanning** : [mobile_scanner](https://pub.dev/packages/mobile_scanner) - Détection en temps réel des codes Data Matrix GS1
- **Base de données locale** : [drift](https://pub.dev/packages/drift) - ORM type-safe avec validation des requêtes à la compilation
- **Sources de données** : Fichiers TXT officiels BDPM (téléchargements directs, pas d'archives ZIP)
- **Gestion d'état** : Riverpod avec génération de code (`@riverpod`)
- **Architecture** : Clean Two-Layer (UI / Services)

### Offline-First avec Drift/SQLite FTS5

PharmaScan fonctionne entièrement hors ligne. La base de données locale (SQLite via Drift) contient toutes les données nécessaires :

- **FTS5 avec trigram** : Recherche full-text performante avec support de la correspondance floue
- **Normalisation** : Les requêtes de recherche sont normalisées (suppression des diacritiques) pour une correspondance cohérente
- **Performance** : Toutes les requêtes Explorer/Search lisent depuis une table dénormalisée optimisée (`MedicamentSummary`)

### Zéro Télémétrie (Privacy)

PharmaScan respecte strictement votre vie privée :

- **Aucune télémétrie externe** : Le manifeste Android désactive explicitement toutes les collectes Firebase/Analytics
- **Données locales uniquement** : Toutes les données restent sur votre appareil
- **Pas de tracking** : Aucun identifiant publicitaire, aucune analyse de comportement

Le plugin `mobile_scanner` intègre Google ML Kit, qui dépend de Google Play Services. PharmaScan désactive explicitement tous les canaux de télémétrie via des flags `<meta-data>` dans le manifeste Android, garantissant qu'**aucune télémétrie ne quitte l'appareil**.

### Architecture : Clean Two-Layer

PharmaScan suit une architecture simple et pragmatique :

- **Couche UI** : Widgets, état local, `HookConsumerWidget` pour la gestion des contrôleurs
- **Couche Services** : Logique métier, accès base de données, parsing (zéro dépendance `flutter/material.dart`)

**Principe clé** : La logique métier n'appartient jamais à un Widget. Les classes générées par Drift sont utilisées directement dans l'UI sans modèles intermédiaires, réduisant la complexité cognitive et la charge de maintenance.

### Modèle de Données Déterministe

L'application utilise un **modèle de données déterministe** basé sur les fichiers relationnels officiels de la BDPM :

- **Sources de données** : Téléchargements directs de fichiers TXT individuels :
  - `CIS_bdpm.txt` - Spécialités avec forme, statut de commercialisation, et titulaire
  - `CIS_CIP_bdpm.txt` - Codes et noms des médicaments
  - `CIS_COMPO_bdpm.txt` - Compositions en principes actifs avec informations de dosage structurées
  - `CIS_GENER_bdpm.txt` - Relations de groupes génériques (source autoritative)

- **Stratégie de parsing : Déterminisme Relationnel** :
  Au lieu de nettoyer heuristiquement les noms chimiques (ex: supprimer "Chlorhydrate"), PharmaScan exploite le lien relationnel entre *Substances Actives* (SA) et *Fractions Thérapeutiques* (FT) fourni dans la structure BDPM. Cela garantit des noms et dosages scientifiquement précis (Base vs Sel) sans suppositions regex. Le parser préfère FT (molécule de base) à SA (forme sel) lorsqu'elles sont liées dans `CIS_COMPO`, produisant naturellement des noms propres (ex: "Metformine" au lieu de "Chlorhydrate de Metformine").

- **Schéma de base de données** : Base de données relationnelle type-safe utilisant l'ORM drift :
  - Schéma défini en Dart (`lib/core/database/database.dart`) avec génération de code automatique
  - `MedicamentSummary` est une table dénormalisée "source de vérité" unique indexée par `cis_code`. Elle est peuplée lors de l'initialisation en agrégant les données de toutes les tables normalisées et en exécutant le parser Knowledge-Injected. Toutes les requêtes UI lisent depuis cette table optimisée

- **Initialisation** : Au premier lancement, l'app télécharge les quatre fichiers TXT, les parse, et peuple la base de données locale. Le processus s'exécute en deux phases déterministes :
  1. **Staging** – Les données TXT sont parsées dans les tables normalisées (`specialites`, `medicaments`, `principes_actifs`, `generique_groups`, `group_members`)
  2. **Agrégation** – `_aggregateDataForSummary()` calcule une ligne `MedicamentSummary` par CIS en utilisant la stratégie de parsing décrite ci-dessus
  Les lancements suivants sont instantanés car les deux couches persistent localement

### Installation & Développement

#### Prérequis

- Flutter SDK installé
- Un éditeur comme VS Code ou Android Studio
- Un appareil physique ou un émulateur pour les tests

#### Installation

1. **Cloner le dépôt :**

    ```bash
    git clone <your-repository-url>
    cd pharma_scan
    ```

2. **Installer les dépendances :**

    ```bash
    dart pub get
    ```

3. **Lancer l'application :**
    Le premier lancement prendra un certain temps car il doit télécharger les fichiers TXT (~20MB au total) depuis la source officielle BDPM et peupler la base de données locale.

    ```bash
    flutter run
    ```

### Principes de Développement

Ce projet est développé par un **développeur solo**. L'architecture privilégie la **simplicité radicale**, l'autonomie (offline-first), et la réduction du boilerplate. Les patterns d'entreprise (Clean Architecture stricte, DTOs, Mappers, multiples couches d'abstraction) sont considérés comme des anti-patterns ici s'ils n'apportent pas de valeur immédiate.

Pour des guidelines détaillées, référez-vous à `AGENTS.md`.

### Roadmap

La version actuelle de PharmaScan se concentre sur l'identification rapide et l'équivalence princeps/générique. Les fonctionnalités suivantes sont envisagées pour le développement futur :

- **Statut de disponibilité en temps réel** : Intégration du fichier `CIS_CIP_Dispo_Spec.txt` pour fournir des informations sur les pénuries de médicaments

---

**PharmaScan** - L'outil professionnel pour les pharmaciens qui valorisent la productivité et la fiabilité.
