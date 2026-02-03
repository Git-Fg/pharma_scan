import 'package:drift/drift.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

QueryExecutor openConnection(LoggerService logger, {String? path}) {
  throw UnsupportedError('Platform not supported for database connection');
}
