import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkLightService extends GetxService {
  static const _key = 'theme_mode';
  final _mode = ThemeMode.system.obs;

  ThemeMode get mode => _mode.value;

  bool get isDark {
    if (_mode.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _mode.value == ThemeMode.dark;
  }

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved;
    try {
      saved = prefs.getString(_key);
    } catch (_) {
      // Legacy value stored as bool (or other type) — wipe and start fresh.
      await prefs.remove(_key);
      saved = null;
    }
    if (saved != null) {
      _mode.value = _fromString(saved);
      Get.changeThemeMode(_mode.value);
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
    Get.changeThemeMode(mode);
  }

  Future<void> toggleTheme() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  static ThemeMode _fromString(String v) {
    switch (v) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      default:
        return 'system';
    }
  }
}
