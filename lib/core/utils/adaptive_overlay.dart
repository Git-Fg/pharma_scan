// lib/core/utils/adaptive_overlay.dart
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Affiche un overlay adaptatif qui s'adapte automatiquement à la largeur d'écran.
///
/// - **Mobile (< sm breakpoint)** : Affiche une [FSheet] avec drag handle et coins arrondis.
/// - **Desktop/Tablette (>= sm breakpoint)** : Affiche un [FDialog] centré avec une largeur maximale de 500px.
///
/// Le contenu fourni par [builder] doit être compatible avec les deux modes d'affichage.
/// Il est recommandé d'utiliser [FCard] ou [FCard.raw] pour le contenu principal.
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
  final screenWidth = MediaQuery.sizeOf(context).width;
  // WHY: Use standard breakpoint value for responsive layout
  // Standard sm breakpoint is 640px (standard responsive breakpoint)
  const breakpointValue = 640;

  if (screenWidth < breakpointValue) {
    // Mobile : BottomSheet using Forui
    return showFSheet<T>(
      context: context,
      side: FLayout.btt, // Bottom to Top
      barrierDismissible: isDismissible,
      draggable: isDismissible,
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
    // Desktop/Tablette : Dialog using Forui
    return showFDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext, style, animation) {
        // Wrap builder content in FDialog if it returns raw content
        final content = builder(dialogContext);

        // If content is already an FDialog, return it
        if (content is FDialog) {
          return content;
        }

        // Otherwise wrap in FDialog
        return FDialog(
          style: style.call,
          animation: animation,
          direction: Axis.vertical,
          title: title != null ? Text(title) : null,
          body: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: content,
          ),
          actions: const [], // Empty actions list
        );
      },
    );
  }
}
