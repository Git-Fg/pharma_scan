// lib/features/scanner/widgets/info_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InfoBubble extends StatefulWidget {
  final Medicament medicament;
  final VoidCallback onClose;

  const InfoBubble({
    required super.key,
    required this.medicament,
    required this.onClose,
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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: ShadCard(
        title: Row(
          children: [
            ShadBadge(
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                'GÉNÉRIQUE',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.primaryForeground,
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
          ],
        ),
        description: Text(
          'Principes Actifs',
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        footer: ShadButton.destructive(
          onPressed: widget.onClose,
          leading: const Icon(LucideIcons.x, size: 16),
          child: const Text('Fermer'),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.medicament.principesActifs
                .map((principe) => Text('• $principe', style: theme.textTheme.p))
                .toList(),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }
}

