import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';

/// Capture a branch's GPS geofence — center point taken from the manager's
/// phone + an allowed radius — used by QR+GPS and GPS-only attendance.
/// On success calls [onSaved] with the persisted values.
Future<void> showBranchLocationSheet(
  BuildContext context, {
  required int branchId,
  required String branchName,
  double? initialLat,
  double? initialLng,
  required int initialRadius,
  required void Function(double lat, double lng, int radius) onSaved,
  // When provided, used to persist instead of the default branch save — e.g.
  // saving a company-wide geofence. Must return the API response map.
  Future<Map<String, dynamic>> Function(double lat, double lng, int radius)?
      onPersist,
}) {
  return Get.bottomSheet<void>(
    _BranchLocationSheet(
      branchId: branchId,
      branchName: branchName,
      initialLat: initialLat,
      initialLng: initialLng,
      initialRadius: initialRadius,
      onSaved: onSaved,
      onPersist: onPersist,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _BranchLocationSheet extends StatefulWidget {
  final int branchId;
  final String branchName;
  final double? initialLat;
  final double? initialLng;
  final int initialRadius;
  final void Function(double lat, double lng, int radius) onSaved;
  final Future<Map<String, dynamic>> Function(double lat, double lng, int radius)?
      onPersist;

  const _BranchLocationSheet({
    required this.branchId,
    required this.branchName,
    required this.initialLat,
    required this.initialLng,
    required this.initialRadius,
    required this.onSaved,
    this.onPersist,
  });

  @override
  State<_BranchLocationSheet> createState() => _BranchLocationSheetState();
}

class _BranchLocationSheetState extends State<_BranchLocationSheet> {
  static const _presets = [10, 30, 50, 100, 200];

  late double? _lat = widget.initialLat;
  late double? _lng = widget.initialLng;
  late int _radius = widget.initialRadius;
  bool _capturing = false;
  bool _saving = false;
  String? _error;

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _error = 'location_services_disabled'.tr);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _error = 'location_required'.tr);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      setState(() => _error = 'location_capture_failed'.tr);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      Get.snackbar('error'.tr, 'capture_location_first'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _saving = true);
    final res = widget.onPersist != null
        ? await widget.onPersist!(_lat!, _lng!, _radius)
        : await BranchData().updateBranchLocation(
            id: widget.branchId,
            latitude: _lat!,
            longitude: _lng!,
            gpsRadiusMeters: _radius,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] == StatusRequest.success) {
      widget.onSaved(_lat!, _lng!, _radius);
      Get.back<void>();
      Get.snackbar('done'.tr, 'config_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr, 'config_save_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasLocation = _lat != null && _lng != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('set_branch_gps'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: 2),
            Text(
              widget.branchName,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'gps_location_hint'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Captured point card.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: hasLocation ? colors.brandSubtle : colors.sunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: hasLocation ? colors.brand : colors.borderHairline),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLocation
                        ? Icons.location_on
                        : Icons.location_off_outlined,
                    color: hasLocation ? colors.brand : colors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLocation ? 'location_set'.tr : 'location_not_set'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                hasLocation ? colors.brand : colors.textSecondary,
                          ),
                        ),
                        if (hasLocation) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 11,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                _error!,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _capturing ? null : _capture,
                icon: _capturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  hasLocation
                      ? 'recapture_location'.tr
                      : 'capture_my_location'.tr,
                  style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brand,
                  side: BorderSide(color: colors.brand),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s5),
            Text(
              'radius_meters_label'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: _presets.map((r) {
                final on = _radius == r;
                return ChoiceChip(
                  label: Text('$r م'),
                  selected: on,
                  onSelected: (_) => setState(() => _radius = r),
                  labelStyle: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: on ? Colors.white : colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  selectedColor: colors.brand,
                  backgroundColor: colors.canvas,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: BorderSide(
                        color: on ? colors.brand : colors.borderHairline),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _radius.clamp(5, 500).toDouble(),
                    min: 5,
                    max: 500,
                    divisions: 99,
                    activeColor: colors.brand,
                    label: '$_radius م',
                    onChanged: (v) => setState(() => _radius = v.round()),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '$_radius م',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back<void>(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.borderHairline),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                    child: Text('cancel'.tr,
                        style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_saving || !hasLocation) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('save'.tr,
                            style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
    );
  }
}
