part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

class _GroupAccumulator {
  _GroupAccumulator({required this.rawLabel});

  String rawLabel;
  final List<({String cis, int type})> members = [];
}

Future<Either<ParseError, GeneriquesParseResult>> parseGeneriquesImpl(
  Stream<List<dynamic>>? rows,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
  Map<String, String> compositionMap,
  Map<String, String> specialitesMap,
) async {
  final generiqueGroups = <GeneriqueGroupsCompanion>[];
  final groupMembers = <GroupMembersCompanion>[];
  final seenGroups = <String>{};
  final groupMeta = <String, _GroupAccumulator>{};

  if (rows == null) {
    return Either.right((
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
    ));
  }

  await for (final row in rows) {
    if (row.length < 4) continue;
    final parts = row.map(_cellAsString).toList(growable: false);
    switch (parts) {
      case [
        final groupId,
        final libelle,
        final cis,
        final typeRaw,
        ...,
      ]:
        final type = int.tryParse(typeRaw);
        final cip13s = cisToCip13[cis];
        final isPrinceps = type == 0;
        final isRecognizedGeneric =
            type == 1 || type == 2 || type == 3 || type == 4;

        if (cip13s != null &&
            (isPrinceps || isRecognizedGeneric) &&
            type != null) {
          final accumulator = groupMeta.putIfAbsent(
            groupId,
            () => _GroupAccumulator(rawLabel: libelle),
          );
          accumulator.members.add((cis: cis, type: type));

          if (seenGroups.add(groupId)) {
            accumulator.rawLabel = libelle;
          }

          for (final cip13 in cip13s) {
            if (medicamentCips.contains(cip13)) {
              groupMembers.add(
                GroupMembersCompanion(
                  codeCip: Value(cip13),
                  groupId: Value(groupId),
                  type: Value(type),
                ),
              );
            }
          }
        }
      default:
        continue;
    }
  }

  for (final entry in groupMeta.entries) {
    final groupId = entry.key;
    final rawLabel = entry.value.rawLabel.trim();
    ({String cis, int type})? princepsMember;
    for (final member in entry.value.members) {
      if (member.type == 0) {
        princepsMember = member;
        break;
      }
    }
    final princepsCis = princepsMember?.cis;

    final relationalMolecule = princepsCis != null
        ? compositionMap[princepsCis]
        : null;
    final relationalPrinceps = princepsCis != null
        ? specialitesMap[princepsCis]
        : null;

    String parsingMethod;
    String moleculeLabel;
    String princepsLabel;

    if (relationalMolecule != null && relationalPrinceps != null) {
      parsingMethod = 'relational';
      moleculeLabel = relationalMolecule;
      princepsLabel = relationalPrinceps;
    } else if (rawLabel.contains(' - ')) {
      parsingMethod = 'text_split';
      final segments = rawLabel.split(' - ');
      final firstSegment = segments.first.trim();
      final lastSegmentRaw = segments.length > 1 ? segments.last.trim() : '';
      princepsLabel = lastSegmentRaw.replaceAll(RegExp(r'\.$'), '').trim();
      moleculeLabel = _normalizeSaltPrefix(
        _removeSaltSuffixes(firstSegment).trim(),
      );
    } else {
      final splitResult = _smartSplitLabel(rawLabel);
      parsingMethod = splitResult.method;
      moleculeLabel = splitResult.title;
      princepsLabel = splitResult.subtitle;
    }

    if (princepsLabel.isEmpty) {
      princepsLabel = Strings.unknownReference;
    }

    final cleanedMoleculeLabel = moleculeLabel
        .replaceAll(RegExp(r'\s*\([^)]+\)\s*$'), '')
        .trim();

    generiqueGroups.add(
      GeneriqueGroupsCompanion(
        groupId: Value(groupId),
        libelle: Value(moleculeLabel),
        princepsLabel: Value(princepsLabel),
        moleculeLabel: Value(cleanedMoleculeLabel),
        rawLabel: Value(rawLabel),
        parsingMethod: Value(parsingMethod),
      ),
    );
  }

  return Either.right((
    generiqueGroups: generiqueGroups,
    groupMembers: groupMembers,
  ));
}

class GeneriquesParser
    implements FileParser<Either<ParseError, GeneriquesParseResult>> {
  GeneriquesParser({
    required this.cisToCip13,
    required this.medicamentCips,
    required this.compositionMap,
    required this.specialitesMap,
  });

  final Map<String, List<String>> cisToCip13;
  final Set<String> medicamentCips;
  final Map<String, String> compositionMap;
  final Map<String, String> specialitesMap;

  @override
  Future<Either<ParseError, GeneriquesParseResult>> parse(
    Stream<List<dynamic>>? rows,
  ) => parseGeneriquesImpl(
    rows,
    cisToCip13,
    medicamentCips,
    compositionMap,
    specialitesMap,
  );
}
