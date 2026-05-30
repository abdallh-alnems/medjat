/// Maps an ISO-4217 currency code to a short label suitable for display
/// next to an amount. Falls back to the code itself when unknown so the
/// user still sees something sensible (e.g. "AUD").
String currencyLabel(String? iso) {
  switch ((iso ?? '').toUpperCase()) {
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
