// lib/features/explorer/widgets/medicament_card.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
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
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    Widget card = Semantics(
      button: onTap != null,
      label: _buildSemanticsLabel(),
      child: cardContent,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }

  Widget _buildMedicamentInfo(ShadThemeData theme) {
    final titulaire = medicament.titulaire ?? 'Titulaire inconnu';
    final dosageLabel = _formatDosage();
    final conditionBadge = _buildConditionBadge(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(medicament.nom, style: theme.textTheme.h4),
        if (conditionBadge != null) ...[
          const SizedBox(height: 6),
          conditionBadge,
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              LucideIcons.building2,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                titulaire,
                style: theme.textTheme.muted,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              LucideIcons.barcode,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(medicament.codeCip, style: theme.textTheme.muted),
            ),
          ],
        ),
        if (!hideDosage && dosageLabel != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                LucideIcons.flaskConical,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(dosageLabel, style: theme.textTheme.muted)),
            ],
          ),
        ],
      ],
    );
  }

  String? _formatDosage() {
    return formatDosageLabel(
      dosage: medicament.dosage,
      unit: medicament.dosageUnit,
    );
  }

  String _buildSemanticsLabel() {
    final buffer = StringBuffer('Médicament ${medicament.nom}');
    buffer.write(', CIP ${medicament.codeCip}');
    if (medicament.titulaire != null) {
      buffer.write(', titulaire ${medicament.titulaire}');
    }
    if (!hideDosage) {
      final dosage = _formatDosage();
      if (dosage != null) {
        buffer.write(', dosage $dosage');
      }
    }
    if (medicament.principesActifs.isNotEmpty) {
      buffer.write(
        ', principes actifs ${medicament.principesActifs.take(3).join(', ')}',
      );
    }
    if (medicament.conditionsPrescription != null) {
      buffer.write(', condition ${medicament.conditionsPrescription}');
    }
    return buffer.toString();
  }

  Widget? _buildConditionBadge(ShadThemeData theme) {
    final condition = medicament.conditionsPrescription;
    if (condition == null || condition.isEmpty) return null;
    return ShadBadge.outline(
      child: Text(condition, style: theme.textTheme.small),
    );
  }
}
