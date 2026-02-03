import 'dart:async';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/features/scanner/presentation/hooks/use_scanner_side_effects.dart';

import 'package:pharma_scan/app/router/app_router.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/utils/hooks/use_async_feedback.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_controller_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
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
    final scannerMode = scannerState.value?.mode ?? .analysis;

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

    useEffect(() {
      if (tabsRouter != null) {
        // Force rebuild when tab changes
        tabsRouter.addListener(onTabChanged);
        return () => tabsRouter?.removeListener(onTabChanged);
      }
      return null;
    }, [tabsRouter]);

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

      if (action == .pick && context.mounted) {
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
      if (initStep != null && initStep != .ready) {
        return;
      }

      isCameraActive.value = !isCameraActive.value;
    }

    final zoomScale = useState(0.0);

    Future<void> toggleTorch() async {
      try {
        await scannerController.toggleTorch();
      } catch (_) {
        // Ignore errors on unsupported platforms
      }
    }

    Future<void> toggleZoom() async {
      // Toggle between 0.0 (1x) and 0.5 (~2x)
      try {
        final newScale = zoomScale.value < 0.2 ? 0.5 : 0.0;
        zoomScale.value = newScale;
        await scannerController.setZoomScale(newScale);
      } catch (_) {
        // Ignore zoom errors (e.g. on Web)
      }
    }

    Future<void> toggleMode() async {
      final ScannerMode nextMode = scannerMode == .analysis
          ? .restock
          : .analysis;
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
    final isInitializing = initStep != null && initStep != .ready;
    final scannerUiState = isInitializing
        ? ScannerInitializing(mode: scannerMode)
        : ScannerActive(
            mode: scannerMode,
            torchState: .off,
            isCameraRunning: isCameraActive.value,
          );

    useAppHeader(title: const SizedBox.shrink(), isVisible: false);

    return SafeArea(
      key: const Key(TestTags.scannerScreen),
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
                padding: .symmetric(horizontal: 24),
                child: Center(
                  child: StatusView(
                    type: .error,
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
                type: .loading,
                icon: LucideIcons.hourglass,
                title: Strings.initializationInProgress,
                description: Strings.initializationDescription,
              ),
            )
          else
            Align(
              alignment: const Alignment(0, -0.2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.actionPrimary.withValues(alpha: 0.15),
                          context.actionPrimary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: context.actionPrimary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.actionPrimary.withValues(alpha: 0.1),
                          blurRadius: 32,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.scanLine,
                      size: 64,
                      color: context.actionPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  Gap(context.spacing.lg),
                  Text(
                    Strings.readyToScan,
                    textAlign: TextAlign.center,
                    style: context.typo.h2.copyWith(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Gap(context.spacing.xs),
                  Text(
                    'Positionnez le code dans le cadre',
                    textAlign: TextAlign.center,
                    style: context.typo.p.copyWith(
                      color: context.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          if (isCameraActive.value && !isInitializing)
            ScanWindowOverlay(mode: scannerMode),
          const ScannerBubbles(),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 20,
            left: 16,
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surfacePrimary.withValues(alpha: 0.7),
                    border: Border.all(
                      color: context.actionSurface.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: context.shadowMedium,
                  ),
                  child: Semantics(
                    button: true,
                    label: Strings.historyTitle,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (sheetContext) => const HistorySheet(),
                          );
                        },
                        icon: const Icon(LucideIcons.history),
                        color: context.colors.foreground,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 20,
            right: 16,
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surfacePrimary.withValues(alpha: 0.7),
                    border: Border.all(
                      color: context.actionSurface.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Semantics(
                    button: true,
                    label: Strings.settings,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton(
                        onPressed: () =>
                            AutoRouter.of(context).push(const SettingsRoute()),
                        icon: const Icon(LucideIcons.settings),
                        color: context.colors.foreground,
                        padding: EdgeInsets.zero,
                      ),
                    ),
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
      padding: const .all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.importFromGallery, style: context.typo.h4),
          Gap(context.spacing.sm),
          Text(
            Strings.pharmascanAnalyzesOnly,
            style: context.typo.small.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
          Gap(context.spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.shield, color: context.actionPrimary, size: 20),
              Gap(context.spacing.md),
              Expanded(
                child: Text(
                  Strings.noPhotoStoredMessage,
                  style: context.typo.small,
                ),
              ),
            ],
          ),
          Gap(context.spacing.md),
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
    late Future<void> Function(String code) submit;

    final controller = useTextEditingController();
    final focusNode = useFocusNode();

    // Auto-focus on mount
    useEffect(() {
      focusNode.requestFocus();
      return null;
    }, []);

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
        focusNode.requestFocus();
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

    return Padding(
      padding: viewInsets,
      child: Container(
        padding: const .all(24),
        decoration: BoxDecoration(
          color: context.surfacePrimary,
          borderRadius: const .vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.manualCipEntry, style: context.typo.h3),
            Gap(context.spacing.sm),
            Text(
              Strings.manualCipDescription,
              style: context.typo.p.copyWith(
                color: context.colors.mutedForeground,
              ),
            ),
            Gap(context.spacing.lg),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: Strings.manualEntryFieldLabel,
                    hint: Strings.cipPlaceholder,
                    value: controller.text,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: Strings.cipPlaceholder,
                        border: OutlineInputBorder(
                          borderRadius: context.radiusMedium,
                        ),
                        contentPadding: const .symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      autofocus: false,
                      keyboardType: .number,
                      textInputAction: .search,
                      maxLength: 13,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      onSubmitted: (val) => unawaited(submit(val)),
                    ),
                  ),
                ),
                Gap(context.spacing.md),
                Semantics(
                  button: true,
                  label: isSubmitting.value
                      ? Strings.searchingInProgress
                      : Strings.searchMedicamentWithCip,
                  enabled: !isSubmitting.value,
                  child: ElevatedButton(
                    onPressed: isSubmitting.value
                        ? null
                        : () => unawaited(submit(controller.text)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.primaryForeground,
                      shape: RoundedRectangleBorder(
                        borderRadius: context.radiusMedium,
                      ),
                    ),
                    child: isSubmitting.value
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.colors.primaryForeground,
                              ),
                            ),
                          )
                        : Text(Strings.search),
                  ),
                ),
              ],
            ),
            Gap(context.spacing.md),
            Text(
              Strings.searchStartsAutomatically,
              style: context.typo.small.copyWith(color: context.colors.muted),
            ),
            Gap(context.spacing.md),
          ],
        ),
      ),
    );
  }
}
