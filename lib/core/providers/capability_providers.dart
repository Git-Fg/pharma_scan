import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'capability_providers.g.dart';

/// Provides the current DateTime. Override for time-travel testing.
@riverpod
DateTime Function() clock(Ref ref) => DateTime.now;

/// Checks for internet connectivity. Override for offline/online testing.
@riverpod
Future<bool> Function() connectivityCheck(Ref ref) {
  return () async {
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on Object catch (_) {
      return false;
    }
  };
}
