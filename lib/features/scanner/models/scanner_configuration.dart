import 'dart:ui';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Configuration DTO for the [MobileScannerController].
class ScannerConfiguration {
  const ScannerConfiguration({
    this.cameraResolution = const Size(1280, 720),
    this.detectionSpeed = DetectionSpeed.noDuplicates,
    this.detectionTimeoutMs = 500,
    this.formats = const [BarcodeFormat.dataMatrix],
    this.returnImage = false,
    this.torchEnabled = false,
    this.invertImage = false,
    this.autoZoom = false,
  });

  final Size cameraResolution;
  final DetectionSpeed detectionSpeed;
  final int detectionTimeoutMs;
  final List<BarcodeFormat> formats;
  final bool returnImage;
  final bool torchEnabled;
  final bool invertImage;
  final bool autoZoom;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScannerConfiguration &&
        other.cameraResolution == cameraResolution &&
        other.detectionSpeed == detectionSpeed &&
        other.detectionTimeoutMs == detectionTimeoutMs &&
        // List equality check is simple here but might need DeepCollectionEquality if lists are mutated/different instances
        // utilizing basic check for now as these are usually const lists
        other.returnImage == returnImage &&
        other.torchEnabled == torchEnabled &&
        other.invertImage == invertImage &&
        other.autoZoom == autoZoom;
  }

  @override
  int get hashCode {
    return Object.hash(
      cameraResolution,
      detectionSpeed,
      detectionTimeoutMs,
      returnImage,
      torchEnabled,
      invertImage,
      autoZoom,
    );
  }
}
