import 'package:get/get.dart';

/// Turns a backend error response into a message in the user's selected
/// language.
///
/// The server sends a machine-readable `error_code` (and sometimes a `meta`
/// map with values like remaining/days) alongside a human message that is
/// hardcoded in a single language. We deliberately ignore that raw message and
/// translate the code through the app's own locale files, so error text always
/// follows the language the user picked — never the server's.
class ApiMessages {
  ApiMessages._();

  /// Backend `error_code` → app translation key.
  static const Map<String, String> _map = {
    // ── Auth ──
    'missing_fields': 'fill_required_fields',
    'activation_code_invalid': 'activation_code_invalid',
    'account_suspended': 'account_suspended',
    'phone_code_mismatch': 'phone_code_mismatch',
    'join_link_invalid': 'join_link_invalid',
    'login_failed': 'error_try_again',

    // ── Attendance ──
    'LOCATION_REQUIRED': 'location_required',
    'GEOFENCE_NOT_CONFIGURED': 'geofence_not_configured',
    'GPS_OUT_OF_RANGE': 'out_of_range',
    'INVALID_QR': 'invalid_qr',
    'QR_REQUIRED': 'qr_required',
    'METHOD_NOT_ALLOWED': 'attendance_method_not_allowed',
    'BRANCH_NOT_FOUND': 'branch_location_unavailable',
    'records_required': 'error_try_again',

    // ── Leaves ──
    'leave_pending_limit': 'leave_pending_limit_msg',
    'leave_past_date': 'leave_past_date',
    'leave_overlap': 'leave_overlap',
    'leave_balance_insufficient': 'leave_balance_insufficient',
    'leave_not_cancellable': 'leave_not_cancellable',
    'leave_not_editable': 'leave_not_editable',
    'invalid_date_range': 'invalid_date_range',

    // ── Breaks / permission requests ──
    'type_too_long': 'break_type_too_long',
    'invalid_time_range': 'invalid_time_range',
    'duration_too_long': 'break_duration_too_long',
    'break_window_passed': 'break_window_passed',
    'break_overlap': 'break_overlap',
    'not_postponed': 'break_not_postponed',
    'no_suggestion': 'break_no_suggestion',
    'accept_failed': 'break_accept_failed',
    'reject_failed': 'break_reject_failed',

    // ── Advance / loans ──
    'invalid_start_month': 'advance_invalid_start_month',
    'start_month_in_past': 'advance_start_month_past',
    'advance_pending_limit': 'advance_pending_limit_msg',

    // ── Assets / custody ──
    'asset_not_returnable': 'asset_not_returnable',

    // ── Documents ──
    'document_not_required': 'document_not_required',
    'file_type_not_allowed': 'file_type_not_allowed',
    'file_too_large': 'file_too_large',
    'no_file': 'no_file_selected',

    // ── Shared ──
    'not_found': 'data_not_found',
    'not_pending': 'request_not_pending',
  };

  /// Localized message for a CRUD error [response].
  ///
  /// Prefers the `error_code`; if the code carries a `meta` map its values fill
  /// the translated template via `trParams`. Falls back to [fallbackKey] when
  /// the code is missing or unknown — never the raw server `message`.
  static String of(
    Map<String, dynamic> response, {
    String fallbackKey = 'error_try_again',
  }) {
    final code = response['error_code'] as String?;
    final key = code != null ? _map[code] : null;
    if (key == null) return fallbackKey.tr;

    final meta = response['meta'];
    if (meta is Map && meta.isNotEmpty) {
      return key.trParams(
        meta.map((k, v) => MapEntry(k.toString(), '$v')),
      );
    }
    return key.tr;
  }
}
