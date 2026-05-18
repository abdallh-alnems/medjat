import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/role_management_controller.dart';
import '../../../data/model/role_model.dart';

class RoleManagementScreen extends StatelessWidget {
  const RoleManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(RoleManagementController());

    return Scaffold(
      appBar: AppBar(title: Text('role_management'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_role_management',
        onPressed: () => _showAddRoleSheet(context, ctrl),
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ctrl.loadRoles();
          await ctrl.loadBranches();
        },
        child: GetBuilder<RoleManagementController>(
          builder: (_) {
            return HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadRoles,
              widget: ctrl.roles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined,
                              size: 48,
                              color: AppColors.of(context).textTertiary),
                          const SizedBox(height: AppSpacing.s3),
                          Text('no_roles'.tr,
                              style: AppTextStyles.bodySecondary(context)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s9,
                      ),
                      itemCount: ctrl.roles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (_, i) => _RoleTile(
                        role: ctrl.roles[i],
                        onEdit: () =>
                            _showEditRoleSheet(context, ctrl, ctrl.roles[i]),
                        onDelete: () =>
                            _confirmDelete(context, ctrl, ctrl.roles[i]),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  void _showAddRoleSheet(
      BuildContext context, RoleManagementController ctrl) {
    _showRoleSheet(context, ctrl, title: 'add_role'.tr);
  }

  void _showEditRoleSheet(
      BuildContext context, RoleManagementController ctrl, RoleModel role) {
    _showRoleSheet(context, ctrl, title: 'edit_role'.tr, role: role);
  }

  void _showRoleSheet(
    BuildContext context, RoleManagementController ctrl, {
    required String title,
    RoleModel? role,
  }) {
    final nameCtrl = TextEditingController(text: role?.name ?? '');
    String scope = role?.scope ?? 'all';
    int? branchId = role?.branchId;
    final allPermissions = [
      'manage_employees',
      'manage_attendance',
      'manage_payroll',
      'view_reports',
      'manage_documents',
      'manage_leaves',
      'add_managers',
      'manage_company_settings',
    ];
    final permissionLabels = {
      'manage_employees': 'manage_employees'.tr,
      'manage_attendance': 'manage_attendance'.tr,
      'manage_payroll': 'manage_payroll'.tr,
      'view_reports': 'view_reports'.tr,
      'manage_documents': 'manage_documents'.tr,
      'manage_leaves': 'manage_leaves'.tr,
      'add_managers': 'add_managers'.tr,
      'manage_company_settings': 'manage_company_settings'.tr,
    };
    final Set<String> selected = Set<String>.from(role?.permissions ?? []);

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryInput(
                    label: 'role_name'.tr,
                    controller: nameCtrl,
                    hint: 'role_name'.tr,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text('scope'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.of(context).textSecondary,
                      )),
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    children: [
                      Expanded(
                        child: _ScopeChip(
                          label: 'all_branches'.tr,
                          selected: scope == 'all',
                          onTap: () => setState(() => scope = 'all'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _ScopeChip(
                          label: 'specific_branch'.tr,
                          selected: scope == 'branch',
                          onTap: () => setState(() => scope = 'branch'),
                        ),
                      ),
                    ],
                  ),
                  if (scope == 'branch') ...[
                    const SizedBox(height: AppSpacing.s3),
                    Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s2,
                      children: ctrl.branches.map((b) {
                        return _ScopeChip(
                          label: b.name,
                          selected: branchId == b.id,
                          onTap: () => setState(() => branchId = b.id),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),
                  Text('permissions'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.of(context).textSecondary,
                      )),
                  const SizedBox(height: AppSpacing.s2),
                  ...allPermissions.map((p) {
                    return CheckboxListTile(
                      value: selected.contains(p),
                      title: Text(
                        permissionLabels[p] ?? p,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selected.add(p);
                          } else {
                            selected.remove(p);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryButton(
                    text: role != null ? 'update'.tr : 'add'.tr,
                    onPressed: () {
                      final data = {
                        'name': nameCtrl.text.trim(),
                        'scope': scope,
                        'permissions': selected.toList(),
                        if (scope == 'branch' && branchId != null)
                          'branch_id': branchId,
                      };
                      if (role != null) {
                        ctrl.updateRole(role.id, data);
                      } else {
                        ctrl.createRole(data);
                      }
                      Get.back();
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, RoleManagementController ctrl, RoleModel role) {
    Get.dialog(
      AlertDialog(
        title: Text('delete_rule'.tr),
        content: Text('${'confirm_delete'.tr} "${role.name}"؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              ctrl.deleteRole(role.id);
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.of(context).error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final RoleModel role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoleTile({
    required this.role,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
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
              Expanded(
                child: Text(
                  role.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: colors.brandSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  role.scopeLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.brand,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: colors.textSecondary),
                onPressed: onEdit,
              ),
              IconButton(
                icon:
                    Icon(Icons.delete_outline, size: 20, color: colors.error),
                onPressed: onDelete,
              ),
            ],
          ),
          if (role.permissions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s1,
              runSpacing: AppSpacing.s1,
              children: role.permissions.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.sunken,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 10,
                      color: colors.textTertiary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? colors.brand : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
