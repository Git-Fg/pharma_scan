// lib/features/explorer/providers/group_cluster_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/cluster_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';

class ClusterLibraryState {
  const ClusterLibraryState({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<ClusterSummary> items;
  final bool hasMore;
  final bool isLoadingMore;

  ClusterLibraryState copyWith({
    List<ClusterSummary>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ClusterLibraryState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final groupClusterProvider =
    AsyncNotifierProvider<GroupClusterNotifier, ClusterLibraryState>(
  GroupClusterNotifier.new,
);

final clusterGroupsProvider = FutureProvider.family<
    List<GenericGroupSummary>,
    String>((ref, clusterKey) async {
  final database = sl<DatabaseService>();
  return database.getClusterGroupSummaries(clusterKey);
});

class GroupClusterNotifier extends AsyncNotifier<ClusterLibraryState> {
  static const _pageSize = 40;

  final DatabaseService _databaseService = sl<DatabaseService>();

  int _offset = 0;
  bool _isFetchingMore = false;

  @override
  Future<ClusterLibraryState> build() async {
    _offset = 0;
    _isFetchingMore = false;
    return _fetchClusters(reset: true);
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

    final result = await AsyncValue.guard(() => _fetchClusters(reset: false));
    _isFetchingMore = false;

    result.when(
      data: (data) => state = AsyncValue.data(data),
      error: (error, stackTrace) {
        state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      },
      loading: () {},
    );
  }

  Future<ClusterLibraryState> _fetchClusters({required bool reset}) async {
    final clusters = await _databaseService.getClusterSummaries(
      limit: _pageSize,
      offset: reset ? 0 : _offset,
    );

    final existing = reset
        ? const <ClusterSummary>[]
        : (state.value?.items ?? const <ClusterSummary>[]);
    final merged = reset ? clusters : [...existing, ...clusters];

    _offset = reset ? clusters.length : _offset + clusters.length;
    final hasMore = clusters.length == _pageSize;

    return ClusterLibraryState(
      items: merged,
      hasMore: hasMore,
      isLoadingMore: false,
    );
  }
}

