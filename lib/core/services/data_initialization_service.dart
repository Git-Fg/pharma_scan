// lib/core/services/data_initialization_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';

class DataInitializationService {
  final Map<String, String> _dataUrls = {
    'specialites':
        'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt',
    'medicaments':
        'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt',
    'compositions':
        'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_COMPO_bdpm.txt',
    'generiques':
        'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_GENER_bdpm.txt',
  };

  final dbService = sl<DatabaseService>();

  Future<File> _downloadFile(String url, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('Failed to download $filename');
    }
  }

  String _decodeContent(List<int> bytes) {
    try {
      return latin1.decode(bytes);
    } catch (e) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  Future<void> initializeDatabase() async {
    final specialitesFile = await _downloadFile(
      _dataUrls['specialites']!,
      'CIS_bdpm.txt',
    );
    final medicamentsFile = await _downloadFile(
      _dataUrls['medicaments']!,
      'CIS_CIP_bdpm.txt',
    );
    final compositionsFile = await _downloadFile(
      _dataUrls['compositions']!,
      'CIS_COMPO_bdpm.txt',
    );
    final generiquesFile = await _downloadFile(
      _dataUrls['generiques']!,
      'CIS_GENER_bdpm.txt',
    );

    // --- Data Parsing ---

    // 1. Parse Specialites (clean names and procedure types)
    final specialites = <Map<String, dynamic>>[];
    final seenCis = <String>{};
    final specialitesContent = _decodeContent(
      specialitesFile.readAsBytesSync(),
    );
    for (final line in specialitesContent.split('\n')) {
      final parts = line.split('\t');
      // WHY: On vérifie la présence d'au moins 11 colonnes pour accéder au titulaire (index 10) en toute sécurité.
      if (parts.length >= 11) {
        final cis = parts[0].trim();
        final nom = parts[1].trim();
        final forme = parts[2].trim(); // Forme pharmaceutique
        final procedure = parts[5].trim();
        final commercialisation = parts[6].trim(); // État de commercialisation
        final titulaire = parts[10].trim(); // Titulaire (laboratoire)

        if (cis.isNotEmpty && nom.isNotEmpty && seenCis.add(cis)) {
          specialites.add({
            'cis_code': cis,
            'nom_specialite': nom,
            'procedure_type': procedure,
            'forme_pharmaceutique': forme,
            'etat_commercialisation': commercialisation,
            'titulaire': titulaire,
          });
        }
      }
    }

    // WHY: One CIS can map to multiple CIP13 codes (different packagings of the same medication)
    // This is a one-to-many relationship that must be handled correctly.
    final cisToCip13 = <String, List<String>>{};
    final medicaments = <Map<String, dynamic>>[];
    final medicamentCips = <String>{};

    final medicamentsContent = _decodeContent(
      medicamentsFile.readAsBytesSync(),
    );
    for (final line in medicamentsContent.split('\n')) {
      final parts = line.split('\t');
      // WHY: Real-world file structure requires at least 7 columns to contain the CIP13 at index 6
      // Column order: [0]=CIS, [2]=Libellé (nom), [6]=CIP13
      if (parts.length >= 7) {
        final cis = parts[0].trim();
        // CORRECTED: The name/description is at index 2
        final nom = parts[2].trim();
        // CORRECTED: The CIP13 is at index 6
        final cip13 = parts[6].trim();

        if (cis.isNotEmpty &&
            cip13.isNotEmpty &&
            nom.isNotEmpty &&
            seenCis.contains(cis)) {
          // Add the CIP13 to the list for the given CIS (handles one-to-many relationship)
          cisToCip13.putIfAbsent(cis, () => []).add(cip13);

          if (medicamentCips.add(cip13)) {
            medicaments.add({'code_cip': cip13, 'nom': nom, 'cis_code': cis});
          }
        }
      }
    }

    // 2. Parse compositions
    final principes = <Map<String, dynamic>>[];
    final compositionsContent = _decodeContent(
      compositionsFile.readAsBytesSync(),
    );
    for (final line in compositionsContent.split('\n')) {
      final parts = line.split('\t');
      // Per documentation: CIS, Element, Code Substance, Denomination, ..., Nature (SA/ST)
      if (parts.length >= 8 && parts[6].trim() == 'SA') {
        final cis = parts[0].trim();
        final principe = parts[3].trim();
        final dosageStr = parts[4].trim(); // Dosage (ex: "500 mg")

        // Get the list of CIP13s for this CIS
        final cip13s = cisToCip13[cis];
        if (cip13s != null && principe.isNotEmpty) {
          double? dosageValue;
          String? dosageUnit;

          // WHY: On sépare la valeur numérique de son unité pour un stockage structuré.
          if (dosageStr.isNotEmpty) {
            final dosageParts = dosageStr.split(' ');
            if (dosageParts.isNotEmpty) {
              dosageValue = double.tryParse(
                dosageParts[0].replaceAll(',', '.'),
              );
              if (dosageParts.length > 1) {
                dosageUnit = dosageParts.sublist(1).join(' ');
              }
            }
          }

          // Add the principle for EACH associated CIP13
          for (final cip13 in cip13s) {
            principes.add({
              'code_cip': cip13,
              'principe': principe,
              'dosage': dosageValue,
              'dosage_unit': dosageUnit,
            });
          }
        }
      }
    }

    // 3. Parse generic groups (the new source of truth)
    final generiqueGroups = <Map<String, dynamic>>[];
    final groupMembers = <Map<String, dynamic>>[];
    final seenGroups = <String>{};

    final generiquesContent = _decodeContent(generiquesFile.readAsBytesSync());
    for (final line in generiquesContent.split('\n')) {
      final parts = line.split('\t');
      // Per documentation: Group ID, Libelle, CIS, Type, Sort Order
      if (parts.length >= 5) {
        final groupId = parts[0].trim();
        final libelle = parts[1].trim();
        final cis = parts[2].trim();
        final type = int.tryParse(parts[3].trim());

        // Get the list of CIP13s for this CIS
        final cip13s = cisToCip13[cis];

        // CORRECTED: A generic can be type 1, 2, or 4.
        final isPrinceps = type == 0;
        final isGeneric = type == 1 || type == 2 || type == 4;

        if (cip13s != null && (isPrinceps || isGeneric)) {
          if (seenGroups.add(groupId)) {
            generiqueGroups.add({'group_id': groupId, 'libelle': libelle});
          }

          // Add EACH CIP13 as a member of the group (handles multiple packagings)
          // Store consistently as 0 for princeps and 1 for all generic types
          for (final cip13 in cip13s) {
            if (medicamentCips.contains(cip13)) {
              groupMembers.add({
                'code_cip': cip13,
                'group_id': groupId,
                'type': isPrinceps ? 0 : 1,
              });
            }
          }
        }
      }
    }

    developer.log(
      'Parsed ${medicaments.length} medicaments, ${principes.length} principles, and ${groupMembers.length} group members.',
      name: 'DataInitService',
    );

    // 4. Insert data into the database
    await dbService.clearDatabase();
    await dbService.insertBatchData(
      specialites: specialites,
      medicaments: medicaments,
      principes: principes,
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
    );
  }
}
