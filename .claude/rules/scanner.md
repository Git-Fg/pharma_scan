---
paths:
  - "lib/features/scanner/**/*"
---

# Scanner Rules for PharmaScan

## Overview

PharmaScan's scanner module handles barcode scanning for French pharmaceutical products using GS1 DataMatrix barcodes. The module implements a Triad Architecture combining **Riverpod** (global state), **Dart Signals** (high-frequency UI state), and **Flutter Hooks** (lifecycle management).

## Scanner Flow

```
Camera → MobileScannerController → MobileScanner → Gs1Parser → ScanOrchestrator.decide()
                                                                  ├─ .analysis → getProductByCip()
                                                                  └─ .restock → addUniqueBox()
```

### MobileScanner Configuration (2026 Best Practice)

Use `MobileScannerController` with explicit lifecycle management and v7.x features:

```dart
class _CameraScreenState extends State<CameraScreen> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, // or .noDuplicates for performance
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: [BarcodeFormat.dataMatrix], // Filter for performance
      // v7.x features (2026):
      autoZoom: true,  // Android only - essential for small pharma codes
      cameraResolution: Size(1920, 1080),  // Explicit resolution
      detectionTimeoutMs: 1000,  // Battery optimization
      invertImage: false,  // For inverted barcodes
    );
    
    // Listen to barcodes
    _controller.barcodes.listen((capture) {
      final barcode = capture.barcodes.firstOrNull;
      if (barcode != null) {
        _handleScan(barcode);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## Directory Structure

```
lib/features/scanner/
├── domain/
│   ├── logic/
│   │   ├── scan_orchestrator.dart    # Decision layer (pure business logic)
│   │   ├── gs1_parser.dart           # GS1 DataMatrix parsing
│   │   └── scan_traffic_control.dart # Debounce/cooldown management
├── presentation/
│   ├── providers/
│   │   ├── scanner_provider.dart     # Riverpod notifier + side effects stream
│   │   └── scanner_controller_provider.dart
│   ├── hooks/
│   │   ├── use_scanner_logic.dart    # Flutter Hook bridging Signals + Riverpod
│   │   └── use_scanner_side_effects.dart # Toast, haptic, dialog handlers
│   ├── widgets/
│   │   ├── scanner_bubbles.dart      # Scan result stack (top of camera)
│   │   ├── scan_window_overlay.dart  # Reticle + scrim overlay
│   │   ├── scanner_result_card.dart  # Individual bubble card
│   │   └── scanner_controls.dart     # Mode toggle, flash, etc.
│   └── screens/
│       └── camera_screen.dart        # Main scanner UI
├── logic/
│   └── scanner_store.dart            # Dart Signals store for high-frequency state
└── constants/
    └── scanner_constants.dart
```

**Note:** `ScannerMode` enum is defined in `lib/core/domain/types/scanner_mode.dart` (shared core type).

## ML Kit AI Features (v7.x)

mobile_scanner uses ML Kit which provides AI-enhanced scanning capabilities:

### Built-in AI Features
- **Automatic deblurring** - Improves scan accuracy on moving targets
- **Damaged code reconstruction** - Up to 30% damage tolerance
- **Multi-code detection** - Detects multiple barcodes in single frame
- **Confidence scoring** - Quality assessment for each scan

### Optimizing for Pharmaceutical Codes

```dart
MobileScannerController _createOptimizedController() {
  return MobileScannerController(
    // Essential for small DataMatrix codes on medication packaging
    autoZoom: true,  // Android only
    cameraResolution: Size(1920, 1080),
    detectionTimeoutMs: 1000,
    formats: [BarcodeFormat.dataMatrix],
    // For difficult-to-scan medications (glossy packaging)
    invertImage: false,
  );
}

