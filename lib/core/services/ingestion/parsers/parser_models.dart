part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

/// Parse error types for functional error handling
sealed class ParseError {
  const ParseError();
}

typedef SpecialitesParseResult = ({
  List<SpecialitesCompanion> specialites,
  Map<String, String> namesByCis,
  Set<String> seenCis,
  Map<String, int> labIdsByName,
  List<LaboratoriesCompanion> laboratories,
});

typedef MedicamentsParseResult = ({
  List<MedicamentsCompanion> medicaments,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
});

typedef GeneriquesParseResult = ({
  List<GeneriqueGroupsCompanion> generiqueGroups,
  List<GroupMembersCompanion> groupMembers,
});

class EmptyContentError extends ParseError {
  const EmptyContentError(this.fileName);
  final String fileName;
}

class InvalidFormatError extends ParseError {
  const InvalidFormatError(this.fileName, this.details);
  final String fileName;
  final String details;
}
