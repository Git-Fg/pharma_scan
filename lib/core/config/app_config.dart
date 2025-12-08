class AppConfig {
  AppConfig._();

  // Network & Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration downloadReceiveTimeout = Duration(minutes: 5);

  // UX & Input
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration rippleAnimation = Duration(milliseconds: 200);

  // Scanner Logic
  static const int cipLength = 13;
  static const int scannerHistoryLimit = 3;
  static const Duration scannerBubbleLifetime = Duration(seconds: 15);
  static const Duration scannerCodeCleanupDelay = Duration(seconds: 2);

  // Pagination & Limits
  static const int defaultPageSize = 40;
  static const int searchMaxResults = 50;

  // Data Ingestion
  static const int batchSize = 1000; // Records per batch for database insertion
}
