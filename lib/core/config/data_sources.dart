// lib/core/config/data_sources.dart

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
}
