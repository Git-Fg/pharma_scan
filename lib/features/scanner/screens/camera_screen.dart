// lib/features/scanner/screens/camera_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// Importez les modèles et services nécessaires
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/widgets/info_bubble.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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

  void _toggleCamera() {
    setState(() {
      _isCameraActive = !_isCameraActive;
    });
  }

  void _processBarcodeCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue == null) continue;

      // 1. Parser le code GS1
      final parsedData = Gs1Parser.parse(barcode.rawValue);
      final codeCip = parsedData.gtin;

      if (codeCip == null || _scannedCodes.contains(codeCip)) {
        continue; // Si pas de code CIP ou déjà affiché, on ignore
      }

      // 2. Interroger la base de données
      _findMedicament(codeCip);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    _processBarcodeCapture(capture);
  }

  Future<void> _pickAndScanImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final BarcodeCapture? capture =
        await _scannerController.analyzeImage(file.path);

    if (capture != null && capture.barcodes.isNotEmpty) {
      _processBarcodeCapture(capture);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'L\'image sélectionnée ne contient pas de code Data Matrix valide.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _findMedicament(String codeCip) async {
    final medicament = await DatabaseService.instance.getGenericMedicamentByCip(codeCip);

    if (medicament != null) {
      _addInfoBubble(medicament);
    }
  }

  void _addInfoBubble(Medicament medicament) {
    _scannedCodes.add(medicament.codeCip);
    final bubbleKey = UniqueKey();

    setState(() {
      _infoBubbles.add(
        InfoBubble(
          key: bubbleKey,
          medicament: medicament,
          onClose: () {
            setState(() {
              _infoBubbles.removeWhere((element) => element.key == bubbleKey);
              // On retire le code après un délai pour éviter de le rescanner immédiatement
              Future.delayed(const Duration(seconds: 5), () {
                _scannedCodes.remove(medicament.codeCip);
              });
            });
          },
        ),
      );
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
                      Icon(LucideIcons.scan, size: 80, color: theme.colorScheme.muted),
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
                      _isCameraActive ? LucideIcons.cameraOff : LucideIcons.camera,
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

