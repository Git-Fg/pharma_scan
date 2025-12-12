import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/views.drift.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';

GroupDetailEntity _detail({
  required String groupId,
  required String codeCip,
  required String cisCode,
  required bool isPrinceps,
  String nomCanonique = 'NOM CANONIQUE',
  String princepsDeReference = 'PRINCEPS REF',
  String princepsBrandName = 'BRAND',
  String? formePharmaceutique,
  String? formattedDosage,
  String? summaryTitulaire,
  String? officialTitulaire,
  String? status,
  String? conditionsPrescription,
  double? prixPublic,
  String? tauxRemboursement,
  String? ansmAlertUrl,
  bool isHospitalOnly = false,
  bool isDental = false,
  bool isList1 = false,
  bool isList2 = false,
  bool isNarcotic = false,
  bool isException = false,
  bool isRestricted = false,
  bool isOtc = true,
  String? availabilityStatus,
  List<String> principes = const ['PARACETAMOL'],
}) {
  final data = ViewGroupDetail(
    groupId: groupId,
    codeCip: codeCip,
    cisCode: cisCode,
    nomCanonique: nomCanonique,
    princepsDeReference: princepsDeReference,
    princepsBrandName: princepsBrandName,
    isPrinceps: isPrinceps,
    status: status,
    formePharmaceutique: formePharmaceutique,
    principesActifsCommuns: principes.join(','),
    formattedDosage: formattedDosage,
    summaryTitulaire: summaryTitulaire,
    officialTitulaire: officialTitulaire,
    nomSpecialite: nomCanonique,
    procedureType: 'AMM',
    conditionsPrescription: conditionsPrescription,
    isSurveillance: false,
    memberType: 0,
    prixPublic: prixPublic,
    tauxRemboursement: tauxRemboursement,
    ansmAlertUrl: ansmAlertUrl,
    isHospitalOnly: isHospitalOnly,
    isDental: isDental,
    isList1: isList1,
    isList2: isList2,
    isNarcotic: isNarcotic,
    isException: isException,
    isRestricted: isRestricted,
    isOtc: isOtc,
    availabilityStatus: availabilityStatus,
  );
  return GroupDetailEntity.fromData(data);
}

