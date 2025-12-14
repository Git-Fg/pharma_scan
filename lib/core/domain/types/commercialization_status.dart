/// Extension Type for commercialization status values
///
/// Provides type safety for medication commercialization status strings from the database.
/// This eliminates string matching throughout the codebase and ensures type safety.
extension type CommercializationStatus(String _value) {
  /// Creates a commercialization status from a raw database string
  ///
  /// Parses common variations and normalizes them to a known set of values.
  /// Unknown values are mapped to [CommercializationStatus.unknown].
  factory CommercializationStatus.fromDatabase(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) {
      return CommercializationStatus('unknown');
    }

    final normalized = rawStatus.toLowerCase().trim();

    // Map common status variations to canonical values
    switch (normalized) {
      case 'en cours':
      case 'actif':
      case 'active':
      case 'current':
        return CommercializationStatus('active');

      case 'abrogé':
      case 'abroge':
      case 'revoked':
      case 'annulé':
        return CommercializationStatus('revoked');

      case 'non commercialisé':
      case 'non commercialise':
      case 'not marketed':
      case 'unmarketed':
        return CommercializationStatus('not_marketed');

      case 'suspendu':
      case 'suspended':
      case 'pause':
        return CommercializationStatus('suspended');

      default:
        // For any unknown status, preserve the original value but mark as unknown
        return CommercializationStatus('unknown');
    }
  }

  /// Named constructors for known statuses
  const CommercializationStatus.active() : _value = 'active';
  const CommercializationStatus.revoked() : _value = 'revoked';
  const CommercializationStatus.notMarketed() : _value = 'not_marketed';
  const CommercializationStatus.suspended() : _value = 'suspended';
  const CommercializationStatus.unknown() : _value = 'unknown';

  /// Gets the raw string value for storage
  String get rawValue => _value;

  /// Gets the display-friendly localized string
  String get displayName {
    switch (_value) {
      case 'active':
        return 'En cours';
      case 'revoked':
        return 'Abrogé';
      case 'not_marketed':
        return 'Non commercialisé';
      case 'suspended':
        return 'Suspendu';
      case 'unknown':
      default:
        return 'Inconnu';
    }
  }

  /// Checks if the medication is commercially available
  bool get isAvailable => _value == 'active';

  /// Checks if the medication has been revoked
  bool get isRevoked => _value == 'revoked';

  /// Checks if the medication is not marketed
  bool get isNotMarketed => _value == 'not_marketed';

  /// Checks if the medication is suspended
  bool get isSuspended => _value == 'suspended';

  /// Checks if the status is unknown
  bool get isUnknown => _value == 'unknown';

  /// Checks if the medication is NOT available for any reason
  bool get isUnavailable => _value != 'active';

}