import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// A simple fake implementation of [PathProviderPlatform] for unit tests.
///
/// - If [throwOnGet] is true, calls to `getApplicationDocumentsPath` will
///   throw a [MissingPluginException] (simulates plugin not being registered).
/// - Otherwise, it returns the provided [documentsPath].
class FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;
  final bool throwOnGet;

  FakePathProviderPlatform(
      {required this.documentsPath, this.throwOnGet = false});

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (throwOnGet) throw MissingPluginException('Fake: no path provider');
    return documentsPath;
  }

  @override
  Future<String?> getTemporaryPath() async => documentsPath;
}
