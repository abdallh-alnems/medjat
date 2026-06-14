enum AttendanceStatus {
  notCheckedIn,
  checkedIn,
  checkedOut,
}

class TodayStatusModel {
  final AttendanceStatus status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final bool isLate;
  final int lateMinutes;
  final int? branchId;
  final String? branchName;
  final double? branchLat;
  final double? branchLng;
  final int? branchRadiusMeters;
  final double? checkInLat;
  final double? checkInLng;

  TodayStatusModel({
    required this.status,
    this.checkInAt,
    this.checkOutAt,
    this.isLate = false,
    this.lateMinutes = 0,
    this.branchId,
    this.branchName,
    this.branchLat,
    this.branchLng,
    this.branchRadiusMeters,
    this.checkInLat,
    this.checkInLng,
  });

  /// MySQL DECIMAL/INT columns come back from the backend as strings via PDO
  /// (e.g. "30.123456"), so a raw `as num` cast throws. Parse defensively.
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

  static DateTime? _parseTime(dynamic value, String? dateStr) {
    if (value == null) return null;
    final s = value.toString();
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
    if (s.contains(':') && s.length <= 8) {
      final base = dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
      return DateTime.tryParse('$base $s');
    }
    return null;
  }

  factory TodayStatusModel.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date']?.toString();
    final checkInTime = json['check_in_time'] ?? json['check_in_at'];
    final checkOutTime = json['check_out_time'] ?? json['check_out_at'];
    final checkIn = _parseTime(checkInTime, dateStr);
    final checkOut = _parseTime(checkOutTime, dateStr);

    AttendanceStatus status;
    if (checkIn != null && checkOut != null) {
      status = AttendanceStatus.checkedOut;
    } else if (checkIn != null) {
      status = AttendanceStatus.checkedIn;
    } else {
      status = AttendanceStatus.notCheckedIn;
    }

    final branch = json['branch'] as Map<String, dynamic>?;

    return TodayStatusModel(
      status: status,
      checkInAt: checkIn,
      checkOutAt: checkOut,
      isLate: json['is_late'] == true || json['is_late'] == 1 || json['is_late'] == '1',
      lateMinutes: _toInt(json['late_minutes']) ?? 0,
      branchId: _toInt(json['branch_id']) ?? _toInt(branch?['id']),
      branchName: (branch?['name'] as String?) ?? json['branch_name'] as String?,
      branchLat: _toDouble(branch?['latitude']) ?? _toDouble(json['branch_lat']),
      branchLng: _toDouble(branch?['longitude']) ?? _toDouble(json['branch_lng']),
      branchRadiusMeters: _toInt(branch?['gps_radius_meters']) ?? _toInt(json['branch_radius_meters']),
      checkInLat: _toDouble(json['check_in_latitude']) ?? _toDouble(json['check_in_lat']),
      checkInLng: _toDouble(json['check_in_longitude']) ?? _toDouble(json['check_in_lng']),
    );
  }

  Map<String, dynamic> toJson() => {
        'check_in_at': checkInAt?.toIso8601String(),
        'check_out_at': checkOutAt?.toIso8601String(),
        'is_late': isLate,
        'late_minutes': lateMinutes,
        'branch_id': branchId,
        'branch_name': branchName,
        'branch_lat': branchLat,
        'branch_lng': branchLng,
        'branch_radius_meters': branchRadiusMeters,
      };
}
