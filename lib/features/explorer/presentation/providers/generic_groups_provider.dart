
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generic_groups_provider.g.dart';

class GenericGroupsState {
  const GenericGroupsState({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<GenericGroupEntity> items;
  final bool hasMore;
  final bool isLoadingMore;

  GenericGroupsState copyWith({
    List<GenericGroupEntity>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return GenericGroupsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class GenericGroupsNotifier extends _$GenericGroupsNotifier {
  static const _pageSize = 40;

  int _offset = 0;
  bool _isFetchingMore = false;

  @override
  Future<GenericGroupsState> build() async {
    ref.watch(lastSyncEpochStreamProvider);

    _offset = 0;
    _isFetchingMore = false;
    ref.watch(searchFiltersProvider);
    return _fetchGroups(reset: true);
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        !currentState.hasMore ||
        _isFetchingMore ||
        state.isLoading) {
      return;
    }

    _isFetchingMore = true;
    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    final result = await AsyncValue.guard(() => _fetchGroups(reset: false));
    _isFetchingMore = false;

    result.when(
      data: (data) => state = AsyncValue.data(data),
      error: (error, stackTrace) {
        LoggerService.error(
          '[GenericGroupsNotifier] Failed to load more groups',
          error,
          stackTrace,
        );
        state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      },
      loading: () {},
    );
  }

  Future<GenericGroupsState> _fetchGroups({required bool reset}) async {
    final catalogDao = ref.read(catalogDaoProvider);
    final filters = ref.read(searchFiltersProvider);

    // Convert filter to routeKeywords format expected by getGenericGroupSummaries
    final routeKeywords = filters.voieAdministration != null
        ? [filters.voieAdministration!]
        : null;

    // Convert enum to code string for database query
    final atcClassCode = filters.atcClass?.code;

    final groups = await catalogDao.getGenericGroupSummaries(
      routeKeywords: routeKeywords,
      atcClass: atcClassCode,
      limit: _pageSize,
      offset: reset ? 0 : _offset,
    );

    final existing = reset
        ? const <GenericGroupEntity>[]
        : (state.value?.items ?? const <GenericGroupEntity>[]);
    final merged = reset ? groups : [...existing, ...groups];

    _offset = reset ? groups.length : _offset + groups.length;
    final hasMore = groups.length == _pageSize;

    return GenericGroupsState(
      items: merged,
      hasMore: hasMore,
      isLoadingMore: false,
    );
  }
}
