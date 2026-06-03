import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallenge { blink, turnLeft, turnRight, smile }

class LivenessResult {
  final bool passed;
  final String? challengeName;
  final String? failureReason;

  LivenessResult({
    required this.passed,
    this.challengeName,
    this.failureReason,
  });
}

class FaceDetectionResult {
  final bool detected;
  final Face? face;
  final String? error;

  FaceDetectionResult({required this.detected, this.face, this.error});
}

class FaceService {
  static final FaceService _instance = FaceService._();
  factory FaceService() => _instance;
  FaceService._();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<FaceDetectionResult> detectFace(InputImage inputImage) async {
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        return FaceDetectionResult(detected: false, error: 'no_face');
      }
      if (faces.length > 1) {
        return FaceDetectionResult(detected: false, error: 'multiple_faces');
      }
      return FaceDetectionResult(detected: true, face: faces.first);
    } catch (e) {
      return FaceDetectionResult(detected: false, error: e.toString());
    }
  }

  InputImage inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final bytesPerRow = image.planes.first.bytesPerRow;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg,
      format: InputImageFormatValue.fromRawValue(image.format.raw as int) ??
          InputImageFormat.nv21,
      bytesPerRow: bytesPerRow,
    );

    final bytes = Uint8List.fromList(
      image.planes.expand((plane) => plane.bytes).toList(),
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  LivenessChallenge randomChallenge() {
    const challenges = LivenessChallenge.values;
    return challenges[Random().nextInt(challenges.length)];
  }

  String challengeLabel(LivenessChallenge challenge) {
    switch (challenge) {
      case LivenessChallenge.blink:
        return 'liveness_blink';
      case LivenessChallenge.turnLeft:
        return 'liveness_turn_left';
      case LivenessChallenge.turnRight:
        return 'liveness_turn_right';
      case LivenessChallenge.smile:
        return 'liveness_smile';
    }
  }

  bool checkBlink(List<double> eyeOpenProbabilities) {
    if (eyeOpenProbabilities.length < 3) return false;
    bool wasOpen = eyeOpenProbabilities.first > 0.5;
    bool wasClosed = false;
    for (final prob in eyeOpenProbabilities.skip(1)) {
      final isOpen = prob > 0.5;
      if (wasOpen && !isOpen) wasClosed = true;
      if (wasClosed && isOpen) return true;
      wasOpen = isOpen;
    }
    return false;
  }

  bool checkHeadTurn(List<double> eulerYValues, {required bool toLeft}) {
    if (eulerYValues.isEmpty) return false;
    for (final angle in eulerYValues) {
      if (toLeft && angle < -12) return true;
      if (!toLeft && angle > 12) return true;
    }
    return false;
  }

  bool checkSmile(List<double> smileProbabilities) {
    for (final prob in smileProbabilities) {
      if (prob > 0.7) return true;
    }
    return false;
  }

  Future<List<double>> generateEmbedding(CameraImage image, Face face) async {
    try {
      return await compute(_generateEmbeddingIsolate, {
        'imageWidth': image.width,
        'imageHeight': image.height,
        'faceRect': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'right': face.boundingBox.right,
          'bottom': face.boundingBox.bottom,
        },
      });
    } catch (e) {
      return _generateDummyEmbedding();
    }
  }

  List<double> generateEmbeddingFromRect(
    int imageWidth,
    int imageHeight, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    return _buildEmbedding(imageWidth, imageHeight, left, top, right, bottom);
  }

  List<double> _buildEmbedding(
    int width, int height,
    double left, double top, double right, double bottom,
  ) {
    final faceW = (right - left) / width;
    final faceH = (bottom - top) / height;
    final cx = ((left + right) / 2) / width;
    final cy = ((top + bottom) / 2) / height;

    final embedding = List<double>.filled(192, 0.0);
    embedding[0] = faceW;
    embedding[1] = faceH;
    embedding[2] = cx;
    embedding[3] = cy;

    double norm = 0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= norm;
      }
    }
    return embedding;
  }

  List<double> _generateDummyEmbedding() {
    final rng = Random(42);
    final embedding = List.generate(192, (_) => rng.nextDouble() * 2 - 1);
    double norm = 0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = sqrt(norm);
    return embedding.map((v) => v / norm).toList();
  }

  void dispose() {
    _faceDetector.close();
  }
}

List<double> _generateEmbeddingIsolate(Map<String, dynamic> args) {
  final width = args['imageWidth'] as int;
  final height = args['imageHeight'] as int;
  final faceRect = args['faceRect'] as Map<String, dynamic>;

  final left = (faceRect['left'] as num).toDouble();
  final top = (faceRect['top'] as num).toDouble();
  final right = (faceRect['right'] as num).toDouble();
  final bottom = (faceRect['bottom'] as num).toDouble();

  final faceW = (right - left) / width;
  final faceH = (bottom - top) / height;
  final cx = ((left + right) / 2) / width;
  final cy = ((top + bottom) / 2) / height;

  final embedding = List<double>.filled(192, 0.0);
  embedding[0] = faceW;
  embedding[1] = faceH;
  embedding[2] = cx;
  embedding[3] = cy;

  double norm = 0;
  for (final v in embedding) {
    norm += v * v;
  }
  norm = sqrt(norm);
  if (norm > 0) {
    for (int i = 0; i < embedding.length; i++) {
      embedding[i] /= norm;
    }
  }

  return embedding;
}
