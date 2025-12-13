import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:ui';

part 'scanner_controller_provider.g.dart';

@riverpod
MobileScannerController scannerController(Ref ref) {
  // 1. Configuration Optimisée (720p + No Duplicates)
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 500,
    returnImage: false, // Critical for RAM
    cameraResolution: const Size(1280, 720),
    autoStart:
        false, // Manual lifecycle control via AppLifecycleListener elsewhere if needed
  );

  // 2. Resource Safety Valve
  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
}
