import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// What the device reports about the WiFi network it is on.
class WifiInfo {
  /// The access point's MAC address, normalised to lower-case colon form.
  /// Null when the device is not on WiFi, or cannot read the value.
  final String? bssid;

  /// The network name. Informational only — the server never trusts it,
  /// because anyone can name a hotspot "Medjat-Office".
  final String? ssid;

  const WifiInfo({this.bssid, this.ssid});

  static const WifiInfo none = WifiInfo();

  bool get isOnWifi => bssid != null;
}

/// Reads the connected access point for the `wifi_gps` attendance method.
class NetworkService {
  NetworkService._();

  /// Android hands back this sentinel instead of a real BSSID when location
  /// permission is missing or location services are off. It is not a network —
  /// the backend rejects it too, but filtering here keeps a useless value out
  /// of the sightings table.
  static const String _deniedSentinel = '02:00:00:00:00:00';

  static Future<WifiInfo> current() async {
    try {
      final info = NetworkInfo();
      final rawBssid = await info.getWifiBSSID();
      final rawSsid = await info.getWifiName();

      return WifiInfo(
        bssid: _normalise(rawBssid),
        ssid: _cleanSsid(rawSsid),
      );
    } catch (e) {
      // On iOS this throws without the com.apple.developer.networking.wifi-info
      // entitlement. That is expected, not an error worth surfacing: the branch
      // can verify by public IP instead, which needs nothing from the device.
      if (Platform.isIOS) {
        debugPrint('NetworkService: WiFi info unavailable on iOS — $e');
      } else {
        debugPrint('NetworkService: failed to read WiFi info — $e');
      }
      return WifiInfo.none;
    }
  }

  static String? _normalise(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase().replaceAll('-', ':');
    if (value.isEmpty) return null;
    if (value == _deniedSentinel || value == '00:00:00:00:00:00') return null;
    if (!RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$').hasMatch(value)) return null;
    return value;
  }

  /// iOS wraps the SSID in quotes; Android sometimes returns `<unknown ssid>`.
  static String? _cleanSsid(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    if (value.isEmpty || value == '<unknown ssid>') return null;
    return value;
  }
}
