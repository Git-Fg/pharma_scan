/// Test products data for E2E testing
///
/// This file contains CIP codes and product information for comprehensive
/// test coverage including controlled substances, generics, out-of-stock items,
/// and various medication types.
class TestProducts {
  // --- Princeps Medicaments (Common OTC Drugs) ---

  /// Doliprane 1000 mg - Most common paracetamol in France
  static const String doliprane1000Cip = '3400934168322';
  static const String doliprane1000Name = 'DOLIPRANE 1000 mg';
  static const String doliprane1000Labo = 'SANOFI AVENTIS FRANCE';

  /// Doliprane 500 mg - Standard paracetamol
  static const String doliprane500Cip = '3400930012345';
  static const String doliprane500Name = 'DOLIPRANE 500 mg';
  static const String doliprane500Labo = 'SANOFI AVENTIS FRANCE';

  /// Ibuprofene 400 mg - Common anti-inflammatory
  static const String ibuprofene400Cip = '3400933632993';
  static const String ibuprofene400Name = 'IBUPROFENE BIOGARAN 400 mg';
  static const String ibuprofene400Labo = 'BIOGARAN';

  /// Aspirine 500 mg - Classic painkiller
  static const String aspirine500Cip = '3400930015678';
  static const String aspirine500Name = 'ASPIRINE UPSA 500 mg';
  static const String aspirine500Labo = 'UPSALAB';

  // --- Generic Medicaments ---

  /// Paracetamol Biogaran 1000 mg - Generic equivalent of Doliprane
  static const String genericDolipraneCip = '3400934168339';
  static const String genericDolipraneName = 'PARACETAMOL BIOGARAN 1000 mg';
  static const String genericDolipraneLabo = 'BIOGARAN';

  /// Amoxicilline Generic - Common antibiotic
  static const String genericAmoxicillineCip = '3400939123456';
  static const String genericAmoxicillineName = 'AMOXICILLINE MYLAN 500 mg';
  static const String genericAmoxicillineLabo = 'MYLAN';

  // --- Controlled Substances & Prescription Medications ---

  /// Ventoline - Controlled asthma medication
  static const String ventolineCip = '3400936473331';
  static const String ventolineName = 'VENTOLINE 100 microgrammes/dose';
  static const String ventolineLabo = 'GLAXO SMITHKLINE';

  /// Methadone - Simulated controlled substance (for testing controlled features)
  static const String methadoneCip = '3400930012345';
  static const String methadoneName = 'METHADONE CHLORHYDRATE 10 mg';
  static const String methadoneLabo = 'SPECIAL PHARMACEUTIQUE';

  /// Oxycodone - Strong opioid (simulated for testing)
  static const String oxycodoneCip = '3400930098765';
  static const String oxycodoneName = 'OXYCODONE 10 mg';
  static const String oxycodoneLabo = 'MUNDIPHARMA';

  /// Rivotril - Benzodiazepine (simulated for testing)
  static const String rivotrilCip = '3400930054321';
  static const String rivotrilName = 'RIVOTRIL 2 mg';
  static const String rivotrilLabo = 'ROCHE';

  // --- Antibiotics ---

  /// Amoxicilline 500 mg - Most common antibiotic
  static const String amoxicilline500Cip = '3400930134055';
  static const String amoxicilline500Name = 'AMOXICILLINE 500 mg';
  static const String amoxicilline500Labo = 'UNKNOWN LABORATORY';

  /// Amoxicilline 1000 mg - Higher dose antibiotic
  static const String amoxicilline1000Cip = '3400930134062';
  static const String amoxicilline1000Name = 'AMOXICILLINE 1000 mg';
  static const String amoxicilline1000Labo = 'UNKNOWN LABORATORY';

  // --- Special Formulations ---

  /// Effervescent medication
  static const String effervescentCip = '3400930033333';
  static const String effervescentName = 'VITAMINE C UPSA 500 mg EFFERVESCENT';
  static const String effervescentLabo = 'UPSALAB';

  /// Injectable medication
  static const String injectableCip = '3400930044444';
  static const String injectableName = 'DOLIPRANE 2 g/10 ml INJECTABLE';
  static const String injectableLabo = 'SANOFI AVENTIS FRANCE';

