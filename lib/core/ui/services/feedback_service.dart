import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_extensions.dart';
import '../../services/haptic_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Service centralisé pour les feedbacks utilisateur (toasts, dialogs, snackbar)
class FeedbackService {
  /// Affiche un toast de succès
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showToast(
      context,
      title: title ?? 'Succès',
      message: message,
      icon: Icon(Icons.check_circle, color: context.colors.primary),
      backgroundColor: context.colors.primary.withValues(alpha: 0.1),
      borderColor: context.colors.primary,
      duration: duration,
      hapticFeedback: () {
        final ref = ProviderScope.containerOf(context, listen: false);
        ref.read(hapticServiceProvider).success();
      },
    );
  }

  /// Affiche un toast d'erreur
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showToast(
      context,
      title: title ?? 'Erreur',
      message: message,
      icon: Icon(Icons.error, color: context.colors.destructive),
      backgroundColor: context.colors.destructive.withValues(alpha: 0.1),
      borderColor: context.colors.destructive,
      duration: duration,
      hapticFeedback: () {
        final ref = ProviderScope.containerOf(context, listen: false);
        ref.read(hapticServiceProvider).error();
      },
    );
  }

  /// Affiche un toast d'avertissement
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showToast(
      context,
      title: title ?? 'Attention',
      message: message,
      icon: Icon(Icons.warning, color: context.colors.ring),
      backgroundColor: context.colors.ring.withValues(alpha: 0.1),
      borderColor: context.colors.ring,
      duration: duration,
      hapticFeedback: () {
        final ref = ProviderScope.containerOf(context, listen: false);
        ref.read(hapticServiceProvider).warning();
      },
    );
  }

  /// Affiche un toast d'information
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showToast(
      context,
      title: title ?? 'Information',
      message: message,
      icon: Icon(Icons.info, color: context.colors.primary),
      backgroundColor: context.colors.primary.withValues(alpha: 0.1),
      borderColor: context.colors.primary,
      duration: duration,
      hapticFeedback: () {
        final ref = ProviderScope.containerOf(context, listen: false);
        ref.read(hapticServiceProvider).selection();
      },
    );
  }

  /// Affiche un toast personnalisé
  static void _showToast(
    BuildContext context, {
    required String title,
    required String message,
    required Widget icon,
    required Color backgroundColor,
    required Color borderColor,
    required Duration duration,
    required VoidCallback hapticFeedback,
  }) {
    // Afficher le feedback haptique
    hapticFeedback();

    // Affichage du toast (utilisation de ScaffoldMessenger pour l'instant,
    // mais pourrait être remplacé par une solution spécifique si shadcn_ui est utilisé)
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            icon,
            const SizedBox(width: 16), // Medium spacing
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Text(
                    title,
                    style: context.typo.large.copyWith(fontWeight: .bold),
                  ),
                  Text(message, style: context.typo.small),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: .floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor),
          borderRadius: .circular(8.0),
        ),
        duration: duration,
        margin: const .all(16.0),
      ),
    );
  }

  /// Affiche une boîte de dialogue de confirmation
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    ShadButtonVariant confirmVariant = .destructive,
    bool barrierDismissible = true,
  }) async {
    final haptics = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(hapticServiceProvider);

    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: context.typo.h4),
          content: Text(
            content,
            style: context.typo.large.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
          actions: [
            ShadButton.ghost(
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop(false);
              },
              child: Text(cancelText),
            ),
            switch (confirmVariant) {
              .destructive => ShadButton.destructive(
                onPressed: () {
                  haptics.selection();
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText),
              ),
              _ => ShadButton(
                onPressed: () {
                  haptics.selection();
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText),
              ),
            },
          ],
        );
      },
    );
  }

  /// Affiche une boîte de dialogue avec une seule action
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'OK',
    bool barrierDismissible = true,
  }) async {
    final haptics = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(hapticServiceProvider);

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: context.typo.h4),
          content: Text(
            content,
            style: context.typo.large.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
          actions: [
            ShadButton(
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop();
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}
