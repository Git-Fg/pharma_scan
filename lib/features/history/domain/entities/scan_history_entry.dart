import 'package:pharma_scan/core/database/queries.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

extension type ScanHistoryEntry(GetScanHistoryResult _row) {
  factory ScanHistoryEntry.fromData(GetScanHistoryResult row) =>
      ScanHistoryEntry(row);

  Cip13 get cip => Cip13.validated(_row.cip);
  DateTime get scannedAt => _row.scannedAt;
  String get label => _row.label;
  String? get princepsDeReference => _row.princepsDeReference;
  bool get isPrinceps => _row.isPrinceps ?? false;
}
