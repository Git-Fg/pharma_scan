import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/services/data_initialization_models.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';

class DataInitializationService {
  DataInitializationService({
    required Ref ref,
    required FileDownloadService fileDownloadService,
    required Dio dio,
    AssetBundle? assetBundle,
  });

  static const String dataVersion = 'web-database';

  Stream<InitializationStep> get onStepChanged => const Stream.empty();
  Stream<String> get onDetailChanged => const Stream.empty();

  void dispose() {}

  /// On Web, we rely on Drif/Wasm logic to hydrate the DB.
  /// This service is a no-op that reports ready.
  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    // Maybe trigger sync?
    return;
  }

  Future<bool> updateDatabase({bool force = false}) async {
    // Web updates happen via app deployment usually.
    return false;
  }

  Future<VersionCheckResult?> checkVersionStatus(
      {bool ignorePolicy = false}) async {
    return null;
  }
}
