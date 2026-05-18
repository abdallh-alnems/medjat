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
      case 'subscription.update':
        return 'تحديث اشتراك';
      case 'plan.create':
        return 'إنشاء باقة';
      case 'plan.update':
        return 'تحديث باقة';
      case 'force_update.trigger':
        return 'تحديث إجباري';
      case 'notification.send_all':
        return 'إرسال إشعار عام';
      case 'notification.send_tenant':
        return 'إرسال إشعار لشركة';
      case 'login':
        return 'تسجيل دخول';
      case 'logout':
        return 'تسجيل خروج';
      default:
        return action ?? 'إجراء';
    }
  }
}
