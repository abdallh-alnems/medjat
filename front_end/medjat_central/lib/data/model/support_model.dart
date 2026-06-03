class SupportTicketModel {
  final int id;
  final int tenantId;
  final int openedByAdminId;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final int? assignedSuperAdminId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final bool unreadForUser;
  final bool unreadForSupport;
  final DateTime? createdAt;

  SupportTicketModel({
    required this.id,
    required this.tenantId,
    required this.openedByAdminId,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    this.assignedSuperAdminId,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadForUser,
    required this.unreadForSupport,
    this.createdAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int,
      openedByAdminId: json['opened_by_admin_id'] as int,
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'open',
      assignedSuperAdminId: json['assigned_super_admin_id'] as int?,
      lastMessageAt: _parseDate(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadForUser: (json['unread_for_user'] as dynamic) == 1 ||
          json['unread_for_user'] == true,
      unreadForSupport: (json['unread_for_support'] as dynamic) == 1 ||
          json['unread_for_support'] == true,
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
    return null;
  }

  String get statusLabel {
    const map = {
      'open': 'ticket_status_open',
      'pending_support': 'ticket_status_pending_support',
      'pending_user': 'ticket_status_pending_user',
      'resolved': 'ticket_status_resolved',
      'closed': 'ticket_status_closed',
    };
    return map[status] ?? status;
  }

  String get categoryLabel {
    const map = {
      'technical': 'ticket_category_technical',
      'billing': 'ticket_category_billing',
      'feature_request': 'ticket_category_feature_request',
      'account': 'ticket_category_account',
      'other': 'ticket_category_other',
    };
    return map[category] ?? category;
  }

  bool get isOpen => status == 'open' || status == 'pending_support' || status == 'pending_user';
  bool get isClosed => status == 'closed' || status == 'resolved';
}

class SupportMessageModel {
  final int id;
  final int ticketId;
  final String senderType;
  final int? senderAdminId;
  final int? senderSuperAdminId;
  final String body;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime? createdAt;

  SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderType,
    this.senderAdminId,
    this.senderSuperAdminId,
    required this.body,
    this.attachmentUrl,
    this.attachmentName,
    this.createdAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      senderType: json['sender_type'] as String? ?? 'user',
      senderAdminId: json['sender_admin_id'] as int?,
      senderSuperAdminId: json['sender_super_admin_id'] as int?,
      body: json['body'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
    return null;
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromSupport => senderType == 'support';
  bool get isSystem => senderType == 'system';
}
