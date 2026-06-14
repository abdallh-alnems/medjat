import 'package:flutter/foundation.dart';

/// Centralised AdMob unit IDs for the Medjat employee app.
///
/// Production banner unit: `ca-app-pub-8595701567488603/6426077622`.
/// Production native (advanced) unit: `ca-app-pub-8595701567488603/9244941954`.
/// In debug builds Google's official test unit is used to avoid serving
/// (and accidentally clicking) live ads during development.
class AdManager {
  AdManager._();

  // ============================== Production =================================

  static const String _productionBanner =
      'ca-app-pub-8595701567488603/6426077622';
  static const String _productionNative =
      'ca-app-pub-8595701567488603/9244941954';

  // ================================ Test IDs =================================

  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696110';

  // ================================== banner =================================

  static String get idBanner => kDebugMode ? _testBanner : _productionBanner;

  // ================================== native =================================

  static String get idNative => kDebugMode ? _testNative : _productionNative;
}
