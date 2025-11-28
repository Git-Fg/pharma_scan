// lib/features/scanner/screens/camera_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/router/routes.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_sheet_layout.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
import 'package:pharma_scan/features/scanner/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/widgets/scan_window_overlay.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/hooks/use_mobile_scanner.dart';

class CameraScreen extends HookConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCameraActive = useState(false);
    final isTorchOn = useState(false);
    final scannerController = useMobileScanner(autoStart: false);
    final picker = useMemoized(ImagePicker.new);

    // Lifecycle handling for the scanner is now encapsulated in useMobileScanner.

    Future<void> openManualEntrySheet() async {
      await showAdaptiveOverlay<void>(
        context: context,
        builder: (sheetContext) => _ManualCipSheet(
          onSubmit: (codeCip) =>
              ref.read(scannerProvider.notifier).findMedicament(codeCip),
        ),
      );
    }

    Future<void> openGallerySheet() async {
      final action = await showAdaptiveOverlay<_GallerySheetResult>(
        context: context,
        builder: (sheetContext) => const _GallerySheet(),
      );

      if (action == _GallerySheetResult.pick && context.mounted) {
        await _pickAndScanImage(ref, context, scannerController, picker);
      }
    }

    Future<void> toggleCamera() async {
      // WHY: Prevent camera from starting during initialization
      final initStepAsync = ref.read(initializationStepProvider);
      final initStep = initStepAsync.value;
      if (initStep != null && initStep != InitializationStep.ready) {
        return;
      }

      if (isCameraActive.value) {
        await _stopScanner(
          context,
          scannerController,
          isCameraActive,
          preserveCameraState: false,
        );
      } else {
        await _startScannerWhenReady(
          ref,
          context,
          scannerController,
          isCameraActive,
        );
      }
    }

    Future<void> toggleTorch() async {
      await scannerController.toggleTorch();
      if (!context.mounted) return;
      isTorchOn.value = !isTorchOn.value;
    }

    void onDetect(BarcodeCapture capture) {
      ref.read(scannerProvider.notifier).processBarcodeCapture(capture);
    }

    Widget buildBubbleItem(ScanBubble bubble, int index) {
      final isPrimary = index == 0;

      return Padding(
        padding: EdgeInsets.only(
          bottom: 12,
          // WHY: Primary bubble (index 0) has no top padding, history bubbles are smaller.
          top: isPrimary ? 0 : 8,
        ),
        child: Dismissible(
          key: ValueKey(bubble.cip),
          direction: DismissDirection.horizontal,
          onDismissed: (_) =>
              ref.read(scannerProvider.notifier).removeBubble(bubble.cip),
          child: _buildBubbleContent(context, ref, bubble),
        ),
      );
    }

    final initStepAsync = ref.watch(initializationStepProvider);
    final initStep = initStepAsync.value;
    final isInitializing =
        initStep != null && initStep != InitializationStep.ready;

    return FScaffold(
      childPad: false, // Disable default padding for full-screen camera
      // WHY: Use SafeArea to ensure camera controls don't overlap with navigation bar
      child: SafeArea(
        top: false, // Don't add top padding - let parent Scaffold handle it
        bottom:
            false, // Don't add bottom padding - let parent Scaffold handle it
        child: Stack(
          children: [
            if (isCameraActive.value && !isInitializing)
              MobileScanner(
                controller: scannerController,
                onDetect: onDetect,
                tapToFocus: true,
                errorBuilder: (context, error) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FIcons.videoOff,
                          size: 64,
                          color: context.theme.colors.destructive,
                        ),
                        const Gap(16),
                        Text(
                          Strings.cameraUnavailable,
                          style: context.theme.typography.xl2,
                        ),
                        const Gap(8),
                        Text(
                          Strings.checkPermissionsMessage,
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else if (isInitializing)
              const Center(
                child: StatusView(
                  type: StatusType.loading,
                  icon: FIcons.loader,
                  title: Strings.initializationInProgress,
                  description: Strings.initializationDescription,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FIcons.scan,
                      size: 80,
                      color: context.theme.colors.muted,
                    ),
                    const Gap(24),
                    Text(
                      Strings.readyToScan,
                      style: context.theme.typography.xl2.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ).animate(effects: AppAnimations.fadeIn),
              ),
            if (isCameraActive.value && !isInitializing)
              const ScanWindowOverlay(),
            // WHY: Torch button only visible when camera is active (scanner mode)
            if (isCameraActive.value && !isInitializing)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: ValueListenableBuilder<bool>(
                  valueListenable: isTorchOn,
                  builder: (context, torchState, _) {
                    return Semantics(
                      button: true,
                      label: torchState
                          ? Strings.turnOffTorch
                          : Strings.turnOnTorch,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.theme.colors.background.withValues(
                                alpha: 0.85,
                              ),
                              border: Border.all(
                                color: context.theme.colors.border.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusLg,
                              ),
                            ),
                            child: FButton.icon(
                              style: FButtonStyle.ghost(),
                              onPress: toggleTorch,
                              child: Icon(
                                FIcons.zap,
                                size: AppDimens.iconLg,
                                color: torchState
                                    ? context.theme.colors.primary
                                    : context.theme.colors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // WHY: Adapt margins for scan bubbles based on screen width
                  final isSmallScreen = constraints.maxWidth < 360;
                  final horizontalMargin = isSmallScreen ? 12.0 : 16.0;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final scannerState = ref.watch(scannerProvider);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var i = 0;
                              i < scannerState.bubbles.length;
                              i++
                            )
                              buildBubbleItem(scannerState.bubbles[i], i),
                          ],
                        ).animate(effects: AppAnimations.bubbleEnter);
                      },
                    ),
                  );
                },
              ),
            ),
            Positioned(
              // WHY: Position controls above bottom navigation bar with adaptive spacing
              bottom: 0,
              left: 0,
              right: 0,
              child:
                  AdaptiveBottomPanel(
                        padding: EdgeInsets.only(
                          left: AppDimens.spacingLg * 0.85,
                          right: AppDimens.spacingLg * 0.85,
                          top: AppDimens.spacingMd * 0.85,
                          bottom: AppDimens.spacingLg * 0.85,
                        ),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLg,
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: EdgeInsets.all(
                                  AppDimens.spacingLg * 0.85,
                                ),
                                decoration: BoxDecoration(
                                  color: context.theme.colors.secondary
                                      .withValues(
                                        alpha: isCameraActive.value
                                            ? 0.2
                                            : 0.92,
                                      ),
                                  border: Border.all(
                                    color: context.theme.colors.border
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: Testable(
                                        id: isCameraActive.value
                                            ? TestTags.scanStopBtn
                                            : TestTags.scanStartBtn,
                                        child: Semantics(
                                          button: true,
                                          label: isCameraActive.value
                                              ? Strings.stopScanning
                                              : Strings.startScanning,
                                          enabled: !isInitializing,
                                          child: GestureDetector(
                                            onTap: isInitializing
                                                ? null
                                                : toggleCamera,
                                            child: Container(
                                              width: 88 * 0.85,
                                              height: 88 * 0.85,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    context
                                                        .theme
                                                        .colors
                                                        .primary,
                                                    context.theme.colors.primary
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: context
                                                        .theme
                                                        .colors
                                                        .primary
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 12),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isCameraActive.value
                                                      ? FIcons.cameraOff
                                                      : FIcons.scanLine,
                                                  size: AppDimens.iconXl * 0.85,
                                                  color: context
                                                      .theme
                                                      .colors
                                                      .primaryForeground,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Gap(AppDimens.spacingLg * 0.85),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        // WHY: Use Expanded to allow buttons to take full width.
                                        // Reduce spacing on very small screens.
                                        final isSmallScreen =
                                            constraints.maxWidth < 360;
                                        final buttonSpacing = isSmallScreen
                                            ? AppDimens.spacingXs
                                            : AppDimens.spacingSm;

                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Testable(
                                                id: TestTags.scanGalleryBtn,
                                                child: Semantics(
                                                  button: true,
                                                  label: Strings
                                                      .importBarcodeFromGallery,
                                                  child: FButton(
                                                    onPress: isInitializing
                                                        ? null
                                                        : openGallerySheet,
                                                    prefix: Icon(
                                                      FIcons.image,
                                                      size:
                                                          AppDimens.iconMd *
                                                          0.85,
                                                      color: context
                                                          .theme
                                                          .colors
                                                          .primaryForeground,
                                                    ),
                                                    child: const Text(
                                                      Strings.gallery,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Gap(buttonSpacing),
                                            Expanded(
                                              child: Testable(
                                                id: TestTags.scanManualBtn,
                                                child: Semantics(
                                                  button: true,
                                                  label: Strings
                                                      .manuallyEnterCipCode,
                                                  child: FButton(
                                                    onPress: isInitializing
                                                        ? null
                                                        : openManualEntrySheet,
                                                    prefix: Icon(
                                                      FIcons.keyboard,
                                                      size:
                                                          AppDimens.iconMd *
                                                          0.85,
                                                      color: context
                                                          .theme
                                                          .colors
                                                          .primaryForeground,
                                                    ),
                                                    child: const Text(
                                                      Strings.manualEntry,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
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
            ),
          ],
        ),
      ),
    );
  }
}

// Helper functions
Future<void> _startScannerWhenReady(
  WidgetRef ref,
  BuildContext context,
  MobileScannerController scannerController,
  ValueNotifier<bool> isCameraActive, {
  bool force = false,
}) async {
  if (!context.mounted) return;
  if (!isCameraActive.value) {
    isCameraActive.value = true;
  } else if (!force) {
    return;
  }

  final binding = WidgetsBinding.instance;
  await binding.endOfFrame;

  if (!context.mounted) return;

  try {
    await scannerController.start();
  } on MobileScannerException catch (error, stack) {
    LoggerService.error(
      '[CameraScreen] Failed to start MobileScannerController',
      error,
      stack,
    );
  }
}

Future<void> _stopScanner(
  BuildContext context,
  MobileScannerController scannerController,
  ValueNotifier<bool> isCameraActive, {
  required bool preserveCameraState,
}) async {
  try {
    await scannerController.stop();
  } on MobileScannerException catch (error, stack) {
    LoggerService.error(
      '[CameraScreen] Failed to stop MobileScannerController',
      error,
      stack,
    );
  }

  if (!context.mounted || preserveCameraState) return;

  isCameraActive.value = false;
}

Future<void> _pickAndScanImage(
  WidgetRef ref,
  BuildContext context,
  MobileScannerController scannerController,
  ImagePicker picker,
) async {
  LoggerService.info('[CameraScreen] Starting image pick and scan');

  if (!context.mounted) {
    LoggerService.warning('[CameraScreen] Widget not mounted, aborting');
    return;
  }

  try {
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    LoggerService.info(
      '[CameraScreen] Image picker result: '
      '${file != null ? "File selected: ${file.path}" : "No file selected"}',
    );

    if (file == null) {
      LoggerService.warning('[CameraScreen] No file selected by user');
      return;
    }

    if (!context.mounted) {
      LoggerService.warning(
        '[CameraScreen] Widget not mounted after file selection',
      );
      return;
    }

    // WHY: Reuse the existing scanner controller for image analysis to avoid
    // creating and disposing heavy controller instances.
    try {
      LoggerService.info(
        '[CameraScreen] Analyzing image at path: ${file.path}',
      );

      final BarcodeCapture? capture = await scannerController.analyzeImage(
        file.path,
      );

      LoggerService.info(
        '[CameraScreen] Image analysis complete - Capture: '
        '${capture != null ? "not null" : "null"}, '
        'Barcodes: ${capture?.barcodes.length ?? 0}',
      );

      if (capture != null && capture.barcodes.isNotEmpty) {
        LoggerService.info(
          '[CameraScreen] Processing ${capture.barcodes.length} barcode(s) from image',
        );
        ref.read(scannerProvider.notifier).processBarcodeCapture(capture);
      } else {
        LoggerService.warning('[CameraScreen] No barcodes detected in image');
        if (context.mounted) {
          showFToast(
            context: context,
            title: const Text(Strings.noBarcodeDetected),
            description: const Text(Strings.imageContainsNoValidBarcode),
            icon: const Icon(FIcons.triangleAlert),
          );
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        '[CameraScreen] Error during image analysis',
        e,
        stackTrace,
      );
      if (context.mounted) {
        showFToast(
          context: context,
          title: const Text(Strings.analysisError),
          description: Text('${Strings.unableToAnalyzeImage} ${e.toString()}'),
          icon: const Icon(FIcons.triangleAlert),
        );
      }
    }
  } catch (e, stackTrace) {
    LoggerService.error(
      '[CameraScreen] Error during image pick',
      e,
      stackTrace,
    );
    if (context.mounted) {
      showFToast(
        context: context,
        title: const Text(Strings.error),
        description: Text('${Strings.unableToSelectImage} ${e.toString()}'),
        icon: const Icon(FIcons.triangleAlert),
      );
    }
  }
}

Widget _buildBubbleContent(
  BuildContext context,
  WidgetRef ref,
  ScanBubble bubble,
) {
  final summary = bubble.summary;

  // Build badges based on product type
  final badges = <Widget>[];
  if (summary.groupId != null) {
    if (summary.isPrinceps) {
      badges.add(
        FTooltip(
          hover: true,
          longPress: true,
          tipBuilder: (context, controller) =>
              const Text(Strings.badgePrincepsTooltip),
          child: FBadge(
            style: FBadgeStyle.secondary(),
            child: Text(
              Strings.badgePrinceps,
              style: context.theme.typography.sm,
            ),
          ),
        ),
      );
    } else {
      badges.add(
        FTooltip(
          hover: true,
          longPress: true,
          tipBuilder: (context, controller) =>
              const Text(Strings.badgeGenericTooltip),
          child: FBadge(
            style: FBadgeStyle.primary(),
            child: Text(Strings.generic, style: context.theme.typography.sm),
          ),
        ),
      );
    }
  } else {
    badges.add(
      FTooltip(
        hover: true,
        longPress: true,
        tipBuilder: (context, controller) =>
            const Text(Strings.badgeStandaloneTooltip),
        child: FBadge(
          style: FBadgeStyle.primary(),
          child: Text(
            Strings.uniqueMedicationBadge,
            style: context.theme.typography.sm,
          ),
        ),
      ),
    );
  }

  // Condition badge
  if (summary.conditionsPrescription != null &&
      summary.conditionsPrescription!.isNotEmpty) {
    badges.add(
      FBadge(
        style: FBadgeStyle.outline(),
        child: Text(
          summary.conditionsPrescription!,
          style: context.theme.typography.sm,
        ),
      ),
    );
  }

  // Compact subtitle lines for scanner bubbles:
  // Line 1: Form & Dosage (e.g., "Comprimé • 10 mg")
  // Line 2: Titulaire (Lab) & CIP (e.g., "BIOGARAN • CIP: 34009...")
  final compactSubtitle = <String>[];
  final form = summary.formePharmaceutique;
  final dosage = summary.formattedDosage?.trim();

  if (form != null && form.isNotEmpty && dosage != null && dosage.isNotEmpty) {
    compactSubtitle.add('$form • $dosage');
  } else if (form != null && form.isNotEmpty) {
    compactSubtitle.add(form);
  } else if (dosage != null && dosage.isNotEmpty) {
    compactSubtitle.add(dosage);
  }

  final titulaire = summary.titulaire;
  final cipLine = (titulaire != null && titulaire.isNotEmpty)
      ? '${titulaire.trim()} • ${Strings.cip} ${bubble.cip}'
      : '${Strings.cip} ${bubble.cip}';
  compactSubtitle.add(cipLine);

  return ProductCard(
    key: ValueKey(
      '${bubble.cip}_${summary.isPrinceps
          ? 'princeps'
          : summary.groupId != null
          ? 'generic'
          : 'standalone'}',
    ),
    summary: summary,
    cip: bubble.cip,
    compact: true,
    showDetails: false,
    subtitle: compactSubtitle,
    groupLabel: summary.groupId != null ? summary.princepsBrandName : null,
    badges: badges,
    showActions: true,
    animation: true,
    onClose: () => ref.read(scannerProvider.notifier).removeBubble(bubble.cip),
    onExplore: summary.groupId != null
        ? () => GroupDetailRoute(groupId: summary.groupId!).go(context)
        : null,
    price: bubble.price,
    refundRate: bubble.refundRate,
    boxStatus: bubble.boxStatus,
    availabilityStatus: bubble.availabilityStatus,
    isHospitalOnly: bubble.isHospitalOnly,
    exactMatchLabel: bubble.libellePresentation,
  );
}

enum _GallerySheetResult { pick }

class _GallerySheet extends StatelessWidget {
  const _GallerySheet();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusLg),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.colors.secondary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusLg),
            ),
          ),
          child: PharmaSheetLayout(
            title: Strings.importFromGallery,
            description: Strings.pharmascanAnalyzesOnly,
            onClose: () => Navigator.of(context).maybePop(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      FIcons.shieldCheck,
                      color: context.theme.colors.primary,
                      size: 20,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        Strings.noPhotoStoredMessage,
                        style: context.theme.typography.sm,
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Semantics(
                  button: true,
                  label: Strings.choosePhotoFromGallery,
                  child: FButton(
                    onPress: () =>
                        Navigator.of(context).pop(_GallerySheetResult.pick),
                    child: const Text(Strings.choosePhoto),
                  ),
                ),
                const Gap(8),
                Semantics(
                  button: true,
                  label: Strings.cancelPhotoSelection,
                  child: FButton(
                    style: FButtonStyle.outline(),
                    onPress: () => Navigator.of(context).maybePop(),
                    child: const Text(Strings.cancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualCipSheet extends HookConsumerWidget {
  const _ManualCipSheet({required this.onSubmit});

  final Future<bool> Function(String codeCip) onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = useState(false);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final cipController = useTextEditingController();
    final focusNode = useFocusNode();

    // WHY: Request focus on the form field after the first frame
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });
      return null;
    }, []);

    Future<void> submit() async {
      if (isSubmitting.value) return;

      // WHY: Validate and save form data
      if (formKey.currentState!.validate()) {
        final code = cipController.text;

        isSubmitting.value = true;

        final success = await onSubmit(code);
        if (!context.mounted) return;

        isSubmitting.value = false;

        if (!success) {
          // WHY: Show toast notification when medicament is not found.
          showFToast(
            context: context,
            title: const Text(Strings.medicamentNotFound),
            description: Text('${Strings.noMedicamentFoundForCipCode} $code'),
            icon: const Icon(FIcons.triangleAlert),
          );
        } else if (context.mounted) {
          unawaited(Navigator.of(context).maybePop());
        }
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colors.secondary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusLg),
              ),
            ),
            child: PharmaSheetLayout(
              title: Strings.manualCipEntry,
              description: Strings.manualCipDescription,
              onClose: () => Navigator.of(context).maybePop(),
              child: FocusTraversalGroup(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        textField: true,
                        label: Strings.manualEntryFieldLabel,
                        hint: Strings.manualEntryFieldHint,
                        child: FTextFormField(
                          controller: cipController,
                          focusNode: focusNode,
                          label: const Text(Strings.cipCodeLabel),
                          hint: Strings.cipPlaceholder,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              AppConfig.cipLength,
                            ),
                          ],
                          validator: (String? v) {
                            if (v == null || v.isEmpty) {
                              return Strings.cipMustBe13Digits;
                            }
                            if (v.length != AppConfig.cipLength) {
                              return Strings.cipMustBe13Digits;
                            }
                            return null;
                          },
                          onChange: (String value) {
                            // WHY: Auto-submit when 13 digits are entered
                            if (value.length == AppConfig.cipLength) {
                              unawaited(submit());
                            }
                          },
                          autofocus: true,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        Strings.searchStartsAutomatically,
                        style: context.theme.typography.sm,
                      ),
                      const Gap(16),
                      Semantics(
                        button: true,
                        label: isSubmitting.value
                            ? Strings.searchingInProgress
                            : Strings.searchMedicamentWithCip,
                        enabled: !isSubmitting.value,
                        child: FButton(
                          onPress: isSubmitting.value ? null : submit,
                          prefix: isSubmitting.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: FCircularProgress.loader(),
                                )
                              : null,
                          child: const Text(Strings.search),
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
    );
  }
}
