import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Encapsulates scanner text input logic: keeps focus active, clears after submit.
({
  TextEditingController controller,
  FocusNode focusNode,
  void Function(String value) submit,
})
useScannerInput({
  required ValueChanged<String> onSubmitted,
  String initialText = '',
}) {
  final controller = useTextEditingController(text: initialText);
  final focusNode = useFocusNode();
  final onSubmittedRef = useRef(onSubmitted);

  useEffect(() {
    onSubmittedRef.value = onSubmitted;
    return null;
  }, [onSubmitted],);

  useEffect(() {
    void keepFocused() {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => keepFocused());
    focusNode.addListener(keepFocused);
    return () => focusNode.removeListener(keepFocused);
  }, [focusNode],);

  void handleSubmit(String value) {
    final trimmed = value.trim();
    onSubmittedRef.value(trimmed);
    controller.clear();
    focusNode.requestFocus();
  }

  return (controller: controller, focusNode: focusNode, submit: handleSubmit);
}
