import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest(
    'Minimal Patrol test',
    ($) async {
      await $.pumpWidgetAndSettle(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const Center(child: Text('Hello')),
          ),
        ),
      );

      expect($('Test'), findsOneWidget);
      expect($('Hello'), findsOneWidget);
    },
  );
}