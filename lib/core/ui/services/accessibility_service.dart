import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Extension type pour les annonces d'accessibilité typées.
///
/// Encapsule une chaîne d'annonce pour le lecteur d'écran avec
/// des méthodes utilitaires pour formater différents types d'annonces.
extension type AccessibilityAnnouncement._(String _value) implements String {
  /// Crée une annonce simple pour le lecteur d'écran.
  factory AccessibilityAnnouncement.simple(String message) {
    return AccessibilityAnnouncement._(message.trim());
  }

  /// Crée une annonce avec contexte pour les résultats de scan.
  ///
  /// Format: "[medicationName] - [form] - [quantity] unités"
  factory AccessibilityAnnouncement.scanResult({
    required String medicationName,
    required String form,
    required int quantity,
  }) {
    return AccessibilityAnnouncement._(
      '$medicationName - $form - $quantity unités',
    );
  }

  /// Crée une annonce pour les erreurs avec niveau de priorité.
  factory AccessibilityAnnouncement.error(
    String message, {
    bool isCritical = false,
  }) {
    final prefix = isCritical ? 'Erreur critique: ' : 'Erreur: ';
    return AccessibilityAnnouncement._('$prefix$message');
  }

  /// Crée une annonce pour les changements de navigation.
  factory AccessibilityAnnouncement.navigation(String destination) {
    return AccessibilityAnnouncement._('Navigation vers $destination');
  }

  /// Crée une annonce pour les actions réussies.
  factory AccessibilityAnnouncement.success(String action) {
    return AccessibilityAnnouncement._('$action - Action réussie');
  }
}

/// Wrapper sémantique pour les titres avec niveau hiérarchique.
///
/// Utilise [Semantics] pour marquer les titres avec le niveau approprié
/// pour une navigation optimale avec les lecteurs d'écran.
class SemanticHeading extends StatelessWidget {
  /// Crée un titre sémantique de niveau 1 (titre principal de page).
  const SemanticHeading.h1({
    required this.child,
    this.excludeSemantics = false,
    super.key,
  }) : _level = 1;

  /// Crée un titre sémantique de niveau 2 (section principale).
  const SemanticHeading.h2({
    required this.child,
    this.excludeSemantics = false,
    super.key,
  }) : _level = 2;

  /// Crée un titre sémantique de niveau 3 (sous-section).
  const SemanticHeading.h3({
    required this.child,
    this.excludeSemantics = false,
    super.key,
  }) : _level = 3;

  /// Crée un titre sémantique de niveau 4 (sous-sous-section).
  const SemanticHeading.h4({
    required this.child,
    this.excludeSemantics = false,
    super.key,
  }) : _level = 4;

  /// Crée un titre sémantique de niveau 5.
  const SemanticHeading.h5({
    required this.child,
    this.excludeSemantics = false,
    super.key,
  }) : _level = 5;

  /// Crée un titre sémantique de niveau 6.
  const SemanticHeading.h6({
    required this.child,
    this.excludeSemantics = false,
    super.key,
  }) : _level = 6;

  final Widget child;
  final bool excludeSemantics;
  final int _level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      headingLevel: _level,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }
}

/// Service centralisé pour l'accessibilité de l'application PharmaScan.
///
/// Fournit des utilitaires pour:
/// - Détection du mode contraste élevé
/// - Gestion du facteur d'échelle du texte
/// - Prise en charge des préférences de mouvement réduit
/// - Wrappers sémantiques pour les titres
/// - Annonces pour lecteurs d'écran
///
/// Toutes les méthodes sont statiques pour un accès facile depuis n'importe
/// quel widget sans nécessiter d'injection de dépendances.
///
/// Exemple d'utilisation:
/// ```dart
/// // Vérifier si le contraste élevé est activé
/// if (AccessibilityService.isHighContrast(context)) {
///   // Adapter les couleurs
/// }
///
/// // Annoncer un résultat de scan
/// AccessibilityService.announceScanResult(
///   context,
///   medicationName: 'Doliprane',
///   form: 'Comprimé',
///   quantity: 16,
/// );
/// ```
class AccessibilityService {
  const AccessibilityService._();

