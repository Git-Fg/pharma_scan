// lib/features/scanner/widgets/standalone_info_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class StandaloneInfoBubble extends StatefulWidget {
  final Medicament medicament;
  final VoidCallback onClose;

  const StandaloneInfoBubble({
    required super.key,
    required this.medicament,
    required this.onClose,
  });

  @override
  State<StandaloneInfoBubble> createState() => _StandaloneInfoBubbleState();
}

class _StandaloneInfoBubbleState extends State<StandaloneInfoBubble> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(const Duration(seconds: 15), widget.onClose);
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final conditionBadge = _buildConditionBadge(
      theme,
      widget.medicament.conditionsPrescription,
    );
    final principesText = widget.medicament.principesActifs.isNotEmpty
        ? widget.medicament.principesActifs.join(', ')
        : Strings.noActivePrincipleReported;

    return Semantics(
      label: Strings.standaloneSemantics(
        widget.medicament.nom,
        widget.medicament.principesActifs.isNotEmpty,
        principesText,
      ),
      child: ShadCard(
        title: Row(
          children: [
            ShadBadge(
              backgroundColor: theme.colorScheme.muted,
              child: Text(
                Strings.uniqueMedicationBadge,
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.medicament.nom,
                style: theme.textTheme.h4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conditionBadge != null) ...[
              const SizedBox(width: 8),
              conditionBadge,
            ],
          ],
        ),
        description: Text(
          Strings.uniqueMedicationDescription,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: Strings.closeMedicationCard,
              child: ShadButton.destructive(
                onPressed: widget.onClose,
                child: const Text(Strings.close),
              ),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.medicament.principesActifs.isNotEmpty)
                Text(
                  Strings.activePrinciplesWithValue(principesText),
                  style: theme.textTheme.p,
                )
              else
                Text(
                  '${Strings.noActivePrincipleReported}.',
                  style: theme.textTheme.p.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (widget.medicament.titulaire.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  Strings.holderWithValue(widget.medicament.titulaire),
                  style: theme.textTheme.p,
                ),
              ],
              if (widget.medicament.formePharmaceutique.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  Strings.formWithValue(widget.medicament.formePharmaceutique),
                  style: theme.textTheme.p,
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(effects: AppAnimations.bubbleEnter);
  }

  Widget? _buildConditionBadge(
    ShadThemeData theme,
    String? conditionsPrescription,
  ) {
    if (conditionsPrescription == null || conditionsPrescription.isEmpty) {
      return null;
    }
    return ShadBadge.outline(
      child: Text(
        conditionsPrescription,
        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
