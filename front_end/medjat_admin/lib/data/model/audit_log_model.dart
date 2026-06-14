class AuditLogModel {
  final int id;
  final int? adminId;
  final String? action;
  final String? targetType;
  final String? targetId;
  final String? payload;
  final String? ip;
  final String? createdAt;

  AuditLogModel({
    required this.id,
    this.adminId,
    this.action,
    this.targetType,
    this.targetId,
    this.payload,
    this.ip,
    this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as int? ?? 0,
      adminId: json['admin_id'] as int?,
      action: json['action'] as String?,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      payload: json['payload'] as String?,
      ip: json['ip'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  String get actionLabel {
    switch (action) {
      case 'tenant.create':
        return 'إنشاء شركة';
      case 'tenant.activate':
        return 'تفعيل شركة';
      case 'tenant.deactivate':
        return 'إيقاف شركة';
      case 'force_update.trigger':
        return 'تحديث إجباري';
      case 'notification.send_all':
        return 'إرسال إشعار عام';
      case 'notification.send_tenant':
        return 'إرسال إشعار لشركة';
      case 'station.generate_pin':
        return 'توليد رمز محطة';
      case 'support.status':
        return 'تغيير حالة تذكرة دعم';
      case 'support.reply':
        return 'رد على تذكرة دعم';
      case 'app_control.set_version':
        return 'تعيين إصدار التطبيق';
      case 'app_control.set_maintenance':
        return 'تغيير وضع الصيانة';
      case 'auth.login':
      case 'auth.firebase_login':
      case 'login':
        return 'تسجيل دخول';
      case 'auth.logout':
      case 'logout':
        return 'تسجيل خروج';
      default:
        return action ?? 'إجراء';
    }
  }

  String? get targetTypeLabel {
    switch (targetType) {
      case 'tenant':
        return 'شركة';
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
}
