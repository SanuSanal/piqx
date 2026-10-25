import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/theme/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opens dark until light is chosen', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ThemeStore.load(), ThemeMode.dark);
  });

  test('the saved choice is what the next launch opens in', () async {
    SharedPreferences.setMockInitialValues({});
    await ThemeStore.save(ThemeMode.light);
    expect(await ThemeStore.load(), ThemeMode.light);
    await ThemeStore.save(ThemeMode.dark);
    expect(await ThemeStore.load(), ThemeMode.dark);
  });
}
