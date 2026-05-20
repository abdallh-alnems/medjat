import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/manager_invitation_model.dart';
import '../../../logic/controller/settings/attendance_method_controller.dart';
import '../../../core/constant/routes/app_routes.dart';

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
                  _InfoBanner(),
                  const SizedBox(height: AppSpacing.s5),
                  Text('tenant_default_method'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s3),
                  _TenantMethodCards(ctrl: ctrl),
                  if (ctrl.branches.length > 1) ...[
                    const SizedBox(height: AppSpacing.s6),
                    _BranchOverridesSection(ctrl: ctrl),
                  ],
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
            _MethodSwitchCard(
              icon: Icons.location_on_outlined,
              title: 'method_gps_only'.tr,
              description: 'method_gps_only_desc'.tr,
              enabled: ctrl.tenantMethods.contains('gps_only'),
              onChanged: (v) => _toggle(context, 'gps_only', v),
            ),
            const SizedBox(height: AppSpacing.s2),
            _ManualMethodCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s2),
            _StationMethodCard(ctrl: ctrl),
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
                separatorBuilder: (_, __) =>
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
          SwitchListTile(
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
            activeColor: colors.brand,
            contentPadding: EdgeInsets.zero,
            dense: true,
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
                return CheckboxListTile(
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
        Text('per_branch_override'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s3),
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
                      final label = m == 'qr_gps'
                          ? 'QR'
                          : m == 'gps_only'
                              ? 'GPS'
                              : m == 'station'
                                  ? 'method_station'.tr
                                  : 'manual'.tr.substring(0, 5);
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
    final radiusCtrl = TextEditingController(
        text: branch.gpsRadiusMeters.toString());

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
                  SwitchListTile(
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
                    activeColor: AppColors.of(context).brand,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
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
                  const SizedBox(height: AppSpacing.s2),
                  _BranchMethodSwitch(
                    label: 'method_station'.tr,
                    enabled: !inheritCompany &&
                        (selectedMethods?.contains('station') ?? false),
                    onChanged: inheritCompany
                        ? null
                        : (v) {
                            setState(() {
                              selectedMethods ??= [];
                              if (v) {
                                selectedMethods!.add('station');
                              } else {
                                if (selectedMethods!.length > 1) {
                                  selectedMethods!.remove('station');
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'gps_radius_meters'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  TextField(
                    controller: radiusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '100',
                      suffixText: 'm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                        vertical: AppSpacing.s2,
                      ),
                    ),
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
                        final ok = await ctrl.saveBranchMethods(
                          branchId: branch.id,
                          methods: inheritCompany ? null : selectedMethods,
                          radius:
                              int.tryParse(radiusCtrl.text.trim()) ?? 100,
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

class _StationMethodCard extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _StationMethodCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AttendanceMethodController>(
      builder: (_) {
        final stationEnabled = ctrl.tenantMethods.contains('station');
        final colors = AppColors.of(context);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: stationEnabled ? colors.brandSubtle : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: stationEnabled ? colors.brand : colors.borderHairline,
              width: stationEnabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_outlined,
                      size: 22,
                      color: stationEnabled
                          ? colors.brand
                          : colors.textSecondary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'method_station'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: stationEnabled
                                ? colors.brand
                                : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'method_station_desc'.tr,
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
                    value: stationEnabled,
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
                          await ctrl.toggleTenantMethod('station', v);
                      _showResultSnackbar(ok);
                    },
                    activeThumbColor: colors.brand,
                  ),
                ],
              ),
              if (stationEnabled) ...[
                const SizedBox(height: AppSpacing.s3),
                _StationBranchesSubSection(ctrl: ctrl),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StationBranchesSubSection extends StatelessWidget {
  final AttendanceMethodController ctrl;
  const _StationBranchesSubSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
            'station_section_title'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          ...ctrl.branches.map((branch) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: InkWell(
                onTap: () => Get.toNamed<void>(
                  AppRoutes.stationSettings,
                  arguments: {'branch_id': branch.id},
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: branch.stationEnabled ? colors.brand : colors.borderHairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.monitor_outlined,
                        size: 22,
                        color: branch.stationEnabled ? colors.brand : colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(branch.name, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              branch.stationEnabled ? 'station_enabled'.tr : 'station_status_pending'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 11,
                                color: branch.stationEnabled ? colors.brand : colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: AppSpacing.s3),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Get.toNamed<void>(AppRoutes.stationsManagement),
            icon: const Icon(Icons.devices_outlined, size: 18),
            label: Text('manage_devices'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.brand,
              side: BorderSide(color: colors.brand),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
