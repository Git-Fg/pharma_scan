import 'dart:io';

import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

class ValidationFailure implements Exception {
  ValidationFailure(this.message);

  final String message;

  @override
  String toString() => 'ValidationFailure: $message';
}

class BdpmFileValidator {
  BdpmFileValidator({
    Map<String, int>? expectedColumns,
  }) : _expectedColumns = expectedColumns ?? _defaultExpectedColumns;

  static const Map<String, int> _defaultExpectedColumns = {
    'specialites': 12,
    'medicaments': 10,
    'compositions': 8,
    'generiques': 4,
    'conditions': 2,
    'availability': 4,
    'mitm': 2,
  };

  static final Map<String, RegExp> _firstColumnValidators = {
    'specialites': RegExp(r'^\d{8}$'),
    'medicaments': RegExp(r'^\d{8}$'),
    'compositions': RegExp(r'^\d{8}$'),
    'conditions': RegExp(r'^\d{8}$'),
    'availability': RegExp(r'^\d{8}$'),
    'mitm': RegExp(r'^\d{8}$'),
  };

  static final Map<String, void Function(List<String>)> _extraChecks = {
    'medicaments': _validateCipColumn,
  };

  final Map<String, int> _expectedColumns;

  Future<void> validateHeader(File file, String fileKey) async {
    final expected = _expectedColumns[fileKey];
    if (expected == null) return;

    if (!await file.exists()) {
      throw ValidationFailure('Missing $fileKey file at ${file.path}');
    }

    final stream = BdpmFileParser.openLineStream(file.path);
    if (stream == null) {
      throw ValidationFailure('Unable to read $fileKey at ${file.path}');
    }

    final lines = await stream.take(5).toList();

    if (lines.isEmpty) {
      throw ValidationFailure('File $fileKey is empty');
    }

    for (final line in lines) {
      final columns = line.split('\t');
      if (columns.length < expected) {
        throw ValidationFailure(
          'File $fileKey has ${columns.length} columns (expected >= $expected)',
        );
      }

      final cisValidator = _firstColumnValidators[fileKey];
      if (cisValidator != null &&
          !cisValidator.hasMatch(columns.first.trim())) {
        throw ValidationFailure(
          'File $fileKey failed CIS format check for value "${columns.first}"',
        );
      }

      final extraCheck = _extraChecks[fileKey];
      if (extraCheck != null) {
        extraCheck(columns);
      }
    }

    LoggerService.info('[BDPM Validation] $fileKey header validated.');
  }

  static void _validateCipColumn(List<String> columns) {
    if (columns.length <= 6) return;
    final cipCandidate = columns[6].trim();
    if (cipCandidate.isEmpty) return;
    if (!RegExp(r'^\d{13}$').hasMatch(cipCandidate)) {
      throw ValidationFailure('Invalid CIP13 value "$cipCandidate"');
    }
  }
}
