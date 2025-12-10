// LINT: Keep library directive to attach @MappableLib for package-wide init.
// ignore_for_file: unnecessary_library_name

@MappableLib(generateInitializerForScope: InitializerScope.package)
library pharma_scan_mappers;

import 'package:dart_mappable/dart_mappable.dart';

export 'mappable_library.init.dart' show initializeMappers;
