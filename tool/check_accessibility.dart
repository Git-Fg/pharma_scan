#!/usr/bin/env dart
// tool/check_accessibility.dart
// WHY: Script to detect missing accessibility properties in the codebase.
// Run with: dart run tool/check_accessibility.dart

import 'dart:io';

void main(List<String> args) {
  print('🔍 Checking accessibility implementation...\n');

  final issues = <String>[];
  final libDir = Directory('lib');

  if (!libDir.existsSync()) {
    print('❌ lib directory not found');
    exit(1);
  }

  // Check for FButton without Semantics
  _checkForMissingSemantics(
    libDir,
    pattern: RegExp(r'FButton\s*\('),
    contextPattern: RegExp(r'Semantics\s*\('),
    widgetName: 'FButton',
    issues: issues,
  );

  // Check for FTile without Semantics (when onPress is present)
  _checkForMissingSemantics(
    libDir,
    pattern: RegExp(r'FTile\s*\('),
    contextPattern: RegExp(r'(Semantics\s*\(|onPress:)'),
    widgetName: 'FTile',
    issues: issues,
    requireContext: false, // FTile might not always need Semantics
  );

  // Check for FSelectTile without Semantics
  _checkForMissingSemantics(
    libDir,
    pattern: RegExp(r'FSelectTile\s*\.'),
    contextPattern: RegExp(r'Semantics\s*\('),
    widgetName: 'FSelectTile',
    issues: issues,
  );

  // Check for decorative chevron icons without ExcludeSemantics
  _checkForDecorativeIcons(libDir, issues);

  // Print results
  if (issues.isEmpty) {
    print('✅ No accessibility issues found!');
    exit(0);
  } else {
    print('⚠️  Found ${issues.length} potential accessibility issue(s):\n');
    for (final issue in issues) {
      print('  • $issue');
    }
    print(
      '\n💡 Tip: Wrap interactive widgets with Semantics widgets and decorative icons with ExcludeSemantics.',
    );
    exit(1);
  }
}

void _checkForMissingSemantics(
  Directory dir,
  RegExp pattern,
  RegExp contextPattern,
  String widgetName,
  List<String> issues, {
  bool requireContext = true,
}) {
  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('.g.dart'))
      .where((f) => !f.path.contains('.freezed.dart'))
      .where((f) => !f.path.contains('.drift.dart'));

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (pattern.hasMatch(line)) {
        // Check if Semantics is nearby (within 10 lines before)
        bool hasSemantics = false;
        for (int j = i - 1; j >= 0 && j >= i - 10; j--) {
          if (contextPattern.hasMatch(lines[j])) {
            hasSemantics = true;
            break;
          }
        }

        if (requireContext && !hasSemantics) {
          final relativePath = file.path.replaceAll(
            '${Directory.current.path}/',
            '',
          );
          issues.add(
            '$relativePath:${i + 1}: $widgetName may need Semantics wrapper',
          );
        }
      }
    }
  }
}

void _checkForDecorativeIcons(Directory dir, List<String> issues) {
  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('.g.dart'))
      .where((f) => !f.path.contains('.freezed.dart'))
      .where((f) => !f.path.contains('.drift.dart'));

  final chevronPattern = RegExp(r'Icon\s*\(\s*FIcons\.chevron(Right|Left)');
  final excludeSemanticsPattern = RegExp(r'ExcludeSemantics\s*\(');

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (chevronPattern.hasMatch(line)) {
        // Check if ExcludeSemantics is nearby (within 5 lines before)
        bool hasExcludeSemantics = false;
        for (int j = i - 1; j >= 0 && j >= i - 5; j--) {
          if (excludeSemanticsPattern.hasMatch(lines[j])) {
            hasExcludeSemantics = true;
            break;
          }
        }

        if (!hasExcludeSemantics) {
          final relativePath = file.path.replaceAll(
            '${Directory.current.path}/',
            '',
          );
          issues.add(
            '$relativePath:${i + 1}: Decorative chevron icon may need ExcludeSemantics wrapper',
          );
        }
      }
    }
  }
}
