import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Splash screen assets should be generated for Android', () {
    // Check main launch background
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    );
    expect(
      launchBackground.existsSync(),
      isTrue,
      reason: 'launch_background.xml should exist in res/drawable',
    );

    // Check styles
    final styles = File('android/app/src/main/res/values/styles.xml');
    expect(
      styles.existsSync(),
      isTrue,
      reason: 'styles.xml should exist in res/values',
    );

    // Check v21 launch background if generated
    final launchBackgroundV21 = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    );
    if (launchBackgroundV21.existsSync()) {
      expect(launchBackgroundV21.existsSync(), isTrue);
    }
  });
}
