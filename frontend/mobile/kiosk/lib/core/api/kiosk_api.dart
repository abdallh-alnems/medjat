import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Every endpoint the kiosk is allowed to call.
///
/// The list is deliberately short and deliberately complete: a kiosk token
/// opens exactly these doors and nothing else. Notably absent is anything
/// under `app/employees/`, `app/payroll/`, or `app/auth/` — a shared tablet has
/// no business reaching an individual's records, and keeping the surface small
/// is most of what makes a branch-scoped credential safe.
class KioskApi {
  KioskApi._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // ---- Device identity -----------------------------------------------------

  /// Unauthenticated. The pairing code is the credential.
  static String get pair => '$base/v1/kiosk/pair';

  /// Also where revocation, a stale version, and maintenance take effect.
  static String get heartbeat => '$base/v1/kiosk/heartbeat';

  // ---- Identification and attendance ---------------------------------------

  static String get challenge => '$base/v1/kiosk/challenge';
  static String get identify => '$base/v1/kiosk/identify';
  static String get identifyByCode => '$base/v1/kiosk/identify-by-code';
  static String get punch => '$base/v1/kiosk/punch';

  // ---- Administration area -------------------------------------------------

  static String get openAdmin => '$base/v1/kiosk/open-admin';
  static String get adminRoster => '$base/v1/kiosk/admin/roster';
  static String get adminEnroll => '$base/v1/kiosk/admin/enroll';
  static String get adminClose => '$base/v1/kiosk/admin/close';
}
