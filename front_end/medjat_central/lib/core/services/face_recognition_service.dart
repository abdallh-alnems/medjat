import 'dart:typed_data';

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._();

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    _isLoaded = true;
  }

  Future<List<double>?> extractEmbedding(Uint8List imageBytes) async {
    return null;
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  double sqrt(double x) {
    if (x <= 0) return 0.0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