  /// Suppository medication
  static const String suppositoryCip = '3400930055555';
  static const String suppositoryName = 'PARACETAMOL 500 mg SUPPOSITORY';
  static const String suppositoryLabo = 'BIOGARAN';

  /// Eye drops
  static const String eyeDropsCip = '3400930066666';
  static const String eyeDropsName = 'DAFILAN 0.1% COLLYRE';
  static const String eyeDropsLabo = 'EUROMED PHARMACEUTICALS';

  // --- Out-of-Stock or Discontinued Items ---

  /// Simulated out-of-stock medication
  static const String outOfStockCip = '3400999999999';
  static const String outOfStockName = 'MEDICAMENT TEMPORAIREMENT INDISPONIBLE';
  static const String outOfStockLabo = 'UNKNOWN LABORATORY';

  /// Discontinued medication
  static const String discontinuedCip = '3400988888888';
  static const String discontinuedName = 'MEDICAMENT RETIRE DU MARCHE';
  static const String discontinuedLabo = 'UNKNOWN LABORATORY';

  // --- Chronic Disease Medications ---

  /// Diabetes medication
  static const String diabetesCip = '3400930077777';
  static const String diabetesName = 'METFORMINE 850 mg';
  static const String diabetesLabo = 'MYLAN';

  /// Hypertension medication
  static const String hypertensionCip = '3400930088888';
  static const String hypertensionName = 'LISINOPRIL 10 mg';
  static const String hypertensionLabo = 'RANBAXY';

  /// Cholesterol medication
  static const String cholesterolCip = '3400930099999';
  static const String cholesterolName = 'ATORVASTATINE 20 mg';
  static const String cholesterolLabo = 'PFIZER';

  // --- Pediatric Medications ---

  /// Children's paracetamol
  static const String pediatricCip = '3400930111111';
  static const String pediatricName = 'DOLIPRANE ENFANT 100 mg';
  static const String pediatricLabo = 'SANOFI AVENTIS FRANCE';

  /// Baby syrup
  static const String babySyrupCip = '3400930122222';
  static const String babySyrupName = 'HUMEX LARYNX 0.33% SYRUP';
  static const String babySyrupLabo = 'UCB PHARMA';

  // --- Vaccines (for testing special categories) ---

  /// Flu vaccine
  static const String fluVaccineCip = '3400930133333';
  static const String fluVaccineName = 'VACCIN GRIPPAL INACTIVÉ';
  static const String fluVaccineLabo = 'SANOFI PASTEUR';

  // --- Complex Medications for Testing Scenarios ---

  /// Multiple dosage forms medication
  static const String multiFormCip = '3400930144444';
  static const String multiFormName = 'IBUPROFENE 400 mg COMPRIMÉ';
  static const String multiFormLabo = 'TEVA';

  // --- Product Collections for Different Test Scenarios ---

  /// All controlled substances for testing restricted features
  static const List<Map<String, String>> controlledSubstances = [
    {'cip': methadoneCip, 'name': methadoneName, 'labo': methadoneLabo},
    {'cip': oxycodoneCip, 'name': oxycodoneName, 'labo': oxycodoneLabo},
    {'cip': rivotrilCip, 'name': rivotrilName, 'labo': rivotrilLabo},
    {'cip': ventolineCip, 'name': ventolineName, 'labo': ventolineLabo},
  ];

  /// Generic equivalents for testing generic/princeps relationships
  static const List<Map<String, String>> genericEquivalents = [
    {'cip': genericDolipraneCip, 'name': genericDolipraneName, 'labo': genericDolipraneLabo, 'princeps': doliprane1000Name},
    {'cip': genericAmoxicillineCip, 'name': genericAmoxicillineName, 'labo': genericAmoxicillineLabo, 'princeps': 'AMOXICILLINE 500 mg'},
  ];

  /// Out-of-stock and discontinued items
  static const List<Map<String, String>> unavailableItems = [
    {'cip': outOfStockCip, 'name': outOfStockName, 'labo': outOfStockLabo, 'status': 'out_of_stock'},
    {'cip': discontinuedCip, 'name': discontinuedName, 'labo': discontinuedLabo, 'status': 'discontinued'},
  ];

