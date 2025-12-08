import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';

MedicamentEntity _buildSummary() {
  return MedicamentEntity.fromData(
    const MedicamentSummaryData(
      cisCode: '123456',
      nomCanonique: 'Test Médicament',
      isPrinceps: false,
      memberType: 1,
      principesActifsCommuns: ['Test'],
      princepsDeReference: 'Test Princeps',
      formePharmaceutique: 'Comprimé',
      princepsBrandName: 'Test Brand',
      procedureType: 'Procédure',
      isSurveillance: false,
      isHospitalOnly: false,
      isDental: false,
      isList1: false,
      isList2: false,
      isNarcotic: false,
      isException: false,
      isRestricted: false,
      isOtc: true,
    ),
  );
}

void main() {
  group('ScanResult.isExpired', () {
    final summary = _buildSummary();
    final cip = Cip13.validated('3400000000012');

    test('returns false when no expiration date', () {
      final result = ScanResult(
        summary: summary,
        cip: cip,
      );

      expect(result.isExpired, isFalse);
    });

    test('returns false when expiry is today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);

      final result = ScanResult(
        summary: summary,
        cip: cip,
        expDate: today,
      );

      expect(result.isExpired, isFalse);
    });

    test('returns true when expiry is before today', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final expiry = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        10,
      );

      final result = ScanResult(
        summary: summary,
        cip: cip,
        expDate: expiry,
      );

      expect(result.isExpired, isTrue);
    });
  });
}
