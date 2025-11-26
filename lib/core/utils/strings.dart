// lib/core/utils/strings.dart
// WHY: Centralized string constants for localization preparation.
// This prepares the codebase for future i18n without requiring a full i18n package.

class Strings {
  Strings._();

  static const String appName = 'PharmaScan';

  // Navigation
  static const String scanner = 'Scanner';
  static const String explorer = 'Explorer';

  // Sync & Updates
  static const String updateCompleted = 'Mise à jour terminée';
  static const String bdpmUpToDate = 'La base BDPM est à jour.';
  static const String syncFailed = 'Synchronisation échouée';
  static const String syncFailedMessage =
      'Impossible de synchroniser les données BDPM.';

  // Buttons & Actions
  static const String close = 'Fermer';
  static const String exploreGroup = 'Explorer le Groupe';
  static const String exploreMedicationGroup =
      'Explorer le groupe de médicaments';
  static const String closeMedicationCard = 'Fermer cette carte de médicament';

  // Medication Labels
  static const String generic = 'GÉNÉRIQUE';
  static const String associatedPrinceps = 'Princeps Associé(s)';
  static const String noPrincepsFound = 'Aucun princeps trouvé.';
  static const String noPrincepsAssociated = 'Aucun princeps associé';
  static const String princepsAssociated = 'princeps associé(s)';
  static const String genericMedication = 'Médicament générique';
  static const String surveillanceBadge = '⚠️ SURVEILLANCE';
  static const String surveillanceDescription = 'Surveillance renforcée';

  // Common Labels
  static const String unknownHolder = 'Titulaire inconnu';
  static const String medication = 'Médicament';
  static const String cip = 'CIP';
  static const String holder = 'titulaire';
  static const String dosage = 'dosage';
  static const String activePrinciples = 'principes actifs';
  static const String condition = 'condition';
  static const String price = 'Prix public';
  static const String refundRate = 'Taux de remboursement';

  // Error Messages
  static const String unknown = 'Inconnu';
  static const String unknownLab = 'Laboratoire Inconnu';
  static const String group = 'Groupe';

  // Settings & Actions
  static const String openSettings = 'Ouvrir les réglages';
  static const String openFilters = 'Ouvrir les filtres de recherche';
  static const String editFilters = 'Modifier les filtres de recherche';
  static const String retry = 'Réessayer';
  static const String retryUpdate = 'Réessayer la mise à jour des données';
  static const String retrySync = 'Réessayer la synchronisation';
  static const String cancel = 'Annuler';
  static const String confirm = 'Confirmer';
  static const String reset = 'Réinitialiser';
  static const String resetFilters = 'Réinitialiser';
  static const String clearFilters = 'Effacer les filtres';
  static const String all = 'Tous';
  static const String allRoutes = 'Toutes les voies';
  static const String back = 'Retour';
  static const String backToSearch = 'Retour à la recherche';

  // Error & Status Messages
  static const String updateError = 'Erreur lors de la mise à jour des données';
  static const String updateLimited =
      'Certaines fonctionnalités peuvent être limitées tant que la base BDPM n\'est pas synchronisée.';
  static const String databaseInitialization =
      'Initialisation de la base de données...';
  static const String initializationInProgress = 'Initialisation en cours';
  static const String initializationDescription =
      'Veuillez patienter pendant la configuration de la base.';
  static const String initializationDownloading =
      'Téléchargement des données de référence...';
  static const String initializationParsing =
      'Traitement de la base de données...';
  static const String initializationReady =
      'Base de données prête à l\'emploi.';
  static const String initializationError = 'Erreur d\'initialisation.';
  static const String initializationDownloadingDescription =
      'Veuillez ne pas quitter l\'application.';
  static const String initializationParsingDescription =
      'Traitement des données massives...';
  static const String initializationAggregatingTitle = 'Finalisation';
  static const String initializationAggregatingDescription =
      'Optimisation de la recherche...';
  static const String initializationErrorDescription =
      'Veuillez vérifier votre connexion.';
  static const String resetDatabaseTitle = 'Réinitialiser la base de données ?';
  static const String resetDatabaseDescription =
      'Cette action supprimera toutes les données locales et les re-téléchargera. Cette opération est irréversible et peut prendre plusieurs minutes.';
  static const String resetComplete = 'Réinitialisation terminée';
  static const String resetSuccess =
      'La base de données a été mise à jour avec succès.';
  static const String resetError = 'Erreur de réinitialisation';
  static const String resetErrorDescription =
      'Impossible de re-télécharger les données. Vérifiez votre connexion internet.';
  static const String loadingError = 'Erreur de chargement';
  static const String loadDetailsError = 'Impossible de charger les détails.';
  static const String loadError = 'Erreur lors du chargement:';

