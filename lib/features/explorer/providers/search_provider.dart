import 'package:fuzzy_bolt/fuzzy_bolt.dart' as fuzzy hide SearchCandidate;
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<SearchCandidate>> searchCandidates(Ref ref) async {
  final databaseService = sl<DatabaseService>();
  return databaseService.getAllSearchCandidates();
}

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

  final filters = ref.watch(searchFiltersProvider);
  final candidates = await ref.watch(searchCandidatesProvider.future);
  if (candidates.isEmpty) return const <SearchResultItem>[];
  final filteredCandidates = _applyFilters(candidates, filters);
  if (filteredCandidates.isEmpty) return const <SearchResultItem>[];

  final membersByGroup = <String, List<SearchCandidate>>{};
  for (final candidate in filteredCandidates) {
    final groupId = candidate.groupId;
    if (groupId == null) continue;
    membersByGroup
        .putIfAbsent(groupId, () => <SearchCandidate>[])
        .add(candidate);
  }

  final scoredResults = await fuzzy.FuzzyBolt.searchWithScores<SearchCandidate>(
    filteredCandidates,
    query,
    selectors: [
      (candidate) => candidate.nomCanonique,
      (candidate) => candidate.medicament.nom,
      (candidate) => candidate.medicament.codeCip,
      (candidate) => candidate.princepsDeReference,
      (candidate) => candidate.commonPrinciples.join(' '),
    ],
    strictThreshold: 0.7,
    typeThreshold: 0.5,
    isolateThreshold: 500,
    maxResults: 50,
    enableStemming: false,
    enableCleaning: false,
  );

  final processedGroups = <String>{};
  final items = <SearchResultItem>[];

  for (final result in scoredResults) {
    final candidate = result.item;
    final commonPrinciples = candidate.commonPrinciples.join(', ');
    final groupId = candidate.groupId;

    if (groupId == null) {
      items.add(
        SearchResultItem.standaloneResult(
          medicament: candidate.medicament,
          commonPrinciples: commonPrinciples,
        ),
      );
      continue;
    }

    if (processedGroups.contains(groupId)) {
      continue;
    }
    processedGroups.add(groupId);

    final groupMembers = membersByGroup[groupId] ?? const <SearchCandidate>[];
    final princeps = groupMembers
        .where((member) => member.isPrinceps)
        .map((member) => member.medicament)
        .toList();
    final generics = groupMembers
        .where((member) => !member.isPrinceps)
        .map((member) => member.medicament)
        .toList();

    if (princeps.isNotEmpty) {
      items.add(
        SearchResultItem.princepsResult(
          princeps: princeps.first,
          generics: generics,
          groupId: groupId,
          commonPrinciples: commonPrinciples,
        ),
      );
    } else if (generics.isNotEmpty) {
      items.add(
        SearchResultItem.genericResult(
          generic: generics.first,
          princeps: princeps,
          groupId: groupId,
          commonPrinciples: commonPrinciples,
        ),
      );
    }
  }

  return items;
}

List<SearchCandidate> _applyFilters(
  List<SearchCandidate> candidates,
  SearchFilters filters,
) {
  return candidates.where((candidate) {
    // Filter by procedure type
    if (filters.procedureType != null) {
      if (candidate.procedureType != filters.procedureType) {
        return false;
      }
    }

    // Filter by pharmaceutical form
    if (filters.formePharmaceutique != null) {
      if (candidate.medicament.formePharmaceutique !=
          filters.formePharmaceutique) {
        return false;
      }
    }

    return true;
  }).toList();
}
