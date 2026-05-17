class BranchModel {
  final int id;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final double gpsRadius;
  final String? qrCode;
  final int employeeCount;

  BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.gpsRadius = 100,
    this.qrCode,
    this.employeeCount = 0,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      gpsRadius: (json['gps_radius'] as num?)?.toDouble() ?? 100,
      qrCode: json['qr_code'],
      employeeCount: json['employee_count'] ?? 0,
    );
  }
}
