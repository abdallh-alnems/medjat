import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  TokenStorageService._();
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';
  static const _deviceIdKey = 'device_id';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveUserData(String json) async {
    await _storage.write(key: _userKey, value: json);
  }

  static Future<String?> getUserData() async {
    return await _storage.read(key: _userKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String> getOrCreateDeviceId() async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId != null && deviceId.isNotEmpty) return deviceId;
    deviceId = _generateUuid();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  static Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  static Future<void> clearAll() async {
    final deviceId = await _storage.read(key: _deviceIdKey);
    await _storage.deleteAll();
    if (deviceId != null) {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
