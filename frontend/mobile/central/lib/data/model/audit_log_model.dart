/// One management action recorded in the company-wide activity log.
class AuditLogModel {
  final int id;
  final int? adminId;
  final String adminName;
  final String action;
  final String? targetType;
  final String? targetId;

  /// The resolved human subject of the action — usually the affected employee's
  /// name (e.g. who an asset was assigned to), or the entity's own name.
  final String? subject;
  final Map<String, dynamic>? payload;
  final DateTime? createdAt;

  const AuditLogModel({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.subject,
    required this.payload,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    Map<String, dynamic>? payload;
    if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    }

    return AuditLogModel(
      id: _toInt(json['id']) ?? 0,
      adminId: _toInt(json['admin_id']),
      adminName: (json['admin_name'] as String?)?.trim().isNotEmpty == true
          ? (json['admin_name'] as String).trim()
          : '',
      action: (json['action'] as String?) ?? '',
      targetType: json['target_type'] as String?,
      targetId: json['target_id']?.toString(),
      subject: (json['subject'] as String?)?.trim().isNotEmpty == true
          ? (json['subject'] as String).trim()
          : null,
      payload: payload,
      createdAt: _toDate(json['created_at']),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}

/// A management user who appears as an actor in the log, for the "who" filter.
class AuditActor {
  final int id;
  final String name;

  const AuditActor({required this.id, required this.name});

  factory AuditActor.fromJson(Map<String, dynamic> json) => AuditActor(
        id: AuditLogModel._toInt(json['id']) ?? 0,
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : 'مدير',
      );
}