// Tap to focus (v7.1.0+) - critical for small pharma codes
MobileScanner(
  controller: _controller,
  onDetect: _handleScan,
  onTap: (position) async {
    await _controller.setFocusPoint(position);
  },
)
```

### Handling Difficult Scans

```dart
Future<void> _handleBarcode(BarcodeCapture capture) async {
  final barcode = capture.barcodes.firstOrNull;
  if (barcode == null) return;
  
  // Check confidence score if available
  final confidence = barcode.rawValue?.length ?? 0;
  if (confidence < 8) {
    // Retry with torch for low-light conditions
    await _controller.toggleTorch();
    return;
  }
  
  // Process valid scan
  _processScan(barcode.rawValue);
}
```

## GS1 DataMatrix Parsing

### Supported Application Identifiers (AIs)

| AI | Field | Format | Example |
|----|-------|--------|---------|
| 01 | GTIN/CIP-13 | 14 digits (strip leading 0) | `3400930011177` |
| 10 | Batch/Lot | Variable length | `ABC123` |
| 11 | Manufacturing Date | YYMMDD | `250115` |
| 17 | Expiration Date | YYMMDD | `271231` |
| 21 | Serial Number | Variable length | `SERIAL001` |

### Pharmaceutical-Specific AIs (French Market)

| AI | Field | Format | Usage |
|----|-------|--------|-------|
| 22 | Consumer Product Variant | Variable | Product differentiation |
| 240 | Additional Product ID | Variable | Secondary product identifier |
| 241 | Customer Part Number | Variable | Customer-specific coding |
| 242 | Made-to-Order Variation | Variable | Custom manufacturing |
| 243 | Packaging Component Number | Variable | Inner/outer packaging |
| 710-719 | National Healthcare Reimbursement | Variable | French healthcare codes |

### GS1 Parser Pattern with Extended AIs

```dart
class Gs1Parser {
  static Gs1DataMatrix parse(String? rawValue) {
    // 1. Normalize: replace whitespace with FNC1
    final normalized = rawValue.replaceAll(RegExp(r'\s'), '\x1D');

    // 2. Parse using petitparser grammar
    final result = _gs1Grammar().parse(normalized);

    // 3. Extract fields by AI
    for (final field in result.value) {
      switch (field.ai) {
        case '01': gtin = _extractGtin(value); // With check digit validation
        case '10': lot = value;
        case '11': mfgDate = _parseDate(value); // Manufacturing date
        case '17': expDate = _parseDate(value);
        case '21': serial = value;
        // Pharmaceutical extensions
        case '22': consumerVariant = value;
        case '240': additionalId = value;
        case '241': customerPartNum = value;
        case '243': packagingComponent = value;
        case '710': case '711': case '712': case '713':
        case '714': case '715': case '716': case '717':
        case '718': case '719': 
          healthcareCodes.add(value); // French reimbursement
      }
    }
    
    // 4. Validate GTIN check digit
    if (gtin != null && !_isValidGtin(gtin)) {
      throw Gs1ParseError('Invalid GTIN check digit');
    }

    return Gs1DataMatrix(
      gtin: gtin, 
      lot: lot, 
      mfgDate: mfgDate, 
      expDate: expDate, 
      serial: serial,
      additionalId: additionalId,
      healthcareCodes: healthcareCodes,
    );
  }
  
  static bool _isValidGtin(String gtin) {
    if (gtin.length != 13 && gtin.length != 14) return false;
    // GTIN-13/14 check digit validation
    final digits = gtin.split('').map(int.parse).toList();
    final checkDigit = digits.removeLast();
    final sum = digits.asMap().entries.fold(0, (sum, entry) {
      final multiplier = (entry.key % 2 == 0) ? 1 : 3;
      return sum + (entry.value * multiplier);
    });
    final calculatedCheck = (10 - (sum % 10)) % 10;
    return checkDigit == calculatedCheck;
  }
}

### Parsing Rules

- Use **petitparser** grammar-based parsing for robustness
- Normalize whitespace to FNC1 separator (`\x1D`)
- Y2K pivot: years 00-49 -> 2000-2049, 50-99 -> 1950-1999
- Day `00` means "last day of month"
- Gracefully ignore unknown/malformed data

### GS1 Parser Pattern

