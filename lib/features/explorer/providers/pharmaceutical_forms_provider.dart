import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pharmaceutical_forms_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<String>> administrationRoutes(Ref ref) async {
  final libraryDao = ref.watch(libraryDaoProvider);
  return libraryDao.getDistinctRoutes();
}
