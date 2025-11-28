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
      autoStart: false, // Lifecycle managed by hook
      formats: const [BarcodeFormat.dataMatrix],
    ),
    [],
  );

  // Ensure the controller is disposed when the widget is unmounted.
  useEffect(() {
    return () {
      unawaited(controller.dispose());
    };
  }, [controller]);

  final lifecycleState = useAppLifecycleState();

  // React to app lifecycle and enabled state changes.
  useEffect(() {
    if (lifecycleState == null) return null;

    // Start camera when enabled AND app is resumed
    if (enabled && lifecycleState == AppLifecycleState.resumed) {
      unawaited(controller.start());
    } else {
      // Stop camera when disabled OR app is not resumed
      unawaited(controller.stop());
    }

    return null;
  }, [lifecycleState, controller, enabled]);

  return controller;
}
