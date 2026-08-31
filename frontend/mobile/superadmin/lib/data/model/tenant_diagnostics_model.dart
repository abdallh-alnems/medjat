/// Why attendance is failing at one company.
///
/// Mirrors v1/admin/tenants/diagnostics. Every section is independent: a
/// company with no face data still gets useful WiFi and terminal answers, and
/// `kiosks` is null when that feature's migration has not been applied.
class TenantDiagnosticsModel {
  final int windowDays;
  final FaceDiagnostics face;
  final SecurityDiagnostics security;
  final List<BranchWifiCoverage> wifi;
  final List<TerminalDevice> devices;
  final List<KioskStation>? kiosks;
  final List<ChannelUsage> channels;
  final String? lastAbsenceDate;
  final String? today;

  const TenantDiagnosticsModel({
    required this.windowDays,
    required this.face,
    required this.security,
    required this.wifi,
    required this.devices,
    required this.kiosks,
    required this.channels,
    this.lastAbsenceDate,
    this.today,
  });

  factory TenantDiagnosticsModel.fromJson(Map<String, dynamic> json) {
    final cron = json['cron'] as Map<String, dynamic>? ?? const {};
    final kiosksRaw = json['kiosks'];

    return TenantDiagnosticsModel(
      windowDays: json['window_days'] as int? ?? 30,
      face: FaceDiagnostics.fromJson(json['face'] as Map<String, dynamic>? ?? const {}),
      security: SecurityDiagnostics.fromJson(json['security'] as Map<String, dynamic>? ?? const {}),
      wifi: (json['wifi'] as List<dynamic>? ?? const [])
          .map((e) => BranchWifiCoverage.fromJson(e as Map<String, dynamic>))
          .toList(),
      devices: (json['devices'] as List<dynamic>? ?? const [])
          .map((e) => TerminalDevice.fromJson(e as Map<String, dynamic>))
          .toList(),
      kiosks: kiosksRaw == null
          ? null
          : (kiosksRaw as List<dynamic>)
              .map((e) => KioskStation.fromJson(e as Map<String, dynamic>))
              .toList(),
      channels: (json['channels'] as List<dynamic>? ?? const [])
          .map((e) => ChannelUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastAbsenceDate: cron['last_absence_date'] as String?,
      today: cron['today'] as String?,
    );
  }
}

class FaceDiagnostics {
  final String enforceMode;
  final double threshold;
  final bool livenessRequired;
  final int attempts;
  final int accepted;
  final double? rejectionRate;
  final int belowThreshold;
  final int livenessFailed;
  final int notEnrolled;
  final int invalidChallenge;
  final double? avgScore;
  final double? minScore;
  final double? maxScore;
  final List<FaceRejection> recentRejections;

  const FaceDiagnostics({
    this.enforceMode = 'log_only',
    this.threshold = 0,
    this.livenessRequired = false,
    this.attempts = 0,
    this.accepted = 0,
    this.rejectionRate,
    this.belowThreshold = 0,
    this.livenessFailed = 0,
    this.notEnrolled = 0,
    this.invalidChallenge = 0,
    this.avgScore,
    this.minScore,
    this.maxScore,
    this.recentRejections = const [],
  });

