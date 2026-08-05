import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The kiosk's credential, and the only thing this app is allowed to persist.
///
/// **Nothing else may be stored on the tablet.** No roster, no face embeddings,
/// no captures. Identification happens entirely on the server, which is what
/// makes a wall-mounted shared device safe to lose: a stolen kiosk carries
/// nobody's biometric data. Adding a local cache here — however convenient it
/// would be for an offline mode — gives that property away, and the offline
/// mode was already traded for it deliberately (FR-024, FR-025).
class KioskTokenStore {
  KioskTokenStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'kiosk_token';
  static const _deviceIdKey = 'kiosk_device_id';

  /// Cached in memory so every request does not hit the keystore. A kiosk makes
  /// several calls per employee and there may be a queue at the door.
  static String? _cachedToken;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Called when the server rejects the token — revoked, unpaired, or unknown.
  ///
  /// The device id deliberately survives: it identifies the hardware, not the
  /// pairing, and keeping it stable means re-pairing the same tablet produces
  /// one device history rather than a new row every time.
  static Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  static Future<String> getOrCreateDeviceId() async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId != null && deviceId.isNotEmpty) return deviceId;
    deviceId = _generateUuid();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // RFC 4122 v4.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
