import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/core/presentation/hooks/use_scanner_input.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/hooks/use_async_feedback.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_controller_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/history/presentation/widgets/history_sheet.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/presentation/models/scanner_ui_state.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/presentation/utils/scanner_utils.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scan_window_overlay.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_bubbles.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_controls.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage(name: 'ScannerRoute')
class CameraScreen extends HookConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCameraActive = useState(false);
    final scannerState = ref.watch(scannerProvider);
    final scannerMode = scannerState.value?.mode ?? ScannerMode.analysis;

    TabsRouter? tabsRouter;
    var isTabActive = true;
    try {
      tabsRouter = AutoTabsRouter.of(context);
      isTabActive = tabsRouter.activeIndex == 0;
    } on Object {
      // Not available in test contexts or when not inside AutoTabsRouter
      tabsRouter = null;
    }

    void onTabChanged() {
      // Trigger rebuild when tab changes
      if (context.mounted) {
        // The widget will rebuild automatically due to useListenable in the original code
      }
    }

    useEffect(
      () {
        if (tabsRouter != null) {
          // Force rebuild when tab changes
          tabsRouter.addListener(onTabChanged);
          return () => tabsRouter?.removeListener(onTabChanged);
        }
        return null;
      },
      [tabsRouter],
    );

    useEffect(
      () {
        final scannerNotifier = ref.read(scannerProvider.notifier);
        final feedback = ref.read(hapticServiceProvider);
        final subscription = scannerNotifier.sideEffects.listen((effect) async {
          if (!context.mounted) return;
          switch (effect) {
            case ScannerToast(:final message):
              ShadToaster.of(context).show(
                ShadToast(
                  title: Text(message),
                ),
              );
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
                showShadSheet<void>(
                  context: context,
                  side: ShadSheetSide.bottom,
                  builder: (dialogContext) => _DuplicateQuantitySheet(
                    event: event,
                    onCancel: () => Navigator.of(dialogContext).pop(),
                    onConfirm: (newQty) async {
                      await scannerNotifier.updateQuantityFromDuplicate(
                        event.cip,
                        newQty,
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ),
              );
          }
        });

        return subscription.cancel;
      },
      [context, ref],
    );

    useAsyncFeedback<ScannerState>(ref, scannerProvider);

    final scannerController = ref.watch(scannerControllerProvider);
    // Camera permission and lifecycle logic is now handled by the provider and app lifecycle, not here.
    final picker = useMemoized(ImagePicker.new);

    Future<void> openManualEntrySheet() async {
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      await showShadSheet<void>(
        context: rootContext,
        side: ShadSheetSide.bottom,
        builder: (sheetContext) => _ManualCipSheet(
          onSubmit: (codeCip) =>
              ref.read(scannerProvider.notifier).findMedicament(codeCip),
        ),
      );
    }

    Future<void> openGallerySheet() async {
      final action = await showShadSheet<_GallerySheetResult>(
        context: context,
        side: ShadSheetSide.bottom,
        builder: (sheetContext) => const _GallerySheet(),
      );

      if (action == _GallerySheetResult.pick && context.mounted) {
        await ScannerUtils.pickAndScanImage(
          ref,
          context,
          scannerController,
          picker,
        );
      }
    }

    Future<void> toggleCamera() async {
      final initStepAsync = ref.read(initializationStepProvider);
      final initStep = initStepAsync.value;
      if (initStep != null && initStep != InitializationStep.ready) {
        return;
      }

      isCameraActive.value = !isCameraActive.value;
    }

    Future<void> toggleTorch() async {
      await scannerController.toggleTorch();
    }

    Future<void> toggleMode() async {
      final nextMode = scannerMode == ScannerMode.analysis
          ? ScannerMode.restock
          : ScannerMode.analysis;
      ref.read(scannerProvider.notifier).setMode(nextMode);
      await ref.read(hapticServiceProvider).selection();
    }

    void onDetect(BarcodeCapture capture) {
      unawaited(
        ref.read(scannerProvider.notifier).processBarcodeCapture(capture),
      );
    }

    final initStepAsync = ref.watch(initializationStepProvider);
    final initStep = initStepAsync.value;
    final isInitializing =
        initStep != null && initStep != InitializationStep.ready;
    final scannerUiState = isInitializing
        ? ScannerInitializing(mode: scannerMode)
        : ScannerActive(
            mode: scannerMode,
            torchState: TorchState.off,
            isCameraRunning: isCameraActive.value,
          );

    useAppHeader(
      title: const SizedBox.shrink(),
      isVisible: false,
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          if (isCameraActive.value && !isInitializing)
            MobileScanner(
              controller: scannerController,
              onDetect: onDetect,
              tapToFocus: true,
              errorBuilder: (context, error) => const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: Center(
                  child: StatusView(
                    type: StatusType.error,
                    icon: LucideIcons.videoOff,
                    title: Strings.cameraUnavailable,
                    description: Strings.checkPermissionsMessage,
                  ),
                ),
              ),
            )
          else if (isInitializing)
            const Center(
              child: StatusView(
                type: StatusType.loading,
                icon: LucideIcons.loader,
                title: Strings.initializationInProgress,
                description: Strings.initializationDescription,
              ),
            )
          else
            Align(
              alignment: const Alignment(0, -0.3),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.scan,
                      size: 80,
                      color: context.shadColors.muted,
                    ),
                    const Gap(20),
                    Text(
                      Strings.readyToScan,
                      style: context.shadTextTheme.h4.copyWith(
                        color: context.shadColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            if (isCameraActive.value && !isInitializing)
              ScanWindowOverlay(mode: scannerMode),
            const ScannerBubbles(),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 16,
              child: ClipRRect(
                borderRadius: context.shadTheme.radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ShadTheme.of(
                      context,
                    ).colorScheme.background.withValues(alpha: 0.82),
                    border: Border.all(
                      color: ShadTheme.of(
                        context,
                      ).colorScheme.border.withValues(alpha: 0.3),
                    ),
                    borderRadius: context.shadTheme.radius,
                  ),
                  child: Semantics(
                    button: true,
                    label: Strings.historyTitle,
                    child: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.history),
                      onPressed: () => showShadSheet<void>(
                        context: context,
                        side: ShadSheetSide.left,
                        builder: (sheetContext) => const HistorySheet(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              right: 16,
              child: ClipRRect(
                borderRadius: context.shadTheme.radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ShadTheme.of(
                      context,
                    ).colorScheme.background.withValues(alpha: 0.82),
                    border: Border.all(
                      color: ShadTheme.of(
                        context,
                      ).colorScheme.border.withValues(alpha: 0.3),
                    ),
                    borderRadius: context.shadTheme.radius,
                  ),
                  child: Semantics(
                    button: true,
                    label: Strings.settings,
                    child: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.settings),
                      onPressed: () =>
                          AutoRouter.of(context).push(const SettingsRoute()),
                    ),
                  ),
                ),
              ),
            ),
            ScannerControls(
              state: scannerUiState,
              onToggleCamera: toggleCamera,
              onGallery: openGallerySheet,
              onManualEntry: openManualEntrySheet,
              onToggleTorch: toggleTorch,
              onToggleMode: toggleMode,
            ),
          ],
        ),
      ),
    );
  }
}