```dart
class Gs1Parser {
  static Gs1DataMatrix parse(String? rawValue) {
    // 1. Normalize: replace whitespace with FNC1
    final normalized = rawValue.replaceAll(RegExp(r'\s'), '\x1D');

    // 2. Parse using petitparser grammar
    final result = _gs1Grammar().parse(normalized);

    // 3. Extract fields by AI
    for (final field in result.value) {
      switch (field.ai) {
        case '01': gtin = value.length == 14 ? value.substring(1) : value;
        case '10': lot = value;
        case '17': expDate = _parseDate(value);
        case '21': serial = value;
      }
    }

    return Gs1DataMatrix(gtin: gtin, lot: lot, expDate: expDate, serial: serial);
  }
}
```

## Scanner State Management

### Triad Architecture Pattern

| Layer | Technology | Purpose | Examples |
|-------|------------|---------|----------|
| **Global** | Riverpod | Database queries, persistence, side effects | `ScannerNotifier`, `ScanOrchestrator` |
| **Local** | Dart Signals | High-frequency UI state (60fps) | `ScannerStore.bubbles`, `mode` |
| **Lifecycle** | Flutter Hooks | Widget lifecycle, bridge | `useScannerLogic()` |

### Signal-Based Store (`scanner_store.dart`)

```dart
class ScannerStore {
  // Core signals (mutable state)
  final bubbles = signal<List<ScanResult>>([]);
  final scannedCodes = signal<Set<String>>({});
  final mode = signal<ScannerMode>(.analysis);

  // Computed signals (derived state)
  late final bubbleCount = computed(() => bubbles.value.length);
  late final hasBubbles = computed(() => bubbles.value.isNotEmpty);
  late final isAtCapacity = computed(() => bubbles.value.length >= _maxBubbles);

  // Actions
  void addScan(ScanResult result) { /* ... */ }
  void removeBubble(String codeCip) { /* ... */ }
  void clearAllBubbles() { /* ... */ }
}
```

### Side Effects Pattern

Never mutate state for side effects. Use `StreamController.broadcast()`:

```dart
// In ScannerNotifier
final _sideEffects = StreamController<ScannerSideEffect>.broadcast(sync: true);

Stream<ScannerSideEffect> get sideEffects => _sideEffects.stream;

void _emit(ScannerSideEffect effect) {
  if (_sideEffects.isClosed) return;
  _sideEffects.add(effect);
}
```

Side effect types:
- `ScannerToast(message)` - Show toast notification
- `ScannerHaptic(type)` - Trigger haptic feedback
- `ScannerResultFound(result)` - New scan result (handled by Signals store)
- `ScannerDuplicateDetected(event)` - Show duplicate dialog

## Scan Orchestration (`scan_orchestrator.dart`)

### Decision Pattern

The orchestrator is a **pure decision layer** - no UI state, no side effects:

```dart
sealed class ScanDecision {
  const ScanDecision();
}

class AnalysisSuccess extends ScanDecision {
  final ScanResult result;
  final bool replacedExisting;
}

class RestockAdded extends ScanDecision {
  final RestockItemEntity item;
  final String toastMessage;
}

class RestockDuplicate extends ScanDecision {
  final DuplicateScanEvent event;
  final String? toastMessage;
}

class ScanWarning extends ScanDecision {
  final String message;
  final String productCip;
}

class ProductNotFound extends ScanDecision;
class ScanError extends ScanDecision;
class Ignore extends ScanDecision;
}

class ScanOrchestrator {
  Future<ScanDecision> decide(
    String rawValue,
    BarcodeFormat format,
    ScannerMode mode, {
    bool force = false,
  }) async { /* ... */ }
}
```

### Traffic Control (`scan_traffic_control.dart`)

Prevents duplicate scans with configurable cooldown:

```dart
class ScanTrafficControl {
  bool shouldProcess(String key, {bool force = false}) {
    // Cooldown: 2 seconds default
    // Cleanup: 5 minutes threshold
    if (_isCooldownActive(key)) return false;
    _record(key);
    return true;
  }

  void reset() {
    _scanCooldowns.clear();
    _processingCips.clear();
  }
}
```

## Barcode Format Handling

### Green Pathway (DataMatrix)
- Full GS1 parsing with batch/expiry/serial extraction
- Supports both analysis and restock modes