  // Scanner
  static const String noBarcodeDetected = 'Aucun code-barres détecté';
  static const String analysisError = 'Erreur d\'analyse';
  static const String error = 'Erreur';
  static const String cameraUnavailable = 'Caméra indisponible';
  static const String gallery = 'Galerie';
  static const String manualEntry = 'Saisie';
  static const String importFromGallery = 'Importer depuis la galerie';
  static const String choosePhoto = 'Choisir une photo';
  static const String medicamentNotFound = 'Médicament non trouvé';
  static const String manualCipEntry = 'Saisie manuelle du CIP';
  static const String manualCipDescription =
      'Entrez les 13 chiffres du code CIP.';
  static const String cipPlaceholder = 'Ex : 3400934056781';
  static const String search = 'Rechercher';

  // Explorer
  static const String searchPlaceholder =
      'Rechercher par nom, CIP, ou principe...';
  static const String searchLabel =
      'Rechercher par nom, CIP, ou principe actif';
  static const String searchHint =
      'Tapez pour rechercher dans la base de données BDPM';
  static const String clearSearch = 'Effacer la recherche';
  static const String noActiveFilters = 'Aucun filtre actif';
  static const String filters = 'Filtres';
  static const String allopathy = 'Allopathie';
  static const String homeopathy = 'Homéopathie / Phytothérapie';
  static const String noRoutesAvailable = 'Aucune voie disponible';
  static const String noResults = 'Aucun résultat trouvé.';
  static const String filterHint =
      'Permet de filtrer par type de procédure et voie d\'administration';
  static const String princeps = 'Princeps';
  static const String generics = 'Génériques';
  static const String relatedTherapies = 'Thérapies Associées';
  static const String sharedActiveIngredients = 'Principe(s) actif(s) partagés';
  static const String notDetermined = 'Non déterminé';

  // Settings
  static const String settings = 'Réglages';
  static const String appearance = 'Apparence';
  static const String systemTheme = 'Thème du système';
  static const String lightTheme = 'Thème clair';
  static const String darkTheme = 'Thème sombre';
  static const String sync = 'Synchronisation';
  static const String never = 'Ne jamais rechercher';
  static const String daily = 'Une fois par jour';
  static const String weekly = 'Une fois par semaine';
  static const String monthly = 'Une fois par mois';
  static const String data = 'Données';
  static const String forceReset = 'Forcer la réinitialisation de la base';
  static const String resetting = 'Réinitialisation en cours...';
  static const String checkUpdates = 'Vérification des mises à jour';
  static const String checkUpdatesTitle = 'Vérification des mises à jour';

  // Stats
  static const String totalPrinceps = 'Princeps';
  static const String totalGenerics = 'Génériques';
  static const String totalPrinciples = 'Principes Actifs';

