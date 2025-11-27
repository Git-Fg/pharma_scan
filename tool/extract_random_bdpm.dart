// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Script utilitaire pour générer un échantillon de données BDPM.
/// Usage: dart run tool/extract_random_bdpm.dart
void main() async {
  final dataDir = Directory('tool/data');
  final outputFilePath = 'tool/data/randomvaluebdpm.txt';
  final outputFile = File(outputFilePath);
  final random = Random();

  // Nettoyage du fichier de sortie précédent
  if (await outputFile.exists()) {
    await outputFile.delete();
  }

  // Vérification du dossier
  if (!await dataDir.exists()) {
    print('❌ Le dossier tool/data/ n\'existe pas.');
    return;
  }

  final files = dataDir.listSync().whereType<File>().where((file) {
    return file.path.endsWith('.txt') &&
        !file.path.contains(
          'randomvaluebdpm.txt',
        ); // Exclure le fichier de sortie
  }).toList();

  if (files.isEmpty) {
    print('❌ Aucun fichier .txt trouvé dans tool/data/');
    return;
  }

  print('🔄 Traitement de ${files.length} fichiers...');

  final buffer = StringBuffer();
  buffer.writeln('=== EXTRAITS ALÉATOIRES BDPM (100 lignes/fichier) ===');
  buffer.writeln('Généré le : ${DateTime.now()}\n');

  for (final file in files) {
    final filename = file.uri.pathSegments.last;
    print('   📄 Lecture de $filename...');

    try {
      // NOTE : Les fichiers BDPM sont encodés en Latin-1 (ISO-8859-1), pas en UTF-8.
      // Si on lit en UTF-8, on aura des crashs ou des caractères corrompus.
      final rawLines = await file.readAsLines(encoding: latin1);

      // WHY: BOIRON flood de granules/doses rend l'échantillon illisible.
      final lines = rawLines
          .where((line) => !line.toUpperCase().contains('BOIRON'))
          .toList();

      if (lines.isEmpty) {
        buffer.writeln('\n--- FICHIER : $filename (Vide) ---\n');
        continue;
      }

      // Sélection aléatoire
      final List<String> selectedLines;
      if (lines.length <= 200) {
        selectedLines = lines;
      } else {
        // Mélange optimisé pour ne pas copier toute la liste si elle est énorme
        // On crée une liste d'indices et on en prend 200 au hasard
        final indices = <int>{};
        while (indices.length < 200) {
          indices.add(random.nextInt(lines.length));
        }
        selectedLines = indices.map((i) => lines[i]).toList();
      }

      // Écriture dans le buffer
      buffer.writeln('\n' + ('=' * 50));
      buffer.writeln('FICHIER : $filename');
      buffer.writeln(
        'Lignes totales : ${lines.length} | Extraites : ${selectedLines.length}',
      );
      buffer.writeln(('=' * 50) + '\n');

      for (final line in selectedLines) {
        buffer.writeln(line);
      }
    } catch (e) {
      print('⚠️ Erreur lors de la lecture de $filename : $e');
      buffer.writeln('\n--- FICHIER : $filename (Erreur de lecture) ---\n');
      buffer.writeln('Erreur : $e');
    }
  }

  // Sauvegarde finale
  await outputFile.writeAsString(buffer.toString(), encoding: utf8);

  print('✅ Terminé !');
  print('📁 Résultat disponible dans : $outputFilePath');
}
