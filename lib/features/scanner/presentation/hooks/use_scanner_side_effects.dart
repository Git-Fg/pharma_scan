import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/presentation/hooks/use_scanner_input.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Hook that handles all scanner side effects (toasts, haptics, dialogs).
/// Extracted from CameraScreen to improve separation of concerns and reusability.
void useScannerSideEffects({
  required BuildContext context,
  required WidgetRef ref,
}) {
  useEffect(() {
    final scannerNotifier = ref.read(scannerProvider.notifier);
    final feedback = ref.read(hapticServiceProvider);

    final subscription = scannerNotifier.sideEffects.listen((effect) async {
      if (!context.mounted) return;

      switch (effect) {
        case ScannerToast(:final message):
          ShadToaster.of(context).show(ShadToast(title: Text(message)));

        case ScannerHaptic(:final type):
          switch (type) {
            case ScannerHapticType.analysisSuccess:
              await feedback.analysisSuccess();
            case ScannerHapticType.restockSuccess:
              await feedback.restockSuccess();
            case ScannerHapticType.warning:
              await feedback.warning();
            case ScannerHapticType.error:
              await feedback.error();
            case ScannerHapticType.duplicate:
              await feedback.duplicate();
            case ScannerHapticType.unknown:
              await feedback.unknown();
          }

        case ScannerDuplicateDetected(:final duplicate):
          final event = duplicate;
          unawaited(
            AppSheet.show<void>(
              context: context,
              title: 'Médicament déjà scanné',
              child: _DuplicateQuantitySheet(
                event: event,
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: (newQty) async {
                  await scannerNotifier.updateQuantityFromDuplicate(
                    event.cip,
                    newQty,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          );
        case ScannerResultFound():
          // Handled by ScannerLogic/ScannerStore for UI data sync
          break;
      }
    });

    return subscription.cancel;
  }, [context, ref]);
}

/// Widget for handling duplicate medication quantity updates.
/// Extracted from CameraScreen to be used with useScannerSideEffects hook.
class _DuplicateQuantitySheet extends HookWidget {
  const _DuplicateQuantitySheet({
    required this.event,
    required this.onCancel,
    required this.onConfirm,
  });

  final DuplicateScanEvent event;
  final VoidCallback onCancel;
  final ValueChanged<int> onConfirm;

  @override
  Widget build(BuildContext context) {
    final scannerInput = useScannerInput(
      onSubmitted: (_) {},
      initialText: event.currentQuantity.toString(),
    );

    useEffect(() {
      final focusNode = scannerInput.focusNode;
      final controller = scannerInput.controller;
      focusNode.requestFocus();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      return null;
    }, [scannerInput.controller, scannerInput.focusNode]);

    void setDelta(int delta) {
      final current = int.tryParse(scannerInput.controller.text) ?? 0;
      final next = (current + delta).clamp(0, 9999);
      final nextStr = next.toString();
      scannerInput.controller
        ..text = nextStr
        ..selection = TextSelection.collapsed(offset: nextStr.length);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 4,
          margin: const .symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            borderRadius: .circular(2),
          ),
        ),
        Padding(
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Médicament déjà scanné',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Gap(8),
              Text(event.productName),
              const Gap(16),
              Text(
                'Quantité actuelle: ${event.currentQuantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Gap(16),
              Text(
                'Nouvelle quantité:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setDelta(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: TextField(
                      controller: scannerInput.controller,
                      focusNode: scannerInput.focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '0',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setDelta(1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const Gap(24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Annuler')),
                  const Gap(8),
                  FilledButton(
                    onPressed: () {
                      final newQuantity =
                          int.tryParse(scannerInput.controller.text) ?? 0;
                      onConfirm(newQuantity);
                    },
                    child: const Text('Mettre à jour'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
