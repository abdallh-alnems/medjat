/// How a kiosk request ended.
///
/// The kiosk distinguishes more failure states than an ordinary app because
/// each one puts a different sentence in front of a person standing at a door,
/// and several of them are addressed to a supervisor rather than to the
/// employee (FR-053).
enum KioskStatus {
  success,

  /// No route to the server. The kiosk records nothing and says so — there is
  /// no queue, because identification cannot happen without the server
  /// (FR-024).
  offline,

  /// Token revoked, unpaired, or unknown. Wipe local state and return to
  /// pairing (FR-005).
  unauthorised,

  /// This build is below `medjat_kiosk_min_version`. Addressed to a supervisor:
  /// a directly-installed kiosk has no store to send anyone to (FR-053).
  updateRequired,

  /// Maintenance mode is on for the kiosk app.
  maintenance,

  /// A single-use code was unknown, expired, or already consumed. Deliberately
  /// one state for all three so the screen is not an oracle.
  codeSpent,

  /// The server understood and refused — wrong branch, method not permitted,
  /// too soon. Carries a message key.
  refused,

  /// Rate limited.
  throttled,

  failure,
}

/// A server response, already reduced to something a screen can act on.
class KioskResult {
  const KioskResult({
    required this.status,
    this.data = const {},
    this.messageKey,
    this.httpStatus,
  });

  final KioskStatus status;
  final Map<String, dynamic> data;

  /// Resolved through the tenant's language on the server. The kiosk never
  /// builds its own English error text — a worker at a branch door reads
  /// Arabic, and a raw status code helps nobody.
  final String? messageKey;

  final int? httpStatus;

  bool get isSuccess => status == KioskStatus.success;

  /// True when the tablet must stop serving employees until something changes.
  /// These four states all mean "this kiosk is out of service right now", and
  /// the shell routes on them rather than each screen handling them separately.
  bool get isBlocking =>
      status == KioskStatus.offline ||
      status == KioskStatus.unauthorised ||
      status == KioskStatus.updateRequired ||
      status == KioskStatus.maintenance;

  @override
  String toString() =>
      'KioskResult($status, http: $httpStatus, key: $messageKey)';
}