  // Scanner States
  static const String readyToScan = 'Prêt à scanner';
  static const String stopScanning = 'Arrêter le scan';
  static const String startScanning = 'Scanner un code';
  static const String checkPermissionsMessage =
      'Veuillez vérifier les autorisations.';
  static const String imageContainsNoValidBarcode =
      'L\'image ne contient pas de code-barres valide.';
  static const String unableToAnalyzeImage = 'Impossible d\'analyser l\'image:';
  static const String unableToSelectImage =
      'Impossible de sélectionner l\'image:';
  static const String cipMustBe13Digits =
      'Le code CIP doit comporter 13 chiffres.';
  static const String noMedicamentFoundForCip =
      'Aucun médicament trouvé pour ce CIP.';
  static const String noMedicamentFoundForCipCode =
      'Aucun médicament trouvé pour le code CIP:';
  static const String searchingInProgress = 'Recherche en cours';
  static const String searchMedicamentWithCip =
      'Rechercher le médicament avec ce code CIP';
  static const String searchStartsAutomatically =
      'La recherche démarre automatiquement après 13 chiffres.';
  static const String choosePhotoFromGallery =
      'Choisir une photo depuis la galerie';
  static const String cancelPhotoSelection = 'Annuler la sélection de photo';
  static const String noPhotoStoredMessage =
      'Aucune photo n\'est conservée et vous pouvez annuler à tout moment.';
  static const String pharmascanAnalyzesOnly =
      'PharmaScan analysera uniquement la photo choisie pour y détecter un code-barres.';
  static const String turnOffTorch = 'Éteindre la lampe torche';
  static const String turnOnTorch = 'Allumer la lampe torche';
  static const String importBarcodeFromGallery =
      'Importer un code-barres depuis la galerie';
  static const String manuallyEnterCipCode = 'Saisir manuellement un code CIP';

  // Settings
  static const String bdpmSynced = 'Base BDPM synchronisée';
  static const String noNewUpdates = 'Aucune nouvelle mise à jour';
  static const String latestBdpmDataApplied =
      'Les dernières données BDPM ont été appliquées.';
  static const String localDataUpToDate =
      'Vos données locales sont déjà à jour.';
  static const String unableToCheckBdpmUpdates =
      'Impossible de vérifier les dernières données BDPM. Réessayez plus tard.';
  static const String determinesCheckFrequency =
      'Détermine la fréquence de vérification des nouvelles données BDPM.';
  static const String checkingUpdatesInProgress = 'Vérification en cours...';
  static const String checkUpdatesNow = 'Vérifier les mises à jour maintenant';
  static const String forceResetDescription =
      'Utilisez cette option si les données semblent corrompues ou pour forcer une mise à jour manuelle.';
  static const String showLogs = 'Afficher les logs';
  static const String showApplicationLogs = 'Afficher les journaux applicatifs';
  static const String openDetailedViewForSupport =
      'Ouvre une vue détaillée des événements pour le support et la QA.';
  static const String diagnostics = 'Diagnostics';
  static const String pleaseWaitSync =
      'Patientez pendant la synchronisation avec le BDPM…';
  static const String checkingUpdatesTitle =
      'Vérification des mises à jour en cours';
  static const String syncBannerWaitingNetworkTitle = 'Connexion requise';
  static const String syncBannerCheckingTitle = 'Recherche de mises à jour';
  static const String syncBannerDownloadingTitle = 'Téléchargement BDPM';
  static const String syncBannerApplyingTitle = 'Mise à jour locale';
  static const String syncBannerSuccessTitle = 'Synchronisation terminée';
  static const String syncBannerErrorTitle = 'Synchronisation échouée';
  static const String syncWaitingNetwork =
      'Vérification de la connexion réseau…';
  static const String syncCheckingUpdates =
      'Analyse des mises à jour disponibles…';
  static const String syncApplyingUpdate = 'Mise à jour de la base de données…';
  static const String syncUpToDate = 'Vos données sont à jour.';
  static const String syncDatabaseUpdated = 'Base de données mise à jour.';
  static const String syncContentVerified = 'Contenu vérifié et à jour.';
  static const String syncErrorNetwork =
      'Connexion réseau requise pour poursuivre la synchronisation.';
  static const String syncErrorScraping =
      'Impossible d\'analyser la page BDPM pour détecter les mises à jour.';
  static const String syncErrorDownload =
      'Téléchargement des fichiers BDPM interrompu.';
  static const String syncErrorApply =
      'Impossible d\'appliquer la mise à jour à la base locale.';
  static const String syncErrorUnknown =
      'Une erreur inattendue est survenue lors de la synchronisation.';

