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
  static String get pair => '$base/app/kiosk/pair.php';

  /// Also where revocation, a stale version, and maintenance take effect.
  static String get heartbeat => '$base/app/kiosk/heartbeat.php';

  // ---- Identification and attendance ---------------------------------------

  static String get challenge => '$base/app/kiosk/challenge.php';
  static String get identify => '$base/app/kiosk/identify.php';
  static String get identifyByCode => '$base/app/kiosk/identify_by_code.php';
  static String get punch => '$base/app/kiosk/punch.php';

  // ---- Administration area -------------------------------------------------

  static String get openAdmin => '$base/app/kiosk/open_admin.php';
  static String get adminRoster => '$base/app/kiosk/admin/roster.php';
  static String get adminEnroll => '$base/app/kiosk/admin/enroll.php';
  static String get adminClose => '$base/app/kiosk/admin/close.php';
}
