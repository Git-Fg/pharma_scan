import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';

void main() {
  patrolTest(
    'Simple app initialization test',
    ($) async {
      // Test le plus simple possible pour vérifier que Patrol fonctionne
      await $.pumpWidgetAndSettle(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text(Strings.appName)),
            backgroundColor: Colors.blue,
          ),
        ),
      );

      // Vérification simple que l'app se lance
      expect($(Strings.appName), findsOneWidget);

      // Test d'interaction native (uniquement sur mobile)
      if (!Platform.isMacOS) {
        await $.native.pressHome();
      }
    },
  );
}