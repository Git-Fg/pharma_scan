# PharmaScan - Manifeste de Développement

Votre mission principale est de contribuer au développement de l'application **PharmaScan**. Ce document est la source unique de vérité pour tous les principes de développement, les standards de qualité et l'architecture du projet.

**Philosophie Fondamentale :** Prioriser la **simplicité**, la **robustesse** et la **performance**. L'application doit être instantanément réactive, même sur des appareils d'entrée de gamme, car elle est un outil professionnel destiné à un usage rapide et répétitif. Le code est l'autorité suprême ; vos contributions doivent être claires, auto-documentées et rigoureusement testées.

---

## 1. Protocoles Fondamentaux et Flux de Travail

### **Flux de Travail A : Développement de Code (Fonctionnalités & Correctifs)**

Ce flux s'applique à toute écriture ou modification de code dans le répertoire `lib/`.

1.  **Comprendre :** Analysez le code existant et les objectifs de la tâche pour vous aligner avec l'architecture actuelle. L'objectif est de maintenir une base de code légère et cohérente.

2.  **Implémenter :** Écrivez du code propre et performant, en adhérant strictement aux meilleures pratiques techniques définies dans ce document.

3.  **Vérifier (La Barrière Qualité) :** Avant tout commit, vous êtes responsable de la validation de vos changements. Exécutez la commande de vérification unifiée :

    ```bash
    flutter analyze && flutter test
    ```

    Cette commande analyse la qualité statique du code et exécute la suite de tests unitaires et widgets. Vous **DEVEZ** résoudre toutes les erreurs et tous les avertissements critiques qu'elle signale.

