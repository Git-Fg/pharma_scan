import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/mixins/safe_async_notifier_mixin.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generic_groups_provider.g.dart';
part 'generic_groups_provider.mapper.dart';

@MappableClass()
class GenericGroupsState with GenericGroupsStateMappable {
  const GenericGroupsState({
    required this.items,
  });

  final List<GenericGroupEntity> items;
}

@Riverpod(keepAlive: true)
class GenericGroupsNotifier extends _$GenericGroupsNotifier with SafeAsyncNotifierMixin {
  @override
  Future<GenericGroupsState> build() async {
    final filters = ref.watch(searchFiltersProvider);
    ref.watch(lastSyncEpochProvider);

    return await _fetchAllGroups(filters);
  }

  Future<GenericGroupsState> _fetchAllGroups(SearchFilters filters) async {
    final result = await safeExecute(() async {
      final catalogDao = ref.read(catalogDaoProvider);

      final routeKeywords = filters.voieAdministration != null
          ? [filters.voieAdministration!]
          : null;

      final atcClassCode = filters.atcClass?.code;

      final groups = await catalogDao.getGenericGroupSummaries(
        routeKeywords: routeKeywords,
        atcClass: atcClassCode,
        limit: 10000,
      );

      if (!isMounted()) {
        return GenericGroupsState(items: []);
      }

      // Ensure downstream listeners receive a fresh list instance on each fetch.
      return GenericGroupsState(items: List<GenericGroupEntity>.of(groups));
    });

    if (!isMounted()) {
      return const GenericGroupsState(items: []);
    }

    if (result.hasError) {
      logError(
        '[GenericGroupsNotifier] Failed to fetch generic groups',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
      return const GenericGroupsState(items: []);
    }

    return result.value ?? const GenericGroupsState(items: []);
  }
}