  // Explorer
  static const String searchErrorOccurred =
      'Une erreur est survenue pendant la recherche.';
  static const String princepsAndGenerics = 'princeps • génériques';
  static const String dosagesLabel = 'Dosages :';
  static const String formsLabel = 'Formes :';
  static const String medicationDetails = 'Détails du médicament';
  static const String closeMedicationDetails =
      'Fermer les détails du médicament';
  static const String nameLabel = 'Nom';
  static const String activePrinciplesLabel = 'Principe(s) actif(s)';
  static const String pharmaceuticalFormLabel = 'Forme pharmaceutique';
  static const String uniqueMedicationNoGroup =
      'Médicament unique (sans groupe générique)';
  static const String showMedicamentDetails =
      'Afficher les détails du médicament';
  static const String princepsLabel = 'Princeps';
  static const String genericsLabel = 'Génériques';
  static const String genericLabel = 'Générique';
  static const String activeIngredientsLabel = 'Principe(s) actif(s)';
  static const String brandPrincepsLabel = 'Marque princeps';
  static const String procedureType = 'Type de procédure';
  static const String administrationRouteFilter = 'Voie d\'administration';
  static const String therapeuticClassFilter = 'Classe Thérapeutique';
  static const String allClasses = 'Toutes les classes';
  static const String resetAllFilters = 'Réinitialiser tous les filtres';
  static const String errorLoadingRoutes =
      'Erreur lors du chargement des voies';
  static const String errorLoadingGroups = 'Impossible de charger les groupes';
  static const String retryLoadingGroups =
      'Réessayer le chargement des groupes';
  static const String canonicalNameLabel = 'Nom canonique (Base)';
  static const String structuredDosageLabel = 'Dosage structuré';
  static const String officialFormulationLabel = 'Formulation officielle';
  static const String nonIdentified = 'Non identifiée';
  static const String notDefined = 'Non défini';

  // Error Details

  // Badge Labels
  // WHY: badgePrinceps is the canonical constant for PRINCEPS badge text.
  // Removed redundant princepsBadge (same value) to avoid duplication.
  static const String badgePrinceps = 'PRINCEPS';
  static const String badgeGeneric = 'GÉNÉRIQUE';
  static const String badgeStandalone = 'UNIQUE';
  static const String uniqueMedicationBadge = 'MÉDICAMENT UNIQUE';
  static const String productStoppedBadge = 'Produit arrêté';
  static const String productCommercializedBadge = 'Commercialisé';
  static const String stockShortageBadge = 'Rupture de stock';
  static const String stockTensionBadge = 'Tension d\'approvisionnement';
  static const String hospitalBadge = '🏥 Usage hospitalier';

  // Badge Tooltips
  static const String badgePrincepsTooltip = 'Médicament de référence original';
  static const String badgeGenericTooltip = 'Médicament générique';
  static const String badgeStandaloneTooltip = 'Médicament unique';
  static const String hospitalTooltip = 'Usage hospitalier';
  static const String shortageTooltip = 'Tension ou Rupture';
  static const String stoppedTooltip = 'Non commercialisé';

  // Medication Information
  static const String noActivePrincipleReported =
      'Aucun principe actif renseigné';
  static const String noGenericsFound = 'Aucun générique correspondant trouvé.';
  static const String uniqueMedicationDescription =
      'Médicament sans groupe générique';
  static const String cipCodeLabel = 'Code CIP';
  static const String activePrincipleLabel = 'Principe Actif';

  // Dynamic String Helpers
  // WHY: These methods ensure UI and tests stay synchronized when constructing
  // dynamic strings with counts or variables. Both UI and tests must use these helpers.

