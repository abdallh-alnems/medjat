import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// The action the server asked the employee to perform.
///
/// The server picks it at random per attempt (see FaceChallengeModel), so a
/// recorded video of one action can't be reused: the next attempt asks for
/// something else and the nonce is already burnt.
enum LivenessChallenge {
  blink,
  turnLeft,
  turnRight,
  smile;

  static LivenessChallenge? fromApi(String? value) => switch (value) {
        'blink' => LivenessChallenge.blink,
        'turn_left' => LivenessChallenge.turnLeft,
        'turn_right' => LivenessChallenge.turnRight,
        'smile' => LivenessChallenge.smile,
        _ => null,
      };

  /// Localisation key for the on-screen instruction.
  String get instructionKey => switch (this) {
        LivenessChallenge.blink => 'face_challenge_blink',
        LivenessChallenge.turnLeft => 'face_challenge_turn_left',
        LivenessChallenge.turnRight => 'face_challenge_turn_right',
        LivenessChallenge.smile => 'face_challenge_smile',
      };
}

/// Tracks progress through one liveness challenge across a stream of frames.
///
/// This is *active* liveness: it proves motion, which defeats a printed photo
/// or a static image on a screen. It does not defeat a replayed video — that
/// needs passive texture/depth analysis, which is a model swap on top of this,
/// not a change in flow. Because the check runs on the device it can be
/// bypassed by a patched build; the server treats it as one signal among
/// several (nonce, GPS, device-integrity flags), never as the sole gate.
class LivenessDetector {
  LivenessDetector(this.challenge);

  final LivenessChallenge challenge;

  /// Blink needs eyes open first, so a photo of closed eyes can't pass.
  bool _sawEyesOpen = false;
  bool _sawNeutralHead = false;
  bool _sawNeutralMouth = false;

  bool _passed = false;
  bool get passed => _passed;

  static const double _eyeOpenThreshold = 0.6;
  static const double _eyeClosedThreshold = 0.25;
  static const double _turnAngle = 22.0;
  static const double _neutralAngle = 10.0;
  static const double _smilingThreshold = 0.7;
  static const double _neutralSmileThreshold = 0.3;

  /// Feeds one detected face. Returns true once the challenge is satisfied.
  bool update(Face face) {
    if (_passed) return true;

    switch (challenge) {
      case LivenessChallenge.blink:
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        if (left == null || right == null) return false;
        if (left > _eyeOpenThreshold && right > _eyeOpenThreshold) {
          _sawEyesOpen = true;
        } else if (_sawEyesOpen &&
            left < _eyeClosedThreshold &&
            right < _eyeClosedThreshold) {
          _passed = true;
        }

      case LivenessChallenge.turnLeft:
      case LivenessChallenge.turnRight:
        final yaw = face.headEulerAngleY;
        if (yaw == null) return false;
        if (yaw.abs() < _neutralAngle) {
          _sawNeutralHead = true;
        } else if (_sawNeutralHead) {
          // ML Kit's yaw is positive when the head turns to the user's left,
          // which is the right side of a mirrored front-camera preview.
          final turned = challenge == LivenessChallenge.turnLeft
              ? yaw > _turnAngle
              : yaw < -_turnAngle;
          if (turned) _passed = true;
        }

      case LivenessChallenge.smile:
        final smiling = face.smilingProbability;
        if (smiling == null) return false;
        if (smiling < _neutralSmileThreshold) {
          _sawNeutralMouth = true;
        } else if (_sawNeutralMouth && smiling > _smilingThreshold) {
          _passed = true;
        }
    }

    return _passed;
  }

  void reset() {
    _passed = false;
    _sawEyesOpen = false;
    _sawNeutralHead = false;
    _sawNeutralMouth = false;
  }
}

/// Quality gate for the frame used as the enrollment reference or the
/// verification capture. A blurry, tilted or tiny face produces an embedding
/// that will not match anything later, so it is rejected up front with a
/// message the employee can act on.
class FaceQuality {
  const FaceQuality._(this.score, this.messageKey);

  final double score;

  /// Null when the frame is good enough to use.
  final String? messageKey;

  bool get isAcceptable => messageKey == null;

  static const double minScore = 0.5;

  static FaceQuality evaluate(Face face, int imageWidth) {
    // Too far from the camera: the crop ends up upscaled and mushy.
    final faceRatio = face.boundingBox.width / imageWidth;
    if (faceRatio < 0.2) {
      return const FaceQuality._(0, 'face_quality_too_far');
    }
    if (faceRatio > 0.9) {
      return const FaceQuality._(0, 'face_quality_too_close');
    }

    final yaw = (face.headEulerAngleY ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    if (yaw > 15 || roll > 15) {
      return const FaceQuality._(0, 'face_quality_look_straight');
    }

    // Combine framing and pose into a 0..1 score the backend stores alongside
    // the enrollment, so a bad enrollment can be spotted after the fact.
    final framing = (1 - (faceRatio - 0.45).abs() / 0.45).clamp(0.0, 1.0);
    final pose = (1 - (yaw + roll) / 30).clamp(0.0, 1.0);
    final score = (framing * 0.5) + (pose * 0.5);

    if (score < minScore) {
      return FaceQuality._(score, 'face_quality_too_low');
    }
    return FaceQuality._(score, null);
  }
}
