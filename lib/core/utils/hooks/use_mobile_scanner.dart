import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Hook that manages a [MobileScannerController] lifecycle and reacts to
/// application lifecycle changes.
///
/// - Always call at the top of a Hook widget's build method.
/// - When [autoStart] is true, the scanner will automatically start when
///   the app is resumed.
/// - Regardless of [autoStart], the scanner is stopped when the app goes
///   into the background to avoid camera usage while inactive.
MobileScannerController useMobileScanner({required bool autoStart}) {
  final controller = useMemoized(
    () => MobileScannerController(
      autoStart: autoStart,
      formats: const [BarcodeFormat.dataMatrix],
    ),
    [autoStart],
  );

  // Ensure the controller is disposed when the widget is unmounted.
  useEffect(
    () {
      return () {
        unawaited(controller.dispose());
      };
    },
    [controller],
  );

  final lifecycleState = useAppLifecycleState();

  // React to app lifecycle changes to pause/resume camera safely.
  useEffect(
    () {
      if (lifecycleState == null) return null;

      switch (lifecycleState) {
        case AppLifecycleState.resumed:
          if (autoStart) {
            unawaited(controller.start());
          }
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          unawaited(controller.stop());
          break;
      }

      return null;
    },
    [lifecycleState, controller, autoStart],
  );

  return controller;
}


