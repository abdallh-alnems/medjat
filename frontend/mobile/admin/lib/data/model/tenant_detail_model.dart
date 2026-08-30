/// The full picture of one client company: who they are, how their attendance
/// is configured, how big they are, and when anyone last used the system.
///
/// Mirrors admin/tenants/detail.php one-for-one.
class TenantDetailModel {
  final TenantProfile tenant;
  final TenantSettings settings;
  final TenantStats stats;
  final TenantActivity activity;
  final List<CompanyManager> managers;

  const TenantDetailModel({
    required this.tenant,
    required this.settings,
    required this.stats,
    required this.activity,
    required this.managers,
  });

  factory TenantDetailModel.fromJson(Map<String, dynamic> json) {
    return TenantDetailModel(
      tenant: TenantProfile.fromJson(json['tenant'] as Map<String, dynamic>? ?? const {}),
      settings: TenantSettings.fromJson(json['settings'] as Map<String, dynamic>? ?? const {}),
      stats: TenantStats.fromJson(json['stats'] as Map<String, dynamic>? ?? const {}),
      activity: TenantActivity.fromJson(json['activity'] as Map<String, dynamic>? ?? const {}),
      managers: (json['managers'] as List<dynamic>? ?? const [])
          .map((e) => CompanyManager.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TenantProfile {
  final int id;
  final String name;
  final int isActive;
  final String? timezone;
  final String? currency;
  final String? countryCode;
  final int cycleStartDay;
  final int weekStartDay;
  final String? createdAt;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? opsNotes;
  final String? companyPhone;
  final String? companyAddress;

  const TenantProfile({
    required this.id,
    required this.name,
    required this.isActive,
    this.timezone,
    this.currency,
    this.countryCode,
    this.cycleStartDay = 1,
    this.weekStartDay = 6,
    this.createdAt,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.opsNotes,
    this.companyPhone,
    this.companyAddress,
  });

  factory TenantProfile.fromJson(Map<String, dynamic> json) {
    return TenantProfile(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as int? ?? 0,
      timezone: json['timezone'] as String?,
      currency: json['currency'] as String?,
      countryCode: json['country_code'] as String?,
      cycleStartDay: json['cycle_start_day'] as int? ?? 1,
      weekStartDay: json['week_start_day'] as int? ?? 6,
      createdAt: json['created_at'] as String?,
      contactName: json['contact_name'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      opsNotes: json['ops_notes'] as String?,
      companyPhone: json['company_phone'] as String?,
      companyAddress: json['company_address'] as String?,
    );
  }

  bool get isActiveTenant => isActive == 1;
}

class TenantSettings {
  final List<String> attendanceMethods;
  final bool allowOffline;
  final bool rejectMockLocation;
  final bool requireLocalBiometric;
  final bool webAttendanceEnabled;
  final double faceThreshold;
  final bool faceLivenessRequired;
  final String faceEnforceMode;
  final int defaultAnnualLeaveDays;

  const TenantSettings({
    this.attendanceMethods = const [],
    this.allowOffline = false,
    this.rejectMockLocation = false,
    this.requireLocalBiometric = false,
    this.webAttendanceEnabled = false,
    this.faceThreshold = 0,
    this.faceLivenessRequired = false,
    this.faceEnforceMode = 'log_only',
    this.defaultAnnualLeaveDays = 21,
  });

  factory TenantSettings.fromJson(Map<String, dynamic> json) {
    return TenantSettings(
      attendanceMethods: (json['attendance_methods'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      allowOffline: json['allow_offline_attendance'] == 1,
      rejectMockLocation: json['reject_mock_location'] == 1,
      requireLocalBiometric: json['require_local_biometric'] == 1,
      webAttendanceEnabled: json['web_attendance_enabled'] == 1,
      faceThreshold: (json['face_match_threshold'] as num?)?.toDouble() ?? 0,
      faceLivenessRequired: json['face_liveness_required'] == 1,
      faceEnforceMode: json['face_enforce_mode'] as String? ?? 'log_only',
      defaultAnnualLeaveDays: json['default_annual_leave_days'] as int? ?? 21,
    );
  }

  static const Map<String, String> methodLabelsAr = {
    'qr_gps': 'QR + الموقع',
    'gps_only': 'الموقع فقط',
    'face_selfie': 'بصمة الوجه',
    'wifi_gps': 'شبكة WiFi + الموقع',
    'device': 'جهاز بصمة',
    'manual': 'تسجيل يدوي',
    'kiosk': 'جهاز الفرع (كشك)',
  };

  List<String> get methodLabels =>
      attendanceMethods.map((m) => methodLabelsAr[m] ?? m).toList();
}

class TenantStats {
  final int employees;
  final int employeesActive;
  final int employeesPending;
  final int employeesBiometric;
  final int branches;
  final int admins;
  final int adminsActive;
  final int pendingInvitations;
  final int attendanceToday;
  final int attendanceLast7Days;

  const TenantStats({
    this.employees = 0,
    this.employeesActive = 0,
    this.employeesPending = 0,
    this.employeesBiometric = 0,
    this.branches = 0,
    this.admins = 0,
    this.adminsActive = 0,
    this.pendingInvitations = 0,
    this.attendanceToday = 0,
    this.attendanceLast7Days = 0,
  });

  factory TenantStats.fromJson(Map<String, dynamic> json) {
    return TenantStats(
      employees: json['employees'] as int? ?? 0,
      employeesActive: json['employees_active'] as int? ?? 0,
      employeesPending: json['employees_pending'] as int? ?? 0,
      employeesBiometric: json['employees_biometric'] as int? ?? 0,
      branches: json['branches'] as int? ?? 0,
      admins: json['admins'] as int? ?? 0,
      adminsActive: json['admins_active'] as int? ?? 0,
      pendingInvitations: json['pending_invitations'] as int? ?? 0,
      attendanceToday: json['attendance_today'] as int? ?? 0,
      attendanceLast7Days: json['attendance_last_7_days'] as int? ?? 0,
    );
  }
}

class TenantActivity {
  final String? today;
  final String? lastAttendanceDate;
  final String? lastAdminLoginAt;
  final String? lastAbsenceRun;

  const TenantActivity({
    this.today,
    this.lastAttendanceDate,
    this.lastAdminLoginAt,
    this.lastAbsenceRun,
  });

  factory TenantActivity.fromJson(Map<String, dynamic> json) {
    return TenantActivity(
      today: json['today'] as String?,
      lastAttendanceDate: json['last_attendance_date'] as String?,
      lastAdminLoginAt: json['last_admin_login_at'] as String?,
      lastAbsenceRun: json['last_absence_run'] as String?,
    );
  }
}

class CompanyManager {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? role;
  final int isActive;
  final String? lastLoginAt;

  const CompanyManager({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.role,
    this.isActive = 1,
    this.lastLoginAt,
  });

  factory CompanyManager.fromJson(Map<String, dynamic> json) {
    return CompanyManager(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      isActive: json['is_active'] as int? ?? 1,
      lastLoginAt: json['last_login_at'] as String?,
    );
  }

  bool get isActiveManager => isActive == 1;
}
