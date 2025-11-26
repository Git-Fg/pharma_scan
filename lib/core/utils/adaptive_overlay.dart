// lib/core/utils/adaptive_overlay.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Affiche un overlay adaptatif qui s'adapte automatiquement à la largeur d'écran.
///
/// - **Mobile (< sm breakpoint)** : Affiche une [ModalBottomSheet] avec drag handle et coins arrondis.
/// - **Desktop/Tablette (>= sm breakpoint)** : Affiche un [Dialog] centré avec une largeur maximale de 500px.
///
/// Le contenu fourni par [builder] doit être compatible avec les deux modes d'affichage.
/// Il est recommandé d'utiliser [ShadCard] pour le contenu principal.
///
/// [context] : Le contexte de build pour accéder au thème et à MediaQuery.
/// [builder] : Fonction qui construit le widget à afficher dans l'overlay.
/// [isDismissible] : Si true, l'overlay peut être fermé en tapant en dehors ou en glissant (mobile).
/// [title] : Titre optionnel pour le Dialog (ignoré sur mobile).
///
/// Retourne la valeur retournée par l'overlay (généralement null sauf si spécifié).
Future<T?> showAdaptiveOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  String? title,
}) {
  final theme = ShadTheme.of(context);
  final screenWidth = MediaQuery.sizeOf(context).width;
  // WHY: Use theme breakpoint value for responsive layout
  // Default sm breakpoint is 640, but we use the theme's configured value
  final breakpointValue = theme.breakpoints.sm is int
      ? theme.breakpoints.sm as int
      : 640; // Fallback to default if not a number

  if (screenWidth < breakpointValue) {
    // Mobile : BottomSheet
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: builder(sheetContext),
        );
      },
    );
  } else {
    // Desktop/Tablette : Dialog
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }
}
