import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

sealed class ScannerUiState {
  const ScannerUiState();
}

class ScannerInitializing extends ScannerUiState {
  const ScannerInitializing({required this.mode});

  final ScannerMode mode;
}

class ScannerActive extends ScannerUiState {
  const ScannerActive({
    required this.mode,
    required this.torchState,
    required this.isCameraRunning,
  });

  final ScannerMode mode;
  final TorchState torchState;
  final bool isCameraRunning;
}
