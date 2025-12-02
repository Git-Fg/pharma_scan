class DataSources {
  static const String baseUrl =
      'https://base-donnees-publique.medicaments.gouv.fr/download/file/';

  static const String updatePageUrl =
      'https://base-donnees-publique.medicaments.gouv.fr/telechargement';

  static const Map<String, String> files = {
    'specialites': '${baseUrl}CIS_bdpm.txt',
    'medicaments': '${baseUrl}CIS_CIP_bdpm.txt',
    'compositions': '${baseUrl}CIS_COMPO_bdpm.txt',
    'generiques': '${baseUrl}CIS_GENER_bdpm.txt',
    'conditions': '${baseUrl}CIS_CPD_bdpm.txt',
    'availability': '${baseUrl}CIS_CIP_Dispo_Spec.txt',
    'mitm': '${baseUrl}CIS_MITM.txt',
  };

  /// Generate ANSM fiche URL for a given CIS code
  static String ficheAnsm(String cisCode) =>
      'https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=$cisCode';

  /// Generate ANSM RCP (Résumé des Caractéristiques du Produit) URL for a given CIS code
  static String rcpAnsm(String cisCode) =>
      'https://base-donnees-publique.medicaments.gouv.fr/medicament/$cisCode/extrait#tab-rcp';
}
