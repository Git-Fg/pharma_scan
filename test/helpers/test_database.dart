import 'package:drift/native.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

/// Crée une instance réelle de la DB, mais en mémoire (rapide + volatile)
/// Utile pour tester la logique métier complexe sans dépendre de fichiers réels
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
        logStatements: false), // Activez logStatements pour débugger le SQL
    LoggerService(),
  );
}
