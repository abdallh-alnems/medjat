import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DarkLightService extends GetxService {
  static const _key = 'theme_mode';
  final _isDark = false.obs;

  bool get isDark => _isDark.value;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key);
    if (saved != null) {
      _isDark.value = saved;
      Get.changeThemeMode(saved ? ThemeMode.dark : ThemeMode.light);
    }
  }

  Future<void> toggleTheme() async {
    _isDark.value = !_isDark.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark.value);
    Get.changeThemeMode(_isDark.value ? ThemeMode.dark : ThemeMode.light);
  }
}
