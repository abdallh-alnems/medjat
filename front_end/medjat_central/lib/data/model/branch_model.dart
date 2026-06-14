class BranchModel {
  final int id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? qrCode;
  final int employeeCount;
  final List<String>? attendanceMethods;
  final int gpsRadiusMeters;
  final bool? allowOfflineAttendance;
  // Per-branch attendance cycle start day; null = inherit company default.
  final int? cycleStartDay;

  BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.qrCode,
    this.employeeCount = 0,
    this.attendanceMethods,
    this.gpsRadiusMeters = 100,
    this.allowOfflineAttendance,
    this.cycleStartDay,
  });

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    List<String>? methods;
    if (json['attendance_methods'] != null) {
      methods = (json['attendance_methods'] as List)
          .map((e) => e.toString())
          .toList();
    }
    bool? allowOffline;
    final rawAllowOffline = json['allow_offline_attendance'];
    if (rawAllowOffline == null) {
      allowOffline = null;
    } else if (rawAllowOffline is bool) {
      allowOffline = rawAllowOffline;
    } else {
      allowOffline = (rawAllowOffline as int) == 1;
    }
    return BranchModel(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      address: json['address'] as String?,
      lat: _parseDouble(json['lat'] ?? json['latitude']),
      lng: _parseDouble(json['lng'] ?? json['longitude']),
      qrCode: json['qr_code'] as String?,
      employeeCount: (json['employee_count'] as int?) ?? 0,
      attendanceMethods: methods,
      gpsRadiusMeters: (json['gps_radius_meters'] as int?) ?? 100,
      allowOfflineAttendance: allowOffline,
      cycleStartDay: (json['cycle_start_day'] as num?)?.toInt(),
    );
  }

  BranchModel copyWith({
    int? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? qrCode,
    int? employeeCount,
    // Sentinel-defaulted so an explicit `null` clears the override (back to
    // inheriting company methods) instead of keeping the previous value.
    Object? attendanceMethods = _unset,
    int? gpsRadiusMeters,
    Object? allowOfflineAttendance = _unset,
    int? cycleStartDay,
  }) {
    return BranchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      qrCode: qrCode ?? this.qrCode,
      employeeCount: employeeCount ?? this.employeeCount,
      attendanceMethods: identical(attendanceMethods, _unset)
          ? this.attendanceMethods
          : attendanceMethods as List<String>?,
      gpsRadiusMeters: gpsRadiusMeters ?? this.gpsRadiusMeters,
      allowOfflineAttendance: identical(allowOfflineAttendance, _unset)
          ? this.allowOfflineAttendance
          : allowOfflineAttendance as bool?,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
    );
  }

  static const Object _unset = Object();
}
