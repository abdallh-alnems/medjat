import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/version_compare.dart';

class UpdateCheckResult {
  final bool needsForceUpdate;
  final bool isMaintenance;
  final String maintenanceMessage;
  UpdateCheckResult({
    required this.needsForceUpdate,
    required this.isMaintenance,
    required this.maintenanceMessage,
  });
}

class RemoteConfigService extends GetxService {
  final remoteConfig = FirebaseRemoteConfig.instance;

  @override
  void onInit() {
    super.onInit();
    remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: Duration.zero,
    ));
    remoteConfig.setDefaults(const {
      'min_required_version': '0.0.0',
      'maintenance_enabled': false,
      'maintenance_message': 'التطبيق تحت الصيانة حالياً، سنعود قريباً',
    });
  }

  Future<UpdateCheckResult> check() async {
    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {}

    final maintenanceEnabled = remoteConfig.getBool('maintenance_enabled');
    final maintenanceMessage = remoteConfig.getString('maintenance_message');
    final minVersion = remoteConfig.getString('min_required_version');

    bool needsUpdate = false;
    if (minVersion != '0.0.0') {
      final packageInfo = await PackageInfoPlus.instance;
      final currentVersion = packageInfo.version;
      needsUpdate = isVersionLower(currentVersion, minVersion);
    }

    return UpdateCheckResult(
      needsForceUpdate: needsUpdate,
      isMaintenance: maintenanceEnabled,
      maintenanceMessage: maintenanceMessage,
    );
  }

  Stream<void> get onConfigUpdated => remoteConfig.onConfigUpdated;
}

class PackageInfoPlus {
  static Future<PackageInfo> get instance => PackageInfo.fromPlatform();
}
