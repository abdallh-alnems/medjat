class SupportMessageModel {
  final int id;
  final int ticketId;
  final String senderType;
  final String body;
  final String createdAt;

  /// Stored path of an attachment, if any. The file itself is never served
  /// publicly — it is fetched through admin_support/attachment.php with the
  /// admin token, since a client's screenshot can hold payroll or staff faces.
  final String? attachmentUrl;
  final String? attachmentName;

  SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.body,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentName,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] as int? ?? 0,
      ticketId: json['ticket_id'] as int? ?? 0,
      senderType: json['sender_type'] as String? ?? 'user',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
    );
  }

  bool get isFromSupport => senderType == 'support';

  bool get hasAttachment => (attachmentUrl ?? '').isNotEmpty;

  /// Images render inline; anything else (a PDF) gets a download row.
  bool get attachmentIsImage {
    final path = (attachmentUrl ?? '').toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }
}