void main() {
  group('ViewGroupDetailPresentation', () {
    test('displayName picks princeps label for princeps', () {
      final detail = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        princepsDeReference: 'DOLIPRANE 500 mg',
        nomCanonique: 'DOLIPRANE 500 mg - cp',
      );

      expect(detail.displayName, equals('DOLIPRANE 500 mg'));
    });

    test('displayName trims generic name when not princeps', () {
      final detail = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: false,
        nomCanonique: 'GENERIQUO - cp pelliculé',
      );

      expect(detail.displayName, equals('GENERIQUO'));
    });

    test('parsedTitulaire prefers summary then official', () {
      final detail = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        summaryTitulaire: 'LABO SUMMARY',
        officialTitulaire: 'LABO OFFICIAL',
      );
      expect(detail.parsedTitulaire, equals('LABO SUMMARY'));
    });

    test('form/dosage labels trimmed and null-safe', () {
      final detail = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        formePharmaceutique: ' Comprimé ',
        formattedDosage: ' 500 mg ',
      );

      expect(detail.formLabel, equals('Comprimé'));
      expect(detail.dosageLabel, equals('500 mg'));
    });

    test('availability/refund labels trimmed and null-safe', () {
      final detail = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        availabilityStatus: ' Rupture ',
        tauxRemboursement: ' 65% ',
      );

      expect(detail.trimmedAvailabilityStatus, equals('Rupture'));
      expect(detail.trimmedRefundRate, equals('65%'));
    });

    test('conditions trimmed and aggregated', () {
      final a = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        conditionsPrescription: 'Liste I, Réservé',
      );
      final b = _detail(
        groupId: 'G1',
        codeCip: 'CIP2',
        cisCode: 'CIS2',
        isPrinceps: false,
        conditionsPrescription: 'Réservé;Usage hospitalier',
      );

      final aggregated = [a, b].aggregateConditions();
      expect(
        aggregated,
        containsAll(['Liste I', 'Réservé', 'Usage hospitalier']),
      );
    });

    test('partitionByPrinceps splits princeps and generics', () {
      final princeps = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
      );
      final generic = _detail(
        groupId: 'G1',
        codeCip: 'CIP2',
        cisCode: 'CIS2',
        isPrinceps: false,
      );

      final partition = [princeps, generic].partitionByPrinceps();
      expect(partition.princeps.length, 1);
      expect(partition.generics.length, 1);
      expect(partition.princeps.first.codeCip, equals('CIP1'));
      expect(partition.generics.first.codeCip, equals('CIP2'));
    });

    test('extractPrincepsCisCode returns cis of first princeps', () {
      final princeps = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
      );
      final generic = _detail(
        groupId: 'G1',
        codeCip: 'CIP2',
        cisCode: 'CIS2',
        isPrinceps: false,
      );

      final cis = [generic, princeps].extractPrincepsCisCode();
      expect(cis, equals('CIS1'));
    });

    test('extractAnsmAlertUrl trims and returns null when empty', () {
      final detail = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        ansmAlertUrl: ' https://ansm.fr/alert ',
      );
      expect([detail].extractAnsmAlertUrl(), equals('https://ansm.fr/alert'));

      final empty = _detail(
        groupId: 'G1',
        codeCip: 'CIP2',
        cisCode: 'CIS2',
        isPrinceps: false,
        ansmAlertUrl: ' ',
      );
      expect([empty].extractAnsmAlertUrl(), isNull);
    });

    test('buildPriceLabel builds single and range labels', () {
      final a = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        prixPublic: 2,
      );
      final b = _detail(
        groupId: 'G1',
        codeCip: 'CIP2',
        cisCode: 'CIS2',
        isPrinceps: false,
        prixPublic: 4,
      );

      expect([a].buildPriceLabel(), contains('2,00'));
      expect(
        [a, b].buildPriceLabel(),
        allOf(contains('2,00'), contains('4,00')),
      );
    });

    test('buildRefundLabel aggregates distinct rates', () {
      final a = _detail(
        groupId: 'G1',
        codeCip: 'CIP1',
        cisCode: 'CIS1',
        isPrinceps: true,
        tauxRemboursement: '65%',
      );
      final b = _detail(
        groupId: 'G1',
        codeCip: 'CIP2',
        cisCode: 'CIS2',
        isPrinceps: false,
        tauxRemboursement: '30%',
      );

      final label = [a, b].buildRefundLabel();
      expect(label, contains('65%'));
      expect(label, contains('30%'));
    });

    test(
      'sortedBySmartComparator sorts by shortage then hospital then name',
      () {
        final a = _detail(
          groupId: 'G1',
          codeCip: 'CIP1',
          cisCode: 'CIS1',
          isPrinceps: true,
          nomCanonique: 'A MED',
          availabilityStatus: 'RUPTURE',
        );
        final b = _detail(
          groupId: 'G1',
          codeCip: 'CIP2',
          cisCode: 'CIS2',
          isPrinceps: false,
          nomCanonique: 'B MED',
          isHospitalOnly: true,
        );
        final c = _detail(
          groupId: 'G1',
          codeCip: 'CIP3',
          cisCode: 'CIS3',
          isPrinceps: false,
          nomCanonique: 'C MED',
        );

        final sorted = [c, b, a].sortedBySmartComparator();
        expect(sorted.first.codeCip, equals('CIP3')); // none first
        expect(sorted[1].codeCip, equals('CIP2')); // hospital-only next
        expect(
          sorted.last.codeCip,
          equals('CIP1'),
        ); // shortage last by comparator
      },
    );
  });
}