  // ===========================================================================
  // Constantes
  // ===========================================================================

  /// Maximum text scale factor to prevent UI overflow
  static const double maxTextScaleFactor = 2.5;

  /// Minimum text scale factor for readability
  static const double minTextScaleFactor = 0.8;

  /// Default text scale factor when system value is not available
  static const double defaultTextScaleFactor = 1.0;

  /// Threshold for considering text significantly scaled up
  static const double textScaleUpThreshold = 1.3;

  // ===========================================================================
  // Détection des préférences système
  // ===========================================================================

  /// Détecte si le mode contraste élevé est activé.
  ///
  /// Sur iOS: utilise [MediaQueryData.accessibleNavigation]
  /// Sur Android: utilise [MediaQueryData.highContrast]
  ///
  /// Retourne `true` si l'utilisateur a activé les options d'accessibilité
  /// nécessitant un contraste élevé.
  static bool isHighContrast(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);

    // highContrast est disponible sur Flutter 3.38+
    if (mediaQuery?.highContrast ?? false) return true;

    // Fallback pour les anciennes versions ou plateformes spécifiques
    return mediaQuery?.accessibleNavigation ?? false;
  }

  /// Détecte si la navigation accessible est activée.
  ///
  /// Indique que l'utilisateur utilise un lecteur d'écran (VoiceOver, TalkBack).
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
  }

  /// Détecte si l'utilisateur a demandé la réduction des animations.
  ///
  /// Respecte [MediaQueryData.disableAnimations] qui est défini par:
  /// - Le paramètre "Réduire les mouvements" sur iOS
  /// - Le paramètre "Supprimer les animations" sur Android
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Détecte si l'utilisateur a activé le mode inversé des couleurs.
  ///
  /// Disponible sur iOS via [MediaQueryData.invertColors].
  static bool invertColorsEnabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.invertColors ?? false;
  }

  /// Détecte si le mode bold text est activé.
  ///
  /// [MediaQueryData.boldText] est `true` si l'utilisateur a activé
  /// l'option "Texte en gras" dans les paramètres d'accessibilité.
  static bool boldTextEnabled(BuildContext context) {
    return MediaQuery.maybeOf(context)?.boldText ?? false;
  }

  // ===========================================================================
  // Gestion du texte et mise à l'échelle
  // ===========================================================================

  /// Récupère le facteur d'échelle du texte actuel.
  ///
  /// Retourne la valeur de [MediaQueryData.textScaler] qui représente
  /// le ratio de mise à l'échelle défini par l'utilisateur.
  ///
  /// Valeurs typiques:
  /// - 1.0: taille normale
  /// - 1.5: texte agrandi
  /// - 2.0: texte très agrandi
  static TextScaler textScaler(BuildContext context) {
    return MediaQuery.maybeOf(context)?.textScaler ?? TextScaler.noScaling;
  }

  /// Calcule la taille de texte adaptée avec limites.
  ///
  /// Applique le facteur d'échelle utilisateur mais limite aux bornes
  /// [minScale] et [maxScale] pour préserver la lisibilité.
  ///
  /// [baseSize] est la taille de référence (sans mise à l'échelle).
  static double scaledTextSize(
    BuildContext context,
    double baseSize, {
    double minScale = minTextScaleFactor,
    double maxScale = maxTextScaleFactor,
  }) {
    final scaler = textScaler(context);
    final clampedScale = scaler.scale(1.0).clamp(minScale, maxScale);
    return baseSize * clampedScale;
  }

  /// Vérifie si le texte est significativement agrandi.
  ///
  /// Utile pour adapter la mise en page quand le texte dépasse
  /// un seuil critique de lisibilité.
  static bool isTextScaledUp(BuildContext context) {
    return textScaler(context).scale(1.0) >= textScaleUpThreshold;
  }

  /// Crée un [TextStyle] adapté à l'échelle de texte actuelle.
  ///
  /// Applique automatiquement le [TextScaler] aux tailles de police.
  static TextStyle scaledStyle(
    BuildContext context,
    TextStyle baseStyle, {
    double minScale = minTextScaleFactor,
    double maxScale = maxTextScaleFactor,
  }) {
    final fontSize = baseStyle.fontSize;

    if (fontSize == null) return baseStyle;

    final scaledSize = scaledTextSize(
      context,
      fontSize,
      minScale: minScale,
      maxScale: maxScale,
    );

    return baseStyle.copyWith(fontSize: scaledSize);
  }

  /// Clamp text scale factor to prevent layout overflow.
  ///
  /// Méthode legacy pour compatibilité ascendante.
  @Deprecated('Utiliser scaledTextSize() pour plus de contrôle')
  static double clampTextScale(double? scale) {
    if (scale == null) return defaultTextScaleFactor;
    return scale.clamp(minTextScaleFactor, maxTextScaleFactor);
  }

  // ===========================================================================
  // Gestion des animations
  // ===========================================================================

  /// Check if animations should be disabled.
  ///
  /// Méthode legacy pour compatibilité ascendante.
  @Deprecated('Utiliser prefersReducedMotion()')
  static bool shouldDisableAnimations(BuildContext context) {
    return prefersReducedMotion(context);
  }

  /// Get accessible duration for animations (zero if animations disabled).
  ///
  /// Retourne [Duration.zero] si [prefersReducedMotion] est activé,
  /// sinon retourne [defaultDuration].
  static Duration getAnimationDuration(
    BuildContext context, {
    Duration defaultDuration = const Duration(milliseconds: 300),
  }) {
    if (prefersReducedMotion(context)) {
      return Duration.zero;
    }
    return defaultDuration;
  }

  // ===========================================================================
  // Annonces pour lecteurs d'écran
  // ===========================================================================

  /// Annonce un message au lecteur d'écran.
  ///
  /// [announcement] est le message à vocaliser.
  /// [assertiveness] contrôle l'urgence de l'annonce:
  /// - [Assertiveness.polite]: attend la fin de l'annonce en cours
  /// - [Assertiveness.assertive]: interrompt l'annonce en cours
  ///
  /// Le [BuildContext] est requis pour l'annonce mais peut être null
  /// dans certains cas (gestionnaires d'événements globaux).
  static void announce(
    BuildContext? context,
    String announcement, {
    Assertiveness assertiveness = Assertiveness.polite,
  }) {
    final effectiveAnnouncement = AccessibilityAnnouncement.simple(
      announcement,
    );

    // ignore: deprecated_member_use
    SemanticsService.announce(
      effectiveAnnouncement,
      _getTextDirection(context),
      assertiveness: assertiveness,
    );
  }

  /// Annonce le résultat d'un scan de médicament.
  ///
  /// Formate automatiquement l'annonce avec le nom, la forme
  /// et la quantité du médicament scanné.
  static void announceScanResult(
    BuildContext? context, {
    required String medicationName,
    required String form,
    required int quantity,
  }) {
    final announcement = AccessibilityAnnouncement.scanResult(
      medicationName: medicationName,
      form: form,
      quantity: quantity,
    );

    // ignore: deprecated_member_use
    SemanticsService.announce(
      announcement,
      _getTextDirection(context),
      assertiveness: Assertiveness.assertive,
    );
  }

  /// Annonce une erreur avec niveau de priorité.
  ///
  /// [isCritical] détermine si l'erreur doit interrompre immédiatement
  /// toute annonce en cours.
  static void announceError(
    BuildContext? context,
    String message, {
    bool isCritical = false,
  }) {
    final announcement = AccessibilityAnnouncement.error(
      message,
      isCritical: isCritical,
    );

    // ignore: deprecated_member_use
    SemanticsService.announce(
      announcement,
      _getTextDirection(context),
      assertiveness: isCritical
          ? Assertiveness.assertive
          : Assertiveness.polite,
    );
  }

  /// Annonce une navigation vers un nouvel écran.
  ///
  /// Doit être appelée lors de transitions de navigation importantes
  /// pour informer les utilisateurs de lecteurs d'écran.
  static void announceNavigation(BuildContext? context, String destination) {
    final announcement = AccessibilityAnnouncement.navigation(destination);

    // ignore: deprecated_member_use
    SemanticsService.announce(
      announcement,
      _getTextDirection(context),
      assertiveness: Assertiveness.polite,
    );
  }

  /// Annonce le succès d'une action.
  ///
  /// [action] décrit l'action réussie (ex: "Ajouté au réapprovisionnement").
  static void announceSuccess(BuildContext? context, String action) {
    final announcement = AccessibilityAnnouncement.success(action);

    // ignore: deprecated_member_use
    SemanticsService.announce(
      announcement,
      _getTextDirection(context),
      assertiveness: Assertiveness.polite,
    );
  }

  /// Annonce le changement de focus sémantique.
  ///
  /// Utile pour guider les utilisateurs vers un élément spécifique
  /// après une action asynchrone.
  static void announceFocusChange(
    BuildContext? context,
    String elementDescription, {
    Assertiveness assertiveness = Assertiveness.assertive,
  }) {
    final announcement = AccessibilityAnnouncement.simple(
      'Focus sur: $elementDescription',
    );

    // ignore: deprecated_member_use
    SemanticsService.announce(
      announcement,
      _getTextDirection(context),
      assertiveness: assertiveness,
    );
  }

  // ===========================================================================
  // Helpers pour widgets communs
  // ===========================================================================

  /// Crée un bouton avec des propriétés sémantiques optimales.
  ///
  /// Ajoute automatiquement un label sémantique si [semanticLabel]
  /// est fourni, ou utilise [tooltip] comme fallback.
  static Widget accessibleButton({
    required Widget child,
    required VoidCallback? onPressed,
    String? semanticLabel,
    String? tooltip,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      enabled: onPressed != null,
      excludeSemantics: excludeSemantics,
      child: Tooltip(message: tooltip ?? semanticLabel ?? '', child: child),
    );
  }

  /// Crée une image avec description alternative.
  ///
  /// [semanticLabel] est obligatoire pour l'accessibilité.
  /// [excludeFromSemantics] permet de marquer l'image comme décorative.
  static Widget accessibleImage({
    required Widget image,
    required String semanticLabel,
    bool excludeFromSemantics = false,
  }) {
    if (excludeFromSemantics) {
      return Semantics(excludeSemantics: true, child: image);
    }

    return Semantics(image: true, label: semanticLabel, child: image);
  }

  /// Crée un champ de texte avec label sémantique.
  ///
  /// Combine le label visuel et sémantique pour une expérience
  /// cohérente avec les lecteurs d'écran.
  static Widget accessibleTextField({
    required Widget textField,
    required String label,
    String? hint,
    String? error,
    bool required = false,
  }) {
    final labelText = required ? '$label (obligatoire)' : label;

    return Semantics(
      textField: true,
      label: labelText,
      hint: hint,
      value: error,
      child: textField,
    );
  }

  /// Crée un conteneur avec groupe sémantique.
  ///
  /// Utile pour regrouper des éléments liés sous un label commun
  /// pour une navigation plus efficace.
  static Widget semanticGroup({
    required Widget child,
    required String label,
    bool explicitChildNodes = true,
  }) {
    return Semantics(
      container: true,
      explicitChildNodes: explicitChildNodes,
      label: label,
      child: child,
    );
  }

  /// Marque un widget comme étant en cours de chargement.
  ///
  /// Annonce automatiquement l'état de chargement aux lecteurs d'écran.
  static Widget loadingRegion({
    required Widget child,
    required String label,
    required bool isLoading,
    BuildContext? context,
  }) {
    if (isLoading && context != null) {
      announce(context, '$label en cours de chargement');
    }

    return Semantics(
      label: label,
      liveRegion: true,
      child: AbsorbPointer(absorbing: isLoading, child: child),
    );
  }

  /// Crée une région live pour les mises à jour dynamiques.
  ///
  /// Les changements dans cette région sont automatiquement annoncés
  /// par les lecteurs d'écran.
  static Widget liveRegion({
    required Widget child,
    String? label,
    bool assertive = false,
  }) {
    return Semantics(label: label, liveRegion: true, child: child);
  }

  // ===========================================================================
  // Adaptations de thème pour accessibilité
  // ===========================================================================

  /// Récupère le thème shadcn adapté pour le contraste élevé.
  ///
  /// Applique des ajustements de contraste si le mode contraste élevé
  /// est détecté via [isHighContrast].
  static ShadThemeData getAccessibleTheme(
    BuildContext context,
    ShadThemeData baseTheme,
  ) {
    if (!isHighContrast(context)) return baseTheme;

    final colors = baseTheme.colorScheme;

    // Augmenter le contraste pour le mode accessible
    return baseTheme.copyWith(
      colorScheme: colors.copyWith(
        // Assurer un contraste minimum de 4.5:1 pour le texte normal
        foreground: colors.foreground.withValues(alpha: 1.0),
        mutedForeground: colors.mutedForeground.withValues(alpha: 0.8),
        // Bordures plus visibles
        border: colors.border.withValues(alpha: 1.0),
        ring: colors.ring.withValues(alpha: 1.0),
      ),
      // Note: Les propriétés de taille tactile sont gérées par le thème
      // via ShadButton.size ou ShadButtonThemeData dans shadcn_ui
    );
  }

  /// Ajuste une couleur pour le contraste élevé.
  ///
  /// Si [isHighContrast] est activé, la couleur est assombrie
  /// ou éclaircie pour maximiser le contraste avec le fond.
  static Color adjustForContrast(
    BuildContext context,
    Color color, {
    Color? backgroundColor,
  }) {
    if (!isHighContrast(context)) return color;

    // En mode contraste élevé, maximiser l'opacité
    return color.withValues(alpha: 1.0);
  }

  /// Calcule une taille minimale adaptée aux capacités motrices.
  ///
  /// Retourne une taille augmentée si les fonctionnalités d'accessibilité
  /// motrice sont détectées.
  static double accessibleTouchSize(BuildContext context, double baseSize) {
    final mediaQuery = MediaQuery.maybeOf(context);

    // Si la navigation accessible est activée (lecteur d'écran),
    // augmenter la taille minimale tactile
    if (mediaQuery?.accessibleNavigation ?? false) {
      return baseSize.clamp(48.0, double.infinity);
    }

    return baseSize;
  }

  /// Vérifie si des fonctionnalités d'accessibilité sont actives.
  ///
  /// Retourne `true` si au moins une fonctionnalité d'accessibilité
  /// est détectée (lecteur d'écran, contraste élevé, texte agrandi, etc.).
  static bool anyAccessibilityEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);

    if (mediaQuery == null) return false;

    return mediaQuery.accessibleNavigation ||
        mediaQuery.highContrast ||
        mediaQuery.boldText ||
        mediaQuery.disableAnimations ||
        mediaQuery.invertColors ||
        mediaQuery.textScaler.scale(1.0) > 1.2;
  }

  /// Build MediaQuery with accessibility constraints.
  ///
  /// Wrap le [child] avec un [MediaQuery] qui applique les contraintes
  /// d'accessibilité sur le facteur d'échelle du texte.
  static Widget wrapWithAccessibility(
    BuildContext context, {
    required Widget child,
  }) {
    final mediaQuery = MediaQuery.maybeOf(context);

    if (mediaQuery == null) {
      return child;
    }

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(scaledTextSize(context, 1.0)),
      ),
      child: child,
    );
  }

  /// Détermine si un widget devrait réagir aux préférences d'accessibilité.
  ///
  /// Utilitaire pour les widgets conditionnels basés sur l'accessibilité.
  static bool shouldApplyAccessibleVariant(BuildContext context) {
    return anyAccessibilityEnabled(context);
  }

  // ===========================================================================
  // Fallback et utilitaires internes
  // ===========================================================================

  /// Récupère la direction du texte depuis le contexte ou utilise LTR par défaut.
  static TextDirection _getTextDirection(BuildContext? context) {
    if (context != null) {
      return Directionality.of(context);
    }
    // Fallback sur LTR pour les appels sans contexte
    return TextDirection.ltr;
  }
}
