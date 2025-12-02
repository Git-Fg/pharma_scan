
/// Base sealed class for all application failures.
/// Used in Railway Oriented Programming (ROP) with dart_either Either.
///
/// WHY: Sealed class enables exhaustive pattern matching and type-safe error handling.
/// All failures in the application must extend this class.
/// Extends Exception to allow throwing in providers for Riverpod AsyncError conversion.
sealed class Failure implements Exception {
  const Failure(this.message, [this.stackTrace]);

  /// Human-readable error message.
  final String message;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;
}

/// Database-related failures (Drift, SQLite errors).
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.stackTrace]);
}

/// Network-related failures (Dio, HTTP errors).
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.stackTrace]);
}

/// Data parsing/transformation failures.
class ParsingFailure extends Failure {
  const ParsingFailure(super.message, [super.stackTrace]);
}

/// Resource not found failures (optional, if "not found" is considered a business error).
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, [super.stackTrace]);
}

/// Cancellation failures (user-initiated cancellations).
class CancellationFailure extends Failure {
  const CancellationFailure(super.message, [super.stackTrace]);
}
