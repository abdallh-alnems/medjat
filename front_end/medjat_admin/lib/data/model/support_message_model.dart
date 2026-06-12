class SupportMessageModel {
  final int id;
  final int ticketId;
  final String senderType;
  final String body;
  final String createdAt;

  SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] as int? ?? 0,
      ticketId: json['ticket_id'] as int? ?? 0,
      senderType: json['sender_type'] as String? ?? 'user',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  bool get isFromSupport => senderType == 'support';
}