### Warning Pathway (1D Barcodes)
- EAN13 (13 digits) - warn about missing DataMatrix
- Code128 - treat as CIP-13, warn about tracking
- Always return `ScanWarning` with message

## Scanner Modes

| Mode | Purpose | Key Behaviors |
|------|---------|---------------|
| `.analysis` | Identify medication | Show product info, availability |
| `.restock` | Add to inventory | Track serial/batch, detect duplicates |

## UI Components

### Bubbles (`scanner_bubbles.dart`)
- Stack of scan results at top of camera
- Dismissible swipe-to-remove
- Auto-dismiss after configurable duration
- Max bubbles: `AppConfig.scannerHistoryLimit`

### Scan Window Overlay (`scan_window_overlay.dart`)
- Custom painter for scrim + reticle
- Animated state: idle -> detecting -> success
- Color-coded by mode: restock (red/orange), analysis (primary)

### Reticle States
```dart
enum _ReticleState { idle, detecting, success }

// Animation behavior
idle       → breathing animation (1.0-1.05 scale)
detecting  → slight expansion (1.02 scale)
success    → pulse then reset to idle
```

## Important Implementation Notes

### DO
- Use `ScannerStore` for high-frequency UI state (bubbles, mode)
- Emit side effects via `StreamController` - never mutate state for side effects
- Use `useScannerLogic()` hook for scanner state access in widgets
- Handle both GS1 and non-GS1 barcodes gracefully
- Implement traffic control to prevent duplicate scans

### DON'T
- Mix global (Riverpod) and local (Signals) state management patterns
- Put UI state in `ScannerNotifier` - use `ScannerStore` instead
- Use `print()` - use `LoggerService`
- Skip barcode format checks - 1D barcodes require different handling

## Scanner Accessibility Requirements

### Screen Reader Support

All scanner UI must be accessible to visually impaired users:

```dart
// Scanner overlay with semantic labels
Stack(
  children: [
    // Camera preview
    MobileScanner(controller: _controller),
    
    // Accessible scan window
    CustomPaint(
      foregroundPainter: ScanWindowPainter(),
      child: Semantics(
        label: 'Zone de scan. Centrez le code-barres DataMatrix dans le cadre.',
        child: const SizedBox.expand(),
      ),
    ),
    
    // Accessible controls
    Semantics(
      button: true,
      label: 'Activer la lampe torche',
      child: IconButton(
        onPressed: _toggleTorch,
        icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
      ),
    ),
  ],
)
```

### Haptic Feedback Patterns

Provide tactile feedback for scan events:

```dart
void _onScanSuccess() {
  HapticFeedback.lightImpact(); // Successful scan
}

void _onScanDuplicate() {
  HapticFeedback.heavyImpact(); // Duplicate warning
}

void _onScanError() {
  HapticFeedback.vibrate(); // Error
}
```

### High Contrast Mode

Support system high contrast settings:

```dart
// Check for high contrast
final isHighContrast = MediaQuery.of(context).highContrast;

// Adjust reticle colors
ReticlePainter(
  color: isHighContrast ? Colors.yellow : context.shadColors.primary,
  strokeWidth: isHighContrast ? 4.0 : 2.0,
)
```

### Reduced Motion

Respect motion preferences for animations:

```dart
final disableAnimations = MediaQuery.of(context).disableAnimations;

AnimatedBuilder(
  animation: disableAnimations ? AlwaysStoppedAnimation(1.0) : _animation,
  builder: (context, child) => // build widget
)
```

## References

- [GS1 DataMatrix Guideline](https://www.gs1.org/standards/gs1-datamatrix-guideline/25)
- [GS1 DataMatrix User Guide](https://www.gs1.org/barcodes/guideline/gs1-datamatrix-user-guide)
- [Flutter Barcode Scanning Best Practices (Scandit)](https://www.scandit.com/blog/flutter-developers-guide-barcode-qr-code-scanning/)
- [Mobile Scanner vs ML Kit Comparison (Scanbot)](https://scanbot.io/blog/mobile-scanner-vs-flutter-ml-kit/)
