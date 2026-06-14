/// Attendance configuration resolved on the backend for the employee's branch.
/// `methods` holds the effective attendance methods (branch override or company
/// default): any of `qr_gps`, `gps_only`, `manual`.
class AttendanceConfigModel {
  final int? branchId;
  final String? branchName;
  final List<String> methods;
  final int gpsRadiusMeters;
  final bool allowOffline;
  final double? branchLat;
  final double? branchLng;

  const AttendanceConfigModel({
    this.branchId,
    this.branchName,
    this.methods = const ['qr_gps'],
    this.gpsRadiusMeters = 100,
    this.allowOffline = true,
    this.branchLat,
    this.branchLng,
  });

  bool get hasQrGps => methods.contains('qr_gps');
  bool get hasGpsOnly => methods.contains('gps_only');
  bool get hasManual => methods.contains('manual');

  /// Methods the employee can act on directly from this app.
  List<String> get selfMethods =>
      methods.where((m) => m == 'qr_gps' || m == 'gps_only').toList();

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
      branchLat: _toDouble(json['branch_lat']),
      branchLng: _toDouble(json['branch_lng']),
    );
  }
}
