class DeductionRuleModel {
  final int id;
  final String type;
  final String name;
  final double value;
  final String unit;
  final bool isActive;

  DeductionRuleModel({
    required this.id,
    required this.type,
    required this.name,
    this.value = 0,
    this.unit = 'fixed',
    this.isActive = true,
  });

  factory DeductionRuleModel.fromJson(Map<String, dynamic> json) {
    return DeductionRuleModel(
      id: (json['id'] as int?) ?? 0,
      type: (json['type'] as String?) ?? 'late_proportional',
      name: (json['name'] as String?) ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] as String?) ?? 'fixed',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'value': value,
        'unit': unit,
        'is_active': isActive,
      };

  String get typeLabel {
    switch (type) {
      case 'late_proportional':
        return 'خصم تأخير نسبي';
      case 'late_fixed':
        return 'خصم تأخير ثابت';
      case 'absence':
        return 'خصم غياب';
      case 'custom':
        return 'خصم مخصص';
      case 'overtime_hourly':
        return 'إضافي بالساعة';
      case 'bonus_fixed':
        return 'مكافأة ثابتة';
      default:
        return type;
    }
  }
}
