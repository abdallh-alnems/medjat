import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/attendance_station_model.dart';
import '../../../data/model/branch_model.dart';
import '../../../logic/controller/station/stations_controller.dart';

class StationsManagementScreen extends StatelessWidget {
  const StationsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(StationsController());

    return Scaffold(
      appBar: AppBar(title: Text('stations_management'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_add_station',
        onPressed: () => _showCreateDialog(context, ctrl),
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: GetBuilder<StationsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.load,
            widget: Column(
              children: [
                _BranchFilter(ctrl: ctrl),
                Expanded(
                  child: ctrl.stations.isEmpty
                      ? Center(
                          child: Text('no_stations'.tr,
                              style: AppTextStyles.bodySecondary(context)))
                      : RefreshIndicator(
                          onRefresh: () => ctrl.load(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            itemCount: ctrl.stations.length,
                            itemBuilder: (_, i) =>
                                _StationTile(station: ctrl.stations[i], ctrl: ctrl),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, StationsController ctrl) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    BranchModel? selectedBranch;

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setState) {
          final colors = AppColors.of(context);
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                      decoration: BoxDecoration(color: colors.borderHairline, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text('add_station'.tr, style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Text('branch'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.borderHairline),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BranchModel>(
                        isExpanded: true,
                        hint: Text('select_branch'.tr),
                        value: selectedBranch,
                        items: ctrl.branches.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.name, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setState(() => selectedBranch = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'device_name'.tr,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextField(
                    controller: pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'admin_pin'.tr,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedBranch == null || nameCtrl.text.isEmpty || pinCtrl.text.isEmpty) {
                          Get.snackbar('error'.tr, 'fill_all_fields'.tr, snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        final result = await ctrl.createStation(
                          selectedBranch!.id, nameCtrl.text.trim(), pinCtrl.text.trim(),
                        );
                        Get.back<void>();
                        if (result != null) {
                          _showQRDialog(context, result);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: Text('create'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showQRDialog(BuildContext context, Map<String, dynamic> data) {
    final colors = AppColors.of(context);
    final qrPayload = data['qr_payload'] as String? ?? '';
    final expiresAt = data['expires_at'] as String? ?? '';

    Get.dialog<void>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('station_qr_title'.tr, style: AppTextStyles.h2(context)),
              const SizedBox(height: AppSpacing.s4),
              QrImageView(data: qrPayload, size: 200),
              const SizedBox(height: AppSpacing.s3),
              Text(
                '${'qr_expires'.tr}: $expiresAt',
                style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12, color: colors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.s4),
              ElevatedButton(
                onPressed: () => Get.back<void>(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: Text('done'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchFilter extends StatelessWidget {
  final StationsController ctrl;
  const _BranchFilter({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            isExpanded: true,
            hint: Text('all_branches'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
            value: ctrl.filterBranchId,
            items: [
              DropdownMenuItem(value: null, child: Text('all_branches'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'))),
              ...ctrl.branches.map((b) => DropdownMenuItem(
                value: b.id,
                child: Text(b.name, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
              )),
            ],
            onChanged: (v) => ctrl.setFilter(v),
          ),
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  final AttendanceStationModel station;
  final StationsController ctrl;
  const _StationTile({required this.station, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(station.statusLabel, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_outlined, size: 22, color: statusColor),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(station.deviceName,
                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'station_status_${station.statusLabel}'.tr,
                  style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, fontWeight: FontWeight.w500, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text('${'branch'.tr}: ${station.branchName}',
              style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12, color: colors.textTertiary)),
          if (station.lastHeartbeatAt != null)
            Text('${'last_activity'.tr}: ${_formatDate(station.lastHeartbeatAt!)}',
                style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, color: colors.textTertiary)),
          const SizedBox(height: AppSpacing.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (station.isLocked)
                TextButton.icon(
                  onPressed: () => ctrl.unlockStation(station.id),
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  label: Text('unlock'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: colors.warning),
                ),
              if (!station.isActivated)
                TextButton.icon(
                  onPressed: () async {
                    final result = await ctrl.regenerateQR(station.id);
                    if (result != null) {
                      _showQRDialog(context, result);
                    }
                  },
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: Text('show_qr'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12)),
                ),
              TextButton.icon(
                onPressed: () => _showGeneratePin(context, ctrl, station.id),
                icon: const Icon(Icons.pin, size: 18),
                label: Text('generate_pin'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: colors.brand),
              ),
              TextButton.icon(
                onPressed: () => _confirmDelete(context, ctrl),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('delete'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: colors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQRDialog(BuildContext context, Map<String, dynamic> data) {
    final colors = AppColors.of(context);
    final qrPayload = data['qr_payload'] as String? ?? '';
    Get.dialog<void>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('station_qr_title'.tr, style: AppTextStyles.h2(context)),
              const SizedBox(height: AppSpacing.s4),
              QrImageView(data: qrPayload, size: 200),
              const SizedBox(height: AppSpacing.s4),
              ElevatedButton(
                onPressed: () => Get.back<void>(),
                style: ElevatedButton.styleFrom(backgroundColor: colors.brand, foregroundColor: Colors.white),
                child: Text('done'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, StationsController ctrl) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('confirm_delete'.tr),
        content: Text('confirm_delete_station'.tr),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back<void>();
              ctrl.deleteStation(station.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.of(context).error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  void _showGeneratePin(BuildContext context, StationsController ctrl, int stationId) async {
    try {
      final result = await ctrl.generateKioskPin(stationId);
      if (result != null) {
        final pin = result['pin'] as String? ?? '';
        final expiresAt = result['expires_at'] as String? ?? '';
        Get.dialog<void>(
          Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('kiosk_pin'.tr, style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      pin,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                        fontFamily: 'Geist',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    '${'expires'.tr}: $expiresAt',
                    style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12, color: AppColors.of(context).textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'pin_one_time_warning'.tr,
                    style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, color: AppColors.of(context).warning),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ElevatedButton(
                    onPressed: () => Get.back<void>(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: Text('done'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (_) {
      Get.snackbar('error'.tr, 'failed_generate_pin'.tr, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'active': return colors.success;
      case 'locked': return colors.warning;
      case 'deactivated': return colors.error;
      case 'pending': return colors.textTertiary;
      default: return colors.textTertiary;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
