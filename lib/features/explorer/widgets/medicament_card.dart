// lib/features/explorer/widgets/medicament_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/accessible_touch.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicamentCard extends StatelessWidget {
  const MedicamentCard({
    super.key,
    required this.medicament,
    this.onTap,
    this.trailing,
    this.padding,
    this.hideDosage = false,
  });

  final Medicament medicament;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool hideDosage;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cardContent = ShadCard(
      padding: padding ?? const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildMedicamentInfo(theme)),
          if (trailing != null) ...[const Gap(12), trailing!],
        ],
      ),
    );

    return AccessibleTouch(
      label: _buildSemanticsLabel(),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
      child: cardContent,
    );
  }

  Widget _buildMedicamentInfo(ShadThemeData theme) {
    final titulaire = medicament.titulaire.isNotEmpty
        ? medicament.titulaire
        : Strings.unknownHolder;
    final dosageLabel = _formatDosage();
    final conditionBadge = _buildConditionBadge(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(medicament.nom, style: theme.textTheme.h4),
        if (conditionBadge != null) ...[const Gap(6), conditionBadge],
        const Gap(8),
        InfoLabel(
          text: titulaire,
          icon: LucideIcons.building2,
          style: theme.textTheme.muted,
        ),
        const Gap(4),
        InfoLabel(
          text: medicament.codeCip,
          icon: LucideIcons.barcode,
          style: theme.textTheme.muted,
        ),
        if (!hideDosage && dosageLabel != null) ...[
          const Gap(4),
          InfoLabel(
            text: dosageLabel,
            icon: LucideIcons.flaskConical,
            style: theme.textTheme.muted,
          ),
        ],
      ],
    );
  }

  String? _formatDosage() {
    return medicament.formattedDosage;
  }

  String _buildSemanticsLabel() {
    final buffer = StringBuffer('${Strings.medication} ${medicament.nom}');
    buffer.write(', ${Strings.cip} ${medicament.codeCip}');
    buffer.write(', ${Strings.holder} ${medicament.titulaire}');
    if (!hideDosage) {
      final dosage = _formatDosage();
      if (dosage != null) {
        buffer.write(', ${Strings.dosage} $dosage');
      }
    }
    if (medicament.principesActifs.isNotEmpty) {
      buffer.write(
        ', ${Strings.activePrinciples} ${medicament.principesActifs.take(3).join(', ')}',
      );
    }
    buffer.write(', ${Strings.condition} ${medicament.conditionsPrescription}');
    return buffer.toString();
  }

  Widget? _buildConditionBadge(ShadThemeData theme) {
    final condition = medicament.conditionsPrescription;
    if (condition.isEmpty) return null;
    return ShadBadge.outline(
      child: Text(condition, style: theme.textTheme.small),
    );
  }
}
