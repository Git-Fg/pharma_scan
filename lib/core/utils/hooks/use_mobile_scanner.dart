import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  }, [controller],);

  final lifecycleState = useAppLifecycleState();

  useEffect(() {
    if (lifecycleState == null) return null;
    final hasPermission = controller.value.hasCameraPermission;

    if (lifecycleState != AppLifecycleState.resumed || !enabled) {
      if (hasPermission) {
        unawaited(controller.stop());
      }
      return null;
    }

    Future<void> startCamera() async {
      if (!controller.value.isRunning) {
        await controller.start();
      }
    }

    unawaited(startCamera());

    return null;
  }, [lifecycleState, controller, enabled],);

  return controller;
}
