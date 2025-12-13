# Architecture de Base de Données Séparées

## Vue d'ensemble

L'application PharmaScan utilise maintenant une architecture de base de données séparée pour distinguer clairement les données cliniques partagées des données utilisateur spécifiques.

## Structure

### 1. Fichiers de base de données

- **`reference.db`**: Contient les données cliniques (médicaments, spécialités, etc.)
  - Téléchargé depuis le backend
  - Mis à jour régulièrement
  - En lecture seule dans l'application (via attachement SQLite)
  
- **`user.db`**: Contient les données utilisateur (paramètres, réapprovisionnement, scans)
  - Stocké localement sur l'appareil
  - Modifiable par l'application
  - Persiste lors des mises à jour de `reference.db`

### 2. Pattern "Attached" SQLite

L'application utilise le pattern "attached" de SQLite pour combiner les deux bases de données :

- `user.db` est ouvert comme base de données principale (modifiable)
- `reference.db` est attaché comme base de données en lecture seule
- Les requêtes peuvent accéder aux deux bases transparentment

### 3. Fichiers de schéma Drift

- **`reference_schema.drift`**: Définit les tables cliniques provenant du backend
- **`user_schema.drift`**: Définit les tables utilisateur spécifiques à l'application
- **`views.drift`**: Définit les vues combinant les données des deux schémas

## Avantages

1. **Persistance des données utilisateur**: Les données utilisateur sont préservées lors des mises à jour de la base clinique
2. **Séparation des préoccupations**: Les données cliniques sont séparées des données utilisateur
3. **Mises à jour efficaces**: Seule la base de données clinique est mise à jour
4. **Accès transparent**: Le code Dart peut accéder aux deux types de données de manière uniforme

## Migration

Puisque l'application est encore en phase de développement, aucune migration complexe n'est nécessaire. L'architecture est entièrement nouvelle.

## Considérations techniques

- Les tables de la base attachée doivent être référencées avec l'alias `reference_db.table_name` dans certaines requêtes
- La journalisation WAL est activée pour les deux bases de données
- Les clés étrangères sont activées pour assurer l'intégrité des données