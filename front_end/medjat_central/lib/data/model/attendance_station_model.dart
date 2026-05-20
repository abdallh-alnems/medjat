class AttendanceStationModel {
  final int id;
  final int branchId;
  final String branchName;
  final String deviceName;
  final String deviceToken;
  final bool isActivated;
  final bool isActive;
  final bool isLocked;
  final String? lockedReason;
  final DateTime? activatedAt;
  final DateTime? lastHeartbeatAt;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final String? qrPayload;
  final DateTime? qrExpiresAt;

  AttendanceStationModel({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.deviceName,
    required this.deviceToken,
    this.isActivated = false,
    this.isActive = true,
    this.isLocked = false,
    this.lockedReason,
    this.activatedAt,
    this.lastHeartbeatAt,
    this.lastKnownLat,
    this.lastKnownLng,
    this.qrPayload,
    this.qrExpiresAt,
  });

  factory AttendanceStationModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStationModel(
      id: (json['id'] as int?) ?? 0,
      branchId: (json['branch_id'] as int?) ?? 0,
      branchName: (json['branch_name'] as String?) ?? '',
      deviceName: (json['device_name'] as String?) ?? '',
      deviceToken: (json['device_token'] as String?) ?? '',
      isActivated: (json['is_activated'] as int?) == 1,
      isActive: (json['is_active'] as int?) == 1,
      isLocked: (json['is_locked'] as int?) == 1,
      lockedReason: json['locked_reason'] as String?,
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'] as String)
          : null,
      lastHeartbeatAt: json['last_heartbeat_at'] != null
          ? DateTime.tryParse(json['last_heartbeat_at'] as String)
          : null,
      lastKnownLat: (json['last_known_lat'] as num?)?.toDouble(),
      lastKnownLng: (json['last_known_lng'] as num?)?.toDouble(),
      qrPayload: json['activation_qr_payload'] as String?,
      qrExpiresAt: json['activation_qr_expires_at'] != null
          ? DateTime.tryParse(json['activation_qr_expires_at'] as String)
          : null,
    );
  }

  String get statusLabel {
    if (isLocked) return 'locked';
    if (!isActive) return 'deactivated';
    if (!isActivated) return 'pending';
    return 'active';
  }
}
