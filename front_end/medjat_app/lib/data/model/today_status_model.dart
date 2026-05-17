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
    this.branchName,
    this.branchLat,
    this.branchLng,
    this.branchRadiusMeters,
    this.checkInLat,
    this.checkInLng,
  });

  factory TodayStatusModel.fromJson(Map<String, dynamic> json) {
    final checkIn = json['check_in_at'] != null
        ? DateTime.tryParse(json['check_in_at'].toString())
        : null;
    final checkOut = json['check_out_at'] != null
        ? DateTime.tryParse(json['check_out_at'].toString())
        : null;

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
      lateMinutes: json['late_minutes'] ?? 0,
      branchName: branch?['name'] ?? json['branch_name'],
      branchLat: (branch?['latitude'] ?? json['branch_lat'])?.toDouble(),
      branchLng: (branch?['longitude'] ?? json['branch_lng'])?.toDouble(),
      branchRadiusMeters: branch?['gps_radius_meters'] ?? json['branch_radius_meters'],
      checkInLat: (json['check_in_lat'])?.toDouble(),
      checkInLng: (json['check_in_lng'])?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'check_in_at': checkInAt?.toIso8601String(),
        'check_out_at': checkOutAt?.toIso8601String(),
        'is_late': isLate,
        'late_minutes': lateMinutes,
        'branch_name': branchName,
        'branch_lat': branchLat,
        'branch_lng': branchLng,
        'branch_radius_meters': branchRadiusMeters,
      };
}
