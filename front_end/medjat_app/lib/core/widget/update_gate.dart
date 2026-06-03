import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constant/strings/update_strings.dart';
import '../constant/strings/upgrade_messages.dart';
import '../constant/theme/app_colors.dart';
import '../constant/theme/app_spacing.dart';
import '../services/update_service.dart';

/// يفحص التحديث عند الإقلاع: تحديث إجباري (شاشة حاجزة) أو اختياري (حوار).
/// على Android يعتمد على in-app updates، وعلى iOS على upgrader.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late Future<UpdateAction> _checkFuture;
  bool _dialogShown = false;

  final Upgrader _iosUpgrader = Upgrader(
    messages: UpgradeMessages(),
    durationUntilAlertAgain: const Duration(days: 1),
    countryCode: 'EG',
  );

  @override
  void initState() {
    super.initState();
    _checkFuture = _runCheck();
  }

  Future<UpdateAction> _runCheck() async {
    final service = Get.find<UpdateService>();
    return service.check();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UpdateAction>(
      future: _checkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(AppColors.of(context).brand),
              ),
            ),
          );
        }

        final action = snapshot.data ?? UpdateAction.none;

        if (Platform.isIOS) {
          return _buildIOS(action);
        }
        return _buildAndroid(action);
      },
    );
  }

  Widget _buildAndroid(UpdateAction action) {
    if (action == UpdateAction.force) {
      return _ForceUpdateScreen(
        onRetry: () async {
          final service = Get.find<UpdateService>();
          await service.triggerAndroidUpdate();
        },
      );
    }

    if (action == UpdateAction.optional && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOptionalDialog();
      });
    }

    return widget.child;
  }

  Widget _buildIOS(UpdateAction action) {
    if (action == UpdateAction.force) {
      return _ForceUpdateScreen(
        onRetry: () async {
          final info = await PackageInfo.fromPlatform();
          final uri = Uri.parse(
            'https://apps.apple.com/app/id${info.packageName}',
          );
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      );
    }

    return UpgradeAlert(
      upgrader: _iosUpgrader,
      showIgnore: false,
      dialogStyle: UpgradeDialogStyle.cupertino,
      child: widget.child,
    );
  }

  Future<void> _showOptionalDialog() async {
    final service = Get.find<UpdateService>();
    if (service.action.value != UpdateAction.optional) return;
    await OptionalUpdateDialog.show();
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _ForceUpdateScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.brand.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.system_update_rounded,
                      size: 48, color: colors.brand),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  UpdateStrings.forceTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  UpdateStrings.forceMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 16,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.s7),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.shop),
                    label: Text(
                      UpdateStrings.updateNow,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.brand,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OptionalUpdateDialog extends StatelessWidget {
  const OptionalUpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        UpdateStrings.optionalTitle,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      content: Text(
        UpdateStrings.optionalMessage,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          color: colors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final service = Get.find<UpdateService>();
            final code = service.lastAvailableVersionCode;
            if (code != null) {
              service.skipOptional(code);
            }
            Navigator.of(context).pop();
          },
          child: Text(
            UpdateStrings.later,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final service = Get.find<UpdateService>();
            await service.startFlexibleUpdate();
          },
          style: FilledButton.styleFrom(backgroundColor: colors.brand),
          child: Text(UpdateStrings.updateNow),
        ),
      ],
    );
  }

  static Future<void> show() async {
    await Get.dialog<void>(
      const OptionalUpdateDialog(),
      barrierDismissible: false,
    );
  }
}
