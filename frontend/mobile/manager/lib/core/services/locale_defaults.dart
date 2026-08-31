import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Company locale settings picked once, when the company is created.
///
/// Getting the timezone wrong is not cosmetic: attendance is stamped on the
/// company's clock, so a wrong zone shifts every check-in and quietly distorts
/// lateness and overtime. Choosing at onboarding is what stops a company from
/// silently running on a default nobody picked.
class LocaleDefaults {
  static const fallbackTimezone = 'Africa/Cairo';

  static const currencies = ['EGP', 'SAR', 'AED', 'USD', 'EUR', 'KWD', 'QAR'];

  /// Zones offered before the admin opens the full list — the markets served.
  static const commonTimezones = [
    'Africa/Cairo',
    'Asia/Riyadh',
    'Asia/Dubai',
    'Asia/Kuwait',
    'Asia/Qatar',
    'Africa/Tripoli',
    'Africa/Khartoum',
    'Europe/London',
    'UTC',
  ];

  /// ISO weekday (1=Mon..7=Sun), Saturday first to match the Arab work week.
  static const weekdays = <int, String>{
    6: 'weekday_sat',
    7: 'weekday_sun',
    1: 'weekday_mon',
    2: 'weekday_tue',
    3: 'weekday_wed',
    4: 'weekday_thu',
    5: 'weekday_fri',
  };

  static const _zoneCurrency = <String, String>{
    'Africa/Cairo': 'EGP',
    'Asia/Riyadh': 'SAR',
    'Asia/Dubai': 'AED',
    'Asia/Kuwait': 'KWD',
    'Asia/Qatar': 'QAR',
  };

  /// The device's timezone, or [fallbackTimezone] when it cannot be resolved.
  static Future<String> detectTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier.isNotEmpty ? info.identifier : fallbackTimezone;
    } catch (_) {
      return fallbackTimezone;
    }
  }

  /// Full IANA list from the bundled tz database (pure Dart, so it does not
  /// depend on a native platform call succeeding).
  static List<String> allTimezones() {
    try {
      tz_data.initializeTimeZones();
      final ids = tz.timeZoneDatabase.locations.keys.toList()..sort();
      if (ids.isNotEmpty) return ids;
    } catch (_) {
      /* fall through */
    }
    return List<String>.from(commonTimezones);
  }

  /// A first guess at the currency from the timezone — a prefill the admin
  /// sees and can change, never a silent decision.
  static String currencyForZone(String zone) => _zoneCurrency[zone] ?? 'EGP';

  /// Egypt and the Gulf start the week on Saturday; elsewhere assume Monday.
  static int weekStartForZone(String zone) =>
      zone.startsWith('Africa/') || zone.startsWith('Asia/') ? 6 : 1;
}
