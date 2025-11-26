// lib/core/database/daos/scan_dao.dart
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

part 'scan_dao.g.dart';

@DriftAccessor(
  tables: [
    MedicamentSummary,
    PrincipesActifs,
    Specialites,
    Medicaments,
    MedicamentAvailability,
    GroupMembers,
    GeneriqueGroups,
  ],
)
class ScanDao extends DatabaseAccessor<AppDatabase> with _$ScanDaoMixin {
  ScanDao(super.db);

  /// WHY: Returns the medicament summary row associated with the scanned CIP.
  /// Scanner UI still needs the CIP itself alongside presentation metadata.
  Future<ScanResult?> getProductByCip(String codeCip) async {
    LoggerService.db('Lookup product for CIP $codeCip');

    final query = select(medicaments).join([
      leftOuterJoin(
        medicamentAvailability,
        medicamentAvailability.codeCip.equalsExp(medicaments.codeCip),
      ),
    ])..where(medicaments.codeCip.equals(codeCip));

    final row = await query.getSingleOrNull();

    if (row == null) {
      LoggerService.db('No medicament row found for CIP $codeCip');
      return null;
    }

    final medicament = row.readTable(medicaments);
    final availabilityRow = row.readTableOrNull(medicamentAvailability);

    final summary =
        await (select(medicamentSummary)
              ..where((tbl) => tbl.cisCode.equals(medicament.cisCode)))
            .getSingleOrNull();

    if (summary == null) {
      LoggerService.warning(
        '[ScanDao] No medicament_summary row found for CIS ${medicament.cisCode}',
      );
      return null;
    }

    return ScanResult(
      summary: summary,
      cip: codeCip,
      price: medicament.prixPublic,
      refundRate: medicament.tauxRemboursement,
      boxStatus: medicament.commercialisationStatut,
      availabilityStatus: availabilityRow?.statut,
      isHospitalOnly: summary.isHospitalOnly ||
          _isHospitalOnly(
            medicament.agrementCollectivites,
            medicament.prixPublic,
            medicament.tauxRemboursement,
          ),
      libellePresentation: medicament.presentationLabel,
    );
  }

  bool _isHospitalOnly(
    String? agrementCollectivites,
    double? price,
    String? refundRate,
  ) {
    if (agrementCollectivites == null) return false;
    final agrement = agrementCollectivites.trim().toLowerCase();
    final isAgreed = agrement == 'oui';
    final hasPrice = price != null && price > 0;
    final hasRefund = refundRate != null && refundRate.trim().isNotEmpty;
    return isAgreed && !hasPrice && hasRefund;
  }
}
