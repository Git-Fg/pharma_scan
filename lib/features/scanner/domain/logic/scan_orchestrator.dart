import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_traffic_control.dart';
import 'package:pharma_scan/features/scanner/domain/scanner_mode.dart';

sealed class ScanDecision {
  const ScanDecision();
}

class Ignore extends ScanDecision {
  const Ignore();
}

class AnalysisSuccess extends ScanDecision {
  const AnalysisSuccess(this.result, {this.replacedExisting = false});

  final ScanResult result;
  final bool replacedExisting;
}

class RestockAdded extends ScanDecision {
  const RestockAdded({
    required this.item,
    required this.scanResult,
    required this.toastMessage,
  });

  final RestockItemEntity item;
  final ScanResult scanResult;
  final String toastMessage;
}

class RestockDuplicate extends ScanDecision {
  const RestockDuplicate(this.event, {this.toastMessage});

  final DuplicateScanEvent event;
  final String? toastMessage;
}

class ProductNotFound extends ScanDecision {
  const ProductNotFound();
}

class ScanError extends ScanDecision {
  const ScanError(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

class DuplicateScanEvent {
  const DuplicateScanEvent({
    required this.cip,
    required this.serial,
    required this.productName,
    required this.currentQuantity,
  });

  final String cip;
  final String serial;
  final String productName;
  final int currentQuantity;
}

/// Pure decision layer for scanner flows (no UI state).
class ScanOrchestrator {
  ScanOrchestrator({
    required CatalogDao catalogDao,
    required RestockDao restockDao,
    required ScanTrafficControl trafficControl,
  }) : _catalogDao = catalogDao,
       _restockDao = restockDao,
       _trafficControl = trafficControl;

  final CatalogDao _catalogDao;
  final RestockDao _restockDao;
  final ScanTrafficControl _trafficControl;

  Future<ScanDecision> decide(
    String rawValue,
    ScannerMode mode, {
    bool force = false,
    Set<String> scannedCodes = const {},
    List<ScanResult> existingBubbles = const [],
  }) async {
    final parsedData = Gs1Parser.parse(rawValue);
    final codeCip = parsedData.gtin;
    if (codeCip == null) {
      return const ProductNotFound();
    }

    final scanKey = _uniqueScanKey(codeCip, parsedData.serial);
    final allowed = _trafficControl.shouldProcess(scanKey, force: force);
    if (!allowed) {
      return const Ignore();
    }

    try {
      return switch (mode) {
        ScannerMode.restock => await _handleRestock(parsedData, codeCip),
        ScannerMode.analysis => await _handleAnalysis(
          codeCip: codeCip,
          scannedCodes: scannedCodes,
          existingBubbles: existingBubbles,
          force: force,
          expDate: parsedData.expDate,
        ),
      };
    } on Object catch (error, stackTrace) {
      return ScanError(error, stackTrace);
    } finally {
      _trafficControl.markProcessed(scanKey);
    }
  }

  Future<ScanDecision> _handleAnalysis({
    required String codeCip,
    required Set<String> scannedCodes,
    required List<ScanResult> existingBubbles,
    required bool force,
    required DateTime? expDate,
  }) async {
    if (!force && scannedCodes.contains(codeCip)) {
      return const Ignore();
    }

    final cip13 = Cip13.validated(codeCip);
    final result = await _catalogDao.getProductByCip(cip13, expDate: expDate);
    if (result == null) {
      return const ProductNotFound();
    }

    final hasExistingBubble = existingBubbles.any(
      (bubble) => bubble.cip.toString() == codeCip,
    );

    return AnalysisSuccess(
      result,
      replacedExisting: force && hasExistingBubble,
    );
  }

  Future<ScanDecision> _handleRestock(
    Gs1DataMatrix parsedData,
    String codeCip,
  ) async {
    final cip13 = Cip13.validated(codeCip);
    final catalogResult = await _catalogDao.getProductByCip(
      cip13,
      expDate: parsedData.expDate,
    );

    if (catalogResult == null) {
      return const ProductNotFound();
    }

    final serial = parsedData.serial;
    if (serial != null && serial.isNotEmpty) {
      final isDuplicate = await _restockDao.isDuplicate(
        cip: codeCip,
        serial: serial,
      );
      if (isDuplicate) {
        final currentQuantity =
            await _restockDao.getRestockQuantity(codeCip) ?? 1;
        return RestockDuplicate(
          DuplicateScanEvent(
            cip: codeCip,
            serial: serial,
            productName: catalogResult.summary.data.nomCanonique,
            currentQuantity: currentQuantity,
          ),
        );
      }
    }

    final outcome = await _restockDao.addUniqueBox(
      cip: cip13,
      serial: serial,
      batchNumber: parsedData.lot,
      expiryDate: parsedData.expDate,
    );

    if (outcome == ScanOutcome.duplicate) {
      final toast = serial != null
          ? Strings.duplicateSerial(serial)
          : Strings.duplicateSerialUnknown;
      final currentQuantity =
          await _restockDao.getRestockQuantity(codeCip) ?? 1;
      return RestockDuplicate(
        DuplicateScanEvent(
          cip: codeCip,
          serial: serial ?? '',
          productName: catalogResult.summary.data.nomCanonique,
          currentQuantity: currentQuantity,
        ),
        toastMessage: toast,
      );
    }

    final quantity = await _restockDao.getRestockQuantity(codeCip) ?? 1;
    final restockItem = RestockItemEntity(
      cip: cip13,
      label: catalogResult.summary.data.nomCanonique,
      princepsLabel: catalogResult.summary.data.princepsDeReference,
      quantity: quantity,
      isChecked: false,
      isPrinceps: catalogResult.summary.data.isPrinceps,
      form: catalogResult.summary.data.formePharmaceutique,
    );

    return RestockAdded(
      item: restockItem,
      scanResult: catalogResult,
      toastMessage: '+1 ${catalogResult.summary.data.nomCanonique}',
    );
  }

  String _uniqueScanKey(String cip, String? serial) {
    if (serial == null || serial.isEmpty) return cip;
    return '$cip::$serial';
  }

  Future<void> updateQuantity(String cip, int newQuantity) {
    return _restockDao.forceUpdateQuantity(
      cip: cip,
      newQuantity: newQuantity,
    );
  }
}
