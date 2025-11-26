// lib/features/scanner/screens/camera_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:shadcn_ui/shadcn_ui.dart';
// Importez les modèles et services nécessaires
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  bool _isCameraActive = false;
  bool _isTorchOn = false;
  late MobileScannerController _scannerController;
  final ImagePicker _picker = ImagePicker();
  Future<void> _openManualEntrySheet() async {
    await showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (sheetContext) => _ManualCipSheet(
        onSubmit: (codeCip) =>
            ref.read(scannerProvider.notifier).findMedicament(codeCip),
      ),
    );
  }

  Future<void> _openGallerySheet() async {
    final action = await showShadSheet<_GallerySheetResult>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (sheetContext) => const _GallerySheet(),
    );

    if (action == _GallerySheetResult.pick) {
      await _pickAndScanImage();
    }
  }

  MobileScannerController _createScannerController() {
    return MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.dataMatrix],
    );
  }

  @override
  void initState() {
    super.initState();
    _scannerController = _createScannerController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _toggleCamera() async {
    // WHY: Prevent camera from starting during initialization
    final initStepAsync = ref.read(initializationStepProvider);
    final initStep = initStepAsync.value;
    if (initStep != null && initStep != InitializationStep.ready) {
      return;
    }

    if (_isCameraActive) {
      await _stopScanner(preserveCameraState: false);
    } else {
      await _startScannerWhenReady();
    }
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) return;
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  Future<void> _startScannerWhenReady({bool force = false}) async {
    if (!mounted) return;
    if (!_isCameraActive) {
      setState(() {
        _isCameraActive = true;
      });
    } else if (!force) {
      return;
    }

    final binding = WidgetsBinding.instance;
    await binding.endOfFrame;

    if (!mounted) return;

    try {
      await _scannerController.start();
    } on MobileScannerException catch (error, stack) {
      LoggerService.error(
        '[CameraScreen] Failed to start MobileScannerController',
        error,
        stack,
      );
    }
  }

  Future<void> _stopScanner({required bool preserveCameraState}) async {
    try {
      await _scannerController.stop();
    } on MobileScannerException catch (error, stack) {
      LoggerService.error(
        '[CameraScreen] Failed to stop MobileScannerController',
        error,
        stack,
      );
    }

    if (!mounted || preserveCameraState) return;

    setState(() {
      _isCameraActive = false;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    ref.read(scannerProvider.notifier).processBarcodeCapture(capture);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isCameraActive) {
          unawaited(_startScannerWhenReady(force: true));
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_isCameraActive) {
          unawaited(_stopScanner(preserveCameraState: true));
        }
        break;
    }
  }

  Future<void> _pickAndScanImage() async {
    LoggerService.info('[CameraScreen] Starting image pick and scan');

    if (!mounted) {
      LoggerService.warning('[CameraScreen] Widget not mounted, aborting');
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      LoggerService.info(
        '[CameraScreen] Image picker result: '
        '${file != null ? "File selected: ${file.path}" : "No file selected"}',
      );

      if (file == null) {
        LoggerService.warning('[CameraScreen] No file selected by user');
        return;
      }

      if (!mounted) {
        LoggerService.warning(
          '[CameraScreen] Widget not mounted after file selection',
        );
        return;
      }

      // WHY: Reuse the existing scanner controller for image analysis to avoid
      // creating and disposing heavy controller instances. The controller is already
      // initialized in initState and will be disposed in the widget's dispose method.
      try {
        LoggerService.info(
          '[CameraScreen] Analyzing image at path: ${file.path}',
        );

        final BarcodeCapture? capture = await _scannerController.analyzeImage(
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
          if (mounted) {
            final sonner = ShadSonner.of(context);
            final toastId = DateTime.now().millisecondsSinceEpoch;
            sonner.show(
              ShadToast.destructive(
                id: toastId,
                title: const Text(Strings.noBarcodeDetected),
                description: const Text(Strings.imageContainsNoValidBarcode),
                action: ShadButton.outline(
                  onPressed: () => sonner.hide(toastId),
                  child: const Text(Strings.close),
                ),
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        LoggerService.error(
          '[CameraScreen] Error during image analysis',
          e,
          stackTrace,
        );
        if (mounted) {
          final sonner = ShadSonner.of(context);
          final toastId = DateTime.now().millisecondsSinceEpoch;
          sonner.show(
            ShadToast.destructive(
              id: toastId,
              title: const Text(Strings.analysisError),
              description: Text(
                '${Strings.unableToAnalyzeImage} ${e.toString()}',
              ),
              action: ShadButton.outline(
                onPressed: () => sonner.hide(toastId),
                child: const Text(Strings.close),
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        '[CameraScreen] Error during image pick',
        e,
        stackTrace,
      );
      if (mounted) {
        final sonner = ShadSonner.of(context);
        final toastId = DateTime.now().millisecondsSinceEpoch;
        sonner.show(
          ShadToast.destructive(
            id: toastId,
            title: const Text(Strings.error),
            description: Text('${Strings.unableToSelectImage} ${e.toString()}'),
            action: ShadButton.outline(
              onPressed: () => sonner.hide(toastId),
              child: const Text(Strings.close),
            ),
          ),
        );
      }
    }
  }

  Widget _buildBubbleItem(ScanBubble bubble, int index) {
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
        child: _buildBubbleContent(bubble),
      ),
    );
  }

  Widget _buildBubbleContent(ScanBubble bubble) {
    final theme = ShadTheme.of(context);
    final summary = bubble.summary;

    // Build badges based on product type
    final badges = <Widget>[];
    if (summary.groupId != null) {
      if (summary.isPrinceps) {
        badges.add(
          ShadTooltip(
            builder: (context) => const Text(Strings.badgePrincepsTooltip),
            child: ShadBadge(
              backgroundColor: theme.colorScheme.secondary,
              child: Text(
                Strings.badgePrinceps,
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.secondaryForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      } else {
        badges.add(
          ShadTooltip(
            builder: (context) => const Text(Strings.badgeGenericTooltip),
            child: ShadBadge(
              backgroundColor: theme.colorScheme.primary,
              child: Text(Strings.generic, style: theme.textTheme.small),
            ),
          ),
        );
      }
    } else {
      badges.add(
        ShadTooltip(
          builder: (context) => const Text(Strings.badgeStandaloneTooltip),
          child: ShadBadge(
            backgroundColor: theme.colorScheme.muted,
            child: Text(
              Strings.uniqueMedicationBadge,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    // Condition badge
    if (summary.conditionsPrescription != null &&
        summary.conditionsPrescription!.isNotEmpty) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            summary.conditionsPrescription!,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

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
      groupLabel: summary.groupId != null ? summary.princepsBrandName : null,
      badges: badges,
      showActions: true,
      showDetails: true,
      animation: true,
      onClose: () =>
          ref.read(scannerProvider.notifier).removeBubble(bubble.cip),
      onExplore: summary.groupId != null
          ? () => context.go(AppRoutes.groupDetail(summary.groupId!))
          : null,
      price: bubble.price,
      refundRate: bubble.refundRate,
      boxStatus: bubble.boxStatus,
      availabilityStatus: bubble.availabilityStatus,
      isHospitalOnly: bubble.isHospitalOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final initStepAsync = ref.watch(initializationStepProvider);
    final initStep = initStepAsync.value;
    final isInitializing =
        initStep != null && initStep != InitializationStep.ready;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      // WHY: Use SafeArea to ensure camera controls don't overlap with navigation bar
      body: SafeArea(
        bottom:
            false, // Don't add bottom padding - let parent Scaffold handle it
        child: Stack(
          children: [
            if (_isCameraActive && !isInitializing)
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                tapToFocus: true,
                errorBuilder: (context, error) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.videoOff,
                          size: 64,
                          color: theme.colorScheme.destructive,
                        ),
                        const Gap(16),
                        Text(
                          Strings.cameraUnavailable,
                          style: theme.textTheme.h4,
                        ),
                        const Gap(8),
                        Text(
                          Strings.checkPermissionsMessage,
                          style: theme.textTheme.muted,
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
                  icon: LucideIcons.loader,
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
                      LucideIcons.scan,
                      size: 80,
                      color: theme.colorScheme.muted,
                    ),
                    const Gap(24),
                    Text(
                      Strings.readyToScan,
                      style: theme.textTheme.h4.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ).animate(effects: AppAnimations.fadeIn),
              ),
            if (_isCameraActive && !isInitializing) const ScanWindowOverlay(),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              right: 16,
              child: Consumer(
                builder: (context, ref, child) {
                  final scannerState = ref.watch(scannerProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < scannerState.bubbles.length; i++)
                        _buildBubbleItem(scannerState.bubbles[i], i),
                    ],
                  ).animate(effects: AppAnimations.bubbleEnter);
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
                        padding: const EdgeInsets.only(
                          left: AppDimens.spacingLg,
                          right: AppDimens.spacingLg,
                          top: AppDimens.spacingMd,
                          bottom: AppDimens.spacingLg,
                        ),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLg,
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(
                                  AppDimens.spacingLg,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.card.withValues(
                                    alpha: 0.92,
                                  ),
                                  border: Border.all(
                                    color: theme.colorScheme.border.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                                    Center(
                                      child: Testable(
                                        id: _isCameraActive
                                            ? TestTags.scanStopBtn
                                            : TestTags.scanStartBtn,
                                        child: Semantics(
                                          button: true,
                                          label: _isCameraActive
                                              ? Strings.stopScanning
                                              : Strings.startScanning,
                                          enabled: !isInitializing,
                                          child: GestureDetector(
                                            onTap: isInitializing
                                                ? null
                                                : _toggleCamera,
                                            child: Container(
                                              width: 88,
                                              height: 88,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    theme.colorScheme.primary,
                                                    theme.colorScheme.primary
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 12),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                _isCameraActive
                                                    ? LucideIcons.cameraOff
                                                    : LucideIcons.scanLine,
                                                size: AppDimens.iconXl,
                                                color: theme
                                                    .colorScheme
                                                    .primaryForeground,
                                              ),
                                            ),
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
                                              label: Strings
                                                  .importBarcodeFromGallery,
                                              child: ShadButton.ghost(
                                                onPressed: isInitializing
                                                    ? null
                                                    : _openGallerySheet,
                                                leading: Icon(
                                                  LucideIcons.image,
                                                  size: AppDimens.iconMd,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                                child: Text(
                                                  Strings.gallery,
                                                  style: theme.textTheme.small,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Gap(AppDimens.spacingSm),
                                        Expanded(
                                          child: Testable(
                                            id: TestTags.scanManualBtn,
                                            child: Semantics(
                                              button: true,
                                              label:
                                                  Strings.manuallyEnterCipCode,
                                              child: ShadButton.ghost(
                                                onPressed: isInitializing
                                                    ? null
                                                    : _openManualEntrySheet,
                                                leading: Icon(
                                                  LucideIcons.keyboard,
                                                  size: AppDimens.iconMd,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                                child: Text(
                                                  Strings.manualEntry,
                                                  style: theme.textTheme.small,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Gap(AppDimens.spacingSm),
                                        Semantics(
                                          button: true,
                                          label: _isTorchOn
                                              ? Strings.turnOffTorch
                                              : Strings.turnOnTorch,
                                          child: SizedBox(
                                            width: 52,
                                            height: 52,
                                            child: ShadButton.outline(
                                              onPressed: isInitializing
                                                  ? null
                                                  : _toggleTorch,
                                              leading: Icon(
                                                LucideIcons.zap,
                                                size: AppDimens.iconMd,
                                                color: _isTorchOn
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                          .colorScheme
                                                          .foreground,
                                              ),
                                              child: const SizedBox.shrink(),
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
            ),
          ],
        ),
      ),
    );
  }
}

enum _GallerySheetResult { pick }

class _GallerySheet extends StatelessWidget {
  const _GallerySheet();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadSheet(
      title: const Text(Strings.importFromGallery),
      description: const Text(Strings.pharmascanAnalyzesOnly),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    Strings.noPhotoStoredMessage,
                    style: theme.textTheme.small,
                  ),
                ),
              ],
            ),
            Semantics(
              button: true,
              label: Strings.choosePhotoFromGallery,
              child: ShadButton(
                onPressed: () =>
                    Navigator.of(context).pop(_GallerySheetResult.pick),
                child: const Text(Strings.choosePhoto),
              ),
            ),
            Semantics(
              button: true,
              label: Strings.cancelPhotoSelection,
              child: ShadButton.outline(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(Strings.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualCipSheet extends ConsumerStatefulWidget {
  const _ManualCipSheet({required this.onSubmit});

  final Future<bool> Function(String codeCip) onSubmit;

  @override
  ConsumerState<_ManualCipSheet> createState() => _ManualCipSheetState();
}

class _ManualCipSheetState extends ConsumerState<_ManualCipSheet> {
  final formKey = GlobalKey<ShadFormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // WHY: Request focus on the form field after the first frame
    scheduleMicrotask(() {
      if (formKey.currentState != null) {
        formKey.currentState!.fields['cip']?.focusNode.requestFocus();
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // WHY: Validate and save form data
    if (formKey.currentState!.saveAndValidate()) {
      final code = formKey.currentState!.value['cip'] as String;

      setState(() {
        _isSubmitting = true;
      });

      final success = await widget.onSubmit(code);
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (!success) {
        // WHY: Show toast notification when medicament is not found.
        ShadSonner.of(context).show(
          ShadToast(
            title: const Text(Strings.medicamentNotFound),
            description: Text('${Strings.noMedicamentFoundForCipCode} $code'),
          ),
        );
      } else if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadSheet(
      title: const Text(Strings.manualCipEntry),
      description: const Text(Strings.manualCipDescription),
      constraints: const BoxConstraints(maxWidth: 480),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text(Strings.close),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: ShadForm(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              ShadInputFormField(
                id: 'cip',
                label: const Text(Strings.cipCodeLabel),
                placeholder: const Text(Strings.cipPlaceholder),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AppConfig.cipLength),
                ],
                validator: (v) {
                  if (v.length != AppConfig.cipLength) {
                    return Strings.cipMustBe13Digits;
                  }
                  return null;
                },
                onChanged: (value) {
                  // WHY: Auto-submit when 13 digits are entered
                  if (value.length == AppConfig.cipLength) {
                    unawaited(_submit());
                  }
                },
              ),
              Text(
                Strings.searchStartsAutomatically,
                style: theme.textTheme.small,
              ),
              Semantics(
                button: true,
                label: _isSubmitting
                    ? Strings.searchingInProgress
                    : Strings.searchMedicamentWithCip,
                enabled: !_isSubmitting,
                child: ShadButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(Strings.search),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
