// lib/features/scanner/widgets/info_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InfoBubble extends StatefulWidget {
  final Medicament medicament;
  final List<Medicament> associatedPrinceps;
  final VoidCallback onClose;
  final VoidCallback onExplore;

  const InfoBubble({
    required super.key,
    required this.medicament,
    required this.associatedPrinceps,
    required this.onClose,
    required this.onExplore,
  });

  @override
  State<InfoBubble> createState() => _InfoBubbleState();
}

class _InfoBubbleState extends State<InfoBubble> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    // Fermeture automatique après 15 secondes
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
    return ShadCard(
      title: Row(
        children: [
          ShadBadge(
            backgroundColor: theme.colorScheme.primary,
            child: Text('GÉNÉRIQUE', style: theme.textTheme.small),
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
      description: Text('Princeps Associé(s)', style: theme.textTheme.muted),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ShadButton.outline(
            onPressed: widget.onExplore,
            leading: const Icon(LucideIcons.search, size: 16),
            child: const Text('Explorer le Groupe'),
          ),
          const SizedBox(width: 8),
          ShadButton.destructive(
            onPressed: widget.onClose,
            child: const Text('Fermer'),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.associatedPrinceps.isEmpty
              ? [Text('Aucun princeps trouvé.', style: theme.textTheme.p)]
              : widget.associatedPrinceps
                    .map((p) => Text('• ${p.nom}', style: theme.textTheme.p))
                    .toList(),
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
      child: Text(conditionsPrescription, style: theme.textTheme.small),
    );
  }
}
