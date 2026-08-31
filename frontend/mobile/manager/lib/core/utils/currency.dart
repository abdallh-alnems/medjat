import 'package:get/get.dart';

/// Maps an ISO-4217 currency code to a short label suitable for display
/// next to an amount, localized to the active app language. In English we
/// show the ISO code (e.g. "EGP"); in Arabic the short Arabic label ("ج.م").
/// Falls back to the code itself when unknown so the user still sees
/// something sensible (e.g. "AUD").
String currencyLabel(String? iso) {
  final code = (iso ?? '').toUpperCase();
  if (Get.locale?.languageCode != 'ar') {
    // English (and any non-Arabic): use the ISO code; '' defaults to EGP.
    if (code.isEmpty) return 'EGP';
    if (code == 'USD') return '\$';
    if (code == 'EUR') return '€';
    if (code == 'GBP') return '£';
    return code;
  }
  switch (code) {
    case 'EGP':
      return 'ج.م';
    case 'SAR':
      return 'ر.س';
    case 'AED':
      return 'د.إ';
    case 'KWD':
      return 'د.ك';
    case 'QAR':
      return 'ر.ق';
    case 'BHD':
      return 'د.ب';
    case 'OMR':
      return 'ر.ع';
    case 'JOD':
      return 'د.أ';
    case 'IQD':
      return 'د.ع';
    case 'LBP':
      return 'ل.ل';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case '':
      return 'ج.م';
    default:
      return iso!.toUpperCase();
  }
}
