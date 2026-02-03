/// Application-wide constants and configuration values
class AppConfig {
  AppConfig._();

  // Network & Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration downloadReceiveTimeout = Duration(minutes: 5);

  // UX & Input
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration rippleAnimation = Duration(milliseconds: 200);

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 80);
  static const Duration mediumAnimation = Duration(milliseconds: 120);
  static const Duration standardAnimation = Duration(milliseconds: 180);
  static const Duration defaultAnimation = Duration(milliseconds: 200);
  static const Duration slowAnimation = Duration(milliseconds: 250);
  static const Duration tabAnimation = Duration(milliseconds: 300);
  static const Duration fabAnimation = Duration(milliseconds: 350);

  // Scanner Animations
  static const Duration scannerPulseAnimation = Duration(milliseconds: 650);
  static const Duration scannerFadeOut = Duration(milliseconds: 1500);
  static const Duration scannerQuickFade = Duration(milliseconds: 260);
  static const Duration scannerOverlayFade = Duration(milliseconds: 220);

  // Haptic Feedback Durations
  static const Duration lightHaptic = Duration(milliseconds: 80);
  static const Duration mediumHaptic = Duration(milliseconds: 120);
  static const Duration heavyHaptic = Duration(milliseconds: 140);

  // Initialization Delays
  static const Duration initializationDelay = Duration(milliseconds: 100);

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

/// Layout breakpoints for responsive design
abstract final class LayoutBreakpoints {
  static const double mobile = 600;
  static const double desktop = 640;
}

/// UI dimensions and sizes
abstract final class UiSizes {
  // Border radius
  static const double radiusFull = 9999.0;

  // Heights
  static const double groupHeaderHeight = 108;

  // Font sizes (for legacy code not using shadcn typography tokens)
  static const double fontXs = 10;
  static const double fontSm = 12;
  static const double fontMd = 14;
  static const double fontLg = 15;
}
