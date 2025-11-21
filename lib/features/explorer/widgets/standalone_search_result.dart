// lib/features/explorer/widgets/standalone_search_result.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:gap/gap.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_card.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

class StandaloneSearchResult extends StatefulWidget {
  const StandaloneSearchResult({super.key, required this.medicament});

  final Medicament medicament;

  @override
  State<StandaloneSearchResult> createState() => _StandaloneSearchResultState();
}

class _StandaloneSearchResultState extends State<StandaloneSearchResult> {
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Semantics(
      button: true,
      label: '${Strings.showMedicamentDetails} ${widget.medicament.nom}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showDetails,
          borderRadius: BorderRadius.circular(12),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
          child: MedicamentCard(
            medicament: widget.medicament,
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails() {
    showAdaptiveOverlay(
      context: context,
      builder: (overlayContext) {
        final overlayTheme = ShadTheme.of(overlayContext);
        return _buildDetailContent(
          theme: overlayTheme,
          onClose: () => Navigator.of(overlayContext).maybePop(),
        );
      },
    );
  }

  Widget _buildDetailContent({
    required ShadThemeData theme,
    required VoidCallback onClose,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      Strings.medicationDetails,
                      style: theme.textTheme.h4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: Strings.closeMedicationDetails,
                    child: ShadButton.ghost(
                      onPressed: onClose,
                      child: const Icon(LucideIcons.x, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailItem(
                      label: Strings.nameLabel,
                      value: widget.medicament.nom,
                    ),
                    if (widget.medicament.principesActifs.isNotEmpty) ...[
                      const Gap(16),
                      DetailItem(
                        label: Strings.activePrinciplesLabel,
                        value: widget.medicament.principesActifs.join(', '),
                      ),
                    ],
                    if (widget.medicament.codeCip.isNotEmpty) ...[
                      const Gap(16),
                      DetailItem(
                        label: Strings.cip,
                        value: widget.medicament.codeCip,
                      ),
                    ],
                    if (widget.medicament.titulaire.isNotEmpty) ...[
                      const Gap(16),
                      DetailItem(
                        label: Strings.holder,
                        value: widget.medicament.titulaire,
                      ),
                    ],
                    if (widget.medicament.formePharmaceutique.isNotEmpty) ...[
                      const Gap(16),
                      DetailItem(
                        label: Strings.pharmaceuticalFormLabel,
                        value: widget.medicament.formePharmaceutique,
                      ),
                    ],
                    const Gap(16),
                    ShadBadge.outline(
                      child: Text(
                        Strings.uniqueMedicationNoGroup,
                        style: theme.textTheme.small,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
