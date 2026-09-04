import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Turns a face crop into an identity embedding, on-device.
///
/// Why on-device: the selfie itself never has to leave the phone (privacy, and
/// the employee's data plan), and extraction is the only expensive part. The
/// resulting vector is sent to the server, which does the actual comparison —
/// the match decision is never made here, because a patched build could simply
/// claim success. See the server-side FaceMatcher.
///
/// The model is a MobileFaceNet-style TFLite graph shipped inside this package,
/// taking a 112x112 RGB image and emitting a 192-float embedding.
///
/// It lives here rather than in either app on purpose: the employee app and the
/// kiosk must extract embeddings the same way, because the server compares both
/// against one stored vector per employee. Two copies of this file would drift.
class FaceEmbedder {
  FaceEmbedder._();

  static final FaceEmbedder instance = FaceEmbedder._();

  /// Must match FaceMatchService::MODEL_VERSION on the backend. Changing the
  /// model invalidates every stored embedding, so the version travels with the
  /// enrollment and is checked at verification time.
  static const String modelVersion = 'mobilefacenet_v1';

  /// Assets owned by a package are addressed as `packages/<name>/<path>` from
  /// every app that depends on it. Dropping the prefix loads nothing and
  /// surfaces as "face check-in unavailable".
  static const String _modelAsset =
      'packages/permedjat_shared/assets/models/mobilefacenet.tflite';
  static const int _inputSize = 112;
  static const int _embeddingSize = 192;

  Interpreter? _interpreter;

  bool get isReady => _interpreter != null;

  /// Loads the model once. Safe to call repeatedly.
  Future<void> load() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    } catch (e) {
      // A missing/corrupt model must surface as "face check-in unavailable",
      // never as a silent failure that looks like an unrecognised face.
      debugPrint('FaceEmbedder: failed to load $_modelAsset — $e');
      rethrow;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Extracts the embedding for [face] within [imageBytes].
  ///
  /// Returns null when the crop is unusable. Runs off the UI thread.
  Future<List<double>?> embed(Uint8List imageBytes, Face face) async {
    if (_interpreter == null) await load();
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    final input = await compute(_prepareInput, _CropRequest(imageBytes, face.boundingBox));
    if (input == null) return null;

    final output = List<double>.filled(_embeddingSize, 0)
        .reshape<double>([1, _embeddingSize]);
    interpreter.run(input, output);

    final raw = (output[0] as List).cast<double>();
    return _l2Normalise(raw);
  }

  /// Cosine similarity assumes unit vectors; normalising here keeps the server
  /// comparison meaningful regardless of the model's output scale.
  static List<double> _l2Normalise(List<double> vector) {
    var sum = 0.0;
    for (final v in vector) {
      sum += v * v;
    }
    final norm = math.sqrt(sum);
    if (norm == 0 || !norm.isFinite) return vector;
    return [for (final v in vector) v / norm];
  }
}

class _CropRequest {
  final Uint8List bytes;
  final Rect box;
  const _CropRequest(this.bytes, this.box);
}

/// Decodes, crops to the detected face (with margin), resizes to the model's
/// input, and normalises to [-1, 1]. Isolate-friendly: no plugin calls.
List<List<List<List<double>>>>? _prepareInput(_CropRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;

  // A tight ML Kit box clips the chin and hairline, which the model relies on;
  // 20% margin matches how these networks are usually trained.
  final box = request.box;
  final margin = box.width * 0.2;
  final left = (box.left - margin).clamp(0, decoded.width - 1).toInt();
  final top = (box.top - margin).clamp(0, decoded.height - 1).toInt();
  final right = (box.right + margin).clamp(0, decoded.width).toInt();
  final bottom = (box.bottom + margin).clamp(0, decoded.height).toInt();

  final width = right - left;
  final height = bottom - top;
  if (width < 40 || height < 40) return null;

  final cropped = img.copyCrop(decoded, x: left, y: top, width: width, height: height);
  final resized = img.copyResize(
    cropped,
    width: FaceEmbedder._inputSize,
    height: FaceEmbedder._inputSize,
    interpolation: img.Interpolation.linear,
  );

  return [
    List.generate(
      FaceEmbedder._inputSize,
      (y) => List.generate(FaceEmbedder._inputSize, (x) {
        final pixel = resized.getPixel(x, y);
        return [
          (pixel.r - 127.5) / 128.0,
          (pixel.g - 127.5) / 128.0,
          (pixel.b - 127.5) / 128.0,
        ];
      }),
    ),
  ];
}
