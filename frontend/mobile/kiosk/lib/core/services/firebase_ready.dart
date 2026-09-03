import 'dart:async';

/// Whether Firebase actually came up on this tablet.
///
/// Firebase starts after the first frame and never finishes on a device
/// without Google Play services, or on a branch network that cannot reach
/// Google — those calls hang rather than throw. Anything that touches a
/// Firebase API must gate on this instead of assuming `initializeApp` ran.
///
/// Lifted from permedjat_app, which learned it on Huawei handsets. A branch buys
/// the cheapest tablet that has a front camera, so the kiosk is at least as
/// exposed to it.
class FirebaseReady {
  FirebaseReady._();

  static final Completer<bool> _completer = Completer<bool>();

  /// True once Firebase core is usable, false when it is unavailable.
  static Future<bool> get future => _completer.future;

  /// Synchronous answer for hot paths (crash breadcrumbs, analytics events)
  /// that must not await anything. Null until [complete] is called.
  static bool? get value => _value;
  static bool? _value;

  /// Resolves false rather than waiting forever, for callers that hold UI.
  static Future<bool> orGiveUp([
    Duration timeout = const Duration(seconds: 3),
  ]) =>
      _completer.future.timeout(timeout, onTimeout: () => false);

  static void complete(bool available) {
    _value = available;
    if (!_completer.isCompleted) _completer.complete(available);
  }
}
