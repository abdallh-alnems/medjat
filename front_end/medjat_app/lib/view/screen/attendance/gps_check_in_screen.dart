import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/location_service.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../logic/controller/home/home_controller.dart';

/// GPS-only check-in / check-out confirmation. Shows the branch, the
/// employee's current distance, and whether they are within range before
/// confirming. Used when the branch's attendance method is `gps_only`.
class GpsCheckInScreen extends StatefulWidget {
  const GpsCheckInScreen({super.key});

  @override
  State<GpsCheckInScreen> createState() => _GpsCheckInScreenState();
}

class _GpsCheckInScreenState extends State<GpsCheckInScreen> {
  double? _distance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Get.find<AttendanceController>().reset();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await LocationService().getCurrentPosition();
      final config = Get.find<HomeController>().attendanceConfig;
      double? distance;
      if (config.branchLat != null && config.branchLng != null) {
        distance = LocationService.distanceBetween(
          position.latitude,
          position.longitude,
          config.branchLat!,
          config.branchLng!,
        );
      }
      if (!mounted) return;
      setState(() {
        _distance = distance;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'location_required'.tr;
      });
    }
  }

  bool get _outOfRange {
    final config = Get.find<HomeController>().attendanceConfig;
    if (_distance == null) return false;
    return _distance! > config.gpsRadiusMeters;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final home = Get.find<HomeController>();
    final isCheckOut = home.canCheckOut;
    final config = home.attendanceConfig;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(isCheckOut
            ? 'gps_check_out_title'.tr
            : 'gps_check_in_title'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.s6),
              Icon(
                Icons.location_on_outlined,
                size: 72,
                color: colors.brand,
              ),
              const SizedBox(height: AppSpacing.s5),
              if (config.branchName != null)
                Text(
                  'your_branch'.trParams({'name': config.branchName!}),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3(context),
                ),
              const SizedBox(height: AppSpacing.s5),
              _buildStatusCard(colors),
              const Spacer(),
              _buildConfirmButton(colors, isCheckOut),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(AppColorScheme colors) {
    if (_loading) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.s3),
          Text('getting_location'.tr, style: TextStyle(
            fontFamily: AppTextStyles.arabicFamily,
            color: colors.textSecondary,
          )),
        ],
      );
    }

    if (_error != null) {
      return _InfoCard(
        colors: colors,
        icon: Icons.error_outline,
        color: colors.error,
        text: _error!,
      );
    }

    if (_distance == null) {
      return _InfoCard(
        colors: colors,
        icon: Icons.info_outline,
        color: colors.textSecondary,
        text: 'branch_location_unavailable'.tr,
      );
    }

    final inRange = !_outOfRange;
    return _InfoCard(
      colors: colors,
      icon: inRange ? Icons.check_circle_outline : Icons.location_off_outlined,
      color: inRange ? colors.brand : colors.warning,
      text: inRange
          ? 'within_branch_range'.tr
          : 'out_of_range'.tr,
      subtitle: _formatDistance(_distance!),
    );
  }

  Widget _buildConfirmButton(AppColorScheme colors, bool isCheckOut) {
    return GetBuilder<AttendanceController>(
      builder: (controller) {
        final processing = controller.status == StatusRequest.loading;
        final disabled = _loading || _error != null || _outOfRange || processing;

        // Surface failures (e.g. backend rejection) without leaving the screen.
        if (controller.status == StatusRequest.failure &&
            controller.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Get.snackbar('error'.tr, controller.errorMessage!,
                snackPosition: SnackPosition.BOTTOM);
            controller.reset();
          });
        }

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: disabled ? null : controller.processGpsCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isCheckOut
                        ? 'confirm_check_out'.tr
                        : 'confirm_check_in'.tr,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.arabicFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return 'm_from_branch'.trParams({'distance': '${meters.round()}'});
    }
    return 'km_from_branch'
        .trParams({'distance': (meters / 1000).toStringAsFixed(1)});
  }
}

class _InfoCard extends StatelessWidget {
  final AppColorScheme colors;
  final IconData icon;
  final Color color;
  final String text;
  final String? subtitle;

  const _InfoCard({
    required this.colors,
    required this.icon,
    required this.color,
    required this.text,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: AppTextStyles.arabicFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: AppTextStyles.arabicFamily,
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
