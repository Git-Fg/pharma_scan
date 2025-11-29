import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DetailItem extends StatelessWidget {
  const DetailItem({
    required this.label, required this.value, super.key,
    this.isHighlight = false,
  });

  final String label;
  final String value;

  /// Si true, utilise une couleur de fond ou un style plus prononcé (optionnel)
  final bool isHighlight;

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
        Text(
          value,
          style: theme.textTheme.p.copyWith(color: textColor),
          maxLines: 10, // Autorise le multiligne pour les détails
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
