import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide ScanWindowOverlay;
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/hooks/use_mobile_scanner.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
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
    final isTorchOn = useState(false);

    TabsRouter? tabsRouter;
    var isTabActive = true;
    try {
      tabsRouter = AutoTabsRouter.of(context);
      isTabActive = tabsRouter.activeIndex == 0;
      useListenable(tabsRouter);
    } on Exception {
      // Not available in test contexts
    }

    final scannerController = useMobileScanner(
      enabled: isTabActive && isCameraActive.value,
    );
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
      if (!context.mounted) return;
      isTorchOn.value = !isTorchOn.value;
    }

    void onDetect(BarcodeCapture capture) {
      ref.read(scannerProvider.notifier).processBarcodeCapture(capture);
    }

    final initStepAsync = ref.watch(initializationStepProvider);
    final initStep = initStepAsync.value;
    final isInitializing =
        initStep != null && initStep != InitializationStep.ready;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            if (isCameraActive.value && !isInitializing)
              MobileScanner(
                controller: scannerController,
                onDetect: onDetect,
                tapToFocus: true,
                errorBuilder: (context, error) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.videoOff,
                          size: 64,
                          color: ShadTheme.of(context).colorScheme.destructive,
                        ),
                        const Gap(AppDimens.spacingMd),
                        Text(
                          Strings.cameraUnavailable,
                          style: ShadTheme.of(context).textTheme.h4,
                        ),
                        const Gap(AppDimens.spacingXs),
                        Text(
                          Strings.checkPermissionsMessage,
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                      color: ShadTheme.of(context).colorScheme.muted,
                    ),
                    const Gap(AppDimens.spacingLg),
                    Text(
                      Strings.readyToScan,
                      style: ShadTheme.of(context).textTheme.h4.copyWith(
                        color: ShadTheme.of(
                          context,
                        ).colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ).animate(effects: AppAnimations.fadeIn),
              ),
            if (isCameraActive.value && !isInitializing)
              const ScanWindowOverlay(),
            if (isCameraActive.value && !isInitializing)
              Positioned(
                top: MediaQuery.of(context).padding.top + AppDimens.spacingMd,
                right: AppDimens.spacingMd,
                child: ValueListenableBuilder<bool>(
                  valueListenable: isTorchOn,
                  builder: (context, torchState, _) {
                    return Semantics(
                      button: true,
                      label: torchState
                          ? Strings.turnOffTorch
                          : Strings.turnOnTorch,
                      child: ClipRRect(
                        borderRadius: ShadTheme.of(context).radius,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: ShadTheme.of(
                                context,
                              ).colorScheme.background.withValues(alpha: 0.85),
                              border: Border.all(
                                color: ShadTheme.of(
                                  context,
                                ).colorScheme.border.withValues(alpha: 0.3),
                              ),
                              borderRadius: ShadTheme.of(context).radius,
                            ),
                            child: ShadIconButton.ghost(
                              icon: Icon(
                                LucideIcons.zap,
                                size: AppDimens.iconLg,
                                color: torchState
                                    ? ShadTheme.of(context).colorScheme.primary
                                    : ShadTheme.of(
                                        context,
                                      ).colorScheme.foreground,
                              ),
                              onPressed: toggleTorch,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const ScannerBubbles(),
            ScannerControls(
              isCameraActive: isCameraActive.value,
              isInitializing: isInitializing,
              onToggleCamera: toggleCamera,
              onGallery: openGallerySheet,
              onManualEntry: openManualEntrySheet,
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
    final theme = ShadTheme.of(context);
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
                size: AppDimens.iconMd,
              ),
              const Gap(AppDimens.spacingSm),
              Expanded(
                child: Text(
                  Strings.noPhotoStoredMessage,
                  style: theme.textTheme.small,
                ),
              ),
            ],
          ),
          const Gap(AppDimens.spacingMd),
          Semantics(
            button: true,
            label: Strings.choosePhotoFromGallery,
            child: ShadButton(
              onPressed: () =>
                  Navigator.of(context).pop(_GallerySheetResult.pick),
              child: const Text(Strings.choosePhoto),
            ),
          ),
          const Gap(AppDimens.spacingXs),
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

class _ManualCipSheet extends HookConsumerWidget {
  const _ManualCipSheet({required this.onSubmit});

  final Future<bool> Function(String codeCip) onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<ShadFormState>.new);
    final isSubmitting = useState(false);

    Future<void> submit() async {
      if (isSubmitting.value) return;

      if (!formKey.currentState!.saveAndValidate()) {
        return;
      }

      final code = formKey.currentState!.value['cip'] as String;
      isSubmitting.value = true;

      final success = await onSubmit(code);
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
    }

    return ShadSheet(
      constraints: const BoxConstraints(maxWidth: 512),
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
            onPressed: isSubmitting.value ? null : submit,
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
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadInputFormField(
                id: 'cip',
                label: const Text(Strings.manualEntryFieldLabel),
                placeholder: const Text(Strings.cipPlaceholder),
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 13,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: (v) {
                  if (v.isEmpty || v.length != 13) {
                    return Strings.cipMustBe13Digits;
                  }
                  return null;
                },
              ),
              const Gap(AppDimens.spacingMd),
              Text(
                Strings.searchStartsAutomatically,
                style: ShadTheme.of(context).textTheme.small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
