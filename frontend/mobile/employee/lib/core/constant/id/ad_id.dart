import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Centralised AdMob unit IDs for the Permedjat employee app (per-platform).
///
/// Android app id: `ca-app-pub-8595701567488603~8653915019`
/// iOS app id:     `ca-app-pub-8595701567488603~2330701747` (set in Info.plist)
/// In debug builds Google's official test unit is used to avoid serving
/// (and accidentally clicking) live ads during development.
class AdManager {
  AdManager._();

  // ============================ Production — Android =========================

  static const String _bannerAndroid =
      'ca-app-pub-8595701567488603/6426077622';
  static const String _nativeAndroid =
      'ca-app-pub-8595701567488603/9244941954';

  // ============================== Production — iOS ===========================

  static const String _bannerIos = 'ca-app-pub-8595701567488603/3448342290';
  static const String _nativeIos = 'ca-app-pub-8595701567488603/3105827447';

  // ================================ Test IDs =================================

  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696110';

  // ================================== banner =================================

  static String get idBanner {
    if (kDebugMode) return _testBanner;
    return Platform.isIOS ? _bannerIos : _bannerAndroid;
  }

  // ================================== native =================================

  static String get idNative {
    if (kDebugMode) return _testNative;
    return Platform.isIOS ? _nativeIos : _nativeAndroid;
  }
}
