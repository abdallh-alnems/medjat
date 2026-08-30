import 'dart:async';

/// Firebase and AdMob only start after the first frame, and never finish on a
/// device without Google Mobile Services (Huawei) or on a network that cannot
/// reach Google — those calls hang rather than throw. Anything touching a
/// Firebase API after startup must gate on [firebaseReady] instead of assuming
/// `Firebase.initializeApp` has already run.
class FirebaseReady {
  FirebaseReady._();

  static final Completer<bool> _completer = Completer<bool>();

  /// Resolves true once Firebase core is usable, false when it is unavailable.
  static Future<bool> get future => _completer.future;

  /// Resolves false rather than waiting forever, for callers that hold UI.
  static Future<bool> orGiveUp([
    Duration timeout = const Duration(seconds: 3),
  ]) =>
      _completer.future.timeout(timeout, onTimeout: () => false);

  static void complete(bool available) {
    if (!_completer.isCompleted) _completer.complete(available);
  }
}
