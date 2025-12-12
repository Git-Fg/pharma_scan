import 'dart:convert';

import 'package:pharma_scan/core/database/database.dart';
import 'seed_builder.dart';

/// Preconfigured database seeds for common integration scenarios.
/// Updated to work directly with medicament_summary table for Server-Side ETL architecture.
class TestScenarios {
  const TestScenarios._();

  /// Seeds a basic Paracetamol group with one princeps and one generic.
  /// Data is inserted directly into medicament_summary table.
  static Future<void> seedParacetamolGroup(AppDatabase db) async {
    await SeedBuilder()
        .inCluster('PARACETAMOL', 'Paracétamol', substanceCode: 'Paracetamol')
        .addPrinceps(
          'Doliprane 500mg',
          'CIS_DOLIPRANE_500',
          cipCode: '3400930012345',
          dosage: '500 mg',
          form: 'Comprimé',
          lab: 'SANOFI AVENTIS FRANCE',
        )
        .addGeneric(
          'Paracétamol Biogaran 500mg',
          'CIS_PARA_BIO_500',
          cipCode: '3400935432109',
          dosage: '500 mg',
          form: 'Comprimé',
          lab: 'BIOGARAN',
          princepsName: 'Doliprane 500mg',
        )
        .insertInto(db);
  }

  /// Seeds a slightly richer Paracetamol set for restock flows (adds a variant).
  /// Includes multiple dosages and forms for comprehensive testing.
  static Future<void> seedParacetamolRestock(AppDatabase db) async {
    await SeedBuilder()
        .inCluster('PARACETAMOL', 'Paracétamol', substanceCode: 'Paracetamol')
        .addPrinceps(
          'Doliprane 500mg',
          'CIS_DOLIPRANE_500',
          cipCode: '3400930012345',
          dosage: '500 mg',
          form: 'Comprimé',
          lab: 'SANOFI AVENTIS FRANCE',
        )
        .addGeneric(
          'Paracétamol Biogaran 500mg',
          'CIS_PARA_BIO_500',
          cipCode: '3400935432109',
          dosage: '500 mg',
          form: 'Comprimé',
          lab: 'BIOGARAN',
          princepsName: 'Doliprane 500mg',
        )
        .addPrinceps(
          'Doliprane 1000mg',
          'CIS_DOLIPRANE_1000',
          cipCode: '3400930067890',
          dosage: '1000 mg',
          form: 'Comprimé',
          lab: 'SANOFI AVENTIS FRANCE',
        )
        .addGeneric(
          'Paracétamol Zentiva 1000mg',
          'CIS_PARA_ZEN_1000',
          cipCode: '3400939876543',
          dosage: '1000 mg',
          form: 'Comprimé',
          lab: 'ZENTIVA FRANCE',
          princepsName: 'Doliprane 1000mg',
        )
        .insertInto(db);
  }

  /// Seeds an Ibuprofen group with medications for anti-inflammatory testing.
  static Future<void> seedIbuprofenGroup(AppDatabase db) async {
    await SeedBuilder()
        .inCluster('IBUPROFEN', 'Ibuprofène', substanceCode: 'Ibuprofène')
        .addPrinceps(
          'Advil 200mg',
          'CIS_ADVIL_200',
          cipCode: '3400931111111',
          dosage: '200 mg',
          form: 'Gélule',
          lab: 'PFIZER',
        )
        .addGeneric(
          'Ibuprofène Mylan 200mg',
          'CIS_IBU_MYL_200',
          cipCode: '3400932222222',
          dosage: '200 mg',
          form: 'Gélule',
          lab: 'MYLAN',
          princepsName: 'Advil 200mg',
        )
        .addPrinceps(
          'Advil 400mg',
          'CIS_ADVIL_400',
          cipCode: '3400933333333',
          dosage: '400 mg',
          form: 'Comprimé',
          lab: 'PFIZER',
          isOtc: false,
        )
        .insertInto(db);
  }

  /// Seeds antibiotics with prescription-only status for testing restricted access.
  static Future<void> seedAntibioticGroup(AppDatabase db) async {
    await SeedBuilder()
        .inCluster('AMOXICILLIN', 'Amoxicilline', substanceCode: 'Amoxicilline')
        .addPrinceps(
          'Augmentin 500mg',
          'CIS_AUGMENTIN_500',
          cipCode: '3400934444444',
          dosage: '500 mg',
          form: 'Comprimé',
          lab: 'GLAXOSMITHKLINE',
          isOtc: false,
          isRestricted: true,
          conditionsPrescription: "Médicament réservé à l'usage professionnel",
          atcCode: 'J01CR02',
        )
        .addGeneric(
          'Amoxicilline Arrow 500mg',
          'CIS_AMOX_ARR_500',
          cipCode: '3400935555555',
          dosage: '500 mg',
          form: 'Comprimé',
          lab: 'ARROW GENERIQUES',
          princepsName: 'Augmentin 500mg',
          isOtc: false,
          isRestricted: true,
        )
        .insertInto(db);
  }

  /// Seeds a comprehensive dataset for smoke testing.
  /// Includes various medication types and categories.
  static Future<void> seedComprehensiveDataset(AppDatabase db) async {
    await Future.wait([
      seedParacetamolGroup(db),
      seedIbuprofenGroup(db),
      seedAntibioticGroup(db),
    ]);

    // Add additional standalone medications
    await SeedBuilder()
        .addMedication(
          cisCode: 'CIS_VITAMIN_C',
          nomCanonique: 'Vitamine C 500mg',
          princepsDeReference: 'Vitamine C',
          cipCode: '3400937777777',
          formattedDosage: '500 mg',
          formePharmaceutique: 'Comprimé à croquer',
          labName: 'MERCK',
          principesActifsCommuns: jsonEncode(['Acide ascorbique']),
        )
        .addMedication(
          cisCode: 'CIS_OMEPRAZOLE',
          nomCanonique: 'Mopral 20mg',
          princepsDeReference: 'Mopral',
          cipCode: '3400938888888',
          formattedDosage: '20 mg',
          formePharmaceutique: 'Gélule gastro-résistante',
          labName: 'ASTRAZENECA',
          isOtc: false,
          isList1: true,
          atcCode: 'A02BC01',
          principesActifsCommuns: jsonEncode(['Oméprazole']),
        )
        .insertInto(db);
  }

  /// Seeds data specifically for testing the search functionality.
  /// Includes medications with accents, special characters, and various naming patterns.
  static Future<void> seedSearchTestData(AppDatabase db) async {
    await SeedBuilder()
        .inCluster('PARACETAMOL', 'Paracétamol')
        .addPrinceps(
          'Doliprane® 500mg',
          'CIS_DOLIPRANE_ACCENT',
          cipCode: '3400939999999',
          dosage: '500 mg',
          lab: 'SANOFI',
        )
        .addGeneric(
          'Paracétamol - Mylan',
          'CIS_PARA_HYPHEN',
          cipCode: '3400930000000',
          dosage: '500 mg',
          lab: 'MYLAN',
          princepsName: 'Doliprane® 500mg',
        )
        .addPrinceps(
          'Efferalgan 500mg',
          'CIS_EFFERALGAN',
          cipCode: '3400931111112',
          dosage: '500 mg',
          form: 'Comprimé effervescent',
          lab: 'UPS',
        )
        .insertInto(db);
  }
}
