import 'dart:io';
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

  static Future<bool> _isVpnActive() async {
    // iOS exposes `utun` interfaces by default (Handoff/AirDrop/Personal Hotspot)
    // even without a user VPN, so matching `utun` there flags every iPhone.
    // On iOS we look only for the interfaces a real VPN actually adds.
    final vpnPrefixes = Platform.isIOS
        ? const ['ipsec', 'ppp', 'tap']
        : const ['tun', 'tap', 'ppp', 'pptp', 'wg'];
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
