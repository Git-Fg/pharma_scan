// lib/features/explorer/widgets/medicament_card.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicamentCard extends StatelessWidget {
  const MedicamentCard({
    super.key,
    required this.medicament,
    this.onTap,
    this.trailing,
    this.padding,
  });

  final Medicament medicament;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicament.nom,
          style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500),
        ),
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
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
                overflow: TextOverflow.ellipsis,
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
              child: Text(
                medicament.codeCip,
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        if (dosageLabel != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                LucideIcons.activity,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dosageLabel,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String? _formatDosage() {
    final dosage = medicament.dosage;
    final unit = medicament.dosageUnit;

    if (dosage == null && unit == null) return null;
    if (dosage == null) return unit;
    if (unit == null) return _formatNumber(dosage);

    return '${_formatNumber(dosage)} $unit';
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _buildSemanticsLabel() {
    final buffer = StringBuffer('Médicament ${medicament.nom}');
    buffer.write(', CIP ${medicament.codeCip}');
    if (medicament.titulaire != null) {
      buffer.write(', titulaire ${medicament.titulaire}');
    }
    final dosage = _formatDosage();
    if (dosage != null) {
      buffer.write(', dosage $dosage');
    }
    if (medicament.principesActifs.isNotEmpty) {
      buffer.write(
        ', principes actifs ${medicament.principesActifs.take(3).join(', ')}',
      );
    }
    return buffer.toString();
  }
}
