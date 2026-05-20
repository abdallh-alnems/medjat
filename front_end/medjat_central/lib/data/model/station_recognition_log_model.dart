class StationRecognitionLogModel {
  final int id;
  final int stationId;
  final String stationName;
  final int? matchedEmployeeId;
  final String? employeeName;
  final String verificationMethod;
  final double? confidenceScore;
  final String result;
  final String? failureReason;
  final DateTime createdAt;

  StationRecognitionLogModel({
    required this.id,
    required this.stationId,
    this.stationName = '',
    this.matchedEmployeeId,
    this.employeeName,
    required this.verificationMethod,
    this.confidenceScore,
    required this.result,
    this.failureReason,
    required this.createdAt,
  });

  factory StationRecognitionLogModel.fromJson(Map<String, dynamic> json) {
    return StationRecognitionLogModel(
      id: (json['id'] as int?) ?? 0,
      stationId: (json['station_id'] as int?) ?? 0,
      stationName: (json['station_name'] as String?) ?? '',
      matchedEmployeeId: json['matched_employee_id'] as int?,
      employeeName: json['employee_name'] as String?,
      verificationMethod: (json['verification_method'] as String?) ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      result: (json['result'] as String?) ?? '',
      failureReason: json['failure_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get resultLabel {
    switch (result) {
      case 'success': return 'recognition_success';
      case 'low_confidence': return 'recognition_low_confidence';
      case 'no_match': return 'recognition_no_match';
      case 'spoofing_detected': return 'recognition_spoofing';
      case 'manual_fallback': return 'recognition_manual';
      case 'too_soon': return 'recognition_too_soon';
      default: return result;
    }
  }
}
