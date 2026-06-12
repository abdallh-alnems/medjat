/// Attendance configuration resolved on the backend for the employee's branch.
/// `methods` holds the effective attendance methods (branch override or company
/// default): any of `qr_gps`, `gps_only`, `manual`, `station`.
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
  bool get hasStation => methods.contains('station');

  /// Methods the employee can act on directly from this app.
  List<String> get selfMethods =>
      methods.where((m) => m == 'qr_gps' || m == 'gps_only').toList();

  /// True when the employee cannot self check-in (only manual/station enabled).
  bool get isSelfCheckDisabled => selfMethods.isEmpty;

  factory AttendanceConfigModel.fromJson(Map<String, dynamic> json) {
    final rawMethods = (json['methods'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['qr_gps'];
    return AttendanceConfigModel(
      branchId: json['branch_id'] as int?,
      branchName: json['branch_name'] as String?,
      methods: rawMethods.isEmpty ? const ['qr_gps'] : rawMethods,
      gpsRadiusMeters: (json['gps_radius_meters'] as num?)?.toInt() ?? 100,
      allowOffline: json['allow_offline'] == true || json['allow_offline'] == 1,
      branchLat: (json['branch_lat'] as num?)?.toDouble(),
      branchLng: (json['branch_lng'] as num?)?.toDouble(),
    );
  }
}
