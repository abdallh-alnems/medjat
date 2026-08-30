class SupportTicketModel {
  final int id;
  final int tenantId;
  final String tenantName;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final bool unreadForSupport;

  SupportTicketModel({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadForSupport,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] as int? ?? 0,
      tenantId: json['tenant_id'] as int? ?? 0,
      tenantName: json['tenant_name'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      status: json['status'] as String? ?? '',
      lastMessageAt: json['last_message_at'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadForSupport: (json['unread_for_support'] as dynamic) == 1 ||
          json['unread_for_support'] == true,
    );
  }

  SupportTicketModel copyWith({
    String? lastMessagePreview,
    String? status,
    bool? unreadForSupport,
  }) {
    return SupportTicketModel(
      id: id,
      tenantId: tenantId,
      tenantName: tenantName,
      subject: subject,
      category: category,
      priority: priority,
      status: status ?? this.status,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadForSupport: unreadForSupport ?? this.unreadForSupport,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'مفتوح';
      case 'pending_support':
        return 'بانتظار الدعم';
      case 'pending_user':
        return 'بانتظار المستخدم';
      case 'resolved':
        return 'تم الحل';
      case 'closed':
        return 'مغلق';
      default:
        return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'low':
        return 'منخفض';
      case 'normal':
        return 'عادي';
      case 'high':
        return 'مرتفع';
      case 'urgent':
        return 'عاجل';
      default:
        return priority;
    }
  }
}
