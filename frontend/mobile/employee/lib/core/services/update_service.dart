import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constant/strings/update_strings.dart';
import '../utils/version_compare.dart';
import 'firebase_ready.dart';

enum UpdateAction { none, optional, force }

/// يقرأ `permedjat_app_min_version` من Remote Config لتحديد التحديث الإجباري،
/// ويستخدم in-app updates على Android و upgrader على iOS.
class UpdateService extends GetxService {
  static const String _minVersionKey = 'permedjat_app_min_version';

  bool _checking = false;
  DateTime? _lastCheckTime;
  int? _lastAvailableVersionCode;
  int? _skippedVersionCode;

  final Rx<UpdateAction> action = UpdateAction.none.obs;
  int? get lastAvailableVersionCode => _lastAvailableVersionCode;

  static const _minRecheckInterval = Duration(minutes: 5);

  Future<UpdateAction> check() async {
    if (_checking) return UpdateAction.none;
    _checking = true;
    try {
      final now = DateTime.now();
      if (_lastCheckTime != null &&
          now.difference(_lastCheckTime!) < _minRecheckInterval) {
        return action.value;
      }
      _lastCheckTime = now;

      // Remote Config is unreachable without Firebase; skip the version gate
      // rather than block the user behind it.
      if (!await FirebaseReady.orGiveUp()) {
        action.value = UpdateAction.none;
        return UpdateAction.none;
      }

      await FirebaseRemoteConfig.instance.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await FirebaseRemoteConfig.instance.fetchAndActivate();

      final current = (await PackageInfo.fromPlatform()).version;
      final minRequired =
          FirebaseRemoteConfig.instance.getString(_minVersionKey);

      final isForce = minRequired.isNotEmpty &&
          minRequired != '0.0.0' &&
          isVersionLower(current, minRequired);

      if (isForce) {
        if (Platform.isAndroid) {
          await _performAndroidImmediate();
        }
        action.value = UpdateAction.force;
        return UpdateAction.force;
      }

      if (Platform.isAndroid) {
        final result = await _checkAndroidOptional();
        action.value = result;
        return result;
      }

      action.value = UpdateAction.none;
      return UpdateAction.none;
    } catch (_) {
      action.value = UpdateAction.none;
      return UpdateAction.none;
    } finally {
      _checking = false;
    }
  }

  /// استدعاء يدوي من زر "تحديث الآن" — يتجاوز الـ throttle.
  Future<void> triggerAndroidUpdate() async {
    if (!Platform.isAndroid) return;
    await _performAndroidImmediate();
  }

  // Google Play's update check can hang indefinitely (no success/failure
  // callback) when the app isn't "owned" by the Play Store — e.g. debug /
  // sideloaded builds, or devices with a limited Play Store. A hang is not a
  // PlatformException, so it would never be caught and would block the UI
  // (UpdateGate spins forever). Bound every Play call with a timeout and
  // swallow any error so the app always proceeds.
  static const _playCheckTimeout = Duration(seconds: 8);

  Future<void> _performAndroidImmediate() async {
    // In-app updates only work for Play-installed release builds; skip the call
    // entirely in debug so development on a sideloaded build never waits on it.
    if (kDebugMode) return;
    try {
      final info =
          await InAppUpdate.checkForUpdate().timeout(_playCheckTimeout);
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } on PlatformException {
      await _openStore();
    } catch (_) {
      // timeout or any other failure — skip the in-app update
    }
  }

  Future<UpdateAction> _checkAndroidOptional() async {
    if (kDebugMode) return UpdateAction.none;
    try {
      final info =
          await InAppUpdate.checkForUpdate().timeout(_playCheckTimeout);
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final availableCode = info.availableVersionCode;
        _lastAvailableVersionCode = availableCode;
        if (_skippedVersionCode != null &&
            _skippedVersionCode == availableCode) {
          return UpdateAction.none;
        }
        return UpdateAction.optional;
      }
    } catch (_) {
      // PlatformException (sideloaded), timeout (hang), or anything else
      return UpdateAction.none;
    }
    return UpdateAction.none;
  }

  Future<void> startFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        _showInstallSnackBar();
      }
    } on PlatformException {
      // update failed silently
    }
  }

  Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on PlatformException {
      // update failed silently
    }
  }

  void skipOptional(int versionCode) {
    _skippedVersionCode = versionCode;
    action.value = UpdateAction.none;
  }

  void _showInstallSnackBar() {
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(UpdateStrings.updateReady),
        action: SnackBarAction(
          label: UpdateStrings.installNow,
          onPressed: () => completeFlexibleUpdate(),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final packageName = (await PackageInfo.fromPlatform()).packageName;
    final marketUri = Uri.parse('market://details?id=$packageName');
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri);
    } else {
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName'),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
