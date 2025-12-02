class RcpSection {
  const RcpSection({
    required this.label,
    required this.anchor,
    this.subSections = const [],
  });

  final String label;
  final String anchor;
  final List<RcpSection> subSections;
}
