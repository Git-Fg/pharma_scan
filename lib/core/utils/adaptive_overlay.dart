// lib/core/utils/adaptive_overlay.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Breakpoint pour déterminer si on est sur mobile ou desktop.
/// En dessous de cette largeur, on utilise une BottomSheet.
/// Au-dessus, on utilise un Dialog.
const double _mobileBreakpoint = 600.0;

/// Affiche un overlay adaptatif qui s'adapte automatiquement à la largeur d'écran.
///
/// - **Mobile (< 600px)** : Affiche une [ModalBottomSheet] avec drag handle et coins arrondis.
/// - **Desktop/Tablette (>= 600px)** : Affiche un [Dialog] centré avec une largeur maximale de 500px.
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
  final screenWidth = MediaQuery.sizeOf(context).width;

  if (screenWidth < _mobileBreakpoint) {
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
