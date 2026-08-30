// A fingerprint / face terminal installed at a branch, the User IDs it knows
// about, and the raw punches it has pushed up.

class AttendanceDeviceModel {
  final int id;
  final String serialNumber;
  final String? name;
  final int? branchId;
  final String? branchName;
  final String? model;
  final String? firmware;
  final String status; // active | disabled
  final bool isOnline;
  final int? secondsSinceSeen;
  final String? lastSeenAt;
  final String? lastPunchAt;
  final String directionMode; // auto | device_status
  final int minIntervalSeconds;
  final int clockOffsetMinutes;
  final bool debugLogging;
  final int linkedUsers;
  final int pendingUsers;
  final int punchesToday;

  const AttendanceDeviceModel({
    required this.id,
    required this.serialNumber,
    this.name,
    this.branchId,
    this.branchName,
    this.model,
    this.firmware,
    this.status = 'active',
    this.isOnline = false,
    this.secondsSinceSeen,
    this.lastSeenAt,
    this.lastPunchAt,
    this.directionMode = 'auto',
    this.minIntervalSeconds = 60,
    this.clockOffsetMinutes = 0,
    this.debugLogging = false,
    this.linkedUsers = 0,
    this.pendingUsers = 0,
    this.punchesToday = 0,
  });

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : serialNumber;

  bool get isDisabled => status == 'disabled';

  /// True when the terminal has never contacted the server — the serial was
  /// typed in but the device's own network settings still need doing.
  bool get neverConnected => lastSeenAt == null;

  factory AttendanceDeviceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceDeviceModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      serialNumber: json['serial_number']?.toString() ?? '',
      name: json['name']?.toString(),
      branchId: (json['branch_id'] as num?)?.toInt(),
      branchName: json['branch_name']?.toString(),
      model: json['model']?.toString(),
      firmware: json['firmware']?.toString(),
      status: json['status']?.toString() ?? 'active',
      isOnline: json['is_online'] == true,
      secondsSinceSeen: (json['seconds_since_seen'] as num?)?.toInt(),
      lastSeenAt: json['last_seen_at']?.toString(),
      lastPunchAt: json['last_punch_at']?.toString(),
      directionMode: json['direction_mode']?.toString() ?? 'auto',
      minIntervalSeconds: (json['min_interval_seconds'] as num?)?.toInt() ?? 60,
      clockOffsetMinutes: (json['clock_offset_minutes'] as num?)?.toInt() ?? 0,
      debugLogging: json['debug_logging'] == true,
      linkedUsers: (json['linked_users'] as num?)?.toInt() ?? 0,
      pendingUsers: (json['pending_users'] as num?)?.toInt() ?? 0,
      punchesToday: (json['punches_today'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One User ID stored on the terminal, and the employee it points at.
class DeviceUserModel {
  final int id;
  final String deviceUserId;
  final String? deviceName;
  final int? employeeId;
  final String? employeeName;
  final String? employeeJobTitle;
  final String? cardNumber;
  final bool isDeviceAdmin;
  final String? lastPunchAt;
  final int unmatchedPunches;

  const DeviceUserModel({
    required this.id,
    required this.deviceUserId,
    this.deviceName,
    this.employeeId,
    this.employeeName,
    this.employeeJobTitle,
    this.cardNumber,
    this.isDeviceAdmin = false,
    this.lastPunchAt,
    this.unmatchedPunches = 0,
  });

  bool get isLinked => employeeId != null;

  factory DeviceUserModel.fromJson(Map<String, dynamic> json) {
    return DeviceUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceUserId: json['device_user_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString(),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      employeeName: json['employee_name']?.toString(),
      employeeJobTitle: json['employee_job_title']?.toString(),
      cardNumber: json['card_number']?.toString(),
      isDeviceAdmin: json['is_device_admin'] == true,
      lastPunchAt: json['last_punch_at']?.toString(),
      unmatchedPunches: (json['unmatched_punches'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A raw punch as the terminal sent it, plus what we did with it.
class DevicePunchModel {
  final int id;
  final int deviceId;
  final String? deviceName;
  final String deviceUserId;
  final String? deviceUserName;
  final int? employeeId;
  final String? employeeName;
  final String punchedAt;
  final String? direction; // in | out
  final String state; // applied | duplicate | unmatched | ignored | failed
  final String? note;
  final String recognition;

  const DevicePunchModel({
    required this.id,
    required this.deviceId,
    required this.deviceUserId,
    required this.punchedAt,
    required this.state,
    this.deviceName,
    this.deviceUserName,
    this.employeeId,
    this.employeeName,
    this.direction,
    this.note,
    this.recognition = 'device_fingerprint',
  });

  factory DevicePunchModel.fromJson(Map<String, dynamic> json) {
    return DevicePunchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceId: (json['device_id'] as num?)?.toInt() ?? 0,
      deviceName: json['device_name']?.toString(),
      deviceUserId: json['device_user_id']?.toString() ?? '',
      deviceUserName: json['device_user_name']?.toString(),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      employeeName: json['employee_name']?.toString(),
      punchedAt: json['punched_at']?.toString() ?? '',
      direction: json['direction']?.toString(),
      state: json['state']?.toString() ?? 'unmatched',
      note: json['note']?.toString(),
      recognition: json['recognition']?.toString() ?? 'device_fingerprint',
    );
  }
}
