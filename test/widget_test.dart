import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('theme mode starts on system and toggles', () async {
    final controller = await ThemeModeController.load();
    expect(controller.mode, ThemeMode.system);

    controller.toggle(currentlyDark: false);
    expect(controller.mode, ThemeMode.dark);

    controller.toggle(currentlyDark: true);
    expect(controller.mode, ThemeMode.light);
  });
}