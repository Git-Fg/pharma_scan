import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../atoms/app_icon.dart';
import '../atoms/app_text.dart';
import '../molecules/app_button.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../../services/haptic_service.dart'; // Assumant que ce service existe

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
      icon: const AppIcon(AppIconData.success, color: Color(0xFF137333)),
      backgroundColor: const Color(0xFFE6F4EA),
      borderColor: const Color(0xFF137333),
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
      icon: const AppIcon(AppIconData.error, color: Color(0xFFC5221F)),
      backgroundColor: const Color(0xFFFCE8E6),
      borderColor: const Color(0xFFC5221F),
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
      icon: const AppIcon(AppIconData.warning, color: Color(0xFFBF5700)),
      backgroundColor: const Color(0xFFFFF4E6),
      borderColor: const Color(0xFFBF5700),
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
      icon: const AppIcon(AppIconData.info, color: Color(0xFF1A73E8)),
      backgroundColor: const Color(0xFFE8F0FE),
      borderColor: const Color(0xFF1A73E8),
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
            HGap(AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    title,
                    variant: TextVariant.labelMedium,
                    fontWeight: FontWeight.bold,
                  ),
                  AppText(
                    message,
                    variant: TextVariant.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(8.0),
        ),
        duration: duration,
        margin: const EdgeInsets.all(16.0),
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
    ButtonVariant confirmVariant = ButtonVariant.destructive,
    bool barrierDismissible = true,
  }) async {
    final haptics = ProviderScope.containerOf(context, listen: false)
        .read(hapticServiceProvider);

    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return AlertDialog(
          title: AppText(
            title,
            variant: TextVariant.headlineSmall,
          ),
          content: AppText(
            content,
            variant: TextVariant.bodyMedium,
            color: context.textSecondary,
          ),
          actions: [
            AppButton(
              label: cancelText,
              variant: ButtonVariant.ghost,
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop(false);
              },
            ),
            AppButton(
              label: confirmText,
              variant: confirmVariant,
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop(true);
              },
            ),
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
    final haptics = ProviderScope.containerOf(context, listen: false)
        .read(hapticServiceProvider);

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return AlertDialog(
          title: AppText(
            title,
            variant: TextVariant.headlineSmall,
          ),
          content: AppText(
            content,
            variant: TextVariant.bodyMedium,
            color: context.textSecondary,
          ),
          actions: [
            AppButton(
              label: confirmText,
              variant: ButtonVariant.primary,
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}