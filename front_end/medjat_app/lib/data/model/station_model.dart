class Station {
  final int stationId;
  final int branchId;
  final String branchName;
  final String deviceName;
  final String methods;
  final double confidenceThreshold;
  final bool antiSpoofing;
  final double gpsRadiusMeters;
  final bool isLocked;
  final String? lockedReason;

  Station({
    required this.stationId,
    required this.branchId,
    required this.branchName,
    required this.deviceName,
    required this.methods,
    required this.confidenceThreshold,
    required this.antiSpoofing,
    required this.gpsRadiusMeters,
    required this.isLocked,
    this.lockedReason,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationId: (json['station_id'] as int?) ?? 0,
      branchId: (json['branch_id'] as int?) ?? 0,
      branchName: (json['branch_name'] as String?) ?? '',
      deviceName: (json['device_name'] as String?) ?? '',
      methods: (json['station_methods'] as String?) ?? 'fingerprint_only',
      confidenceThreshold:
          (json['station_confidence_threshold'] as num?)?.toDouble() ?? 0.7,
      antiSpoofing: json['station_anti_spoofing_enabled'] == true ||
          json['station_anti_spoofing_enabled'] == 1,
      gpsRadiusMeters:
          (json['station_gps_radius_meters'] as num?)?.toDouble() ?? 100.0,
      isLocked: json['is_locked'] == true || json['is_locked'] == 1,
      lockedReason: json['locked_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'station_id': stationId,
        'branch_id': branchId,
        'branch_name': branchName,
        'device_name': deviceName,
        'station_methods': methods,
        'station_confidence_threshold': confidenceThreshold,
        'station_anti_spoofing_enabled': antiSpoofing,
        'station_gps_radius_meters': gpsRadiusMeters,
        'is_locked': isLocked,
        'locked_reason': lockedReason,
      };
}

class BranchEmployee {
  final int id;
  final String name;
  final String? phone;
  final String? jobTitle;
  final String biometricEnrollmentStatus;

  BranchEmployee({
    required this.id,
    required this.name,
    this.phone,
    this.jobTitle,
    required this.biometricEnrollmentStatus,
  });

  factory BranchEmployee.fromJson(Map<String, dynamic> json) {
    return BranchEmployee(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      jobTitle: json['job_title'] as String?,
      biometricEnrollmentStatus:
          (json['biometric_enrollment_status'] as String?) ?? 'none',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'job_title': jobTitle,
        'biometric_enrollment_status': biometricEnrollmentStatus,
      };
}

class KioskCheckInResult {
  final String action;
  final int? attendanceId;
  final String employeeName;
  final String? timestamp;

  KioskCheckInResult({
    required this.action,
    this.attendanceId,
    required this.employeeName,
    this.timestamp,
  });

  factory KioskCheckInResult.fromJson(Map<String, dynamic> json) {
    return KioskCheckInResult(
      action: (json['action'] as String?) ?? 'check_in',
      attendanceId: json['attendance_id'] as int?,
      employeeName: (json['employee_name'] as String?) ?? '',
      timestamp: json['timestamp'] as String?,
    );
  }
}
