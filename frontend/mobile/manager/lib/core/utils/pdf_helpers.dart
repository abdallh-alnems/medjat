import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/locale_service.dart';
import '../../logic/controller/settings/company_settings_controller.dart';

/// Shared helpers for the client-side PDF exporters so every document follows
/// the same rules: direction driven by the app language, and a company title
/// that never leaks the signed-in user's name.

/// True when the app language is Arabic. Uses [LocaleService] (the app's
/// source of truth, set in main.dart) and falls back to [Get.locale].
bool pdfIsArabic() {
  if (Get.isRegistered<LocaleService>()) {
    return Get.find<LocaleService>().isArabic;
  }
  return (Get.locale?.languageCode ?? 'ar') == 'ar';
}

/// Page text direction: RTL for Arabic, LTR for English.
pw.TextDirection pdfTextDirection() =>
    pdfIsArabic() ? pw.TextDirection.rtl : pw.TextDirection.ltr;

/// Title shown on exported documents. Prefers an explicit [override], then the
/// company name from settings, then a neutral brand. Never the user's name.
String pdfCompanyTitle([String? override]) {
  if (override != null && override.trim().isNotEmpty) return override.trim();
  if (Get.isRegistered<CompanySettingsController>()) {
    final name = Get.find<CompanySettingsController>().companyData['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
  }
  return 'Medjat';
}
