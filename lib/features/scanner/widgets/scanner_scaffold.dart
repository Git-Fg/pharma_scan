import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scanner_configuration.dart';

/// A scaffold that enforces portrait orientation for the scanner.
class ScannerScaffold extends StatefulWidget {
  const ScannerScaffold({
    super.key,
    required this.child,
    required this.configuration,
  });

  final Widget child;
  final ScannerConfiguration configuration;

  @override
  State<ScannerScaffold> createState() => _ScannerScaffoldState();
}

class _ScannerScaffoldState extends State<ScannerScaffold> {
  @override
  void initState() {
    super.initState();
    // Enforce portrait up orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Reset to system default (all orientations allowed)
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
    );
  }
}
