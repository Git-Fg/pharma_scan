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
  bool get isPrinceps => _row.isPrinceps == 1;
}
