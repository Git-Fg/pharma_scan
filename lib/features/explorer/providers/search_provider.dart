import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters();

  void updateFilters(SearchFilters filters) {
    state = filters;
  }

  void clearFilters() {
    state = const SearchFilters();
  }
}

@riverpod
Future<List<SearchResultItem>> searchResults(Ref ref, String rawQuery) async {
  final query = rawQuery.trim();
  if (query.isEmpty) return const <SearchResultItem>[];

  // WHY: Native debounce in provider - wait before executing search to avoid excessive queries
  // This eliminates the need for Timer-based debouncing in the UI layer
  // Note: This debounce applies per query value - if the query changes during the delay,
  // the provider will be called again with the new value, cancelling this execution
  await Future.delayed(AppConfig.searchDebounce);

  // WHY: Check if provider is still mounted after async delay to prevent UnmountedRefException
  if (!ref.mounted) return const <SearchResultItem>[];

  final searchDao = ref.watch(searchDaoProvider);
  final filters = ref.watch(searchFiltersProvider);

  // WHY: Use FTS5 search directly in SQLite - no client-side indexing needed
  // Filters are applied in the SQL query for efficiency
  final summaries = await searchDao.searchMedicaments(query, filters: filters);
  if (summaries.isEmpty) return const <SearchResultItem>[];

  // WHY: Batch fetch representative CIPs for all results to avoid N+1 queries
  final db = ref.read(appDatabaseProvider);
  final cisCodes = summaries.map((s) => s.cisCode).toSet().toList();
  final medicaments = await (db.select(
    db.medicaments,
  )..where((tbl) => tbl.cisCode.isIn(cisCodes))).get();

  // Build map of CIS code -> first CIP (representative CIP)
  final cisToCipMap = <String, String>{};
  for (final med in medicaments) {
    cisToCipMap.putIfAbsent(med.cisCode, () => med.codeCip);
  }

  // WHY: Deduplicate results by groupId (for groups) or canonical name (for standalone)
  final processedGroups = <String>{};
  final processedStandaloneNames = <String>{};
  final items = <SearchResultItem>[];

  for (final summary in summaries) {
    final groupId = summary.groupId;
    final representativeCip = cisToCipMap[summary.cisCode] ?? summary.cisCode;

    if (groupId != null && groupId.isNotEmpty) {
      // This is a group result
      if (processedGroups.contains(groupId)) {
        continue;
      }
      processedGroups.add(groupId);

      final commonPrinciples = summary.principesActifsCommuns
          .map(sanitizeActivePrinciple)
          .join(', ');

      // WHY: Return GenericGroupEntity directly - do NOT hydrate full medication lists
      // The UI will lazy-load medications when user taps the group card
      items.add(
        SearchResultItem.groupResult(
          group: GenericGroupEntity(
            groupId: groupId,
            commonPrincipes: commonPrinciples,
            princepsReferenceName: summary.princepsDeReference,
          ),
        ),
      );
    } else {
      // This is a standalone result
      final canonicalName = summary.nomCanonique.toUpperCase().trim();
      if (processedStandaloneNames.contains(canonicalName)) {
        continue;
      }
      processedStandaloneNames.add(canonicalName);

      final commonPrinciples = summary.principesActifsCommuns
          .map(sanitizeActivePrinciple)
          .join(', ');

      // WHY: Use MedicamentSummaryData directly - no domain model conversion needed
      items.add(
        SearchResultItem.standaloneResult(
          cisCode: summary.cisCode,
          summary: summary,
          representativeCip: representativeCip,
          commonPrinciples: commonPrinciples,
        ),
      );
    }
  }

  return items;
}
