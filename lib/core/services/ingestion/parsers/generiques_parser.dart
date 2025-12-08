part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

class _GroupAccumulator {
  _GroupAccumulator({required this.rawLabel});

  String rawLabel;
  final List<({String cis, int type})> members = [];
}

Future<Either<ParseError, GeneriquesParseResult>> parseGeneriquesImpl(
  Stream<String>? lines,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
  Map<String, String> compositionMap,
  Map<String, String> specialitesMap,
) async {
  final generiqueGroups = <GeneriqueGroupsCompanion>[];
  final groupMembers = <GroupMembersCompanion>[];
  final seenGroups = <String>{};
  final groupMeta = <String, _GroupAccumulator>{};

  if (lines == null) {
    return Either.right((
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
    ));
  }

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('\t');
    switch (parts) {
      case [
        final groupIdRaw,
        final libelleRaw,
        final cisRaw,
        final typeRaw,
        ...,
      ]:
        final groupId = groupIdRaw.trim();
        final libelle = libelleRaw.trim();
        final cis = cisRaw.trim();
        final type = int.tryParse(typeRaw.trim());
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
