import 'package:pharma_scan/core/database/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  // La connexion est gérée en interne par AppDatabase via drift_flutter
  final db = AppDatabase();

  // Fermer la connexion proprement si le provider est détruit (rare avec keepAlive)
  ref.onDispose(db.close);

  return db;
}
