import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/features/scanner/presentation/models/scanner_ui_state.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

import 'package:pharma_scan/core/ui/theme/app_spacing.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
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
    required this.onToggleMode,
    super.key,
  });

  final ScannerUiState state;
  final VoidCallback onToggleCamera;
  final VoidCallback onGallery;
  final VoidCallback onManualEntry;
  final VoidCallback onToggleTorch;
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
      ScannerActive(
        :final mode,
        :final torchState,
        :final isCameraRunning,
      ) =>
        (
          mode: mode,
          isCameraRunning: isCameraRunning,
          torchState: torchState,
          isInitializing: false,
        ),
    };
    final buttonColor = mode == ScannerMode.restock
        ? context.textNegative
        : context.actionPrimary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      bottom: AppDimens.spacingMd + bottomInset,
      left: 0,
      right: 0,
      child: AdaptiveBottomPanel(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ClipRRect(
                borderRadius: context.radiusMedium,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surfacePrimary.withValues(alpha: 0.9),
                    border: Border.all(
                      color: context.actionSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(
                      AppDimens.spacingLg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppDimens.spacingMd,
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
                          padding:
                              const EdgeInsets.only(top: AppDimens.spacingSm),
                          child: Row(
                            spacing: AppSpacing.small,
                            children: [
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: Strings.importBarcodeFromGallery,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: ShadButton.secondary(
                                      onPressed:
                                          isInitializing ? null : onGallery,
                                      leading: const Icon(Icons.image),
                                      child: Text(Strings.gallery),
                                    ),
                                  ),
                                ),
                              ),
                              if (isCameraRunning) ...[
                                const Gap(AppDimens.spacingSm),
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
                                    child: const Icon(Icons.flash_on),
                                  ),
                                ),
                                const Gap(AppDimens.spacingSm),
                              ] else
                                const Gap(AppDimens.spacingMd),
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: Strings.manuallyEnterCipCode,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: ShadButton.secondary(
                                      key:
                                          const Key(TestTags.manualEntryButton),
                                      onPressed:
                                          isInitializing ? null : onManualEntry,
                                      leading: const Icon(Icons.keyboard),
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
          color: buttonColor,
          borderRadius:
              BorderRadius.circular(44), // Moitié de la taille pour un cercle
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isInitializing ? null : onPressed,
            borderRadius: BorderRadius.circular(44),
            child: Icon(
              isCameraRunning ? Icons.camera_alt : Icons.qr_code_scanner,
              size: AppDimens.iconXl,
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
    final color = isRestock ? context.textNegative : context.actionPrimary;
    final icon = isRestock ? Icons.inventory : Icons.search;
    final label =
        isRestock ? Strings.scannerModeRestock : Strings.scannerModeAnalysis;

    return FittedBox(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: GestureDetector(
          onTap: onToggle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
                vertical: AppDimens.spacing2xs,
              ),
              child: Row(
                key: ValueKey(mode),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: AppDimens.iconSm,
                    color: color,
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 180)),
                  const Gap(AppDimens.spacing2xs),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 180)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
