class DashboardModel {
  final int totalTenants;
  final int activeTenants;
  final int totalUsers;
  final int totalEmployees;

  DashboardModel({
    required this.totalTenants,
    required this.activeTenants,
    required this.totalUsers,
    required this.totalEmployees,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      totalTenants: json['total_tenants'] as int? ?? 0,
      activeTenants: json['active_tenants'] as int? ?? 0,
      totalUsers: json['total_users'] as int? ?? 0,
      totalEmployees: json['total_employees'] as int? ?? 0,
    );
  }
}
