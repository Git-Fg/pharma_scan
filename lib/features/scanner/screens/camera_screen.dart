// lib/features/scanner/screens/camera_screen.dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// Importez les modèles et services nécessaires
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:pharma_scan/features/scanner/widgets/info_bubble.dart';
import 'package:pharma_scan/features/scanner/widgets/princeps_info_bubble.dart';

class CameraScreen extends StatefulWidget {
  final ValueChanged<String> onExploreGroup;

  const CameraScreen({required this.onExploreGroup, super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isCameraActive = false;
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.dataMatrix], // On ne scanne QUE les DataMatrix
  );
  final ImagePicker _picker = ImagePicker();
  final List<Widget> _infoBubbles = [];
  final Set<String> _scannedCodes = {}; // Pour éviter les scans en double
  final DatabaseService _dbService = sl<DatabaseService>();

  void _toggleCamera() {
    setState(() {
      _isCameraActive = !_isCameraActive;
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
            ShadToaster.of(context).show(
              ShadToast.destructive(
                title: const Text('Aucun code-barres détecté'),
                description: const Text(
                  'L\'image ne contient pas de code-barres valide.',
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
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text('Erreur d\'analyse'),
              description: Text(
                'Impossible d\'analyser l\'image: ${e.toString()}',
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
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur'),
            description: Text(
              'Impossible de sélectionner l\'image: ${e.toString()}',
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
        scanResult.when(
          generic: (medicament, associatedPrinceps, groupId) {
            developer.log(
              'Generic Medicament found: ${medicament.nom}',
              name: 'CameraScreen',
            );
            _addGenericInfoBubble(medicament, associatedPrinceps, groupId);
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            developer.log(
              'Princeps Medicament found: ${princeps.nom}, molecule: $moleculeName, labs: ${genericLabs.length}',
              name: 'CameraScreen',
            );
            _addPrincepsInfoBubble(
              princeps,
              moleculeName,
              genericLabs,
              groupId,
            );
          },
        );
      } else {
        developer.log(
          'No medicament found in database for CIP: $codeCip',
          name: 'CameraScreen',
        );
        if (mounted) {
          ShadToaster.of(context).show(
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

  void _addGenericInfoBubble(
    Medicament medicament,
    List<Medicament> associatedPrinceps,
    String groupId,
  ) {
    developer.log(
      'Adding generic info bubble for medicament: ${medicament.nom} (CIP: ${medicament.codeCip})',
      name: 'CameraScreen',
    );

    _scannedCodes.add(medicament.codeCip);
    final bubbleKey = UniqueKey();

    setState(() {
      _infoBubbles.add(
        InfoBubble(
          key: bubbleKey,
          medicament: medicament,
          associatedPrinceps: associatedPrinceps,
          onClose: () => _removeBubble(bubbleKey, medicament.codeCip),
          onExplore: () => widget.onExploreGroup(groupId),
        ),
      );
    });
  }

  void _addPrincepsInfoBubble(
    Medicament princeps,
    String moleculeName,
    List<String> genericLabs,
    String groupId,
  ) {
    developer.log(
      'Adding princeps info bubble for medicament: ${princeps.nom} (CIP: ${princeps.codeCip})',
      name: 'CameraScreen',
    );

    _scannedCodes.add(princeps.codeCip);
    final bubbleKey = UniqueKey();

    setState(() {
      _infoBubbles.add(
        PrincepsInfoBubble(
          key: bubbleKey,
          princeps: princeps,
          moleculeName: moleculeName,
          genericLabs: genericLabs,
          onClose: () => _removeBubble(bubbleKey, princeps.codeCip),
          onExplore: () => widget.onExploreGroup(groupId),
        ),
      );
    });
  }

  void _removeBubble(Key key, String codeCip) {
    setState(() {
      _infoBubbles.removeWhere((element) => element.key == key);
      // On retire le code après un délai pour éviter de le rescanner immédiatement
      Future.delayed(const Duration(seconds: 5), () {
        _scannedCodes.remove(codeCip);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          // Caméra ou écran d'accueil
          _isCameraActive
              ? MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                )
              : Center(
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
                  ).animate().fadeIn(duration: 600.ms),
                ),

          // Bulles d'information
          ..._infoBubbles,

          // Boutons flottants pour activer/désactiver la caméra et scanner depuis la galerie
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
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
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.5, end: 0),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
