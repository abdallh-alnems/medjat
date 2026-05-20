class StationSettingsModel {
  final bool enabled;
  final String methods;
  final int gpsRadiusMeters;
  final double confidenceThreshold;
  final bool antiSpoofing;
  final bool hasAdminPin;

  StationSettingsModel({
    this.enabled = false,
    this.methods = 'face_only',
    this.gpsRadiusMeters = 30,
    this.confidenceThreshold = 0.85,
    this.antiSpoofing = true,
    this.hasAdminPin = false,
  });

  factory StationSettingsModel.fromJson(Map<String, dynamic> json) {
    return StationSettingsModel(
      enabled: (json['station_enabled'] as int?) == 1,
      methods: (json['station_methods'] as String?) ?? 'face_only',
      gpsRadiusMeters: (json['station_gps_radius_meters'] as int?) ?? 30,
      confidenceThreshold:
          (json['station_confidence_threshold'] as num?)?.toDouble() ?? 0.85,
      antiSpoofing: (json['station_anti_spoofing_enabled'] as int?) == 1,
      hasAdminPin: (json['station_admin_pin_hash'] as String?) != null,
    );
  }
}
