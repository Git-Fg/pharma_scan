import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Hook that manages a [MobileScannerController] lifecycle and reacts to
/// application lifecycle changes.
///
/// - Always call at the top of a Hook widget's build method.
/// - When [enabled] is true and the app is resumed, the scanner will
///   automatically start.
/// - The scanner is stopped when [enabled] is false or when the app goes
///   into the background to avoid camera usage while inactive.
/// - The hook encapsulates all lifecycle management, making the consumer
///   declarative: simply pass `enabled: isCameraActive.value`.
MobileScannerController useMobileScanner({required bool enabled}) {
  final controller = useMemoized(
    () => MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.dataMatrix],
    ),
    [],
  );

  useEffect(() {
    return () {
      unawaited(controller.dispose());
    };
  }, [controller]);

  final lifecycleState = useAppLifecycleState();

  useEffect(() {
    if (lifecycleState == null) return null;
    final hasPermission = controller.value.hasCameraPermission;

    if (lifecycleState != AppLifecycleState.resumed) {
      if (!hasPermission) {
        return null;
      }

      unawaited(controller.stop());
      return null;
    }

    if (!enabled) {
      unawaited(controller.stop());
      return null;
    }

    Future<void> startCamera() async {
      try {
        if (!controller.value.isRunning) {
          await controller.start();
        }
      } on Exception {
        // Ignore camera start errors (permission denied, already running, etc.)
      }
    }

    unawaited(startCamera());

    return null;
  }, [lifecycleState, controller, enabled]);

  return controller;
}
