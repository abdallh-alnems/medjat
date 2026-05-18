import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class LocaleService extends GetxService {
  static const _key = 'app_locale';

  late final GetStorage _box;

  final Rx<Locale> locale = const Locale('ar').obs;

  LocaleService() : _box = Get.find<GetStorage>();

  @override
  void onInit() {
    super.onInit();
    final saved = _box.read<String>(_key);
    if (saved != null) {
      locale.value = Locale(saved);
    } else {
      final deviceLocale = Get.deviceLocale;
      if (deviceLocale != null &&
          (deviceLocale.languageCode == 'ar' ||
              deviceLocale.languageCode == 'en')) {
        locale.value = Locale(deviceLocale.languageCode);
      }
    }
  }

  Locale get currentLocale => locale.value;

  bool get isArabic => locale.value.languageCode == 'ar';

  void toggleLocale() {
    final newCode = isArabic ? 'en' : 'ar';
    locale.value = Locale(newCode);
    _box.write(_key, newCode);
    Get.updateLocale(locale.value);
  }

  void setLocale(String code) {
    locale.value = Locale(code);
    _box.write(_key, code);
    Get.updateLocale(locale.value);
  }
}
