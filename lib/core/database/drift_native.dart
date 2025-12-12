// Stub implementation for mobile platforms
// This file provides empty implementations for web-only types

import 'dart:typed_data';
import 'package:drift/drift.dart';

class WasmDatabase {
  static Future<DatabaseConnection> open({
    required String databaseName,
    required Uri sqlite3Uri,
    required Uri driftWorkerUri,
    required Future<Uint8List> Function() initializeDatabase,
  }) async {
    throw UnsupportedError('WasmDatabase is only supported on web platform');
  }
}