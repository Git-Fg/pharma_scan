import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Text controller with debounced value exposure.
({TextEditingController controller, ValueNotifier<String> debouncedText})
useDebouncedController({
  Duration duration = const Duration(milliseconds: 300),
}) {
  final controller = useTextEditingController();
  final debouncedText = useState(controller.text);

  useEffect(() {
    Timer? timer;

    void listener() {
      timer?.cancel();
      timer = Timer(duration, () {
        debouncedText.value = controller.text;
      });
    }

    controller.addListener(listener);
    return () {
      timer?.cancel();
      controller.removeListener(listener);
    };
  }, [controller, duration, debouncedText]);

  return (controller: controller, debouncedText: debouncedText);
}
