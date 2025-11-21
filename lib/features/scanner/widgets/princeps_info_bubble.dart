// lib/features/scanner/widgets/princeps_info_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
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
    return Semantics(
      label: Strings.princepsSemantics(
        widget.princeps.nom,
        widget.moleculeName,
        widget.genericLabs.isNotEmpty,
      ),
      child: ShadCard(
        title: Row(
          children: [
            ShadBadge(
              backgroundColor: theme.colorScheme.secondary,
              child: Text(
                Strings.princepsBadge,
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
          Strings.activePrincipleWithValue(widget.moleculeName),
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: Strings.exploreMedicationGroup,
              child: ShadButton.outline(
                onPressed: widget.onExplore,
                leading: const Icon(LucideIcons.search, size: 16),
                child: const Text(Strings.exploreGroup),
              ),
            ),
            const SizedBox(width: 8),
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
          child: widget.genericLabs.isEmpty
              ? Text(
                  Strings.noGenericsFound,
                  style: theme.textTheme.p.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Text(
                  Strings.genericsExistWithLabs(widget.genericLabs),
                  style: theme.textTheme.p,
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
