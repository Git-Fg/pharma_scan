import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/features/scanner/presentation/models/scanner_ui_state.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Widget that displays the bottom control panel for the scanner screen.
///
/// Handles:
/// - Camera start/stop button with gradient styling
/// - Gallery and Manual Entry buttons
/// - Responsive layout with blur backdrop
/// - Entrance animations
class ScannerControls extends ConsumerWidget {
  const ScannerControls({
    required this.state,
    required this.onToggleCamera,
    required this.onGallery,
    required this.onManualEntry,
    required this.onToggleTorch,
    required this.onToggleZoom,
    required this.onToggleMode,
    super.key,
  });

  final ScannerUiState state;
  final VoidCallback onToggleCamera;
  final VoidCallback onGallery;
  final VoidCallback onManualEntry;
  final VoidCallback onToggleTorch;
  final VoidCallback onToggleZoom;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      :mode,
      :isCameraRunning,
      :torchState,
      :isInitializing,
    ) = switch (state) {
      ScannerInitializing(:final mode) => (
        mode: mode,
        isCameraRunning: false,
        torchState: TorchState.off,
        isInitializing: true,
      ),
      ScannerActive(:final mode, :final torchState, :final isCameraRunning) => (
        mode: mode,
        isCameraRunning: isCameraRunning,
        torchState: torchState,
        isInitializing: false,
      ),
    };
    final buttonColor = mode == .restock
        ? context.colors.destructive
        : context.actionPrimary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final spacing = context.spacing;

    return Positioned(
      bottom: spacing.md + bottomInset,
      left: 0,
      right: 0,
      child: AdaptiveBottomPanel(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ClipRRect(
                borderRadius: context.radiusXLarge,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.surfacePrimary.withValues(alpha: 0.85),
                      border: Border.all(
                        color: context.actionSurface.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: .all(spacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: spacing.md,
                        children: [
                          Center(
                            child: ScannerModeToggle(
                              mode: mode,
                              onToggle: onToggleMode,
                            ),
                          ),
                          Center(
                            child: ScannerActionButton(
                              isCameraRunning: isCameraRunning,
                              isInitializing: isInitializing,
                              onPressed: onToggleCamera,
                              buttonColor: buttonColor,
                            ),
                          ),
                          Padding(
                            padding: .only(top: spacing.sm),
                            child: Row(
                              spacing: spacing.sm,
                              children: [
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    label: Strings.importBarcodeFromGallery,
                                    child: SizedBox(
                                      height: 56,
                                      child: ShadButton.secondary(
                                        width: double.infinity,
                                        onPressed: isInitializing
                                            ? null
                                            : onGallery,
                                        leading: const Icon(LucideIcons.image),
                                        child: Text(Strings.gallery),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isCameraRunning) ...[
                                  Gap(spacing.sm),
                                  Semantics(
                                    button: true,
                                    label: torchState == TorchState.on
                                        ? Strings.turnOffTorch
                                        : Strings.turnOnTorch,
                                    child: ShadButton.secondary(
                                      onPressed:
                                          isCameraRunning && !isInitializing
                                          ? onToggleTorch
                                          : null,
                                      child: Icon(
                                        torchState == TorchState.on
                                            ? LucideIcons.zap
                                            : LucideIcons.zapOff,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  Gap(spacing.sm),
                                  Semantics(
                                    button: true,
                                    label: 'Zoom',
                                    child: ShadButton.secondary(
                                      onPressed:
                                          isCameraRunning && !isInitializing
                                          ? onToggleZoom
                                          : null,
                                      child: Text(
                                        '2x',
                                        style: context.typo.small.copyWith(
                                          fontWeight: .bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Gap(spacing.sm),
                                ] else
                                  Gap(spacing.md),
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    label: Strings.manuallyEnterCipCode,
                                    child: SizedBox(
                                      height: 56,
                                      child: ShadButton.secondary(
                                        width: double.infinity,
                                        key: const Key(
                                          TestTags.manualEntryButton,
                                        ),
                                        onPressed: isInitializing
                                            ? null
                                            : onManualEntry,
                                        leading: const Icon(
                                          LucideIcons.keyboard,
                                        ),
                                        child: Text(Strings.manualEntry),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Main scanner action button (Scan/Stop) with animation and gradient.
class ScannerActionButton extends StatelessWidget {
  const ScannerActionButton({
    required this.isCameraRunning,
    required this.isInitializing,
    required this.onPressed,
    required this.buttonColor,
    super.key,
  });

  final bool isCameraRunning;
  final bool isInitializing;
  final VoidCallback onPressed;
  final Color buttonColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [buttonColor, buttonColor.withValues(alpha: 0.85)],
          ),
          borderRadius: .circular(44),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isInitializing ? null : onPressed,
            borderRadius: .circular(44),
            child: Icon(
              isCameraRunning ? LucideIcons.camera : LucideIcons.scanLine,
              size: 40,
              color: context.actionOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class ScannerModeToggle extends StatelessWidget {
  const ScannerModeToggle({
    required this.mode,
    required this.onToggle,
    super.key,
  });

  final ScannerMode mode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isRestock = mode == ScannerMode.restock;
    final color = isRestock
        ? context.colors.destructive
        : context.actionPrimary;
    final icon = isRestock ? LucideIcons.packagePlus : LucideIcons.search;
    final label = isRestock ? 'Rangement' : 'Analyse';
    final spacing = context.spacing;

    return FittedBox(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: GestureDetector(
          onTap: onToggle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: .circular(999),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: .symmetric(horizontal: spacing.md, vertical: spacing.xs),
              child: Row(
                key: ValueKey(mode),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color).animate().fadeIn(
                    duration: const Duration(milliseconds: 180),
                  ),
                  Gap(spacing.xs),
                  Text(
                    label,
                    style: context.typo.small.copyWith(
                      color: color,
                      fontWeight: .w600,
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(
                    duration: const Duration(milliseconds: 180),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
