class SubscriptionModel {
  final int id;
  final int tenantId;
  final int planId;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? createdAt;
  final String? tenantName;
  final String? planName;

  SubscriptionModel({
    required this.id,
    required this.tenantId,
    required this.planId,
    this.startDate,
    this.endDate,
    required this.status,
    this.createdAt,
    this.tenantName,
    this.planName,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as int? ?? 0,
      tenantId: json['tenant_id'] as int? ?? 0,
      planId: json['plan_id'] as int? ?? 0,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      tenantName: json['tenant_name'] as String?,
      planName: json['plan_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'plan_id': planId,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      };

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'suspended':
        return 'معلّق';
      case 'expired':
        return 'منتهي';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}
