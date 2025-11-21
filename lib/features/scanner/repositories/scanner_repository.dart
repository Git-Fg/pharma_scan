import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

class ScannerRepository {
  final DriftDatabaseService _databaseService;

  ScannerRepository(this._databaseService);

  Future<ScanResult?> getScanResult(String cip) async {
    return _databaseService.getScanResultByCip(cip);
  }
}
