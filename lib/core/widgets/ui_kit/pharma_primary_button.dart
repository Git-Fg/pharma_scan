import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Primary action button used across PharmaScan to ensure gradient + shadow
/// styling stays aligned with the Shadcn UI kit.
class PharmaPrimaryButton extends StatelessWidget {
  const PharmaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.semanticLabel,
    this.height = 56,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final String? semanticLabel;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final effectiveLabel = semanticLabel ?? label;
    final Color spinnerColor = theme.colorScheme.primaryForeground;

    Widget? leading;
    if (isLoading) {
      leading = SizedBox(
        width: AppDimens.iconMd,
        height: AppDimens.iconMd,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        ),
      );
    } else if (leadingIcon != null) {
      leading = Icon(leadingIcon, size: AppDimens.iconLg, color: spinnerColor);
    }

    return SizedBox(
      height: height,
      child: Semantics(
        button: true,
        label: effectiveLabel,
        enabled: onPressed != null && !isLoading,
        child: ShadButton(
          onPressed: isLoading ? null : onPressed,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.9),
            ],
          ),
          shadows: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          leading: leading,
          child: Text(
            label,
            style: theme.textTheme.large.copyWith(
              color: theme.colorScheme.primaryForeground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
