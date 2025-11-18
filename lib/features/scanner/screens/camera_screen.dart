// lib/features/scanner/screens/camera_screen.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:shadcn_ui/shadcn_ui.dart';
// Importez les modèles et services nécessaires
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:pharma_scan/features/scanner/widgets/info_bubble.dart';
import 'package:pharma_scan/features/scanner/widgets/princeps_info_bubble.dart';
import 'package:pharma_scan/features/scanner/widgets/scan_window_overlay.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';

class CameraScreen extends StatefulWidget {
  final bool isVisible;

  const CameraScreen({super.key, this.isVisible = true});

  @override
  State<CameraScreen> createState() => _CameraScreenState();

  // WHY: Public method to access state for tab visibility changes
  static void onVisibilityChanged(
    GlobalKey<State<CameraScreen>> key,
    bool isVisible,
  ) {
    final state = key.currentState;
    if (state is _CameraScreenState) {
      state.onVisibilityChanged(isVisible);
    }
  }
}

class _BubbleInfo {
  _BubbleInfo({
    required this.key,
    required this.scanResult,
    required this.dismissTimer,
  });

  final UniqueKey key;
  final ScanResult scanResult;
  final Timer dismissTimer;
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  bool _isCameraActive = false;
  bool _isTorchOn = false;
  bool _isResolutionLocked = false;
  late MobileScannerController _scannerController;
  final ImagePicker _picker = ImagePicker();
  final List<_BubbleInfo> _activeBubbles = [];
  final Set<String> _scannedCodes = {}; // Pour éviter les scans en double
  static const int _maxBubbles = 3;
  static const Duration _bubbleLifetime = Duration(seconds: 15);
  final DatabaseService _dbService = sl<DatabaseService>();
  final ShadPopoverController _manualEntryPopoverController =
      ShadPopoverController();

