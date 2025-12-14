import 'dart:io';

import 'package:drift/native.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref, {String? overridePath}) {
  final logger = ref.read(loggerProvider);

  // Permet d'injecter un chemin custom pour les tests
  final db = overridePath != null
      ? AppDatabase.forTesting(NativeDatabase(File(overridePath)), logger)
      : AppDatabase(logger);

  ref.onDispose(() async {
    await db.close();
  });

  return db;
}
