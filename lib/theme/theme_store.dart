import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the light/dark choice on the device, so the next launch, splash included, opens in it.
///
/// On Android 12+ the choice is also handed to the system as the app's night mode, which is
/// what the system launch screen (shown before Flutter starts) follows. Older Android shows
/// that brief launch screen dark.
class ThemeStore {
  const ThemeStore._();

  static const _key = 'theme.mode';
  static const _native = MethodChannel('piqx/theme');

  /// The saved choice; dark until the user picks light.
  static Future<ThemeMode> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      return saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {
      // Not saved: the next launch opens dark.
    }
    await syncLaunchScreen(mode);
  }

  /// Tells Android which theme its launch screen should use from the next launch on.
  static Future<void> syncLaunchScreen(ThemeMode mode) async {
    try {
      await _native.invokeMethod('setNightMode', {'dark': mode != ThemeMode.light});
    } catch (_) {
      // Not on Android, or too old to set an app night mode.
    }
  }
}
