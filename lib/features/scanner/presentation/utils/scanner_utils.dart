import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/core/ui/services/feedback_service.dart';

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
          unawaited(
            ref.read(scannerProvider.notifier).processBarcodeCapture(
                  capture,
                  force: true,
                ),
          );
        } else {
          if (context.mounted) {
            FeedbackService.showError(
              context,
              Strings.imageContainsNoValidBarcode,
              title: Strings.noBarcodeDetected,
            );
          }
        }
      } on Exception catch (e, stackTrace) {
        ref.read(loggerProvider).error(
              '[ScannerUtils] Error during image analysis',
              e,
              stackTrace,
            );
        if (context.mounted) {
          FeedbackService.showError(
            context,
            '${Strings.unableToAnalyzeImage} $e',
            title: Strings.analysisError,
          );
        }
      }
    } on Exception catch (e, stackTrace) {
      ref.read(loggerProvider).error(
            '[ScannerUtils] Error during image pick',
            e,
            stackTrace,
          );
      if (context.mounted) {
        FeedbackService.showError(
          context,
          '${Strings.unableToSelectImage} $e',
          title: Strings.error,
        );
      }
    }
  }
}
