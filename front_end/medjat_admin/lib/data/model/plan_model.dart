class PlanModel {
  final int id;
  final String name;
  final double price;
  final int maxEmployees;
  final int maxBranches;
  final String? createdAt;

  PlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.maxEmployees,
    required this.maxBranches,
    this.createdAt,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      maxEmployees: json['max_employees'] as int? ?? 10,
      maxBranches: json['max_branches'] as int? ?? 1,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'max_employees': maxEmployees,
        'max_branches': maxBranches,
      };
}
