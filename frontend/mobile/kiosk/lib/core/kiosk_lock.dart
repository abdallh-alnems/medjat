import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Screen pinning, from Dart.
///
/// The Android side does the work; this exists so the rest of the app can ask
/// for lockdown without knowing about platform channels, and so a failure to
/// pin never takes the kiosk down. A tablet that cannot pin is still a working
/// kiosk — just an easier one to navigate away from — and that is a much better
/// outcome than a device on a wall showing a crash.
class KioskLock {
  KioskLock._();

  static const _channel = MethodChannel('permedjat.kiosk/lock');

  static Future<bool> enter() => _invoke('enterKioskMode');

  /// Only ever called from inside the administration area, which means an
  /// administrator-generated access code was presented first.
  static Future<bool> exit() => _invoke('exitKioskMode');

  static Future<bool> isLocked() => _invoke('isLocked');

  static Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      // Running somewhere without the Android host — a test, or a desktop
      // debug session. Not an error worth surfacing.
      return false;
    } catch (e) {
      debugPrint('KioskLock.$method failed: $e');
      return false;
    }
  }
}
