import 'package:pharma_scan/core/database/mappers.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/features/explorer/models/cluster_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';

class ExplorerRepository {
  final DriftDatabaseService _databaseService;

  ExplorerRepository(this._databaseService);

  Future<List<SearchCandidate>> getAllSearchCandidates() async {
    final summaries = await _databaseService.getAllSearchCandidates();
    final candidates = <SearchCandidate>[];

    // WHY: All medications (both grouped and standalone) are now in MedicamentSummary table.
    // Use the mapper extension to convert to SearchCandidate, eliminating duplicate mapping logic.
    for (final summary in summaries) {
      // Get representative CIP for this CIS code
      final medicamentRows = _databaseService.database.select(
        _databaseService.database.medicaments,
      )..where((tbl) => tbl.cisCode.equals(summary.cisCode));
      final medicaments = await medicamentRows.get();
      final representativeCip = medicaments.isNotEmpty
          ? medicaments.first.codeCip
          : summary.cisCode;

      candidates.add(
        summary.toSearchCandidate(representativeCip: representativeCip),
      );
    }

    return candidates;
  }

  Future<List<ClusterSummary>> getClusterSummaries({
    required int limit,
    required int offset,
    String? procedureType,
    String? formePharmaceutique,
  }) async {
    final rows = await _databaseService.getClusterSummaries(
      limit: limit,
      offset: offset,
      procedureType: procedureType,
      formePharmaceutique: formePharmaceutique,
    );
    return rows.map((row) => row.toClusterSummary()).toList();
  }

  Future<List<GenericGroupEntity>> getClusterGroupSummaries(String clusterKey) {
    return _databaseService.getClusterGroupSummaries(clusterKey);
  }

  Future<List<GenericGroupEntity>> getGenericGroupSummaries({
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    List<String>? procedureTypeKeywords,
    required int limit,
    required int offset,
  }) {
    return _databaseService.getGenericGroupSummaries(
      formKeywords: formKeywords,
      excludeKeywords: excludeKeywords,
      procedureTypeKeywords: procedureTypeKeywords,
      limit: limit,
      offset: offset,
    );
  }

  Future<ProductGroupClassification?> classifyProductGroup(
    String groupId,
  ) async {
    final data = await _databaseService.classifyProductGroup(groupId);
    return data?.toDomain();
  }

  Future<Map<String, dynamic>> getDatabaseStats() {
    return _databaseService.getDatabaseStats();
  }

  Future<List<String>> getDistinctPharmaceuticalForms() {
    return _databaseService.getDistinctPharmaceuticalForms();
  }
}
