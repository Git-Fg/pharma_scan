// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element

import '../../features/explorer/domain/models/generic_group_entity.dart' as p2;
import '../../features/explorer/domain/models/search_filters_model.dart' as p3;
import '../../features/explorer/domain/models/search_result_item_model.dart'
    as p4;
import '../../features/explorer/presentation/providers/generic_groups_provider.dart'
    as p5;
import '../../features/explorer/presentation/providers/group_explorer_state.dart'
    as p6;
import '../../features/home/models/sync_state.dart' as p7;
import '../../features/restock/domain/entities/restock_item_entity.dart' as p8;
import '../../features/scanner/presentation/providers/scanner_provider.dart'
    as p9;
import '../models/scan_result.dart' as p0;
import '../utils/gs1_parser.dart' as p1;

void initializeMappers() {
  p0.ScanResultMapper.ensureInitialized();
  p0.ScanMetadataMapper.ensureInitialized();
  p1.Gs1DataMatrixMapper.ensureInitialized();
  p2.GenericGroupEntityMapper.ensureInitialized();
  p3.SearchFiltersMapper.ensureInitialized();
  p4.SearchResultItemMapper.ensureInitialized();
  p4.GroupResultMapper.ensureInitialized();
  p4.PrincepsResultMapper.ensureInitialized();
  p4.GenericResultMapper.ensureInitialized();
  p4.StandaloneResultMapper.ensureInitialized();
  p4.ClusterResultMapper.ensureInitialized();
  p5.GenericGroupsStateMapper.ensureInitialized();
  p6.GroupExplorerStateMapper.ensureInitialized();
  p7.SyncProgressMapper.ensureInitialized();
  p8.RestockItemEntityMapper.ensureInitialized();
  p9.ScannerStateMapper.ensureInitialized();
}

