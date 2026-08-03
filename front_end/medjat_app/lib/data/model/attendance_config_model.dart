/// Attendance configuration resolved on the backend for the employee's branch.
/// `methods` holds the effective attendance methods (branch override or company
/// default): any of `qr_gps`, `gps_only`, `manual`.
class AttendanceConfigModel {
  final int? branchId;
  final String? branchName;
  final List<String> methods;
  final int gpsRadiusMeters;
  final bool allowOffline;

  /// Company opted into confirming self check-in/out with the phone's own
  /// fingerprint/FaceID. The server enforces this either way; the flag only
  /// lets the app prompt first instead of letting the employee do the work and
  /// then be rejected.
  final bool requireLocalBiometric;
  final double? branchLat;
  final double? branchLng;

  const AttendanceConfigModel({
    this.branchId,
    this.branchName,
    this.methods = const ['qr_gps'],
    this.gpsRadiusMeters = 100,
    this.allowOffline = true,
    this.requireLocalBiometric = false,
    this.branchLat,
    this.branchLng,
  });

  bool get hasQrGps => methods.contains('qr_gps');
  bool get hasGpsOnly => methods.contains('gps_only');
  bool get hasManual => methods.contains('manual');
  bool get hasFaceSelfie => methods.contains('face_selfie');
  bool get hasWifiGps => methods.contains('wifi_gps');

  /// Methods the employee can act on directly from this app.
  List<String> get selfMethods => methods
      .where((m) =>
          m == 'qr_gps' ||
          m == 'gps_only' ||
          m == 'face_selfie' ||
          m == 'wifi_gps')
      .toList();

  /// True when the employee cannot self check-in (only manual enabled).
  bool get isSelfCheckDisabled => selfMethods.isEmpty;

  /// MySQL DECIMAL/INT columns arrive as strings via PDO, so raw `as num`
  /// casts throw. Parse defensively.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory AttendanceConfigModel.fromJson(Map<String, dynamic> json) {
    final rawMethods = (json['methods'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['qr_gps'];
    return AttendanceConfigModel(
      branchId: _toInt(json['branch_id']),
      branchName: json['branch_name'] as String?,
      methods: rawMethods.isEmpty ? const ['qr_gps'] : rawMethods,
      gpsRadiusMeters: _toInt(json['gps_radius_meters']) ?? 100,
      allowOffline: json['allow_offline'] == true ||
          json['allow_offline'] == 1 ||
          json['allow_offline'] == '1',
      requireLocalBiometric: json['require_local_biometric'] == true ||
          json['require_local_biometric'] == 1 ||
          json['require_local_biometric'] == '1',
      branchLat: _toDouble(json['branch_lat']),
      branchLng: _toDouble(json['branch_lng']),
    );
  }
}
