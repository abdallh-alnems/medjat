class AppControlModel {
  final String key;
  final String name;
  final String minVersion;
  final bool? maintenance;
  final bool supportsMaintenance;

  AppControlModel({
    required this.key,
    required this.name,
    required this.minVersion,
    this.maintenance,
    required this.supportsMaintenance,
  });

  factory AppControlModel.fromJson(Map<String, dynamic> json) {
    return AppControlModel(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      minVersion: json['min_version'] as String? ?? '0.0.0',
      maintenance: json['maintenance'] as bool?,
      supportsMaintenance: json['supports_maintenance'] as bool? ?? false,
    );
  }

  AppControlModel copyWith({
    String? minVersion,
    bool? maintenance,
  }) {
    return AppControlModel(
      key: key,
      name: name,
      minVersion: minVersion ?? this.minVersion,
      maintenance: maintenance ?? this.maintenance,
      supportsMaintenance: supportsMaintenance,
    );
  }
}