  factory FaceDiagnostics.fromJson(Map<String, dynamic> json) {
    return FaceDiagnostics(
      enforceMode: json['enforce_mode'] as String? ?? 'log_only',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      livenessRequired: json['liveness_required'] == 1,
      attempts: json['attempts'] as int? ?? 0,
      accepted: json['accepted'] as int? ?? 0,
      rejectionRate: (json['rejection_rate'] as num?)?.toDouble(),
      belowThreshold: json['below_threshold'] as int? ?? 0,
      livenessFailed: json['liveness_failed'] as int? ?? 0,
      notEnrolled: json['not_enrolled'] as int? ?? 0,
      invalidChallenge: json['invalid_challenge'] as int? ?? 0,
      avgScore: (json['avg_score'] as num?)?.toDouble(),
      minScore: (json['min_score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
      recentRejections: (json['recent_rejections'] as List<dynamic>? ?? const [])
          .map((e) => FaceRejection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEnforcing => enforceMode == 'enforce';

  /// A company rejecting most genuine attempts is mis-tuned, not defrauded.
  bool get thresholdLooksWrong =>
      attempts >= 10 && (rejectionRate ?? 0) > 0.3;
}

class FaceRejection {
  final int employeeId;
  final String? employeeName;
  final String? result;
  final double? matchScore;
  final double? threshold;
  final bool livenessPassed;
  final String? purpose;
  final String? createdAt;

  const FaceRejection({
    required this.employeeId,
    this.employeeName,
    this.result,
    this.matchScore,
    this.threshold,
    this.livenessPassed = false,
    this.purpose,
    this.createdAt,
  });

  factory FaceRejection.fromJson(Map<String, dynamic> json) {
    return FaceRejection(
      employeeId: json['employee_id'] as int? ?? 0,
      employeeName: json['employee_name'] as String?,
      result: json['result'] as String?,
      matchScore: (json['match_score'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
      livenessPassed: json['liveness_passed'] == 1,
      purpose: json['purpose'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  static const Map<String, String> resultLabelsAr = {
    'matched': 'تطابق',
    'below_threshold': 'أقل من العتبة',
    'liveness_failed': 'فشل اختبار الحياة',
    'not_enrolled': 'غير مسجَّل',
    'invalid_challenge': 'تحدٍ غير صالح',
    'bad_embedding': 'بصمة وجه غير صالحة',
    'model_mismatch': 'اختلاف النموذج',
  };

  String get resultLabel => resultLabelsAr[result] ?? (result ?? '—');
}

class SecurityDiagnostics {
  final List<SecurityReasonCount> byReason;
  final List<SecurityEvent> recent;

  const SecurityDiagnostics({this.byReason = const [], this.recent = const []});

  factory SecurityDiagnostics.fromJson(Map<String, dynamic> json) {
    return SecurityDiagnostics(
      byReason: (json['by_reason'] as List<dynamic>? ?? const [])
          .map((e) => SecurityReasonCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent: (json['recent'] as List<dynamic>? ?? const [])
          .map((e) => SecurityEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  int get total => byReason.fold(0, (sum, r) => sum + r.count);
}

const Map<String, String> securityReasonLabelsAr = {
  'mock_location': 'موقع مزيّف',
  'rooted': 'جهاز مروت',
  'jailbroken': 'جهاز مكسور الحماية',
  'vpn': 'VPN',
  'gps_out_of_range': 'خارج نطاق الفرع',
  'no_local_biometric': 'لم يمرّ ببصمة الجهاز',
};

class SecurityReasonCount {
  final String? reason;
  final String? action;
  final int count;

  const SecurityReasonCount({this.reason, this.action, this.count = 0});

  factory SecurityReasonCount.fromJson(Map<String, dynamic> json) {
    return SecurityReasonCount(
      reason: json['reason'] as String?,
      action: json['action'] as String?,
      count: json['count'] as int? ?? 0,
    );
  }

  String get reasonLabel => securityReasonLabelsAr[reason] ?? (reason ?? '—');
  String get actionLabel => action == 'blocked' ? 'مرفوض' : 'مُعلَّم';
}

class SecurityEvent {
  final int employeeId;
  final String? employeeName;
  final String? reason;
  final String? action;
  final String? platform;
  final String? appVersion;
  final String? createdAt;

  const SecurityEvent({
    required this.employeeId,
    this.employeeName,
    this.reason,
    this.action,
    this.platform,
    this.appVersion,
    this.createdAt,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      employeeId: json['employee_id'] as int? ?? 0,
      employeeName: json['employee_name'] as String?,
      reason: json['reason'] as String?,
      action: json['action'] as String?,
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  String get reasonLabel => securityReasonLabelsAr[reason] ?? (reason ?? '—');
  String get actionLabel => action == 'blocked' ? 'مرفوض' : 'مُعلَّم';
}

class BranchWifiCoverage {
  final int branchId;
  final String? branchName;
  final int networks;
  final int approved;
  final int pendingApproval;

  const BranchWifiCoverage({
    required this.branchId,
    this.branchName,
    this.networks = 0,
    this.approved = 0,
    this.pendingApproval = 0,
  });

  factory BranchWifiCoverage.fromJson(Map<String, dynamic> json) {
    return BranchWifiCoverage(
      branchId: json['branch_id'] as int? ?? 0,
      branchName: json['branch_name'] as String?,
      networks: json['networks'] as int? ?? 0,
      approved: json['approved'] as int? ?? 0,
      pendingApproval: json['pending_approval'] as int? ?? 0,
    );
  }

  /// One router usually broadcasts several BSSIDs — approving only some of them
  /// is the classic "half my staff can't check in" call.
  bool get hasPartialCoverage => pendingApproval > 0;
}

class TerminalDevice {
  final int id;
  final String? serialNumber;
  final String? name;
  final String? vendor;
  final String? model;
  final String? status;
  final String? branchName;
  final String? lastSeenAt;
  final String? lastPunchAt;
  final int? userCount;

  const TerminalDevice({
    required this.id,
    this.serialNumber,
    this.name,
    this.vendor,
    this.model,
    this.status,
    this.branchName,
    this.lastSeenAt,
    this.lastPunchAt,
    this.userCount,
  });

  factory TerminalDevice.fromJson(Map<String, dynamic> json) {
    return TerminalDevice(
      id: json['id'] as int? ?? 0,
      serialNumber: json['serial_number'] as String?,
      name: json['name'] as String?,
      vendor: json['vendor'] as String?,
      model: json['model'] as String?,
      status: json['status'] as String?,
      branchName: json['branch_name'] as String?,
      lastSeenAt: json['last_seen_at'] as String?,
      lastPunchAt: json['last_punch_at'] as String?,
      userCount: json['user_count'] as int?,
    );
  }
}

class KioskStation {
  final int id;
  final String? name;
  final String? status;
  final String? branchName;
  final String? appVersion;
  final String? lastSeenAt;
  final String? lastPunchAt;
  final int punchCount;

  const KioskStation({
    required this.id,
    this.name,
    this.status,
    this.branchName,
    this.appVersion,
    this.lastSeenAt,
    this.lastPunchAt,
    this.punchCount = 0,
  });

  factory KioskStation.fromJson(Map<String, dynamic> json) {
    return KioskStation(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      status: json['status'] as String?,
      branchName: json['branch_name'] as String?,
      appVersion: json['app_version'] as String?,
      lastSeenAt: json['last_seen_at'] as String?,
      lastPunchAt: json['last_punch_at'] as String?,
      punchCount: json['punch_count'] as int? ?? 0,
    );
  }
}

class ChannelUsage {
  final String? method;
  final int count;

  const ChannelUsage({this.method, this.count = 0});

  factory ChannelUsage.fromJson(Map<String, dynamic> json) {
    return ChannelUsage(
      method: json['method'] as String?,
      count: json['count'] as int? ?? 0,
    );
  }

  static const Map<String, String> labelsAr = {
    'qr_gps': 'QR + موقع',
    'gps_only': 'موقع فقط',
    'qr_gps_face': 'QR + وجه',
    'face_selfie': 'بصمة وجه',
    'wifi_gps': 'WiFi + موقع',
    'device': 'جهاز بصمة',
    'manual': 'يدوي',
    'kiosk': 'كشك الفرع',
    'offline': 'دون اتصال',
  };

  String get label => labelsAr[method] ?? (method ?? '—');
}
