/// A tracked bulk bonus/deduction batch and its per-employee members.
class BulkAdjustmentModel {
  final int id;
  final String kind; // 'bonus' | 'deduction'
  final String scopeType; // 'all' | 'branch' | 'category' | 'employee'
  final int? scopeId;
  final String? scopeName;
  final double amount; // fixed money OR percent value
  final String amountType; // 'fixed' | 'percent'
  final String reason;
  final String month; // YYYY-MM
  final String? createdByName;
  final String? createdAt;
  final int memberCount;
  final double totalAmount;

  BulkAdjustmentModel({
    required this.id,
    required this.kind,
    required this.scopeType,
    this.scopeId,
    this.scopeName,
    this.amount = 0,
    this.amountType = 'fixed',
    this.reason = '',
    this.month = '',
    this.createdByName,
    this.createdAt,
    this.memberCount = 0,
    this.totalAmount = 0,
  });

  bool get isBonus => kind == 'bonus';
  bool get isPercent => amountType == 'percent';

  factory BulkAdjustmentModel.fromJson(Map<String, dynamic> json) {
    return BulkAdjustmentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: (json['kind'] as String?) ?? 'deduction',
      scopeType: (json['scope_type'] as String?) ?? 'all',
      scopeId: (json['scope_id'] as num?)?.toInt(),
      scopeName: json['scope_name'] as String?,
      amount: double.tryParse('${json['amount']}') ?? 0,
      amountType: (json['amount_type'] as String?) ?? 'fixed',
      reason: (json['reason'] as String?) ?? '',
      month: (json['month'] as String?) ?? '',
      createdByName: json['created_by_name'] as String?,
      createdAt: json['created_at'] as String?,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      totalAmount: double.tryParse('${json['total_amount']}') ?? 0,
    );
  }
}

class BulkAdjustmentMember {
  final int id; // the per-employee manual row id
  final int employeeId;
  final String employeeName;
  final double amount;
  final String reason;

  BulkAdjustmentMember({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    this.amount = 0,
    this.reason = '',
  });

  factory BulkAdjustmentMember.fromJson(Map<String, dynamic> json) {
    return BulkAdjustmentMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: (json['employee_name'] as String?) ?? '',
      amount: double.tryParse('${json['amount']}') ?? 0,
      reason: (json['reason'] as String?) ?? '',
    );
  }
}
