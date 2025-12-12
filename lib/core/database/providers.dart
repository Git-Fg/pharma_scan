import 'package:pharma_scan/core/database/connection/open_connection.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  // On injecte la connexion définie dans open_connection.dart
  final db = AppDatabase(openDownloadedDatabase());

  // Fermer la connexion proprement si le provider est détruit (rare avec keepAlive)
  ref.onDispose(db.close);

  return db;
}