  MobileScannerController _createScannerController(bool lockResolution) {
    return MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.dataMatrix],
      cameraResolution: lockResolution ? const Size(1280, 720) : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _scannerController = _createScannerController(_isResolutionLocked);
    WidgetsBinding.instance.addObserver(this);
  }

  // WHY: Public method to notify camera screen when tab visibility changes
  // Called from MainScreen when tab is switched
  void onVisibilityChanged(bool isVisible) {
    if (!isVisible && _isCameraActive) {
      unawaited(_stopScanner(preserveCameraState: false));
    }
  }

  @override
  void didUpdateWidget(CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // WHY: Stop camera when tab becomes invisible to save resources and allow tab navigation
    if (oldWidget.isVisible && !widget.isVisible && _isCameraActive) {
      unawaited(_stopScanner(preserveCameraState: false));
    }
    // WHY: Optionally start camera when tab becomes visible again
    // But don't auto-start - let user click the button
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

  Future<void> _toggleResolutionLock() async {
    final newResolutionState = !_isResolutionLocked;
    final wasActive = _isCameraActive;

    if (wasActive) {
      await _stopScanner(preserveCameraState: true);
    }

    await _scannerController.dispose();

    if (!mounted) return;

    setState(() {
      _isResolutionLocked = newResolutionState;
      _scannerController = _createScannerController(newResolutionState);
    });

    if (wasActive) {
      await _startScannerWhenReady(force: true);
    }
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
      developer.log(
        'Failed to start MobileScannerController',
        name: 'CameraScreen',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _stopScanner({required bool preserveCameraState}) async {
    try {
      await _scannerController.stop();
    } on MobileScannerException catch (error, stack) {
      developer.log(
        'Failed to stop MobileScannerController',
        name: 'CameraScreen',
        error: error,
        stackTrace: stack,
      );
    }

    if (!mounted || preserveCameraState) return;

    setState(() {
      _isCameraActive = false;
    });
  }

  void _processBarcodeCapture(BarcodeCapture capture) {
    developer.log(
      'Processing barcode capture: ${capture.barcodes.length} barcode(s) found',
      name: 'CameraScreen',
    );

    for (final barcode in capture.barcodes) {
      final rawValuePreview = barcode.rawValue != null
          ? (barcode.rawValue!.length > 50
                ? '${barcode.rawValue!.substring(0, 50)}...'
                : barcode.rawValue!)
          : 'null';
      developer.log(
        'Barcode found - Format: ${barcode.format}, RawValue: $rawValuePreview',
        name: 'CameraScreen',
      );

      if (barcode.rawValue == null) {
        developer.log(
          'Barcode has null rawValue, skipping',
          name: 'CameraScreen',
        );
        continue;
      }

      // 1. Parser le code GS1
      final parsedData = Gs1Parser.parse(barcode.rawValue);
      final codeCip = parsedData.gtin;

      developer.log('Parsed GS1 data - GTIN: $codeCip', name: 'CameraScreen');

      if (codeCip == null) {
        developer.log('No GTIN extracted from barcode', name: 'CameraScreen');
        continue;
      }

      if (_scannedCodes.contains(codeCip)) {
        developer.log(
          'Code CIP already scanned: $codeCip',
          name: 'CameraScreen',
        );
        continue;
      }

      // 2. Interroger la base de données
      developer.log(
        'Searching for medicament with CIP: $codeCip',
        name: 'CameraScreen',
      );
      _findMedicament(codeCip);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    _processBarcodeCapture(capture);
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
    developer.log('Starting image pick and scan', name: 'CameraScreen');

    if (!mounted) {
      developer.log('Widget not mounted, aborting', name: 'CameraScreen');
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      developer.log(
        'Image picker result: ${file != null ? "File selected: ${file.path}" : "No file selected"}',
        name: 'CameraScreen',
      );

      if (file == null) {
        developer.log('No file selected by user', name: 'CameraScreen');
        return;
      }

      if (!mounted) {
        developer.log(
          'Widget not mounted after file selection',
          name: 'CameraScreen',
        );
        return;
      }

      // WHY: Create a separate controller for static image analysis to avoid
      // conflicts with the live scanning controller. For static images, we allow
      // all formats since the user might upload different barcode types.
      developer.log('Creating image scanner controller', name: 'CameraScreen');
      final MobileScannerController imageScannerController =
          MobileScannerController();

      try {
        developer.log(
          'Analyzing image at path: ${file.path}',
          name: 'CameraScreen',
        );

        final BarcodeCapture? capture = await imageScannerController
            .analyzeImage(file.path);

        developer.log(
          'Image analysis complete - Capture: ${capture != null ? "not null" : "null"}, Barcodes: ${capture?.barcodes.length ?? 0}',
          name: 'CameraScreen',
        );

        if (capture != null && capture.barcodes.isNotEmpty) {
          developer.log(
            'Processing ${capture.barcodes.length} barcode(s) from image',
            name: 'CameraScreen',
          );
          _processBarcodeCapture(capture);
        } else {
          developer.log('No barcodes detected in image', name: 'CameraScreen');
          if (mounted) {
            final sonner = ShadSonner.of(context);
            final toastId = DateTime.now().millisecondsSinceEpoch;
            sonner.show(
              ShadToast.destructive(
                id: toastId,
                title: const Text('Aucun code-barres détecté'),
                description: const Text(
                  'L\'image ne contient pas de code-barres valide.',
                ),
                action: ShadButton.outline(
                  onPressed: () => sonner.hide(toastId),
                  child: const Text('Fermer'),
                ),
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        developer.log(
          'Error during image analysis: $e',
          name: 'CameraScreen',
          error: e,
          stackTrace: stackTrace,
        );
        if (mounted) {
          final sonner = ShadSonner.of(context);
          final toastId = DateTime.now().millisecondsSinceEpoch;
          sonner.show(
            ShadToast.destructive(
              id: toastId,
              title: const Text('Erreur d\'analyse'),
              description: Text(
                'Impossible d\'analyser l\'image: ${e.toString()}',
              ),
              action: ShadButton.outline(
                onPressed: () => sonner.hide(toastId),
                child: const Text('Fermer'),
              ),
            ),
          );
        }
      } finally {
        developer.log(
          'Disposing image scanner controller',
          name: 'CameraScreen',
        );
        await imageScannerController.dispose();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error during image pick: $e',
        name: 'CameraScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        final sonner = ShadSonner.of(context);
        final toastId = DateTime.now().millisecondsSinceEpoch;
        sonner.show(
          ShadToast.destructive(
            id: toastId,
            title: const Text('Erreur'),
            description: Text(
              'Impossible de sélectionner l\'image: ${e.toString()}',
            ),
            action: ShadButton.outline(
              onPressed: () => sonner.hide(toastId),
              child: const Text('Fermer'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _findMedicament(String codeCip) async {
    developer.log('Querying database for CIP: $codeCip', name: 'CameraScreen');

    try {
      final scanResult = await _dbService.getScanResultByCip(codeCip);

      if (scanResult != null) {
        developer.log(
          'Scan result received, updating bubble queue',
          name: 'CameraScreen',
        );
        _addBubble(scanResult);
        // WHY: Close manual entry popover after successful scan
        if (_manualEntryPopoverController.isOpen) {
          _manualEntryPopoverController.toggle();
        }
      } else {
        developer.log(
          'No medicament found in database for CIP: $codeCip',
          name: 'CameraScreen',
        );
        if (mounted) {
          ShadSonner.of(context).show(
            ShadToast(
              title: const Text('Médicament non trouvé'),
              description: Text(
                'Aucun médicament trouvé pour le code CIP: $codeCip',
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error querying database: $e',
        name: 'CameraScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _onManualCipChanged(String value) {
    // WHY: Process CIP when all 13 digits are entered
    if (value.length == 13) {
      developer.log('Manual CIP entry complete: $value', name: 'CameraScreen');
      _findMedicament(value);
    }
  }

  void _addBubble(ScanResult scanResult) {
    final codeCip = _codeFromResult(scanResult);
    if (_scannedCodes.contains(codeCip)) return;

    _scannedCodes.add(codeCip);

    // WHY: Remove oldest bubble if we exceed max capacity.
    // New bubbles are inserted at index 0, so oldest is at the end.
    if (_activeBubbles.length >= _maxBubbles) {
      final oldest = _activeBubbles.removeLast();
      oldest.dismissTimer.cancel();
      final oldestCode = _codeFromResult(oldest.scanResult);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _scannedCodes.remove(oldestCode);
        }
      });
    }

    final bubbleKey = UniqueKey();
    final timer = Timer(
      _bubbleLifetime,
      () => _removeBubble(bubbleKey, codeCip),
    );

    final bubbleInfo = _BubbleInfo(
      key: bubbleKey,
      scanResult: scanResult,
      dismissTimer: timer,
    );

    // WHY: Insert at index 0 so newest bubble appears at the top.
    _activeBubbles.insert(0, bubbleInfo);
    setState(() {});
  }

  void _removeBubble(Key key, String codeCip) {
    final index = _activeBubbles.indexWhere((bubble) => bubble.key == key);
    if (index == -1) return;

    final bubble = _activeBubbles.removeAt(index);
    bubble.dismissTimer.cancel();

    setState(() {});

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _scannedCodes.remove(codeCip);
      }
    });
  }

  Widget _buildBubbleItem(_BubbleInfo bubbleInfo, int index) {
    final codeCip = _codeFromResult(bubbleInfo.scanResult);
    final isPrimary = index == 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        // WHY: Primary bubble (index 0) has no top padding, history bubbles are smaller.
        top: isPrimary ? 0 : 8,
      ),
      child: Dismissible(
        key: bubbleInfo.key,
        direction: DismissDirection.horizontal,
        onDismissed: (_) => _removeBubble(bubbleInfo.key, codeCip),
        child: _buildBubbleContent(bubbleInfo),
      ),
    );
  }

  Widget _buildBubbleContent(_BubbleInfo bubbleInfo) {
    return bubbleInfo.scanResult.when(
      generic: (medicament, associatedPrinceps, groupId) {
        return InfoBubble(
          key: ValueKey('${bubbleInfo.key}_generic'),
          medicament: medicament,
          associatedPrinceps: associatedPrinceps,
          onClose: () => _removeBubble(bubbleInfo.key, medicament.codeCip),
          onExplore: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GroupExplorerView(
                  groupId: groupId,
                  onExit: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        );
      },
      princeps: (princeps, moleculeName, genericLabs, groupId) {
        return PrincepsInfoBubble(
          key: ValueKey('${bubbleInfo.key}_princeps'),
          princeps: princeps,
          moleculeName: moleculeName,
          genericLabs: genericLabs,
          onClose: () => _removeBubble(bubbleInfo.key, princeps.codeCip),
          onExplore: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GroupExplorerView(
                  groupId: groupId,
                  onExit: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _codeFromResult(ScanResult scanResult) {
    return scanResult.map(
      generic: (value) => value.medicament.codeCip,
      princeps: (value) => value.princeps.codeCip,
    );
  }

  Widget _buildManualCipEntry(BuildContext context) {
    final theme = ShadTheme.of(context);
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saisie manuelle du CIP', style: theme.textTheme.h4),
                ShadButton.ghost(
                  onPressed: () => _manualEntryPopoverController.toggle(),
                  child: const Icon(LucideIcons.x, size: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entrez le code CIP à 13 chiffres',
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 24),
                ShadInputOTP(
                  onChanged: _onManualCipChanged,
                  maxLength: 13,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  children: const [
                    ShadInputOTPGroup(
                      children: [
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                      ],
                    ),
                    SizedBox(width: 8),
                    ShadInputOTPGroup(
                      children: [
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                      ],
                    ),
                    SizedBox(width: 8),
                    ShadInputOTPGroup(
                      children: [
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                        ShadInputOTPSlot(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Le médicament sera recherché automatiquement lorsque les 13 chiffres sont saisis.',
                  style: theme.textTheme.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final bubble in _activeBubbles) {
      bubble.dismissTimer.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    _manualEntryPopoverController.dispose();
    unawaited(_scannerController.dispose());
    super.dispose();
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
                        const SizedBox(height: 16),
                        Text('Caméra indisponible', style: theme.textTheme.h4),
                        const SizedBox(height: 8),
                        Text(
                          'Veuillez vérifier les autorisations.',
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
                    const SizedBox(height: 24),
                    Text(
                      'Prêt à scanner',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _activeBubbles.length; i++)
                    _buildBubbleItem(_activeBubbles[i], i),
                ],
              ).animate(effects: AppAnimations.bubbleEnter),
            ),
            Positioned(
              // WHY: Position buttons above bottom navigation bar (80px height + padding)
              bottom: 100,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCameraActive)
                    ShadButton.ghost(
                      onPressed: _toggleResolutionLock,
                      leading: Icon(
                        LucideIcons.settings,
                        size: 20,
                        color: _isResolutionLocked
                            ? theme.colorScheme.primary
                            : theme.colorScheme.mutedForeground,
                      ),
                      child: const SizedBox.shrink(),
                    ),
                  Wrap(
                    spacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ShadButton(
                        onPressed: _toggleCamera,
                        leading: Icon(
                          _isCameraActive
                              ? LucideIcons.cameraOff
                              : LucideIcons.camera,
                          size: 20,
                        ),
                        child: Text(_isCameraActive ? 'Arrêter' : 'Scanner'),
                      ),
                      ShadButton.outline(
                        onPressed: _pickAndScanImage,
                        leading: const Icon(LucideIcons.image, size: 20),
                        child: const Text('Galerie'),
                      ),
                      ShadPopover(
                        controller: _manualEntryPopoverController,
                        popover: (context) => _buildManualCipEntry(context),
                        child: ShadButton.outline(
                          leading: const Icon(LucideIcons.keyboard, size: 20),
                          child: const Text('Saisie'),
                        ),
                      ),
                      if (_isCameraActive)
                        ShadButton.outline(
                          onPressed: _toggleTorch,
                          leading: Icon(
                            LucideIcons.zap,
                            size: 20,
                            color: _isTorchOn
                                ? theme.colorScheme.primary
                                : theme.colorScheme.foreground,
                          ),
                          child: const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ],
              ).animate(effects: AppAnimations.controlPanelEnter),
            ),
          ],
        ),
      ),
    );
  }
}
