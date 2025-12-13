import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/features/scanner/presentation/models/scanner_ui_state.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
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
        ? context.shadColors.destructive
        : context.shadColors.primary;
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
                borderRadius: context.shadTheme.radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ShadTheme.of(
                      context,
                    ).colorScheme.background.withValues(alpha: 0.9),
                    border: Border.all(
                      color: ShadTheme.of(
                        context,
                      ).colorScheme.border.withValues(alpha: 0.5),
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
                            spacing: AppDimens.spacingSm,
                            children: [
                              Expanded(
                                child: Testable(
                                  id: TestTags.scanGalleryBtn,
                                  child: Semantics(
                                    button: true,
                                    label: Strings.importBarcodeFromGallery,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: ShadButton.secondary(
                                        onPressed:
                                            isInitializing ? null : onGallery,
                                        leading: const Icon(
                                          LucideIcons.image,
                                          size: AppDimens.iconSm,
                                        ),
                                        child: const Text(
                                          Strings.gallery,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
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
                                  child: ShadIconButton.secondary(
                                    onPressed:
                                        isCameraRunning && !isInitializing
                                            ? onToggleTorch
                                            : null,
                                    icon: Icon(
                                      LucideIcons.zap,
                                      size: AppDimens.iconLg,
                                      color: torchState == TorchState.on
                                          ? context.shadColors.primary
                                          : null,
                                    ),
                                  ),
                                ),
                                const Gap(AppDimens.spacingSm),
                              ] else
                                const Gap(AppDimens.spacingMd),
                              Expanded(
                                child: Testable(
                                  id: TestTags.scanManualBtn,
                                  child: Semantics(
                                    button: true,
                                    label: Strings.manuallyEnterCipCode,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: ShadButton.secondary(
                                        onPressed: isInitializing
                                            ? null
                                            : onManualEntry,
                                        leading: const Icon(
                                          LucideIcons.keyboard,
                                          size: AppDimens.iconSm,
                                        ),
                                        child: const Text(
                                          Strings.manualEntry,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
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
      )
          .animate()
          .fadeIn(delay: 200.ms)
          .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
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
    return Testable(
      id: isCameraRunning ? TestTags.scanStopBtn : TestTags.scanStartBtn,
      child: SizedBox(
        width: 88,
        height: 88,
        child: ShadIconButton(
          onPressed: isInitializing ? null : onPressed,
          icon: Icon(
            isCameraRunning ? LucideIcons.cameraOff : LucideIcons.scanLine,
            size: AppDimens.iconXl,
            color: context.shadColors.primaryForeground,
          ),
          gradient: LinearGradient(
            colors: [
              buttonColor,
              buttonColor.withValues(alpha: 0.85),
            ],
          ),
          shadows: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
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
    final theme = context.shadTheme;
    final isRestock = mode == ScannerMode.restock;
    final color =
        isRestock ? theme.colorScheme.destructive : theme.colorScheme.primary;
    final icon = isRestock ? LucideIcons.box : LucideIcons.scanSearch;
    final label =
        isRestock ? Strings.scannerModeRestock : Strings.scannerModeAnalysis;

    return FittedBox(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: ShadButton.raw(
          onPressed: onToggle,
          variant: ShadButtonVariant.secondary,
          padding: EdgeInsets.zero,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Row(
                  key: ValueKey(mode),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: AppDimens.iconSm,
                      color: color,
                    ),
                    const Gap(AppDimens.spacing2xs),
                    Text(
                      label,
                      style: theme.textTheme.small.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
