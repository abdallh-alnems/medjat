class BiometricEnrollmentModel {
  final int employeeId;
  final String status;
  final DateTime? faceEnrolledAt;
  final DateTime? fingerprintEnrolledAt;
  final double? faceQualityScore;
  final bool hasLinkedAccount;

  BiometricEnrollmentModel({
    required this.employeeId,
    this.status = 'not_enrolled',
    this.faceEnrolledAt,
    this.fingerprintEnrolledAt,
    this.faceQualityScore,
    this.hasLinkedAccount = false,
  });

  factory BiometricEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return BiometricEnrollmentModel(
      employeeId: (json['employee_id'] as int?) ?? 0,
      status: (json['biometric_enrollment_status'] as String?) ?? 'not_enrolled',
      faceEnrolledAt: json['face_enrolled_at'] != null
          ? DateTime.tryParse(json['face_enrolled_at'] as String)
          : null,
      fingerprintEnrolledAt: json['fingerprint_enrolled_at'] != null
          ? DateTime.tryParse(json['fingerprint_enrolled_at'] as String)
          : null,
      faceQualityScore: (json['face_quality_score'] as num?)?.toDouble(),
      hasLinkedAccount: (json['has_linked_account'] as int?) == 1,
    );
  }

  bool get hasFace => status == 'face_only' || status == 'both';
  bool get hasFingerprint => status == 'fingerprint_only' || status == 'both';
  bool get isEnrolled => status != 'not_enrolled';
}
