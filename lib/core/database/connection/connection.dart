import 'package:drift/drift.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

// Conditional import to select the right implementation
// Default to unsupported to prevent leaking native dependencies
import 'unsupported.dart'
    if (dart.library.html) 'web.dart'
    if (dart.library.io) 'native.dart' as impl;

QueryExecutor openConnection(LoggerService logger, {String? path}) {
  return impl.openConnection(logger, path: path);
}
