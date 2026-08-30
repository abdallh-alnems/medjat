/// One entry in our own audit trail.
///
/// `payload` was previously typed as a String and never displayed, so the only
/// record of *what* changed was thrown away at parse time; the backend now
/// sends it decoded and it is shown in the entry's detail sheet. `adminName` is
/// the other half of the answer — who did it.
class AuditLogModel {
  final int id;
  final int? adminId;
  final String? adminName;
  final String? action;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? payload;
  final String? ip;
  final String? createdAt;

  AuditLogModel({
    required this.id,
    this.adminId,
    this.adminName,
    this.action,
    this.targetType,
    this.targetId,
    this.payload,
    this.ip,
    this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    final raw = json['payload'];
    Map<String, dynamic>? payload;
    if (raw is Map<String, dynamic>) {
      payload = raw;
    } else if (raw is List) {
      // Some entries record a bare list (e.g. the fields a tenant update
      // touched); index it so one renderer handles both shapes.
      payload = {for (var i = 0; i < raw.length; i++) '${i + 1}': raw[i]};
    } else if (raw is String && raw.isNotEmpty) {
      payload = {'raw': raw};
    }

    return AuditLogModel(
      id: json['id'] as int? ?? 0,
      adminId: json['admin_id'] as int?,
      adminName: json['admin_name'] as String?,
      action: json['action'] as String?,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      payload: payload,
      ip: json['ip'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  static const Map<String, String> _actionLabels = {
    'tenant.create': 'إنشاء شركة',
    'tenant.update': 'تعديل بيانات شركة',
    'tenant.activate': 'تفعيل شركة',
    'tenant.deactivate': 'إيقاف شركة',
    'admin.activate': 'تفعيل حساب مدير',
    'admin.deactivate': 'إيقاف حساب مدير',
    'admin.password_reset': 'إرسال إعادة تعيين كلمة مرور',
    'admin.invite': 'دعوة مدير لشركة',
    'admin.impersonate': 'دخول تشخيصي لحساب عميل',
    'super_admin.create': 'إضافة مشرف عام',
    'auth.change_password': 'تغيير كلمة المرور',
    'auth.change_password_failed': 'محاولة تغيير كلمة مرور فاشلة',
    'force_update.trigger': 'تحديث إجباري',
    'notification.send_all': 'إرسال إشعار عام',
    'notification.send_tenant': 'إرسال إشعار لشركة',
    'station.generate_pin': 'توليد رمز محطة',
    'support.status': 'تغيير حالة تذكرة دعم',
    'support.reply': 'رد على تذكرة دعم',
    'app_control.set_version': 'تعيين إصدار التطبيق',
    'app_control.set_maintenance': 'تغيير وضع الصيانة',
    'auth.login': 'تسجيل دخول',
    'auth.firebase_login': 'تسجيل دخول',
    'login': 'تسجيل دخول',
    'auth.logout': 'تسجيل خروج',
    'logout': 'تسجيل خروج',
  };

  String get actionLabel => _actionLabels[action] ?? (action ?? 'إجراء');

  /// Actions worth spotting at a glance in a long list.
  bool get isSensitive =>
      action == 'admin.impersonate' ||
      action == 'tenant.deactivate' ||
      action == 'admin.deactivate' ||
      action == 'auth.change_password_failed';

  String? get targetTypeLabel {
    switch (targetType) {
      case 'tenant':
        return 'شركة';
      case 'admin':
        return 'مدير شركة';
      case 'station':
        return 'محطة';
      case 'support_ticket':
        return 'تذكرة دعم';
      case 'remote_config':
        return 'إعدادات التطبيق';
      case 'super_admin':
        return 'مشرف عام';
      default:
        return targetType;
    }
  }

  /// Filters offered in the audit screen, in the order they are shown.
  static const List<MapEntry<String, String>> filterableActions = [
    MapEntry('', 'كل الإجراءات'),
    MapEntry('tenant', 'الشركات'),
    MapEntry('admin', 'مديرو الشركات'),
    MapEntry('notification', 'الإشعارات'),
    MapEntry('support', 'الدعم الفني'),
    MapEntry('app_control', 'التحكم بالتطبيقات'),
    MapEntry('auth', 'الدخول والخروج'),
  ];
}
