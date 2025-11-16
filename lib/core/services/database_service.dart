// lib/core/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  // Factory optionnelle pour les tests (définie par sqflite_common_ffi)
  static DatabaseFactory? testFactory;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medicaments.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Utiliser la factory de test si disponible, sinon utiliser sqflite normal
    if (testFactory != null) {
      final dbPath = await testFactory!.getDatabasesPath();
      final path = join(dbPath, filePath);
      return await testFactory!.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
      );
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Table pour stocker les informations de base des médicaments
    await db.execute('''
      CREATE TABLE medicaments (
        code_cip TEXT PRIMARY KEY,
        nom TEXT NOT NULL
      )
    ''');
    
    // Table pour lier les médicaments à leurs principes actifs
    await db.execute('''
      CREATE TABLE principes_actifs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_cip TEXT NOT NULL,
        principe TEXT NOT NULL,
        FOREIGN KEY (code_cip) REFERENCES medicaments (code_cip)
      )
    ''');

    // Table pour identifier les génériques
    await db.execute('''
      CREATE TABLE generiques (
        code_cip TEXT PRIMARY KEY,
        FOREIGN KEY (code_cip) REFERENCES medicaments (code_cip)
      )
    ''');
  }

  // Méthode pour récupérer un médicament générique et ses principes actifs
  Future<Medicament?> getGenericMedicamentByCip(String codeCip) async {
    final db = await instance.database;

    // 1. Vérifier si le médicament est un générique
    final isGenericResult = await db.query(
      'generiques',
      where: 'code_cip = ?',
      whereArgs: [codeCip],
    );

    if (isGenericResult.isEmpty) {
      return null; // Ce n'est pas un générique, on ne fait rien
    }
    
    // 2. Récupérer le nom du médicament
    final medicamentResult = await db.query(
      'medicaments',
      where: 'code_cip = ?',
      whereArgs: [codeCip],
    );

    if (medicamentResult.isEmpty) {
      return null; // Données incohérentes, on ne fait rien
    }
    final nom = medicamentResult.first['nom'] as String;

    // 3. Récupérer tous les principes actifs
    final principesResult = await db.query(
      'principes_actifs',
      where: 'code_cip = ?',
      whereArgs: [codeCip],
    );

    final principes = principesResult.map((row) => row['principe'] as String).toList();

    return Medicament(
      nom: nom,
      codeCip: codeCip,
      principesActifs: principes,
    );
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('principes_actifs');
    await db.delete('generiques');
    await db.delete('medicaments');
  }

  // Méthode pour réinitialiser la connexion à la base de données (utile pour les tests)
  static void resetDatabase() {
    _database?.close();
    _database = null;
  }

  Future<void> insertBatchData(List<Map<String, dynamic>> medicaments,
                                  List<Map<String, dynamic>> principes,
                                  List<Map<String, dynamic>> generiques) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batchMedicaments = txn.batch();
      for (var med in medicaments) {
        batchMedicaments.insert('medicaments', med, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batchMedicaments.commit(noResult: true);

      final batchPrincipes = txn.batch();
      for (var p in principes) {
        batchPrincipes.insert('principes_actifs', p);
      }
      await batchPrincipes.commit(noResult: true);

      final batchGeneriques = txn.batch();
      for (var gen in generiques) {
        batchGeneriques.insert('generiques', gen, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batchGeneriques.commit(noResult: true);
    });
  }
}

