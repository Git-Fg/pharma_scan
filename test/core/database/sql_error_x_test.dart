import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/utils/sql_error_x.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

void main() {
  test('detects various unique constraint messages', () {
    expect('UNIQUE constraint failed: scanned_boxes.box_label'
        .isUniqueConstraintViolation(),
        isTrue);

    expect('sqlite3_result_code: 19'.isUniqueConstraintViolation(), isTrue);

    expect('Some DB error: code 2067'.isUniqueConstraintViolation(), isTrue);

    expect('SQLITE_CONSTRAINT: UNIQUE constraint failed'
        .isUniqueConstraintViolation(), isTrue);
  });

  test('non-unique messages return false', () {
    expect('foreign key constraint failed'.isUniqueConstraintViolation(), isFalse);
    expect(Exception('random error').isUniqueConstraintViolation(), isFalse);
  });

  test('typed SqliteException is detected', () {
    final ex = SqliteException(19, 'UNIQUE constraint failed');
    expect(ex.isUniqueConstraintViolation(), isTrue);
  });
}
