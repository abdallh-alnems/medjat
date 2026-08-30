import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_device/safe_device.dart';

// All device-side checks (mock/root/vpn) can be bypassed in a modified app build.
// The strong layer is server-side Geofence. These flags are advisory — the server
// logs them but does not trust them absolutely.
// iOS note: Position.isMocked always returns false on iOS (the OS does not allow
// mock location unless the device is jailbroken). iOS GPS spoofing protection
// comes from jailbreak detection.

class DeviceIntegrityResult {
  final bool isMockLocation;
  final bool isRooted;
  final bool isVpn;

  const DeviceIntegrityResult({
    required this.isMockLocation,
    required this.isRooted,
    required this.isVpn,
  });

  bool get isBlocking => isMockLocation || isRooted;
}

class DeviceIntegrityService {
  static Future<DeviceIntegrityResult> check(Position position) async {
    bool rooted = false;
    try {
      rooted = await SafeDevice.isJailBroken;
    } catch (_) {
      rooted = false;
    }

    bool mock = position.isMocked;
    if (!mock && Platform.isAndroid) {
      try {
        mock = await SafeDevice.isMockLocation;
      } catch (_) {}
    }

    final vpn = await _isVpnActive();

    return DeviceIntegrityResult(
      isMockLocation: mock,
      isRooted: rooted,
      isVpn: vpn,
    );
  }

  /// Public, lightweight VPN-only probe used by the app-open gate (splash)
  /// so the app refuses to open while a VPN/proxy interface is active.
  static Future<bool> isVpnActive() => _isVpnActive();

  static const _iosVpnChannel = MethodChannel('app/vpn');

  static Future<bool> _isVpnActive() async {
    // iOS: interface-name matching is unreliable. `utun` interfaces exist on
    // every iPhone (Handoff/Hotspot) and a configured-but-disconnected IKEv2
    // VPN leaves an idle `ipsec0` interface — both produce false positives.
    // The native side reads the system proxy scoped settings instead, which
    // only list VPN keys while a tunnel is actively routing traffic.
    if (Platform.isIOS) {
      try {
        final active = await _iosVpnChannel.invokeMethod<bool>('isVpnActive');
        return active ?? false;
      } catch (_) {
        return false;
      }
    }
    // Android: interface-name detection is reliable.
    const vpnPrefixes = ['tun', 'tap', 'ppp', 'pptp', 'wg'];
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (vpnPrefixes.any((p) => name.startsWith(p))) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