  static String genericCount(int count) => '${Strings.genericsLabel} ($count)';
  static String princepsCount(int count) => '${Strings.princepsLabel} ($count)';
  static String groupCount(int count) => '$count groupe(s)';
  static String memberCount(int count) => '$count spécialités';
  static String presentationCount(int count) => '$count présentation(s)';
  static String activeFilterCount(int count) => '$count filtre(s) actif(s)';
  static String associatedPrincepsCount(int count) =>
      '$count princeps associés';
  static String syncDownloadingSource(String sourceLabel) =>
      'Téléchargement de $sourceLabel…';
  static String summaryLine(int princepsCount, int genericsCount) =>
      '$princepsCount ${Strings.princepsLabel.toLowerCase()} • $genericsCount ${Strings.genericsLabel.toLowerCase()}';
  static String presentationSubtitle(int count, String labs) =>
      '${presentationCount(count)} • Laboratoires: $labs';
  static const String availableAt = 'Disponible chez : ';
  static String andOthers(int count) => ' et $count autres';
  static String searchResultSemanticsForPrinceps(String name, int generics) =>
      'Princeps $name avec $generics génériques';
  static String searchResultSemanticsForGeneric(String name, int princeps) =>
      'Générique $name avec $princeps princeps';
  static String associatedTherapySemantics(String name) =>
      'Thérapie associée: $name';
  static String activePrincipleWithValue(String value) =>
      '${Strings.activePrincipleLabel}: $value';
  static String genericsExistWithLabs(List<String> labs) {
    final displayedLabs = labs.take(3).join(', ');
    final moreIndicator = labs.length > 3 ? ', ...' : '';
    return 'Des génériques existent (labos: $displayedLabs$moreIndicator).';
  }

  static String princepsSemantics(
    String name,
    String molecule,
    bool hasGenerics,
  ) {
    final genericsText = hasGenerics
        ? 'Génériques disponibles'
        : 'Aucun générique';
    return 'Princeps: $name. PA: $molecule. $genericsText';
  }

  static String standaloneSemantics(
    String name,
    bool hasPrinciples,
    String? principlesText,
  ) {
    final principlesSection = hasPrinciples
        ? 'Principes actifs: $principlesText'
        : Strings.noActivePrincipleReported;
    return 'Médicament unique: $name. $principlesSection';
  }

  static String activePrinciplesWithValue(String value) =>
      'Principes actifs: $value';
  static String holderWithValue(String value) => 'Titulaire: $value';
  static String formWithValue(String value) => 'Forme: $value';

  // Summary List Item Helpers
  // WHY: Centralize bullet point formatting for search result lists
  // to ensure consistency and prepare for i18n
  static String genericSummaryItem(String name, int count) {
    if (count > 1) {
      return '• $name ($count)';
    }
    return '• $name';
  }

  static String princepsSummaryItem(String name) => '• $name';

  static String stockAlert(String status) => '⚠️ $status';

  // ATC Level 1 Class Labels
  // WHY: Map ATC Level 1 codes (single letters) to French therapeutic class labels
  static String? getAtcLevel1Label(String? atcCode) {
    if (atcCode == null || atcCode.isEmpty) return null;
    final level1 = atcCode.substring(0, 1).toUpperCase();
    return _atcLevel1Labels[level1];
  }

  static const Map<String, String> _atcLevel1Labels = {
    'A': 'Système digestif',
    'B': 'Sang',
    'C': 'Système cardio-vasculaire',
    'D': 'Dermatologie',
    'G': 'Système génito-urinaire',
    'H': 'Hormones',
    'J': 'Anti-infectieux',
    'L': 'Antinéoplasiques',
    'M': 'Muscles et Squelette',
    'N': 'Système nerveux',
    'P': 'Antiparasitaires',
    'R': 'Système respiratoire',
    'S': 'Organes sensoriels',
    'V': 'Divers',
  };
}
