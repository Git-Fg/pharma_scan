import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy_bolt/fuzzy_bolt.dart' as fuzzy hide SearchCandidate;
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';

final searchCandidatesProvider = FutureProvider<List<SearchCandidate>>((
  ref,
) async {
  ref.keepAlive();
  final databaseService = sl<DatabaseService>();
  return databaseService.getAllSearchCandidates();
});

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<SearchResultItem>, String>((ref, rawQuery) async {
      final query = rawQuery.trim();
      if (query.isEmpty) return const <SearchResultItem>[];

      final candidates = await ref.watch(searchCandidatesProvider.future);
      if (candidates.isEmpty) return const <SearchResultItem>[];
      final filteredCandidates = _filterRestrictedProcedures(candidates);
      if (filteredCandidates.isEmpty) return const <SearchResultItem>[];

      final membersByGroup = <String, List<SearchCandidate>>{};
      for (final candidate in filteredCandidates) {
        final groupId = candidate.groupId;
        if (groupId == null) continue;
        membersByGroup
            .putIfAbsent(groupId, () => <SearchCandidate>[])
            .add(candidate);
      }

      final scoredResults =
          await fuzzy.FuzzyBolt.searchWithScores<SearchCandidate>(
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

        final groupMembers =
            membersByGroup[groupId] ?? const <SearchCandidate>[];
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
    });

List<SearchCandidate> _filterRestrictedProcedures(
  List<SearchCandidate> candidates,
) {
  return candidates.where((candidate) {
    final normalized = candidate.procedureType?.toLowerCase() ?? '';
    if (normalized.contains('homéo') || normalized.contains('phyto')) {
      return false;
    }
    return true;
  }).toList();
}
