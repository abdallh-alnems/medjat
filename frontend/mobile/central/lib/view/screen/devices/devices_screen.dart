import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/attendance_device_model.dart';
import '../../../logic/controller/devices/devices_controller.dart';

/// Fingerprint / face terminals registered to the company.
///
/// The card leads with two facts, because they are the two things that are
/// ever actually wrong: is the device talking to us, and is anyone still
/// unlinked on it.
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text('devices'.tr),
        actions: [
          // Reachable even with no device registered: the customers who need
          // it most are exactly the ones whose terminal never connects.
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'import_punches'.tr,
            onPressed: () => Get.toNamed<void>(AppRoutes.importPunches),
          ),
        ],
      ),
      floatingActionButton: GetBuilder<DevicesController>(
        builder: (c) => FloatingActionButton.extended(
          onPressed: c.branches.isEmpty ? null : () => _showAddSheet(context, c),
          icon: const Icon(Icons.add),
          label: Text('device_add'.tr),
        ),
      ),
      body: GetBuilder<DevicesController>(
        builder: (c) {
          if (c.status == StatusRequest.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, 96),
              children: [
                Text(
                  'devices_hint'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textTertiary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                if (c.devices.isEmpty)
                  _EmptyState(colors: colors)
                else
                  for (final device in c.devices) ...[
                    _DeviceCard(device: device, ctrl: c, colors: colors),
                    const SizedBox(height: AppSpacing.s3),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, DevicesController c) {
    final serialCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    int? branchId = c.branches.length == 1 ? c.branches.first.id : null;
    final colors = AppColors.of(context);

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s4,
            top: AppSpacing.s4,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'device_add'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'device_serial_hint'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: serialCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  // Serials are printed as capitals; typing them in lower case
                  // is the single most common way to get "not found".
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => newValue.copyWith(
                      text: newValue.text.toUpperCase(),
                    ),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'device_serial'.tr,
                  hintText: 'ABC1234567890',
                  prefixIcon: const Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              DropdownButtonFormField<int>(
                initialValue: branchId,
                decoration: InputDecoration(labelText: 'branch'.tr),
                items: [
                  for (final b in c.branches)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setSheetState(() => branchId = v),
              ),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'device_name_optional'.tr,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              GetBuilder<DevicesController>(
                builder: (cc) => ElevatedButton(
                  onPressed: cc.saving
                      ? null
                      : () async {
                          if (branchId == null ||
                              serialCtrl.text.trim().isEmpty) {
                            return;
                          }
                          final ok = await cc.register(
                            serialNumber: serialCtrl.text,
                            branchId: branchId!,
                            name: nameCtrl.text,
                          );
                          if (ok) Get.back<void>();
                        },
                  child: cc.saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('device_register'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.ctrl,
    required this.colors,
  });

  final AttendanceDeviceModel device;
  final DevicesController ctrl;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline;
    final statusColor = device.isDisabled
        ? colors.textTertiary
        : (online ? colors.success : colors.error);

    return InkWell(
      onTap: () => Get.toNamed<void>(
        AppRoutes.deviceUsers,
        arguments: {
          'device_id': device.id,
          'device_label': device.displayName,
        },
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    device.displayName,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _onMenu(context, value),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'sync_time',
                      child: Text('device_sync_time'.tr),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Text('device_settings'.tr),
                    ),
                    PopupMenuItem(
                      value: device.isDisabled ? 'enable' : 'disable',
                      child: Text(
                        device.isDisabled
                            ? 'device_enable'.tr
                            : 'device_disable'.tr,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'release',
                      child: Text('device_release'.tr),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              '${device.serialNumber}'
              '${device.branchName != null ? ' · ${device.branchName}' : ''}',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                _Stat(
                  label: 'device_status'.tr,
                  value: device.isDisabled
                      ? 'device_disabled'.tr
                      : (online ? 'device_online'.tr : 'device_offline'.tr),
                  color: statusColor,
                  colors: colors,
                ),
                _Stat(
                  label: 'device_punches_today'.tr,
                  value: '${device.punchesToday}',
                  colors: colors,
                ),
                _Stat(
                  label: 'device_linked_users'.tr,
                  value: '${device.linkedUsers}',
                  colors: colors,
                ),
              ],
            ),
            if (device.pendingUsers > 0) ...[
              const SizedBox(height: AppSpacing.s3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'device_pending_users'
                      .trParams({'n': '${device.pendingUsers}'}),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.warning,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s2),
            Text(
              ctrl.lastSeenLabel(device),
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenu(BuildContext context, String value) {
    switch (value) {
      case 'sync_time':
        ctrl.sendCommand(device.id, 'sync_time');
        break;
      case 'settings':
        _showSettingsSheet(context);
        break;
      case 'enable':
        ctrl.updateDevice(deviceId: device.id, status: 'active');
        break;
      case 'disable':
        ctrl.updateDevice(deviceId: device.id, status: 'disabled');
        break;
      case 'release':
        Get.dialog<void>(
          AlertDialog(
            title: Text('device_release'.tr),
            content: Text('device_release_confirm'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back<void>(),
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: () {
                  Get.back<void>();
                  ctrl.release(device.id);
                },
                child: Text('confirm'.tr),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _showSettingsSheet(BuildContext context) {
    String directionMode = device.directionMode;
    int interval = device.minIntervalSeconds;
    int offset = device.clockOffsetMinutes;
    bool debug = device.debugLogging;

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'device_settings'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'device_direction_mode'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                for (final mode in const ['auto', 'device_status'])
                  _ModeOption(
                    colors: colors,
                    selected: directionMode == mode,
                    title: mode == 'auto'
                        ? 'device_direction_auto'.tr
                        : 'device_direction_status'.tr,
                    description: mode == 'auto'
                        ? 'device_direction_auto_desc'.tr
                        : 'device_direction_status_desc'.tr,
                    onTap: () => setSheetState(() => directionMode = mode),
                  ),
                const SizedBox(height: AppSpacing.s3),
                TextFormField(
                  initialValue: '$interval',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'device_min_interval'.tr,
                    helperText: 'device_min_interval_desc'.tr,
                  ),
                  onChanged: (v) => interval = int.tryParse(v) ?? interval,
                ),
                const SizedBox(height: AppSpacing.s3),
                TextFormField(
                  initialValue: '$offset',
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  decoration: InputDecoration(
                    labelText: 'device_clock_offset'.tr,
                    helperText: 'device_clock_offset_desc'.tr,
                  ),
                  onChanged: (v) => offset = int.tryParse(v) ?? offset,
                ),
                const SizedBox(height: AppSpacing.s2),
                SwitchListTile(
                  value: debug,
                  onChanged: (v) => setSheetState(() => debug = v),
                  title: Text('device_debug_logging'.tr),
                  subtitle: Text('device_debug_logging_desc'.tr),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.s3),
                ElevatedButton(
                  onPressed: () {
                    Get.back<void>();
                    ctrl.updateDevice(
                      deviceId: device.id,
                      directionMode: directionMode,
                      minIntervalSeconds: interval,
                      clockOffsetMinutes: offset,
                      debugLogging: debug,
                    );
                  },
                  child: Text('save'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.colors,
    this.color,
  });

  final String label;
  final String value;
  final AppColorScheme colors;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? colors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.colors,
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final AppColorScheme colors;
  final bool selected;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: selected
                ? colors.brand.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.brand : colors.borderHairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? colors.brand : colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: [
          Icon(Icons.fingerprint, size: 44, color: colors.textTertiary),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'devices_empty'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
