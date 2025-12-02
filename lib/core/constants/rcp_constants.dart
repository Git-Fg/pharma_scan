import 'package:pharma_scan/features/explorer/domain/models/rcp_section_model.dart';

class RcpConstants {
  const RcpConstants._();

  static const List<RcpSection> rcpHierarchy = [
    RcpSection(
      label: '1. Dénomination',
      anchor: '#1._DENOMINATION_DU_MEDICAMENT',
    ),
    RcpSection(
      label: '4. Données Cliniques',
      anchor: '#4._DONNEES_CLINIQUES',
      subSections: [
        RcpSection(
          label: 'Indications',
          anchor: '#4.1._Indications_thérapeutiques',
        ),
        RcpSection(
          label: 'Posologie',
          anchor: '#4.2._Posologie_et_mode_d_administration',
        ),
        RcpSection(
          label: 'Contre-indications',
          anchor: '#4.3._Contre-indications',
        ),
        RcpSection(
          label: 'Mises en garde',
          anchor: '#4.4._Mises_en_garde_spéciales_et_précautions_d_emploi',
        ),
      ],
    ),
    RcpSection(
      label: '5. Propriétés Pharmaco.',
      anchor: '#5._PROPRIETES_PHARMACOLOGIQUES',
      subSections: [
        RcpSection(
          label: 'Pharmacodynamie',
          anchor: '#5.1._Propriétés_pharmacodynamiques',
        ),
        RcpSection(
          label: 'Pharmacocinétique',
          anchor: '#5.2._Propriétés_pharmacocinétiques',
        ),
      ],
    ),
    RcpSection(
      label: '6. Données Pharmaceutiques',
      anchor: '#6._DONNEES_PHARMACEUTIQUES',
    ),
  ];
}