  /// Common OTC medications for basic functionality testing
  static const List<Map<String, String>> commonMedications = [
    {'cip': doliprane1000Cip, 'name': doliprane1000Name, 'labo': doliprane1000Labo},
    {'cip': doliprane500Cip, 'name': doliprane500Name, 'labo': doliprane500Labo},
    {'cip': ibuprofene400Cip, 'name': ibuprofene400Name, 'labo': ibuprofene400Labo},
    {'cip': aspirine500Cip, 'name': aspirine500Name, 'labo': aspirine500Labo},
  ];

  /// Antibiotics for testing prescription requirements
  static const List<Map<String, String>> antibiotics = [
    {'cip': amoxicilline500Cip, 'name': amoxicilline500Name, 'labo': amoxicilline500Labo},
    {'cip': amoxicilline1000Cip, 'name': amoxicilline1000Name, 'labo': amoxicilline1000Labo},
    {'cip': genericAmoxicillineCip, 'name': genericAmoxicillineName, 'labo': genericAmoxicillineLabo},
  ];

  /// Special formulations for testing diverse medication types
  static const List<Map<String, String>> specialFormulations = [
    {'cip': effervescentCip, 'name': effervescentName, 'labo': effervescentLabo, 'form': 'effervescent'},
    {'cip': injectableCip, 'name': injectableName, 'labo': injectableLabo, 'form': 'injectable'},
    {'cip': suppositoryCip, 'name': suppositoryName, 'labo': suppositoryLabo, 'form': 'suppository'},
    {'cip': eyeDropsCip, 'name': eyeDropsName, 'labo': eyeDropsLabo, 'form': 'eye_drops'},
  ];

  // --- Utility Methods ---

  /// Get product info by CIP code
  static Map<String, String>? getProductByCip(String cip) {
    final allProducts = [
      ...controlledSubstances,
      ...genericEquivalents,
      ...unavailableItems,
      ...commonMedications,
      ...antibiotics,
      ...specialFormulations,
    ];

    for (final product in allProducts) {
      if (product['cip'] == cip) {
        return product;
      }
    }
    return null;
  }

  /// Get products by category
  static List<Map<String, String>> getProductsByCategory(String category) {
    switch (category.toLowerCase()) {
      case 'controlled':
        return controlledSubstances;
      case 'generic':
        return genericEquivalents;
      case 'unavailable':
        return unavailableItems;
      case 'common':
        return commonMedications;
      case 'antibiotic':
        return antibiotics;
      case 'special':
        return specialFormulations;
      default:
        return commonMedications;
    }
  }

  /// Get products requiring prescription
  static List<Map<String, String>> getPrescriptionOnlyMedications() {
    return [
      ...controlledSubstances,
      ...antibiotics,
      {'cip': oxycodoneCip, 'name': oxycodoneName, 'labo': oxycodoneLabo},
    ];
  }

  /// Get OTC medications
  static List<Map<String, String>> getOtcMedications() {
    return commonMedications;
  }

  /// Search products by name
  static List<Map<String, String>> searchProductsByName(String searchTerm) {
    final allProducts = [
      ...controlledSubstances,
      ...genericEquivalents,
      ...unavailableItems,
      ...commonMedications,
      ...antibiotics,
      ...specialFormulations,
    ];

    return allProducts.where((product) {
      final name = product['name']?.toLowerCase() ?? '';
      final labo = product['labo']?.toLowerCase() ?? '';
      final searchLower = searchTerm.toLowerCase();

      return name.contains(searchLower) || labo.contains(searchLower);
    }).toList();
  }

  /// Get random product for testing
  static Map<String, String> getRandomProduct() {
    final allProducts = [
      ...controlledSubstances,
      ...genericEquivalents,
      ...unavailableItems,
      ...commonMedications,
      ...antibiotics,
      ...specialFormulations,
    ];

    final random = DateTime.now().millisecondsSinceEpoch % allProducts.length;
    return allProducts[random];
  }

  /// Validate CIP code format
  static bool isValidCip(String cip) {
    // CIP codes should be 13 digits starting with 34009
    return RegExp(r'^34009\d{8}$').hasMatch(cip);
  }
}