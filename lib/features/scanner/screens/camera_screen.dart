// lib/features/scanner/screens/camera_screen.dart
import 'dart:async';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:pharma_scan/features/scanner/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/widgets/info_bubble.dart';
import 'package:pharma_scan/features/scanner/widgets/princeps_info_bubble.dart';
import 'package:pharma_scan/features/scanner/widgets/standalone_info_bubble.dart';
import 'package:pharma_scan/features/scanner/widgets/scan_window_overlay.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_primary_button.dart';

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

      // WHY: Create a separate controller for static image analysis to avoid
      // conflicts with the live scanning controller. For static images, we allow
      // all formats since the user might upload different barcode types.
      LoggerService.debug('[CameraScreen] Creating image scanner controller');
      final MobileScannerController imageScannerController =
          MobileScannerController();

      try {
        LoggerService.info(
          '[CameraScreen] Analyzing image at path: ${file.path}',
        );

        final BarcodeCapture? capture = await imageScannerController
            .analyzeImage(file.path);

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
      } finally {
        LoggerService.debug(
          '[CameraScreen] Disposing image scanner controller',
        );
        await imageScannerController.dispose();
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

  String _codeFromResult(ScanResult scanResult) {
    return scanResult.map(
      generic: (value) => value.medicament.codeCip,
      princeps: (value) => value.princeps.codeCip,
      standalone: (value) => value.medicament.codeCip,
    );
  }

  Widget _buildBubbleItem(ScanResult scanResult, int index) {
    final codeCip = _codeFromResult(scanResult);
    final isPrimary = index == 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        // WHY: Primary bubble (index 0) has no top padding, history bubbles are smaller.
        top: isPrimary ? 0 : 8,
      ),
      child: Dismissible(
        key: ValueKey(codeCip),
        direction: DismissDirection.horizontal,
        onDismissed: (_) =>
            ref.read(scannerProvider.notifier).removeBubble(codeCip),
        child: _buildBubbleContent(scanResult, codeCip),
      ),
    );
  }

  Widget _buildBubbleContent(ScanResult scanResult, String codeCip) {
    return scanResult.when(
      generic: (medicament, associatedPrinceps, groupId) {
        return InfoBubble(
          key: ValueKey('${codeCip}_generic'),
          medicament: medicament,
          associatedPrinceps: associatedPrinceps,
          onClose: () => ref
              .read(scannerProvider.notifier)
              .removeBubble(medicament.codeCip),
          onExplore: () {
            context.go(AppRoutes.groupDetail(groupId));
          },
        );
      },
      princeps: (princeps, moleculeName, genericLabs, groupId) {
        return PrincepsInfoBubble(
          key: ValueKey('${codeCip}_princeps'),
          princeps: princeps,
          moleculeName: moleculeName,
          genericLabs: genericLabs,
          onClose: () =>
              ref.read(scannerProvider.notifier).removeBubble(princeps.codeCip),
          onExplore: () {
            context.go(AppRoutes.groupDetail(groupId));
          },
        );
      },
      standalone: (medicament) {
        return StandaloneInfoBubble(
          key: ValueKey('${codeCip}_standalone'),
          medicament: medicament,
          onClose: () => ref
              .read(scannerProvider.notifier)
              .removeBubble(medicament.codeCip),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      // WHY: Use SafeArea to ensure camera controls don't overlap with navigation bar
      body: SafeArea(
        bottom:
            false, // Don't add bottom padding - let parent Scaffold handle it
        child: Stack(
          children: [
            if (_isCameraActive)
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
            if (_isCameraActive) const ScanWindowOverlay(),
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
                        children: [
                          PharmaPrimaryButton(
                            label: _isCameraActive
                                ? Strings.stopScanning
                                : Strings.startScanning,
                            semanticLabel: _isCameraActive
                                ? Strings.stopScanning
                                : Strings.startScanning,
                            leadingIcon: _isCameraActive
                                ? LucideIcons.cameraOff
                                : LucideIcons.scanLine,
                            onPressed: _toggleCamera,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: Semantics(
                                    button: true,
                                    label: Strings.importBarcodeFromGallery,
                                    child: ShadButton.outline(
                                      onPressed: _openGallerySheet,
                                      leading: const Icon(
                                        LucideIcons.image,
                                        size: 18,
                                      ),
                                      child: const Text(Strings.gallery),
                                    ),
                                  ),
                                ),
                              ),
                              const Gap(14),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: Semantics(
                                    button: true,
                                    label: Strings.manuallyEnterCipCode,
                                    child: ShadButton.outline(
                                      onPressed: _openManualEntrySheet,
                                      leading: const Icon(
                                        LucideIcons.keyboard,
                                        size: 18,
                                      ),
                                      child: const Text(Strings.manualEntry),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isCameraActive)
                            Semantics(
                              button: true,
                              label: _isTorchOn
                                  ? Strings.turnOffTorch
                                  : Strings.turnOnTorch,
                              child: ShadButton.ghost(
                                onPressed: _toggleTorch,
                                leading: Icon(
                                  LucideIcons.zap,
                                  size: 22,
                                  color: _isTorchOn
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.foreground,
                                ),
                                child: const SizedBox.shrink(),
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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_focusNode.requestFocus);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final code = _controller.text;
    if (code.length != 13) {
      setState(() {
        _error = Strings.cipMustBe13Digits;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final success = await widget.onSubmit(code);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (!success) {
        _error = Strings.noMedicamentFoundForCip;
        // WHY: Show toast notification when medicament is not found.
        ShadSonner.of(context).show(
          ShadToast(
            title: const Text(Strings.medicamentNotFound),
            description: Text('${Strings.noMedicamentFoundForCipCode} $code'),
          ),
        );
      }
    });

    if (success && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _onChanged(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly != value) {
      _controller.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
    }

    if (digitsOnly.length == 13) {
      unawaited(_submit());
    } else {
      setState(() {
        _error = null;
      });
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Semantics(
              textField: true,
              label: Strings.cipCodeLabel,
              hint: Strings.manualCipDescription,
              value: _controller.text,
              child: ShadInput(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                placeholder: const Text(Strings.cipPlaceholder),
                onChanged: _onChanged,
              ),
            ),
            Text(
              Strings.searchStartsAutomatically,
              style: theme.textTheme.small,
            ),
            if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.destructive,
                ),
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
    );
  }
}
