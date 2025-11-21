import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/features/explorer/repositories/explorer_repository.dart';
import 'package:pharma_scan/features/scanner/repositories/scanner_repository.dart';

part 'repositories_providers.g.dart';

@riverpod
ExplorerRepository explorerRepository(Ref ref) {
  final dbService = ref.watch(driftDatabaseServiceProvider);
  return ExplorerRepository(dbService);
}

@riverpod
ScannerRepository scannerRepository(Ref ref) {
  final dbService = ref.watch(driftDatabaseServiceProvider);
  return ScannerRepository(dbService);
}
