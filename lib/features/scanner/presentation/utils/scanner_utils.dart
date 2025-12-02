import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ScannerUtils {
  ScannerUtils._();

  static Future<void> pickAndScanImage(
    WidgetRef ref,
    BuildContext context,
    MobileScannerController scannerController,
    ImagePicker picker,
  ) async {
    try {
      final file = await picker.pickImage(source: ImageSource.gallery);

      if (file == null) {
        return;
      }

      try {
        final capture = await scannerController.analyzeImage(
          file.path,
        );

        if (capture != null && capture.barcodes.isNotEmpty) {
          ref.read(scannerProvider.notifier).processBarcodeCapture(capture);
        } else {
          if (context.mounted) {
            ShadToaster.of(context).show(
              const ShadToast.destructive(
                title: Text(Strings.noBarcodeDetected),
                description: Text(Strings.imageContainsNoValidBarcode),
              ),
            );
          }
        }
      } on Exception catch (e, stackTrace) {
        LoggerService.error(
          '[ScannerUtils] Error during image analysis',
          e,
          stackTrace,
        );
        if (context.mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text(Strings.analysisError),
              description: Text(
                '${Strings.unableToAnalyzeImage} $e',
              ),
            ),
          );
        }
      }
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[ScannerUtils] Error during image pick',
        e,
        stackTrace,
      );
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.error),
            description: Text('${Strings.unableToSelectImage} $e'),
          ),
        );
      }
    }
  }
}
