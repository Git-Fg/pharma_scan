// lib/features/explorer/models/generic_group_summary_model.dart

class GenericGroupSummary {
  const GenericGroupSummary({
    required this.groupId,
    required this.commonPrincipes,
    required this.princepsReferenceName,
  });

  final String groupId;
  final String commonPrincipes; // RENOMMÉ: groupLabel -> commonPrincipes
  final String princepsReferenceName;
}
