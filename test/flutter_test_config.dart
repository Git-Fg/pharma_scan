import 'dart:async';

import 'package:drift/drift.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Silence drift's multiple database warning in test runs where isolated
  // NativeDatabase instances intentionally share the same executor.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
