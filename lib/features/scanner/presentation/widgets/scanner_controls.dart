import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
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
    required this.isCameraActive,
    required this.isInitializing,
    required this.onToggleCamera,
    required this.onGallery,
    required this.onManualEntry,
    super.key,
  });

  final bool isCameraActive;
  final bool isInitializing;
  final VoidCallback onToggleCamera;
  final VoidCallback onGallery;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child:
          AdaptiveBottomPanel(
                children: [
                  ClipRRect(
                    borderRadius: context.shadTheme.radius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(
                          AppDimens.spacingLg,
                        ),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (context) {
                                final scannerState = ref.watch(scannerProvider);
                                final mode = scannerState.maybeWhen(
                                  data: (value) => value.mode,
                                  orElse: () => ScannerMode.analysis,
                                );
                                final isRestockMode =
                                    mode == ScannerMode.restock;

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isRestockMode
                                            ? Strings.scannerModeRestock
                                            : Strings.scannerModeAnalysis,
                                        style: context.shadTextTheme.small,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ShadSwitch(
                                      value: isRestockMode,
                                      onChanged: (value) {
                                        ref
                                            .read(scannerProvider.notifier)
                                            .setMode(
                                              value
                                                  ? ScannerMode.restock
                                                  : ScannerMode.analysis,
                                            );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const Gap(AppDimens.spacingMd),
                            Center(
                              child: Testable(
                                id: isCameraActive
                                    ? TestTags.scanStopBtn
                                    : TestTags.scanStartBtn,
                                child: SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: ShadIconButton(
                                    onPressed: isInitializing
                                        ? null
                                        : onToggleCamera,
                                    icon: Icon(
                                      isCameraActive
                                          ? LucideIcons.cameraOff
                                          : LucideIcons.scanLine,
                                      size: AppDimens.iconXl,
                                      color: ShadTheme.of(
                                        context,
                                      ).colorScheme.primaryForeground,
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        ShadTheme.of(
                                          context,
                                        ).colorScheme.primary,
                                        ShadTheme.of(
                                          context,
                                        ).colorScheme.primary.withValues(
                                          alpha: 0.85,
                                        ),
                                      ],
                                    ),
                                    shadows: [
                                      BoxShadow(
                                        color:
                                            ShadTheme.of(
                                              context,
                                            ).colorScheme.primary.withValues(
                                              alpha: 0.35,
                                            ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Gap(AppDimens.spacingLg),
                            Row(
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
                                          onPressed: isInitializing
                                              ? null
                                              : onGallery,
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
                          ],
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
