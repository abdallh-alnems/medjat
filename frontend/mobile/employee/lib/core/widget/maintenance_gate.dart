import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../constant/strings/update_strings.dart';
import '../constant/theme/app_colors.dart';
import '../constant/theme/app_spacing.dart';
import '../services/firebase_ready.dart';

/// مفتاح التخزين الذي يحمل إشارة الصيانة الواردة عبر FCM بينما التطبيق في
/// الخلفية أو مغلق؛ تقرأه البوابة عند أول بناء فور إعادة الفتح.
const String kPendingMaintenanceKey = 'pending_maintenance';

/// موضوع FCM الذي يشترك فيه التطبيق لاستقبال إشارات الصيانة الفورية.
const String kMaintenanceTopic = 'maintenance_permedjat_app';

/// يقرأ `permedjat_app_maintenance_enabled` من Remote Config ويعرض شاشة الصيانة
/// عند تفعيلها. يستمع للتحديثات الحيّة عبر onConfigUpdated، ويعيد الفحص عند
/// عودة التطبيق للمقدمة، ويستجيب فورًا لإشعار FCM عبر [trigger].
class MaintenanceGate extends StatefulWidget {
  final Widget child;
  const MaintenanceGate({super.key, required this.child});

  static const String _key = 'permedjat_app_maintenance_enabled';

  static _MaintenanceGateState? _instance;

  static void trigger(bool enabled) {
    _instance?._setMaintenance(enabled);
  }

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate>
    with WidgetsBindingObserver {
  bool _isMaintenance = false;
  bool _isChecking = true;
  StreamSubscription<RemoteConfigUpdate>? _rcSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MaintenanceGate._instance = this;
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rcSubscription?.cancel();
    MaintenanceGate._instance = null;
    super.dispose();
  }

  Future<void> _init() async {
    // إشارة وصلت عبر FCM والتطبيق مغلق/في الخلفية → طبّقها فورًا ثم استهلكها.
    final storage = GetStorage();
    if (storage.read<bool>(kPendingMaintenanceKey) ?? false) {
      _isMaintenance = true;
      unawaited(storage.remove(kPendingMaintenanceKey));
    }

    // Firebase initializes after the first frame, so this gate can mount before
    // it is ready. Wait briefly, then give up rather than spin on a device
    // where Firebase will never become available.
    if (!await FirebaseReady.orGiveUp()) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await rc.fetchAndActivate();
      _isMaintenance = rc.getBool(MaintenanceGate._key);
      _rcSubscription = rc.onConfigUpdated.listen((_) async {
        await rc.activate();
        if (!mounted) return;
        _setMaintenance(rc.getBool(MaintenanceGate._key));
      });
    } catch (_) {}

    if (mounted) setState(() => _isChecking = false);
  }

  void _setMaintenance(bool enabled) {
    if (!mounted || enabled == _isMaintenance) return;
    setState(() => _isMaintenance = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNow();
    }
  }

  Future<void> _checkNow() async {
    if (!await FirebaseReady.orGiveUp()) return;

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      _setMaintenance(rc.getBool(MaintenanceGate._key));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(AppColors.of(context).brand),
          ),
        ),
      );
    }

    if (_isMaintenance) return const _MaintenanceScreen();

    return widget.child;
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
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
                      color: colors.warning.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.build_rounded,
                        size: 48, color: colors.warning),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    UpdateStrings.maintenanceTitle,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    UpdateStrings.maintenanceMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 16,
                      color: colors.textSecondary,
                      height: 1.5,
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
