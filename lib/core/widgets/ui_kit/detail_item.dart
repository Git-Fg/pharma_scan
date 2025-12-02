import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DetailItem extends StatelessWidget {
  const DetailItem({
    required this.label,
    required this.value,
    super.key,
    this.isHighlight = false,
    this.copyable = false,
    this.onCopy,
    this.copyLabel,
  });

  final String label;
  final String value;

  /// Si true, utilise une couleur de fond ou un style plus prononcé (optionnel)
  final bool isHighlight;

  /// Si true, affiche un bouton de copie à côté de la valeur
  final bool copyable;

  /// Callback appelé lors de la copie
  final VoidCallback? onCopy;

  /// Label d'accessibilité pour le bouton de copie
  final String? copyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mutedForeground = theme.colorScheme.mutedForeground;
    final textColor = isHighlight ? null : theme.colorScheme.foreground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.small.copyWith(color: mutedForeground),
        ),
        const Gap(AppDimens.spacing2xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.p.copyWith(color: textColor),
                maxLines: 10, // Autorise le multiligne pour les détails
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (copyable && onCopy != null) ...[
              const Gap(AppDimens.spacingXs),
              Semantics(
                button: true,
                label: copyLabel ?? 'Copier',
                hint: 'Copie la valeur dans le presse-papiers',
                child: ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.copy, size: 16),
                  onPressed: onCopy,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
