import 'dart:io';

import 'package:csv/csv.dart';
import 'package:enough_convert/enough_convert.dart';

Stream<List<dynamic>> createBdpmRowStream(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const Stream<List<dynamic>>.empty();
  }

  return file
      .openRead()
      .transform(const Windows1252Decoder(allowInvalid: true))
      .transform(
        const CsvToListConverter(
          fieldDelimiter: '\t',
          shouldParseNumbers: false,
          eol: '\n',
        ),
      );
}
