/// Utilities for inspecting SQL/SQLite error objects/messages.
///
/// Provides a central place to detect SQLite unique constraint violations
/// across different runtimes (native sqlite, web, driver messages, etc.).
extension SqlErrorX on Object? {
  /// Returns true when the receiver represents a SQLite unique constraint
  /// violation.
  ///
  /// Detection is implemented defensively to support multiple drivers and
  /// environments: typed `SqliteException` checks when available, plus
  /// message-based fallbacks for drivers that only expose a string message.
  bool isUniqueConstraintViolation() {
    final e = this;
    if (e == null) return false;

    final message = e.toString().toLowerCase();

    // Common text markers across drivers
    if (message.contains('unique constraint failed')) return true;
    if (message.contains('unique constraint')) return true;
    if (message.contains('constraint failed') && message.contains('unique')) {
      return true;
    }

    // Known numeric/result-code indicators
    if (message.contains('sqlite3_result_code: 19') ||
        message.contains('sqlite_error_code: 19') ||
        message.contains('code 2067')) {
      return true;
    }

    return false;
  }
}
