import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/features/scanner/presentation/hooks/use_scanner_side_effects.dart';
import 'package:pharma_scan/core/presentation/hooks/use_scanner_input.dart';
import 'package:pharma_scan/app/router/app_router.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/utils/hooks/use_async_feedback.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_controller_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/core/widgets/sheets/history_sheet.dart';
import 'package:pharma_scan/core/providers/initialization_provider.dart';
import 'package:pharma_scan/features/scanner/presentation/models/scanner_ui_state.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/presentation/utils/scanner_utils.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scan_window_overlay.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_bubbles.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_controls.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:pharma_scan/core/ui/services/feedback_service.dart';
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
    try {
      tabsRouter = AutoTabsRouter.of(context);
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

    // Scanner side effects handling (extracted to dedicated hook)
    useScannerSideEffects(context: context, ref: ref);

    // ScannerLogic initialization intentionally omitted (handled elsewhere)

    useAsyncFeedback<ScannerState>(ref, scannerProvider);

    final scannerController = ref.watch(scannerControllerProvider);
    // Camera permission and lifecycle logic is now handled by the provider and app lifecycle, not here.
    final picker = useMemoized(ImagePicker.new);

    Future<void> openManualEntrySheet() async {
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      await showModalBottomSheet<void>(
        context: rootContext,
        isScrollControlled: true,
        builder: (sheetContext) => _ManualCipSheet(
          onSubmit: (codeCip) =>
              ref.read(scannerProvider.notifier).findMedicament(codeCip),
        ),
      );
    }

    Future<void> openGallerySheet() async {
      final action = await showModalBottomSheet<_GallerySheetResult>(
        context: context,
        isScrollControlled: true,
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

    final zoomScale = useState(0.0);

    Future<void> toggleTorch() async {
      await scannerController.toggleTorch();
    }

    Future<void> toggleZoom() async {
      // Toggle between 0.0 (1x) and 0.5 (~2x)
      final newScale = zoomScale.value < 0.2 ? 0.5 : 0.0;
      zoomScale.value = newScale;
      await scannerController.setZoomScale(newScale);
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
                    icon: Icons.videocam_off,
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
                icon: Icons.hourglass_empty,
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
                    Icons.qr_code_scanner,
                    size: 80,
                    color: context.textMuted,
                  ),
                  const Gap(20),
                  Text(
                    Strings.readyToScan,
                    style: context.typo.h3.copyWith(
                      color: context.textSecondary,
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
              borderRadius: context.radiusMedium,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.surfacePrimary.withValues(alpha: 0.82),
                  border: Border.all(
                    color: context.actionSurface.withValues(alpha: 0.3),
                  ),
                  borderRadius: context.radiusMedium,
                ),
                child: Semantics(
                  button: true,
                  label: Strings.historyTitle,
                  child: ShadButton.ghost(
                    onPressed: () {
                      // Pour l'instant, nous ouvrons un panneau latéral simple
                      // La migration complète du ShadSheet nécessiterait une implémentation personnalisée
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (sheetContext) => const HistorySheet(),
                      );
                    },
                    child: const Icon(Icons.history),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 16,
            child: ClipRRect(
              borderRadius: context.radiusMedium,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.surfacePrimary.withValues(alpha: 0.82),
                  border: Border.all(
                    color: context.actionSurface.withValues(alpha: 0.3),
                  ),
                  borderRadius: context.radiusMedium,
                ),
                child: Semantics(
                  button: true,
                  label: Strings.settings,
                  child: ShadButton.ghost(
                    onPressed: () =>
                        AutoRouter.of(context).push(const SettingsRoute()),
                    child: const Icon(Icons.settings),
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
            onToggleZoom: toggleZoom,
            onToggleMode: toggleMode,
          ),
        ],
      ),
    );
  }
}

enum _GallerySheetResult { pick }

class _GallerySheet extends StatelessWidget {
  const _GallerySheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.importFromGallery,
            style: context.typo.h4,
          ),
          const Gap(8),
          Text(
            Strings.pharmascanAnalyzesOnly,
            style: context.typo.small.copyWith(color: context.textSecondary),
          ),
          const Gap(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield,
                color: context.actionPrimary,
                size: 20,
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  Strings.noPhotoStoredMessage,
                  style: context.typo.small,
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
              child: Text(Strings.choosePhoto),
            ),
          ),
          const Gap(8),
          Semantics(
            button: true,
            label: Strings.cancelPhotoSelection,
            child: ShadButton.outline(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(Strings.cancel),
            ),
          ),
        ],
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
        FeedbackService.showError(
          context,
          Strings.cipMustBe13Digits,
          title: Strings.cipMustBe13Digits,
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
        FeedbackService.showError(
          context,
          '${Strings.noMedicamentFoundForCipCode} $code',
          title: Strings.medicamentNotFound,
        );
      } else if (context.mounted) {
        unawaited(Navigator.of(context).maybePop());
      }
    };

    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final maxWidth = screenWidth >= 512.0 ? 512.0 : screenWidth;

        return Padding(
          padding: viewInsets,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      Strings.manualCipEntry,
                      style: context.typo.h3,
                    ),
                    const Gap(8),
                    Text(
                      Strings.manualCipDescription,
                      style:
                          context.typo.p.copyWith(color: context.textSecondary),
                    ),
                    const Gap(16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : null,
                            child: Text(Strings.search),
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            Strings.manualEntryFieldLabel,
                            style: context.typo.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Gap(4),
                          Semantics(
                            textField: true,
                            label: Strings.manualEntryFieldLabel,
                            hint: Strings.cipPlaceholder,
                            value: scanner.controller.text,
                            child: TextField(
                              controller: scanner.controller,
                              focusNode: scanner.focusNode,
                              decoration: InputDecoration(
                                hintText: Strings.cipPlaceholder,
                                border: OutlineInputBorder(
                                  borderRadius: context.radiusMedium,
                                ),
                              ),
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
                            style: context.typo.small,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
