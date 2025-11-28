import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/logic/classifier.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_summary_provider.g.dart';

class GroupSummaryState {
  const GroupSummaryState({
    required this.items,
    required this.category,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<GenericGroupEntity> items;
  final FormCategory category;
  final bool hasMore;
  final bool isLoadingMore;

  GroupSummaryState copyWith({
    List<GenericGroupEntity>? items,
    FormCategory? category,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return GroupSummaryState(
      items: items ?? this.items,
      category: category ?? this.category,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class GroupSummaryNotifier extends _$GroupSummaryNotifier {
  static const int _pageSize = 50;

  int _offset = 0;
  FormCategory _selectedCategory = FormCategory.oral;
  bool _isFetchingMore = false;

  @override
  Future<GroupSummaryState> build() async {
    // WHY: Watch sync timestamp to automatically re-fetch when sync completes
    // The provider will automatically re-execute when the stream emits a new value
    ref.watch(lastSyncEpochStreamProvider);

    _offset = 0;
    _selectedCategory = FormCategory.oral;
    return _fetchSummaries(reset: true);
  }

  Future<void> setCategory(FormCategory category) async {
    if (_selectedCategory == category && state.value != null) {
      return;
    }
    _selectedCategory = category;
    _offset = 0;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchSummaries(reset: true));
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

    final result = await AsyncValue.guard(() => _fetchSummaries(reset: false));
    _isFetchingMore = false;

    result.when(
      data: (data) => state = AsyncValue.data(data),
      error: (error, stackTrace) {
        state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      },
      loading: () {},
    );
  }

  Future<GroupSummaryState> _fetchSummaries({required bool reset}) async {
    final libraryDao = ref.watch(libraryDaoProvider);
    final params = keywordsForCategory(_selectedCategory);
    final summaries = await libraryDao.getGenericGroupSummaries(
      formKeywords: params.formKeywords,
      excludeKeywords: params.excludeKeywords,
      procedureTypeKeywords: params.procedureTypeKeywords,
      limit: _pageSize,
      offset: reset ? 0 : _offset,
    );

    final existing = reset
        ? const <GenericGroupEntity>[]
        : (state.value?.items ?? const <GenericGroupEntity>[]);
    final merged = reset ? summaries : [...existing, ...summaries];

    _offset = reset ? summaries.length : _offset + summaries.length;
    final hasMore = summaries.length == _pageSize;

    return GroupSummaryState(
      items: merged,
      category: _selectedCategory,
      hasMore: hasMore,
      isLoadingMore: false,
    );
  }
}