4.  **Commettre (Le Protocole d'Atomicité) :** Après une vérification réussie, vous **DEVEZ** commettre vos changements dans le dépôt local. Chaque commit doit représenter une unité de travail logique et unique, et suivre le format des [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): résumé`).

    **Contrainte Absolue :** Vous ne devez **JAMAIS** utiliser `git push`. Votre rôle est de construire un historique de commits local propre et atomique. Un utilisateur humain est seul responsable de l'interaction avec le dépôt distant.

---

## 2. Meilleures Pratiques Techniques (Les Règles Immuables)

Ce sont les principes fondamentaux de qualité du code pour ce projet.

### 2.1. Qualité du Code et Lisibilité

*   **Les Commentaires Expliquent le "Pourquoi" :** Les commentaires doivent justifier une décision de conception ou clarifier une logique complexe (`// POURQUOI : ...`), pas décrire ce que le code fait.
*   **Zéro Artefact de Débogage :** Avant tout commit, vous **DEVEZ** supprimer tous les `print()`, `debugPrint()`, et le code commenté.

### 2.2. Design System : Stratégie Centralisée avec Shadcn UI

**CRITIQUE :** Le projet utilise un système de design centralisé et sémantique basé sur **Shadcn UI**. C'est une contrainte architecturale non négociable pour garantir la cohérence visuelle et la maintenabilité.

*   **Interdiction Absolue :** Vous ne devez **JAMAIS** utiliser de styles codés en dur directement dans les widgets. Les éléments suivants sont strictement interdits dans le code des widgets :
    *   `BoxDecoration` (ex: `BoxDecoration(color: Colors.blue, ...)`)
    *   `TextStyle` (ex: `TextStyle(fontSize: 16, color: Colors.red)`)
    *   Valeurs de couleur directes (ex: `Colors.grey`, `Color(0xFF...)`)
    *   Valeurs numériques pour `BorderRadius`, `EdgeInsets`, `SizedBox`, etc.

*   **Modèle Obligatoire :** TOUS les styles et espacements DOIVENT être accédés via le thème `Shadcn` ou des constantes de design centralisées.

    ```dart
    // ✅ CORRECT : Utiliser le thème Shadcn
    final theme = ShadTheme.of(context);
    ...
    ShadCard(
      title: Text('Générique Détecté', style: theme.textTheme.h4),
      backgroundColor: theme.colorScheme.card,
    )

    // ✅ CORRECT : Utiliser des constantes de design pour les espacements
    const SizedBox(height: AppSpacing.md)

    // ❌ INCORRECT : Styles et valeurs codés en dur
    Card(
      color: Colors.white, // INTERDIT
      child: Text(
        'Titre',
        style: TextStyle(fontSize: 18), // INTERDIT
      ),
    )
    ```

*   **Nommage Sémantique :** Les styles personnalisés (si jamais nécessaires) doivent être nommés par leur fonction, pas leur apparence.
    *   ✅ `theme.colorScheme.destructive`, `theme.textTheme.muted`
    *   ❌ `redColor`, `greyText`

*   **Zéro Bibliothèque d'UI Externe :** Vous ne **DEVEZ PAS** introduire d'autres bibliothèques de composants UI. Les composants natifs de Flutter et l'écosystème de **Shadcn UI** fournissent tout ce qui est nécessaire.

### 2.3. Gestion d'État : Approche Minimale et Locale

**Principe de Simplicité :** L'application PharmaScan est conçue pour être simple. Nous n'utiliserons **PAS** de solution de gestion d'état globale (comme Riverpod, BLoC, etc.) sauf si une complexité future l'exige absolument.

*   **`StatefulWidget` est la Norme :** L'état de l'interface (comme `_isCameraActive` ou la liste `_infoBubbles`) **DOIT** être géré localement à l'aide de `StatefulWidget` et `setState`.
*   **Pas d'État Global :** L'état n'est pas partagé entre les écrans. Cette contrainte maintient la simplicité, la prévisibilité et la performance.
*   **Accès aux Services :** Les widgets peuvent instancier et appeler directement les classes de service (comme `DatabaseService`) car il n'y a pas de logique complexe à orchestrer.

### 2.4. Architecture : Séparation en Deux Couches

L'application applique une architecture simple mais stricte à deux couches.

*   **Couche UI (Widgets) :**
    *   ✅ Gère l'état de l'interface (via `StatefulWidget`).
    *   ✅ Capture les interactions de l'utilisateur.
    *   ✅ Affiche les données.
    *   ✅ Appelle directement les méthodes des services pour la logique métier.
    *   ❌ Ne contient **JAMAIS** de logique métier (parsing de données, requêtes DB complexes).

*   **Couche Service (Logique Métier) :**
    *   ✅ Contient toute la logique métier (ex: `Gs1Parser`, `DatabaseService`).
    *   ✅ Effectue les opérations de base de données.
    *   ✅ Télécharge et traite les données externes.
    *   ✅ Est totalement indépendante de l'interface utilisateur.
    *   ❌ Ne gère **JAMAIS** l'état de l'UI.
    *   ❌ N'a **AUCUNE** dépendance envers `flutter/material.dart` ou `flutter/widgets.dart`.

**Règle Critique :** Tout bug ou nouvelle fonctionnalité lié(e) à la manipulation de données **DOIT** être implémenté(e) ou corrigé(e) dans la couche de service appropriée.

### 2.5. Performance et Optimisation

*   **Scan Ciblé :** Le `MobileScannerController` **DOIT** être configuré pour ne détecter que les `BarcodeFormat.dataMatrix` afin de minimiser l'utilisation du CPU.
*   **Opérations Asynchrones :** Toute opération longue (requête DB, parsing de fichier) **DOIT** être `async` pour ne pas bloquer le thread UI.
*   **Prévention des Doubles Scans :** Une logique (par exemple, un `Set` de codes CIP récemment scannés) **DOIT** être implémentée pour éviter d'afficher plusieurs fois la même bulle d'information en succession rapide.

---

## 3. Commandes de Référence du Projet

*   **`flutter pub get`**: Installe ou met à jour les dépendances Dart.
*   **`flutter pub run flutter_launcher_icons:main`**: La commande obligatoire après toute modification du fichier `assets/icon/icon.png` ou de la configuration `flutter_launcher_icons` dans `pubspec.yaml`.
*   **`flutter analyze`**: Analyse statique du code. Doit retourner zéro erreur ou avertissement critique.
*   **`flutter test`**: Exécute tous les tests du projet.
*   **`flutter analyze && flutter test`**: La **Barrière Qualité** à exécuter avant tout commit.

---

## 4. Documentation et Maintenance

### 4.1. Protocole du `CHANGELOG.md`

Vous **DEVEZ** maintenir le fichier `CHANGELOG.md` à la racine du projet.

*   **Quand Créer une Entrée :**
    *   Créez une nouvelle entrée pour une **réalisation majeure** (mise en place de l'architecture, finalisation de la logique de scan, intégration du design system).
    *   Les changements mineurs sont ajoutés comme des points sous la dernière entrée majeure.
    *   **CRITIQUE :** Avant de créer une nouvelle entrée, vérifiez si une entrée existe déjà pour la date du jour. Si oui, mettez à jour l'entrée existante.

*   **Format d'Entrée :**
    *   Ajoutez toujours les nouvelles entrées en **haut** du fichier.
    *   **Date Requise :** Utilisez la commande `date +%Y-%m-%d` pour obtenir la date actuelle au format AAAA-MM-JJ.
    *   Format : `# [AAAA-MM-JJ] - Titre de la Réalisation Majeure`
    *   Suivez d'un résumé concis (1-2 lignes maximum).

*   **Préservation de l'Historique :** Ne supprimez jamais les entrées passées. Elles ne sont que clarifiées si nécessaire.