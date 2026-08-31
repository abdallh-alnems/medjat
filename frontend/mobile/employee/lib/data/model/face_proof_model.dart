/// The evidence a face check-in carries to the server.
///
/// Deliberately does NOT contain a "matched" flag: the device extracts the
/// embedding, the server decides. A client-side verdict would be trivially
/// forged by a patched build, which would make the whole method decorative.
class FaceProof {
  /// The on-device face embedding, L2-normalised.
  final List<double> embedding;

  /// Single-use nonce issued by v1/attendance/face-challenge. Stops a captured embedding
  /// from being replayed later or from another device.
  final String nonce;

  /// Whether the employee completed the server's random liveness action.
  final bool livenessPassed;

  /// The capture, kept by the server for HR audit only — never for matching.
  final String? imageBase64;

  const FaceProof({
    required this.embedding,
    required this.nonce,
    required this.livenessPassed,
    this.imageBase64,
  });

  Map<String, dynamic> toJson() => {
        'face_embedding': embedding,
        'face_nonce': nonce,
        'liveness_passed': livenessPassed,
        if (imageBase64 != null) 'image_base64': imageBase64,
      };
}

/// Server response to a challenge request.
class FaceChallengeModel {
  final String nonce;
  final String challenge;
  final int expiresIn;
  final bool livenessRequired;

  const FaceChallengeModel({
    required this.nonce,
    required this.challenge,
    required this.expiresIn,
    required this.livenessRequired,
  });

  factory FaceChallengeModel.fromJson(Map<String, dynamic> json) =>
      FaceChallengeModel(
        nonce: json['nonce']?.toString() ?? '',
        challenge: json['challenge']?.toString() ?? 'blink',
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 120,
        livenessRequired: json['liveness_required'] as bool? ?? true,
      );
}

/// The employee's own enrollment state, from v1/biometric/self/status.
class FaceStatusModel {
  final bool enrolled;
  final bool needsReenrollment;
  final bool livenessRequired;
  final double minQualityScore;

  const FaceStatusModel({
    required this.enrolled,
    required this.needsReenrollment,
    required this.livenessRequired,
    required this.minQualityScore,
  });

  factory FaceStatusModel.fromJson(Map<String, dynamic> json) => FaceStatusModel(
        enrolled: json['enrolled'] as bool? ?? false,
        needsReenrollment: json['needs_reenrollment'] as bool? ?? false,
        livenessRequired: json['liveness_required'] as bool? ?? true,
        minQualityScore:
            (json['min_quality_score'] as num?)?.toDouble() ?? 0.5,
      );
}
