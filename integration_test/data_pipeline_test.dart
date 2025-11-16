import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  // Nettoyer et réinitialiser la base de données avant chaque test
  setUp(() async {
    DatabaseService.resetDatabase();
    await DatabaseService.instance.clearDatabase();
  });

  testWidgets('Pipeline de données complet', (WidgetTester tester) async {
    // GIVEN: Une base de données vide et un service d'initialisation
    final dataService = DataInitializationService();
    final dbService = DatabaseService.instance;

    // WHEN: On exécute le processus d'initialisation complet
    // Cela va télécharger, décompresser, parser et insérer les données.
    await dataService.initializeDatabase();

    // THEN: On vérifie que les données ont été correctement insérées
    
    // Vérifier d'abord que des données ont été insérées en interrogeant directement la base
    final db = await dbService.database;
    final medicamentCount = await db.rawQuery('SELECT COUNT(*) as count FROM medicaments');
    final count = medicamentCount.first['count'] as int;
    expect(count, greaterThan(0), reason: "Aucun médicament n'a été inséré dans la base de données");
    
    // Vérifier qu'il y a des génériques
    final generiqueCount = await db.rawQuery('SELECT COUNT(*) as count FROM generiques');
    final genCount = generiqueCount.first['count'] as int;
    expect(genCount, greaterThan(0), reason: "Aucun générique n'a été inséré dans la base de données");
    
    // Trouver un générique quelconque pour vérifier que la requête fonctionne
    final generiques = await db.rawQuery('SELECT code_cip FROM generiques LIMIT 1');
    if (generiques.isNotEmpty) {
      final codeCipGenerique = generiques.first['code_cip'] as String;
      final medicamentResult = await dbService.getGenericMedicamentByCip(codeCipGenerique);
      
      expect(medicamentResult, isNotNull, reason: "Le médicament générique n'a pas été trouvé avec le CIP: $codeCipGenerique");
      expect(medicamentResult!.nom, isNotEmpty);
      expect(medicamentResult.principesActifs, isNotEmpty);
    }
    
    // Vérifier qu'un médicament qui n'est pas un générique retourne null
    // On prend un médicament qui n'est pas dans la table generiques
    final nonGeneriques = await db.rawQuery('''
      SELECT m.code_cip FROM medicaments m 
      LEFT JOIN generiques g ON m.code_cip = g.code_cip 
      WHERE g.code_cip IS NULL 
      LIMIT 1
    ''');
    if (nonGeneriques.isNotEmpty) {
      final codeCipPrinceps = nonGeneriques.first['code_cip'] as String;
      final nonGeneriqueResult = await dbService.getGenericMedicamentByCip(codeCipPrinceps);
      expect(nonGeneriqueResult, isNull, reason: "Un princeps a été incorrectement identifié comme générique: $codeCipPrinceps");
    }

  }, timeout: const Timeout(Duration(minutes: 5))); // Augmenter le timeout car le téléchargement peut être long
}

