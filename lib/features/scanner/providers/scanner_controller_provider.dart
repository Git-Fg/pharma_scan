import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/scanner_configuration.dart';

part 'scanner_controller_provider.g.dart';

@riverpod
MobileScannerController scannerController(
    Ref ref, ScannerConfiguration config) {
  final controller = MobileScannerController(
    cameraResolution: config.cameraResolution,
    detectionSpeed: config.detectionSpeed,
    detectionTimeoutMs: config.detectionTimeoutMs,
    formats: config.formats,
    returnImage: config.returnImage,
    torchEnabled: config.torchEnabled,
    invertImage: config.invertImage,
    autoStart:
        false, // Managed by the UI (e.g. MobileScanner widget or manual start)
  );

  ref.onDispose(() {
    controller.stop();
    controller.dispose();
  });

  return controller;
}
