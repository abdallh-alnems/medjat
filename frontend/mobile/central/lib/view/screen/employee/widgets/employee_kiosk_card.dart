import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../data/data_source/remote/kiosk_data/kiosk_data.dart';
import '../../../../core/class/status_request.dart';
import '../../kiosk/widgets/kiosk_code_dialog.dart';

/// Kiosk facts about one employee: whether their face is enrolled, and their
/// personal fallback code.
///
/// Both belong on the employee rather than in the kiosk screen, because both
/// answer a question an HR person asks while looking at a person: "why can't
/// Ahmed clock in?" The two usual answers are that nobody ever enrolled his
/// face, or that his code was never issued.
class EmployeeKioskCard extends StatefulWidget {
  const EmployeeKioskCard({
    super.key,
    required this.employeeId,
    required this.faceEnrolledAt,
    required this.enrolledStationName,
    required this.hasKioskCode,
    required this.canManage,
  });

  final int employeeId;

  /// Null when the employee has never been enrolled — which is the single most
  /// common reason a kiosk does not recognise somebody.
  final String? faceEnrolledAt;

  final String? enrolledStationName;
  final bool hasKioskCode;

  /// `manage_employees` — matching what v1/kiosk/set-pin enforces.
  final bool canManage;

  @override
  State<EmployeeKioskCard> createState() => _EmployeeKioskCardState();
}

class _EmployeeKioskCardState extends State<EmployeeKioskCard> {
  final KioskData _data = Get.isRegistered<KioskData>()
      ? Get.find<KioskData>()
      : Get.put(KioskData());

  bool _busy = false;
  late bool _hasCode = widget.hasKioskCode;

  Future<void> _issueCode() async {
    setState(() => _busy = true);
    final response = await _data.setEmployeeCode(employeeId: widget.employeeId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (response['status'] != StatusRequest.success) {
      Get.snackbar('error'.tr, 'generic_error'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final data = response['data'] is Map && response['data']['data'] is Map
        ? response['data']['data']
        : response['data'];
    final code = data is Map ? data['code'] as String? : null;
    if (code == null || !mounted) return;

    setState(() => _hasCode = true);

    // Shown once: the server keeps only a hash, so there is no second chance
    // to read it and no way to look it up later.
    await showKioskCodeDialog(
      context,
      code: code,
      title: 'kiosk_employee_code'.tr,
      explanation: 'kiosk_employee_code_hint'.tr,
    );
  }

  Future<void> _clearCode() async {
    setState(() => _busy = true);
    final response =
        await _data.setEmployeeCode(employeeId: widget.employeeId, clear: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (response['status'] == StatusRequest.success) _hasCode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enrolled = widget.faceEnrolledAt != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tablet_android, size: 20, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text('kiosks'.tr,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: colors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),

          // ── Face enrollment, and where it came from ──
          Row(
            children: [
              Icon(
                enrolled ? Icons.how_to_reg : Icons.person_off_outlined,
                size: 18,
                color: enrolled ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enrolled
                          ? '${'kiosk_enrolled_at'.tr}: ${widget.faceEnrolledAt}'
                          : 'kiosk_enrolled_never'.tr,
                      style: TextStyle(
                          fontSize: 13, color: colors.textPrimary),
                    ),
                    // Provenance: an enrollment nobody watched being made is
                    // worth being able to trace back to a device.
                    if (enrolled && widget.enrolledStationName != null)
                      Text(
                        'kiosk_enrolled_via'
                            .trParams({'station': widget.enrolledStationName!}),
                        style: TextStyle(
                            fontSize: 11, color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: AppSpacing.s5),

          // ── Personal fallback code ──
          Row(
            children: [
              Icon(Icons.dialpad,
                  size: 18,
                  color: _hasCode ? Colors.green : colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  _hasCode
                      ? 'kiosk_employee_code_set'.tr
                      : 'kiosk_employee_code_none'.tr,
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                ),
              ),
              if (widget.canManage)
                if (_busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: (v) =>
                        v == 'issue' ? _issueCode() : _clearCode(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'issue',
                        child: Text('kiosk_employee_code_issue'.tr),
                      ),
                      if (_hasCode)
                        PopupMenuItem(
                          value: 'clear',
                          child: Text('kiosk_employee_code_clear'.tr),
                        ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