enum _GallerySheetResult { pick }

class _GallerySheet extends StatelessWidget {
  const _GallerySheet();

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    return ShadSheet(
      title: const Text(Strings.importFromGallery),
      description: const Text(Strings.pharmascanAnalyzesOnly),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.shieldCheck,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  Strings.noPhotoStoredMessage,
                  style: theme.textTheme.small,
                ),
              ),
            ],
          ),
          const Gap(16),
          Semantics(
            button: true,
            label: Strings.choosePhotoFromGallery,
            child: ShadButton(
              onPressed: () =>
                  Navigator.of(context).pop(_GallerySheetResult.pick),
              child: const Text(Strings.choosePhoto),
            ),
          ),
          const Gap(8),
          Semantics(
            button: true,
            label: Strings.cancelPhotoSelection,
            child: ShadButton.outline(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(Strings.cancel),
            ),
          ),
        ],
      ),
    );
  }
}

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

    useEffect(
      () {
        final focusNode = scannerInput.focusNode;
        final controller = scannerInput.controller;
        focusNode.requestFocus();
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
        return null;
      },
      [scannerInput.controller, scannerInput.focusNode],
    );

    void setDelta(int delta) {
      final current = int.tryParse(scannerInput.controller.text) ?? 0;
      final next = (current + delta).clamp(0, 9999);
      final nextStr = next.toString();
      scannerInput.controller
        ..text = nextStr
        ..selection = TextSelection.collapsed(offset: nextStr.length);
    }

    return ShadSheet(
      title: Row(
        children: [
          Icon(
            LucideIcons.copy,
            color: context.shadColors.destructive,
            size: 20,
          ),
          const Gap(12),
          const Expanded(
            child: Text(Strings.duplicateScannedTitle),
          ),
        ],
      ),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.productName,
            style: context.shadTextTheme.small.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(8),
          const Text(Strings.duplicateScannedDescription),
          const Gap(16),
          Text(
            Strings.duplicateAdjustQuantity,
            style: context.shadTextTheme.small.copyWith(
              color: context.shadColors.mutedForeground,
            ),
          ),
        ],
      ),
      actions: [
        ShadButton.ghost(
          onPressed: onCancel,
          child: const Text(Strings.duplicateCancel),
        ),
        ShadButton(
          onPressed: () {
            final qty = int.tryParse(scannerInput.controller.text);
            if (qty != null) {
              onConfirm(qty);
            }
          },
          child: const Text(Strings.duplicateUpdate),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ShadButton.outline(
              onPressed: () => setDelta(-1),
              child: const Icon(LucideIcons.minus, size: 16),
            ),
            const Gap(12),
            Expanded(
              child: ShadInput(
                controller: scannerInput.controller,
                focusNode: scannerInput.focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: context.shadTextTheme.large.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Gap(12),
            ShadButton.outline(
              onPressed: () => setDelta(1),
              child: const Icon(LucideIcons.plus, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualCipSheet extends HookConsumerWidget {
  const _ManualCipSheet({required this.onSubmit});

  final Future<bool> Function(String codeCip) onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = useState(false);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    late Future<void> Function(String code) submit;

    final scanner = useScannerInput(
      onSubmitted: (code) => unawaited(submit(code)),
    );

    submit = (String code) async {
      if (isSubmitting.value) return;

      final trimmed = code.trim();
      if (trimmed.length != 13) {
        if (!context.mounted) return;
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text(Strings.cipMustBe13Digits),
            description: Text(Strings.cipMustBe13Digits),
          ),
        );
        scanner.focusNode.requestFocus();
        return;
      }

      isSubmitting.value = true;

      final success = await onSubmit(trimmed);
      if (!context.mounted) {
        isSubmitting.value = false;
        return;
      }

      isSubmitting.value = false;

      if (!success) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.medicamentNotFound),
            description: Text('${Strings.noMedicamentFoundForCipCode} $code'),
          ),
        );
      } else if (context.mounted) {
        unawaited(Navigator.of(context).maybePop());
      }
    };

    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final maxWidth = breakpoint >= context.shadTheme.breakpoints.md
            ? 512.0
            : screenWidth;

        return Padding(
          padding: viewInsets,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ShadSheet(
                constraints: BoxConstraints(maxWidth: maxWidth),
                title: const Text(Strings.manualCipEntry),
                description: const Text(Strings.manualCipDescription),
                actions: [
                  Semantics(
                    button: true,
                    label: isSubmitting.value
                        ? Strings.searchingInProgress
                        : Strings.searchMedicamentWithCip,
                    enabled: !isSubmitting.value,
                    child: ShadButton(
                      onPressed: isSubmitting.value
                          ? null
                          : () => scanner.submit(scanner.controller.text),
                      leading: isSubmitting.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                      child: const Text(Strings.search),
                    ),
                  ),
                ],
                child: ShadForm(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          Strings.manualEntryFieldLabel,
                          style: context.shadTextTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Semantics(
                          textField: true,
                          label: Strings.manualEntryFieldLabel,
                          hint: Strings.cipPlaceholder,
                          value: scanner.controller.text,
                          child: ShadInput(
                            controller: scanner.controller,
                            focusNode: scanner.focusNode,
                            placeholder: const Text(Strings.cipPlaceholder),
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.search,
                            maxLength: 13,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(13),
                            ],
                            onSubmitted: scanner.submit,
                          ),
                        ),
                        const Gap(16),
                        Text(
                          Strings.searchStartsAutomatically,
                          style: context.shadTextTheme.small,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
