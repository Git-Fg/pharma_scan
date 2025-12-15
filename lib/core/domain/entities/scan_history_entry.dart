import 'package:pharma_scan/core/database/queries.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

extension type ScanHistoryEntry(GetScanHistoryResult _row) {
  factory ScanHistoryEntry.fromData(GetScanHistoryResult row) =>
      ScanHistoryEntry(row);

  Cip13 get cip {
    final cipStr = _row.cip;
    if (cipStr == null || cipStr.isEmpty) {
      throw StateError('CIP code is null or empty in scan history');
    }
    return Cip13.validated(cipStr);
  }

  DateTime get scannedAt {
    final scanned = _row.scannedAt;
    if (scanned == null) {
      throw StateError('Scan timestamp is null in scan history');
    }
    return scanned;
  }

  String get label => _row.label;
  String? get princepsDeReference => _row.princepsDeReference;
  bool get isPrinceps => _convertToBool(_row.isPrinceps);

  // Helper to convert potentially string/int values to boolean
  // Handles various database representations: 1/0, '1'/'0', 'true'/'false', 't'/'f', etc.
  static bool _convertToBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is int) return value != 0;

    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == '1' || lower == 'true' || lower == 't' || lower == 'yes' || lower == 'y') {
        return true;
      } else if (lower == '0' || lower == 'false' || lower == 'f' || lower == 'no' || lower == 'n') {
        return false;
      }
    }

    // If conversion isn't straightforward, treat non-empty as true
    return value.toString().isNotEmpty && value.toString() != '0';
  }
}
