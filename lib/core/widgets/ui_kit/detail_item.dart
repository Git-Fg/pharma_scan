import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DetailItem extends StatelessWidget {
  const DetailItem({
    super.key,
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;

  /// Si true, utilise une couleur de fond ou un style plus prononcé (optionnel)
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(AppDimens.spacing2xs),
        Text(
          value,
          style: isHighlight
              ? theme.textTheme.p.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.p,
          overflow: TextOverflow.ellipsis,
          maxLines: 10, // Autorise le multiligne pour les détails
        ),
      ],
    );
  }
}
