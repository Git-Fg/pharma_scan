// lib/features/scanner/widgets/princeps_info_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PrincepsInfoBubble extends StatefulWidget {
  final Medicament princeps;
  final String moleculeName;
  final List<String> genericLabs;
  final VoidCallback onClose;
  final VoidCallback onExplore;

  const PrincepsInfoBubble({
    required super.key,
    required this.princeps,
    required this.moleculeName,
    required this.genericLabs,
    required this.onClose,
    required this.onExplore,
  });

  @override
  State<PrincepsInfoBubble> createState() => _PrincepsInfoBubbleState();
}

class _PrincepsInfoBubbleState extends State<PrincepsInfoBubble> {
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
      widget.princeps.conditionsPrescription,
    );
    return ShadCard(
      title: Row(
        children: [
          ShadBadge(
            backgroundColor: theme.colorScheme.secondary,
            child: Text(
              'PRINCEPS',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.secondaryForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.princeps.nom,
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
        'Principe Actif: ${widget.moleculeName}',
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        ),
      ),
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
        child: widget.genericLabs.isEmpty
            ? Text(
                'Aucun générique correspondant trouvé.',
                style: theme.textTheme.p.copyWith(fontStyle: FontStyle.italic),
              )
            : Text(
                'Des génériques existent (labos: ${widget.genericLabs.take(3).join(', ')}${widget.genericLabs.length > 3 ? ', ...' : ''}).',
                style: theme.textTheme.p,
              ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
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
