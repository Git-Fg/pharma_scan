import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';

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
    final mutedForeground = context.theme.colors.mutedForeground;
    final textColor = isHighlight ? null : context.theme.colors.foreground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.theme.typography.sm.copyWith(color: mutedForeground),
        ),
        const Gap(AppDimens.spacing2xs),
        Text(
          value,
          style: context.theme.typography.base.copyWith(color: textColor),
          maxLines: 10, // Autorise le multiligne pour les détails
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
