import 'package:fuzzy_bolt/fuzzy_bolt.dart' as fuzzy hide SearchCandidate;
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/providers/repositories_providers.dart';

part 'search_provider.g.dart';

@riverpod
Future<List<SearchCandidate>> searchCandidates(Ref ref) async {
  final repository = ref.watch(explorerRepositoryProvider);
  return repository.getAllSearchCandidates();
}

@riverpod
List<SearchCandidate> filteredSearchCandidates(Ref ref) {
  final candidates = ref.watch(searchCandidatesProvider).value ?? [];
  final filters = ref.watch(searchFiltersProvider);
  return _applyFilters(candidates, filters);
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

  // WHY: Use filteredSearchCandidatesProvider to avoid re-filtering on every query change.
  // Filtering only runs when filters change, not when the query changes.
  final filteredCandidates = ref.watch(filteredSearchCandidatesProvider);
  if (filteredCandidates.isEmpty) return const <SearchResultItem>[];

  final membersByGroup = <String, List<SearchCandidate>>{};
  for (final candidate in filteredCandidates) {
    final groupId = candidate.groupId;
    if (groupId == null) continue;
    membersByGroup
        .putIfAbsent(groupId, () => <SearchCandidate>[])
        .add(candidate);
  }

  final payloads = List<_FuzzySearchItem>.generate(filteredCandidates.length, (
    index,
  ) {
    final candidate = filteredCandidates[index];
    return _FuzzySearchItem(
      index: index,
      canonicalName: candidate.nomCanonique,
      displayName: candidate.medicament.nom,
      codeCip: candidate.medicament.codeCip,
      princepsReference: candidate.princepsDeReference,
      principles: candidate.commonPrinciples.join(' '),
    );
  });

  final scoredResults =
      await fuzzy.FuzzyBolt.searchWithScores<_FuzzySearchItem>(
        payloads,
        query,
        selectors: [
          (item) => item.canonicalName,
          (item) => item.displayName,
          (item) => item.codeCip,
          (item) => item.princepsReference,
          (item) => item.principles,
        ],
        strictThreshold: 0.7,
        typeThreshold: 0.5,
        isolateThreshold: 500,
        maxResults: 50,
        enableStemming: false,
        enableCleaning: false,
      );

  final processedGroups = <String>{};
  final processedStandaloneNames = <String>{};
  final items = <SearchResultItem>[];

  for (final result in scoredResults) {
    final candidate = filteredCandidates[result.item.index];
    final commonPrinciples = candidate.commonPrinciples.join(', ');
    final groupId = candidate.groupId;

    if (groupId == null) {
      // WHY: Deduplicate standalone results by medicament name to avoid
      // showing multiple identical results for the same medication.
      final medicamentName = candidate.medicament.nom.toUpperCase().trim();
      if (processedStandaloneNames.contains(medicamentName)) {
        continue;
      }
      processedStandaloneNames.add(medicamentName);
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

class _FuzzySearchItem {
  const _FuzzySearchItem({
    required this.index,
    required this.canonicalName,
    required this.displayName,
    required this.codeCip,
    required this.princepsReference,
    required this.principles,
  });

  final int index;
  final String canonicalName;
  final String displayName;
  final String codeCip;
  final String princepsReference;
  final String principles;
}

List<SearchCandidate> _applyFilters(
  List<SearchCandidate> candidates,
  SearchFilters filters,
) {
  return candidates.where((candidate) {
    final normalizedProcedure = (candidate.procedureType ?? '')
        .toLowerCase()
        .trim();

    // Filter by procedure type selection
    if (filters.procedureType == 'Autorisation') {
      if (!_isAutorisationProcedure(normalizedProcedure)) {
        return false;
      }
    } else if (filters.procedureType == 'Enregistrement') {
      if (!_isAlternativeProcedure(normalizedProcedure)) {
        return false;
      }
    } else if (_isAlternativeProcedure(normalizedProcedure)) {
      // Default relevance filter excludes homeopathy / phytotherapy entries.
      return false;
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

bool _isAutorisationProcedure(String procedureType) {
  if (procedureType.isEmpty) return true;
  return procedureType.contains('autorisation');
}

bool _isAlternativeProcedure(String procedureType) {
  if (procedureType.isEmpty) return false;
  return _containsAny(procedureType, _alternativeProcedureTokens);
}

bool _containsAny(String haystack, List<String> keywords) {
  for (final keyword in keywords) {
    if (haystack.contains(keyword)) {
      return true;
    }
  }
  return false;
}

const List<String> _alternativeProcedureTokens = [
  'homéo',
  'homeo',
  'homéopath',
  'homeopath',
  'phyto',
  'phytothé',
];
