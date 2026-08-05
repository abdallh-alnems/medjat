import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/manager_invitation_model.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../widget/branch/branch_location_sheet.dart';
import '../../../logic/controller/settings/attendance_method_controller.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/class/status_request.dart';

class AttendanceMethodScreen extends StatelessWidget {
  const AttendanceMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AttendanceMethodController());

    return Scaffold(
      appBar: AppBar(title: Text('attendance_method_title'.tr)),
      body: GetBuilder<AttendanceMethodController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.load,
            widget: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryCard(ctrl: ctrl),
                  const SizedBox(height: AppSpacing.s4),
                  _CollapsibleSection(
                    icon: Icons.business_outlined,
                    title: 'tenant_default_method'.tr,
                    subtitle: _methodsSummary(ctrl.tenantMethods),
                    initiallyExpanded: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoBanner(),
                        const SizedBox(height: AppSpacing.s3),
                        _TenantMethodCards(ctrl: ctrl),
                        const SizedBox(height: AppSpacing.s3),
                        _OfflineModeCard(ctrl: ctrl),
                        const SizedBox(height: AppSpacing.s3),
                        _RejectMockLocationCard(ctrl: ctrl),
                        const SizedBox(height: AppSpacing.s3),
                        _RequireLocalBiometricCard(ctrl: ctrl),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  if (ctrl.branches.isNotEmpty)
                    _CollapsibleSection(
                      icon: Icons.store_outlined,
                      title: 'per_branch_override'.tr,
                      subtitle: ctrl.branchOverrideCount > 0
                          ? 'overrides_count'
                              .trParams({'n': '${ctrl.branchOverrideCount}'})
                          : 'no_overrides'.tr,
                      child: _BranchOverridesSection(ctrl: ctrl),
                    ),
                  const SizedBox(height: AppSpacing.s3),
                  _CollapsibleSection(
                    icon: Icons.label_outline,
                    title: 'per_category_override'.tr,
                    subtitle: ctrl.categoryOverrideCount > 0
                        ? 'overrides_count'
                            .trParams({'n': '${ctrl.categoryOverrideCount}'})
                        : 'no_overrides'.tr,
                    child: _CategoryOverridesSection(ctrl: ctrl),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _CollapsibleSection(
                    icon: Icons.person_outline,
                    title: 'per_employee_override'.tr,
                    subtitle: ctrl.employeeOverrideCount > 0
                        ? 'overrides_count'
                            .trParams({'n': '${ctrl.employeeOverrideCount}'})
                        : 'no_overrides'.tr,
                    child: _EmployeeOverridesSection(ctrl: ctrl),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Short, human label for a method id.
String methodLabel(String m) {
  switch (m) {
    case 'qr_gps':
      return 'method_qr_gps'.tr;
    case 'gps_only':
      return 'method_gps_only'.tr;
    case 'manual':
      return 'method_manual_admin'.tr;
    case 'device':
      return 'method_device'.tr;
    case 'face_selfie':
      return 'method_face_selfie'.tr;
    case 'wifi_gps':
      return 'method_wifi_gps'.tr;
    case 'kiosk':
      return 'method_kiosk'.tr;
    default:
      return m;
  }
}

/// Short badge text for a method chip.
///
/// Previously a nested conditional whose final `else` returned
/// `'manual'.tr.substring(0, 5)` — which labelled **every** unrecognised
/// method as a truncated "manual", already wrong for `device`, and would throw
/// a RangeError outright if a translation were shorter than five characters.
String methodBadge(String m) => switch (m) {
      'qr_gps' => 'QR',
      'gps_only' => 'GPS',
      'face_selfie' => 'face_badge'.tr,
      'wifi_gps' => 'WiFi',
      'device' => 'method_device'.tr,
      'kiosk' => 'method_kiosk'.tr,
      'manual' => 'method_manual_admin'.tr,
      _ => m,
    };

String _methodsSummary(Iterable<String> methods) =>
    methods.map(methodLabel).join(' · ');

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colors.brand),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              'attendance_method_info'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.brand,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantMethodCards extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _TenantMethodCards({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final qrEnabled = ctrl.tenantMethods.contains('qr_gps');
        return Column(
          children: [
            _MethodSwitchCard(
              icon: Icons.qr_code_2,
              title: 'method_qr_gps'.tr,
              description: 'method_qr_gps_desc'.tr,
              enabled: qrEnabled,
              onChanged: (v) => _toggle(context, 'qr_gps', v),
            ),
            if (qrEnabled) ...[
              const SizedBox(height: AppSpacing.s2),
              _QrPosterAccessButton(ctrl: ctrl),
            ],
            const SizedBox(height: AppSpacing.s2),
            _GpsOnlyMethodCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s2),
            _WifiMethodCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s2),
            _FaceMethodCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s2),
            _DeviceMethodCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s3),
            _KioskMethodCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s2),
            _ManualMethodCard(ctrl: ctrl),
          ],
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, String method, bool enable) async {
    if (!enable && ctrl.tenantMethods.length <= 1) {
      Get.snackbar(
        'error'.tr,
        'at_least_one_method_required'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final ok = await ctrl.toggleTenantMethod(method, enable);
    _showResultSnackbar(ok);
  }
}

void _showResultSnackbar(bool ok) {
  if (ok) {
    Get.snackbar('done'.tr, 'config_saved'.tr,
        snackPosition: SnackPosition.BOTTOM);
  } else {
    Get.snackbar('error'.tr, 'config_save_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }
}

class _QrPosterAccessButton extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _QrPosterAccessButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openBranchPicker(context),
        icon: Icon(Icons.qr_code_2, size: 18, color: colors.brand),
        label: Text(
          'show_branch_qr'.tr,
          style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.brand,
          side: BorderSide(color: colors.brand),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        ),
      ),
    );
  }

  void _openBranchPicker(BuildContext context) {
    final branches = ctrl.branches;
    if (branches.isEmpty) {
      Get.snackbar('error'.tr, 'no_branches'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (branches.length == 1) {
      Get.toNamed<void>(
        AppRoutes.branchQrPoster,
        arguments: {'branch': branches.first},
      );
      return;
    }

    final colors = AppColors.of(context);
    Get.bottomSheet<void>(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
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
            Text('show_branch_qr'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s3),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: branches.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.s2),
                itemBuilder: (_, i) {
                  final b = branches[i];
                  return InkWell(
                    onTap: () {
                      Get.back<void>();
                      Get.toNamed<void>(
                        AppRoutes.branchQrPoster,
                        arguments: {'branch': b},
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2,
                              size: 22, color: colors.brand),
                          const SizedBox(width: AppSpacing.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (b.address != null &&
                                    b.address!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    b.address!,
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
                          Icon(Icons.chevron_left,
                              size: 20, color: colors.textTertiary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _MethodSwitchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _MethodSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: enabled ? colors.brandSubtle : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: enabled ? colors.brand : colors.borderHairline,
          width: enabled ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 22,
              color: enabled ? colors.brand : colors.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled ? colors.brand : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: colors.brand,
          ),
        ],
      ),
    );
  }
}

class _ManualMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _ManualMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final manualEnabled = ctrl.tenantMethods.contains('manual');
        final colors = AppColors.of(context);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: manualEnabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: manualEnabled ? colors.brand : colors.borderHairline,
              width: manualEnabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 22,
                      color:
                          manualEnabled ? colors.brand : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'method_manual_admin'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: manualEnabled
                                ? colors.brand
                                : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'method_manual_admin_desc'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: manualEnabled,
                    onChanged: (v) async {
                      if (!v && ctrl.tenantMethods.length <= 1) {
                        Get.snackbar(
                          'error'.tr,
                          'at_least_one_method_required'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      final ok =
                          await ctrl.toggleTenantMethod('manual', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              if (manualEnabled) ...[
                const SizedBox(height: AppSpacing.s3),
                _ManualAdminsSubSection(ctrl: ctrl),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ManualAdminsSubSection extends StatefulWidget {
  final AttendanceMethodController ctrl;
  const _ManualAdminsSubSection({required this.ctrl});

  @override
  State<_ManualAdminsSubSection> createState() =>
      _ManualAdminsSubSectionState();
}

class _ManualAdminsSubSectionState extends State<_ManualAdminsSubSection> {
  bool _allowAll = true;

  @override
  void initState() {
    super.initState();
    _allowAll = widget.ctrl.manualAdminIds == null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selectedAdmins = <AdminModel>[];
    if (widget.ctrl.manualAdminIds != null) {
      for (final admin in widget.ctrl.eligibleAdmins) {
        if (widget.ctrl.manualAdminIds!.contains(admin.id)) {
          selectedAdmins.add(admin);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'manual_admins_section'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              title: Text(
                'allow_all_admins'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'allow_all_admins_hint'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
              value: _allowAll,
              onChanged: (v) async {
                if (v) {
                  final ok = await widget.ctrl.saveManualAdminIds(null);
                  if (ok) {
                    setState(() => _allowAll = true);
                    _showResultSnackbar(true);
                  } else {
                    _showResultSnackbar(false);
                  }
                } else {
                  if (widget.ctrl.eligibleAdmins.isEmpty) {
                    await widget.ctrl.loadEligibleAdmins();
                    setState(() {});
                  }
                  setState(() => _allowAll = false);
                }
              },
              activeThumbColor: colors.brand,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          if (!_allowAll) ...[
            const SizedBox(height: AppSpacing.s2),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAdminPickerSheet(context),
                icon: const Icon(Icons.group_outlined, size: 18),
                label: Text(
                  'choose_admins'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brand,
                  side: BorderSide(color: colors.brand),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
                ),
              ),
            ),
            if (selectedAdmins.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s2,
                children: selectedAdmins.map((admin) {
                  return Chip(
                    label: Text(
                      admin.name,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textPrimary,
                      ),
                    ),
                    deleteIcon: Icon(Icons.close, size: 16, color: colors.textSecondary),
                    onDeleted: () async {
                      final newIds = widget.ctrl.manualAdminIds
                              ?.where((id) => id != admin.id)
                              .toList() ??
                          [];
                      final ok = await widget.ctrl
                          .saveManualAdminIds(newIds.isEmpty ? null : newIds);
                      if (ok) {
                        setState(() {});
                        _showResultSnackbar(true);
                      } else {
                        _showResultSnackbar(false);
                      }
                    },
                    backgroundColor: colors.surface,
                    side: BorderSide(color: colors.borderHairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ] else if (widget.ctrl.manualAdminIds != null &&
                widget.ctrl.manualAdminIds!.isEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                'no_admin_selected'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAdminPickerSheet(BuildContext context) {
    final initialSelected = Set<int>.from(widget.ctrl.manualAdminIds ?? []);
    _AdminPickerSheet.show(
      context: context,
      admins: widget.ctrl.eligibleAdmins,
      initialSelected: initialSelected,
      onSaved: (selectedIds) async {
        final ok = await widget.ctrl
            .saveManualAdminIds(selectedIds.isEmpty ? null : selectedIds);
        if (ok) {
          setState(() {
            _allowAll = selectedIds.isEmpty;
          });
        }
        _showResultSnackbar(ok);
      },
    );
  }
}

class _AdminPickerSheet extends StatefulWidget {
  final List<AdminModel> admins;
  final Set<int> initialSelected;
  final ValueChanged<List<int>> onSaved;

  const _AdminPickerSheet({
    required this.admins,
    required this.initialSelected,
    required this.onSaved,
  });

  static void show({
    required BuildContext context,
    required List<AdminModel> admins,
    required Set<int> initialSelected,
    required ValueChanged<List<int>> onSaved,
  }) {
    Get.bottomSheet<void>(
      _AdminPickerSheet(
        admins: admins,
        initialSelected: initialSelected,
        onSaved: onSaved,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<_AdminPickerSheet> createState() => _AdminPickerSheetState();
}

class _AdminPickerSheetState extends State<_AdminPickerSheet> {
  late Set<int> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filtered = widget.admins.where((a) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return a.name.toLowerCase().contains(q) ||
          (a.email.toLowerCase().contains(q));
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.borderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'choose_admins'.tr,
            style: AppTextStyles.h3(context),
          ),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'search_admins'.tr,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final admin = filtered[index];
                final isSelected = _selected.contains(admin.id);
                return Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(admin.id);
                        } else {
                          _selected.remove(admin.id);
                        }
                      });
                    },
                    title: Text(
                      admin.name,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${admin.email}${admin.branchName != null ? ' · ${admin.branchName}' : ''}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                    dense: true,
                    activeColor: colors.brand,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back<void>(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.borderHairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s3),
                  ),
                  child: Text(
                    'cancel'.tr,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSaved(_selected.toList());
                    Get.back<void>();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s3),
                  ),
                  child: Text(
                    'save'.tr,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
  }
}

class _BranchOverridesSection extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _BranchOverridesSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...ctrl.branches.map((branch) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: _BranchTile(
                branch: branch,
                ctrl: ctrl,
              ),
            )),
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  final BranchModel branch;
  final AttendanceMethodController ctrl;

  const _BranchTile({
    required this.branch,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isInherited = branch.attendanceMethods == null;
    final methods = branch.attendanceMethods ?? ctrl.tenantMethods.toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSpacing.s1,
                  runSpacing: AppSpacing.s1,
                  children: [
                    ...methods.map((m) {
                      final label = methodBadge(m);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.brandSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 10,
                            color: colors.brand,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                    if (isInherited) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.sunken,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'inherits_company_methods'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 10,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (methods.contains('gps_only') || methods.contains('qr_gps'))
            IconButton(
              tooltip: 'set_branch_gps'.tr,
              icon: Icon(Icons.location_on_outlined,
                  size: 20, color: colors.brand),
              onPressed: () => showBranchLocationSheet(
                context,
                branchId: branch.id,
                branchName: branch.name,
                initialLat: branch.lat,
                initialLng: branch.lng,
                initialRadius: branch.gpsRadiusMeters,
                onSaved: (lat, lng, radius) =>
                    ctrl.applyBranchLocation(branch.id, lat, lng, radius),
              ),
            ),
          if (methods.contains('qr_gps'))
            IconButton(
              tooltip: 'show_branch_qr'.tr,
              icon: Icon(Icons.qr_code_2,
                  size: 20, color: colors.brand),
              onPressed: () => Get.toNamed<void>(
                AppRoutes.branchQrPoster,
                arguments: {'branch': branch},
              ),
            ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
            onPressed: () => _showBranchSheet(context),
          ),
        ],
      ),
    );
  }

  void _showBranchSheet(BuildContext context) {
    List<String>? selectedMethods = branch.attendanceMethods != null
        ? List<String>.from(branch.attendanceMethods!)
        : null;
    bool inheritCompany = branch.attendanceMethods == null;
    double? geoLat = branch.lat;
    double? geoLng = branch.lng;
    int geoRadius = branch.gpsRadiusMeters;
    int? offlineOverride;
    if (branch.allowOfflineAttendance == null) {
      offlineOverride = null;
    } else if (branch.allowOfflineAttendance == true) {
      offlineOverride = 1;
    } else {
      offlineOverride = 0;
    }

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branch.name, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      title: Text(
                        'inherits_company_methods'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.of(context).textPrimary,
                        ),
                      ),
                      value: inheritCompany,
                      onChanged: (v) {
                        setState(() {
                          inheritCompany = v;
                          if (v) {
                            selectedMethods = null;
                          } else {
                            selectedMethods = List<String>.from(
                                ctrl.tenantMethods);
                          }
                        });
                      },
                      activeThumbColor: AppColors.of(context).brand,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BranchMethodSwitch(
                    label: 'method_qr_gps'.tr,
                    enabled: !inheritCompany &&
                        (selectedMethods?.contains('qr_gps') ?? false),
                    onChanged: inheritCompany
                        ? null
                        : (v) {
                            setState(() {
                              selectedMethods ??= [];
                              if (v) {
                                selectedMethods!.add('qr_gps');
                              } else {
                                if (selectedMethods!.length > 1) {
                                  selectedMethods!.remove('qr_gps');
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BranchMethodSwitch(
                    label: 'method_gps_only'.tr,
                    enabled: !inheritCompany &&
                        (selectedMethods?.contains('gps_only') ?? false),
                    onChanged: inheritCompany
                        ? null
                        : (v) {
                            setState(() {
                              selectedMethods ??= [];
                              if (v) {
                                selectedMethods!.add('gps_only');
                              } else {
                                if (selectedMethods!.length > 1) {
                                  selectedMethods!.remove('gps_only');
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BranchMethodSwitch(
                    label: 'method_wifi_gps'.tr,
                    enabled: !inheritCompany &&
                        (selectedMethods?.contains('wifi_gps') ?? false),
                    onChanged: inheritCompany
                        ? null
                        : (v) {
                            setState(() {
                              selectedMethods ??= [];
                              if (v) {
                                selectedMethods!.add('wifi_gps');
                              } else {
                                if (selectedMethods!.length > 1) {
                                  selectedMethods!.remove('wifi_gps');
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BranchMethodSwitch(
                    label: 'method_face_selfie'.tr,
                    enabled: !inheritCompany &&
                        (selectedMethods?.contains('face_selfie') ?? false),
                    onChanged: inheritCompany
                        ? null
                        : (v) {
                            setState(() {
                              selectedMethods ??= [];
                              if (v) {
                                selectedMethods!.add('face_selfie');
                              } else {
                                if (selectedMethods!.length > 1) {
                                  selectedMethods!.remove('face_selfie');
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BranchMethodSwitch(
                    label: 'method_manual_admin'.tr,
                    enabled: !inheritCompany &&
                        (selectedMethods?.contains('manual') ?? false),
                    onChanged: inheritCompany
                        ? null
                        : (v) {
                            setState(() {
                              selectedMethods ??= [];
                              if (v) {
                                selectedMethods!.add('manual');
                              } else {
                                if (selectedMethods!.length > 1) {
                                  selectedMethods!.remove('manual');
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'branch_gps_location'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Builder(
                    builder: (context) {
                      final colors = AppColors.of(context);
                      final hasLoc = geoLat != null && geoLng != null;
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () => showBranchLocationSheet(
                          context,
                          branchId: branch.id,
                          branchName: branch.name,
                          initialLat: geoLat,
                          initialLng: geoLng,
                          initialRadius: geoRadius,
                          onSaved: (lat, lng, radius) {
                            setState(() {
                              geoLat = lat;
                              geoLng = lng;
                              geoRadius = radius;
                            });
                            ctrl.applyBranchLocation(
                                branch.id, lat, lng, radius);
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          decoration: BoxDecoration(
                            color: hasLoc ? colors.brandSubtle : colors.canvas,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: hasLoc
                                    ? colors.brand
                                    : colors.borderHairline),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasLoc
                                    ? Icons.location_on
                                    : Icons.add_location_alt_outlined,
                                color: hasLoc
                                    ? colors.brand
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.s3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasLoc
                                          ? 'location_set'.tr
                                          : 'set_branch_gps'.tr,
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: hasLoc
                                            ? colors.brand
                                            : colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'radius_value'.trParams(
                                          {'n': '$geoRadius'}),
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 11,
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_left,
                                  size: 20, color: colors.textTertiary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Text(
                    'allow_offline_branch_label'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  StatefulBuilder(
                    builder: (context, sbSetState) {
                      return DropdownButtonFormField<int?>(
                        initialValue: offlineOverride,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s3,
                            vertical: AppSpacing.s2,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            child: Text(
                              'inherit_company_default'.tr,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: 1,
                            child: Text(
                              'offline_enabled'.tr,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: 0,
                            child: Text(
                              'offline_disabled'.tr,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          sbSetState(() => offlineOverride = v);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.of(context).brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      onPressed: () async {
                        bool? branchAllowOffline;
                        if (offlineOverride == null) {
                          branchAllowOffline = null;
                        } else {
                          branchAllowOffline = offlineOverride == 1;
                        }
                        final ok = await ctrl.saveBranchMethods(
                          branchId: branch.id,
                          methods: inheritCompany ? null : selectedMethods,
                          allowOfflineAttendance: branchAllowOffline,
                        );
                        Get.back<void>();
                        _showResultSnackbar(ok);
                      },
                      child: Text(
                        'save'.tr,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            );
          },
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _BranchMethodSwitch extends StatelessWidget {
  final String label;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _BranchMethodSwitch({
    required this.label,
    required this.enabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final disabled = onChanged == null;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: disabled
            ? colors.sunken
            : enabled
                ? colors.brandSubtle
                : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: disabled
              ? colors.borderHairline
              : enabled
                  ? colors.brand
                  : colors.borderHairline,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: disabled
                    ? colors.textTertiary
                    : enabled
                        ? colors.brand
                        : colors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: colors.brand,
          ),
        ],
      ),
    );
  }
}

/// Company-wide switch for rejecting check-ins from a spoofed GPS location.
/// Deliberately opt-in: the flag is reported by the device, and iOS never
/// reports it at all, so a company should turn this on knowing what it covers.
class _RejectMockLocationCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _RejectMockLocationCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final colors = AppColors.of(context);
        final enabled = ctrl.rejectMockLocation;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.wrong_location_outlined,
                  size: 22,
                  color: enabled ? colors.brand : colors.textSecondary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'reject_mock_location'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled ? colors.brand : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'reject_mock_location_hint'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (v) async {
                  final ok = await ctrl.toggleRejectMockLocation(v);
                  _showResultSnackbar(ok);
                },
                activeThumbColor: colors.brand,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Requires the phone's own fingerprint/FaceID at the moment of the tap, which
/// is what stops a colleague checking in on a handset that is already signed
/// in. It proves the tapper can unlock this phone, not who they are — the
/// method that proves identity against an enrolled template is face_selfie.
class _RequireLocalBiometricCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _RequireLocalBiometricCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final colors = AppColors.of(context);
        final enabled = ctrl.requireLocalBiometric;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.fingerprint,
                  size: 22,
                  color: enabled ? colors.brand : colors.textSecondary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'require_local_biometric'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled ? colors.brand : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'require_local_biometric_hint'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (v) async {
                  final ok = await ctrl.toggleRequireLocalBiometric(v);
                  _showResultSnackbar(ok);
                },
                activeThumbColor: colors.brand,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfflineModeCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _OfflineModeCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final colors = AppColors.of(context);
        final enabled = ctrl.allowOffline;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 22,
                  color: enabled ? colors.brand : colors.textSecondary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'allow_offline'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled ? colors.brand : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'allow_offline_hint'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (v) async {
                  final ok = await ctrl.toggleAllowOffline(v);
                  _showResultSnackbar(ok);
                },
                activeThumbColor: colors.brand,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GpsOnlyMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _GpsOnlyMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final enabled = ctrl.tenantMethods.contains('gps_only');
        final colors = AppColors.of(context);
        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 22,
                      color: enabled ? colors.brand : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'method_gps_only'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                enabled ? colors.brand : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'method_gps_only_desc'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) async {
                      if (!v && ctrl.tenantMethods.length <= 1) {
                        Get.snackbar(
                          'error'.tr,
                          'at_least_one_method_required'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      final ok = await ctrl.toggleTenantMethod('gps_only', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: AppSpacing.s3),
                _CompanyLocationCard(ctrl: ctrl, embedded: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Selfie + face-recognition method, with its settings folded in so the
/// threshold and liveness switches only appear once the method is on.
/// Branch WiFi method. Unlike the other methods there is nothing to configure
/// company-wide — every access point belongs to a specific branch — so the card
/// leads into the per-branch approval screen instead.
class _WifiMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _WifiMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final enabled = ctrl.tenantMethods.contains('wifi_gps');
        final colors = AppColors.of(context);
        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.wifi,
                      size: 22,
                      color: enabled ? colors.brand : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'method_wifi_gps'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: enabled ? colors.brand : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'method_wifi_gps_desc'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) async {
                      if (!v && ctrl.tenantMethods.length <= 1) {
                        Get.snackbar(
                          'error'.tr,
                          'at_least_one_method_required'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      final ok = await ctrl.toggleTenantMethod('wifi_gps', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: AppSpacing.s3),
                _BranchNetworksPicker(ctrl: ctrl),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Fingerprint / face terminals.
///
/// Unlike the other methods this one is not something the employee app does —
/// enabling it only tells the app to stop offering self check-in where the
/// device is the way in. The devices themselves are managed on their own
/// screen, which is where the real work (linking User IDs) happens.
class _DeviceMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _DeviceMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final enabled = ctrl.tenantMethods.contains('device');
        final colors = AppColors.of(context);
        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fingerprint,
                      size: 22,
                      color: enabled ? colors.brand : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'method_device'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: enabled ? colors.brand : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'method_device_desc'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) async {
                      if (!v && ctrl.tenantMethods.length <= 1) {
                        Get.snackbar(
                          'error'.tr,
                          'at_least_one_method_required'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      final ok = await ctrl.toggleTenantMethod('device', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => Get.toNamed<void>(AppRoutes.devices),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.devices_other,
                          size: 18, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          'devices'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_left,
                          size: 18, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Each branch has its own access points, so this lists the branches and opens
/// the approval screen for whichever one the admin taps.
class _BranchNetworksPicker extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _BranchNetworksPicker({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (ctrl.branches.isEmpty) {
      return Text(
        'no_branches'.tr,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          color: colors.textTertiary,
        ),
      );
    }

    return Column(
      children: [
        for (final branch in ctrl.branches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => Get.toNamed<void>(
                AppRoutes.branchNetworks,
                arguments: {
                  'branch_id': branch.id,
                  'branch_name': branch.name,
                },
              )?.then((_) => ctrl.load()),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.router_outlined,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(
                        branch.name,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'wifi_networks'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.brand,
                      ),
                    ),
                    Icon(Icons.chevron_left,
                        size: 18, color: colors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FaceMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _FaceMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final enabled = ctrl.tenantMethods.contains('face_selfie');
        final colors = AppColors.of(context);
        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.face_retouching_natural_outlined,
                      size: 22,
                      color: enabled ? colors.brand : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'method_face_selfie'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: enabled ? colors.brand : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'method_face_selfie_desc'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) async {
                      if (!v && ctrl.tenantMethods.length <= 1) {
                        Get.snackbar(
                          'error'.tr,
                          'at_least_one_method_required'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      final ok =
                          await ctrl.toggleTenantMethod('face_selfie', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: AppSpacing.s3),
                _FaceSettingsPanel(ctrl: ctrl),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FaceSettingsPanel extends StatefulWidget {
  final AttendanceMethodController ctrl;
  const _FaceSettingsPanel({required this.ctrl});

  @override
  State<_FaceSettingsPanel> createState() => _FaceSettingsPanelState();
}

class _FaceSettingsPanelState extends State<_FaceSettingsPanel> {
  late double _threshold = widget.ctrl.faceThreshold;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ctrl = widget.ctrl;
    final enforcing = ctrl.faceEnforceMode == 'enforce';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Match threshold ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'face_match_threshold'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                _threshold.toStringAsFixed(2),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                ),
              ),
            ],
          ),
          Slider(
            value: _threshold,
            min: 0.3,
            max: 0.95,
            divisions: 65,
            activeColor: colors.brand,
            onChanged: (v) => setState(() => _threshold = v),
            onChangeEnd: (v) async {
              final ok = await ctrl.saveFaceSettings(matchThreshold: v);
              if (!ok) setState(() => _threshold = ctrl.faceThreshold);
              _showResultSnackbar(ok);
            },
          ),
          Text(
            'face_match_threshold_hint'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),

          // ── Liveness ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'face_liveness_required'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'face_liveness_hint'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: ctrl.faceLivenessRequired,
                activeThumbColor: colors.brand,
                onChanged: (v) async =>
                    _showResultSnackbar(await ctrl.saveFaceSettings(
                  livenessRequired: v,
                )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),

          // ── Enforcement mode ──
          Text(
            'face_enforce_mode'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'face_mode_log_only'.tr,
                  selected: !enforcing,
                  onTap: () async => _showResultSnackbar(
                      await ctrl.saveFaceSettings(enforceMode: 'log_only')),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: _ModeChip(
                  label: 'face_mode_enforce'.tr,
                  selected: enforcing,
                  onTap: () async => _showResultSnackbar(
                      await ctrl.saveFaceSettings(enforceMode: 'enforce')),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'face_mode_hint'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: colors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CompanyLocationCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  final bool embedded;
  const _CompanyLocationCard({required this.ctrl, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final colors = AppColors.of(context);
        final has = ctrl.hasCompanyLocation;
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => showBranchLocationSheet(
            context,
            branchId: 0,
            branchName: 'company_gps_location'.tr,
            initialLat: ctrl.companyLat,
            initialLng: ctrl.companyLng,
            initialRadius: ctrl.companyRadius,
            onSaved: (lat, lng, radius) =>
                ctrl.applyCompanyLocation(lat, lng, radius),
            onPersist: (lat, lng, radius) =>
                ctrl.persistCompanyLocation(lat, lng, radius),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: embedded
                  ? colors.sunken
                  : (has ? colors.brandSubtle : colors.surface),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: embedded
                  ? null
                  : Border.all(
                      color: has ? colors.brand : colors.borderHairline,
                      width: has ? 1.5 : 1,
                    ),
            ),
            child: Row(
              children: [
                Icon(
                  has ? Icons.location_on : Icons.add_location_alt_outlined,
                  size: 22,
                  color: has ? colors.brand : colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'company_gps_location'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: has ? colors.brand : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        has
                            ? 'radius_value'
                                .trParams({'n': '${ctrl.companyRadius}'})
                            : 'company_gps_hint'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          color: colors.textTertiary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Redesign widgets ─────────────────────────

class _SummaryCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _SummaryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brand, colors.brand.withValues(alpha: 0.82)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: Colors.white, size: 22),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'company_default'.tr,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s1,
            children:
                ctrl.tenantMethods.map((m) => _chip(methodLabel(m))).toList(),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              _stat(ctrl.branchOverrideCount, 'branches_word'.tr),
              const SizedBox(width: AppSpacing.s2),
              _stat(ctrl.categoryOverrideCount, 'categories_word'.tr),
              const SizedBox(width: AppSpacing.s2),
              _stat(ctrl.employeeOverrideCount, 'employees_word'.tr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _stat(int count, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: colors.brandSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(widget.icon, size: 20, color: colors.brand),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s3, 0, AppSpacing.s3, AppSpacing.s3),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _MethodChips extends StatelessWidget {
  final List<String>? methods; // null = inherits
  const _MethodChips({required this.methods});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (methods == null) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
        decoration: BoxDecoration(
          color: colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          'inherits_default'.tr,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 10,
            color: colors.textTertiary,
          ),
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.s1,
      runSpacing: AppSpacing.s1,
      children: methods!
          .map((m) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.brandSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  methodLabel(m),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    color: colors.brand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _OverrideTile extends StatelessWidget {
  final String title;
  final List<String>? methods;
  final String? trailingInfo;
  final VoidCallback onEdit;

  const _OverrideTile({
    required this.title,
    required this.methods,
    required this.onEdit,
    this.trailingInfo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (trailingInfo != null && trailingInfo!.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        '· $trailingInfo',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _MethodChips(methods: methods),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          color: colors.textTertiary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _CategoryOverridesSection extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _CategoryOverridesSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.categories.isEmpty) {
      return _EmptyHint(text: 'no_categories_hint'.tr);
    }
    return Column(
      children: ctrl.categories
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: _OverrideTile(
                  title: c.name,
                  methods: c.methods,
                  trailingInfo:
                      'employees_n'.trParams({'n': '${c.employeeCount}'}),
                  onEdit: () => _MethodsOverrideSheet.show(
                    context: context,
                    title: c.name,
                    initialMethods: c.methods,
                    defaultMethods: ctrl.tenantMethods.toList(),
                    onSave: (methods) async {
                      final ok = await ctrl.saveCategoryMethods(c.id, methods);
                      _showResultSnackbar(ok);
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _EmployeeOverridesSection extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _EmployeeOverridesSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctrl.employeeOverrides.isEmpty)
          _EmptyHint(text: 'no_employee_overrides_hint'.tr)
        else
          ...ctrl.employeeOverrides.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: _OverrideTile(
                  title: e.name,
                  methods: e.methods,
                  trailingInfo: e.branchName,
                  onEdit: () => _MethodsOverrideSheet.show(
                    context: context,
                    title: e.name,
                    initialMethods: e.methods,
                    defaultMethods: ctrl.tenantMethods.toList(),
                    onSave: (methods) async {
                      final ok = await ctrl.saveEmployeeMethods(e.id, methods);
                      _showResultSnackbar(ok);
                    },
                  ),
                ),
              )),
        const SizedBox(height: AppSpacing.s2),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openPicker(context),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text('add_employee_override'.tr,
                style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.brand,
              side: BorderSide(color: colors.brand),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            ),
          ),
        ),
      ],
    );
  }

  void _openPicker(BuildContext context) {
    _EmployeePickerSheet.show(
      context: context,
      onPicked: (id, name, branchName) {
        _MethodsOverrideSheet.show(
          context: context,
          title: name,
          initialMethods: ctrl.tenantMethods.toList(),
          defaultMethods: ctrl.tenantMethods.toList(),
          startCustom: true,
          onSave: (methods) async {
            final ok = await ctrl.saveEmployeeMethods(id, methods,
                name: name, branchName: branchName);
            _showResultSnackbar(ok);
          },
        );
      },
    );
  }
}

/// Bottom sheet to pick the attendance methods for a scope (category/employee),
/// or inherit the next level (clears the override).
class _MethodsOverrideSheet extends StatefulWidget {
  final String title;
  final List<String>? initialMethods;
  final List<String> defaultMethods;
  final bool startCustom;
  final ValueChanged<List<String>?> onSave;

  const _MethodsOverrideSheet({
    required this.title,
    required this.initialMethods,
    required this.defaultMethods,
    required this.onSave,
    this.startCustom = false,
  });

  static void show({
    required BuildContext context,
    required String title,
    required List<String>? initialMethods,
    required List<String> defaultMethods,
    required ValueChanged<List<String>?> onSave,
    bool startCustom = false,
  }) {
    Get.bottomSheet<void>(
      _MethodsOverrideSheet(
        title: title,
        initialMethods: initialMethods,
        defaultMethods: defaultMethods,
        onSave: onSave,
        startCustom: startCustom,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<_MethodsOverrideSheet> createState() => _MethodsOverrideSheetState();
}

class _MethodsOverrideSheetState extends State<_MethodsOverrideSheet> {
  static const _all = ['qr_gps', 'gps_only', 'manual'];
  late bool _inherit =
      widget.startCustom ? false : widget.initialMethods == null;
  late final Set<String> _selected = {
    ...(widget.initialMethods ??
        (widget.defaultMethods.isEmpty ? ['qr_gps'] : widget.defaultMethods))
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
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
          Text(widget.title, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s3),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              title: Text(
                'inherit_default_methods'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              value: _inherit,
              onChanged: (v) => setState(() => _inherit = v),
              activeThumbColor: colors.brand,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          if (!_inherit) ...[
            const SizedBox(height: AppSpacing.s2),
            ..._all.map((m) => _methodRow(colors, m)),
          ],
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
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
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
                  onPressed: (!_inherit && _selected.isEmpty)
                      ? null
                      : () {
                          widget.onSave(
                              _inherit ? null : _selected.toList());
                          Get.back<void>();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                  child: Text('save'.tr,
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
    );
  }

  Widget _methodRow(AppColorScheme colors, String m) {
    final on = _selected.contains(m);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => setState(() {
          if (on) {
            if (_selected.length > 1) _selected.remove(m);
          } else {
            _selected.add(m);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3, vertical: AppSpacing.s3),
          decoration: BoxDecoration(
            color: on ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: on ? colors.brand : colors.borderHairline),
          ),
          child: Row(
            children: [
              Icon(on ? Icons.check_circle : Icons.circle_outlined,
                  size: 20, color: on ? colors.brand : colors.textTertiary),
              const SizedBox(width: AppSpacing.s3),
              Text(
                methodLabel(m),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: on ? colors.brand : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Debounced employee search sheet for adding an employee override.
class _EmployeePickerSheet extends StatefulWidget {
  final void Function(int id, String name, String? branchName) onPicked;
  const _EmployeePickerSheet({required this.onPicked});

  static void show({
    required BuildContext context,
    required void Function(int id, String name, String? branchName) onPicked,
  }) {
    Get.bottomSheet<void>(
      _EmployeePickerSheet(onPicked: onPicked),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  final EmployeeData _employeeData = EmployeeData();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final res = await _employeeData.getEmployees(
      search: q.trim().isEmpty ? null : q.trim(),
    );
    final items = <Map<String, dynamic>>[];
    if (res['status'] == StatusRequest.success) {
      // API success wraps the payload: { status, data: { items, ... } }.
      dynamic data = res['data'];
      if (data is Map && data['data'] is Map) data = data['data'];
      if (data is Map && data['items'] is List) {
        for (final e in data['items'] as List) {
          if (e is Map<String, dynamic>) items.add(e);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _results = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.borderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('choose_employee'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'search_employees'.tr,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
            ),
            style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic', fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.s3),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.s5),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.s5),
                        child: Text('no_results'.tr,
                            style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                color: colors.textTertiary)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.s2),
                        itemBuilder: (_, i) {
                          final e = _results[i];
                          final id = (e['id'] as int?) ?? 0;
                          final name = (e['name'] as String?) ?? '';
                          final branchName = e['branch_name'] as String?;
                          return InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () {
                              Get.back<void>();
                              widget.onPicked(id, name, branchName);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.s3),
                              decoration: BoxDecoration(
                                color: colors.canvas,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border:
                                    Border.all(color: colors.borderHairline),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 20, color: colors.textSecondary),
                                  const SizedBox(width: AppSpacing.s3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontFamily:
                                                    'IBM Plex Sans Arabic',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        if (branchName != null &&
                                            branchName.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(branchName,
                                              style: TextStyle(
                                                  fontFamily:
                                                      'IBM Plex Sans Arabic',
                                                  fontSize: 11,
                                                  color: colors.textTertiary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_left,
                                      size: 20, color: colors.textTertiary),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
      ),
    );
  }
}


/// The branch kiosk method, and the route into managing the tablets.
///
/// Sits beside the fingerprint-terminal card because both answer the same
/// question — "how do employees without the app clock in?" — but they are not
/// the same thing: a terminal is third-party hardware pushing punches at us,
/// while a kiosk is our own app authenticating as a branch.
class _KioskMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _KioskMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final enabled = ctrl.tenantMethods.contains('kiosk');
        final colors = AppColors.of(context);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: enabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? colors.brand : colors.borderHairline,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tablet_android,
                      size: 22,
                      color: enabled ? colors.brand : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('method_kiosk'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            )),
                        const SizedBox(height: 2),
                        Text('method_kiosk_desc'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) async {
                      if (!v && ctrl.tenantMethods.length <= 1) {
                        Get.snackbar(
                          'error'.tr,
                          'at_least_one_method_required'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      final ok = await ctrl.toggleTenantMethod('kiosk', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              // Always reachable, even with the method switched off: a tablet
              // has to be paired and its people enrolled BEFORE the method is
              // turned on, or the first morning is a queue of refusals.
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => Get.toNamed<void>(AppRoutes.kiosks),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tablet_android,
                          size: 18, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text('kiosks'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textPrimary,
                            )),
                      ),
                      Icon(Icons.chevron_right,
                          size: 18, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
