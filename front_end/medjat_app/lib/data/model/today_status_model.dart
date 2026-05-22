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
      isLate: json['is_late'] == true || json['is_late'] == 1,
      lateMinutes: (json['late_minutes'] as int?) ?? 0,
      branchId: (json['branch_id'] as int?) ?? (branch?['id'] as int?),
      branchName: (branch?['name'] as String?) ?? json['branch_name'] as String?,
      branchLat: (branch?['latitude'] as num? ?? json['branch_lat'] as num?)?.toDouble(),
      branchLng: (branch?['longitude'] as num? ?? json['branch_lng'] as num?)?.toDouble(),
      branchRadiusMeters: branch?['gps_radius_meters'] as int? ?? json['branch_radius_meters'] as int?,
      checkInLat: (json['check_in_latitude'] as num? ?? json['check_in_lat'] as num?)?.toDouble(),
      checkInLng: (json['check_in_longitude'] as num? ?? json['check_in_lng'] as num?)?.toDouble(),
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
