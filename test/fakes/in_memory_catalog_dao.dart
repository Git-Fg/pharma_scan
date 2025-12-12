import 'dart:async';

import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

/// In-memory fake implementation of CatalogDao for widget tests.
///
/// Provides real state integration testing without requiring a full database.
/// Use this instead of MockCatalogDao when testing state transitions and UI updates.
///
/// Note: This is a simplified implementation that provides the essential methods
/// needed for widget tests. Use provider overrides to inject this into tests.
class InMemoryCatalogDao {
  InMemoryCatalogDao({
    this.medicaments = const [],
    this.groupDetails = const {},
    this.genericGroups = const [],
    this.databaseStats = const (
      totalPrinceps: 0,
      totalGeneriques: 0,
      totalPrincipes: 0,
      avgGenPerPrincipe: 0.0,
    ),
  });

  final List<MedicamentEntity> medicaments;
  final Map<String, List<GroupDetailEntity>> groupDetails;
  final List<GenericGroupEntity> genericGroups;
  final DatabaseStats databaseStats;

  Future<List<MedicamentEntity>> searchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) async {
    final queryLower = query.toString().toLowerCase();
    return medicaments.where((m) {
      final name = m.data.nomCanonique.toLowerCase();
      final brand = m.data.princepsBrandName.toLowerCase();
      return name.contains(queryLower) || brand.contains(queryLower);
    }).toList();
  }

  Stream<List<MedicamentEntity>> watchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) async* {
    yield await searchMedicaments(query, filters: filters);
  }

  Stream<List<GroupDetailEntity>> watchGroupDetails(String groupId) {
    return Stream.value(groupDetails[groupId] ?? []);
  }

  Future<List<GroupDetailEntity>> getGroupDetails(String groupId) async {
    return groupDetails[groupId] ?? [];
  }

  Future<List<GroupDetailEntity>> fetchRelatedPrinceps(String groupId) async {
    return [];
  }

  Future<List<GenericGroupEntity>> getGenericGroupSummaries({
    List<String>? routeKeywords,
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    List<String>? procedureTypeKeywords,
    String? atcClass,
    int limit = 100,
    int offset = 0,
  }) async {
    return genericGroups.skip(offset).take(limit).toList();
  }

  Future<DatabaseStats> getDatabaseStats() async {
    return databaseStats;
  }

  Future<bool> hasExistingData() async {
    return medicaments.isNotEmpty;
  }
}
