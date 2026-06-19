import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/services/device_integrity_service.dart';

/// Full-screen gate shown when the app is opened while a VPN/proxy interface
/// is active. The app does not proceed past this screen until the user
/// disables the VPN and the re-check passes.
class VpnBlockedScreen extends StatefulWidget {
  const VpnBlockedScreen({super.key});

  @override
  State<VpnBlockedScreen> createState() => _VpnBlockedScreenState();
}

class _VpnBlockedScreenState extends State<VpnBlockedScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    bool stillVpn;
    try {
      stillVpn = await DeviceIntegrityService.isVpnActive();
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      Get.snackbar('vpn_blocked_title'.tr, 'vpn_blocked_message'.tr);
      return;
    }
    if (!mounted) return;
    if (stillVpn) {
      setState(() => _checking = false);
      Get.snackbar('vpn_blocked_title'.tr, 'vpn_blocked_message'.tr);
      return;
    }
    // VPN is off — restart the normal launch flow from splash.
    unawaited(Get.offAllNamed<void>(AppRoutes.splash));
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_lock_rounded, size: 72, color: colors.error),
                  const SizedBox(height: 24),
                  Text(
                    'vpn_blocked_title'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'vpn_blocked_message'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      height: 1.6,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _recheck,
                      child: _checking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : Text('retry'.tr),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
