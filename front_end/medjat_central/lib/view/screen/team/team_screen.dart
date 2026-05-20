import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/manager_invitation_model.dart';
import '../../../logic/controller/team/team_controller.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TeamController _teamCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _teamCtrl = Get.put(TeamController());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('team_management'.tr),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Tab(text: 'admins'.tr),
            Tab(text: 'pending_invitations'.tr),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          GetBuilder<TeamController>(
            builder: (_) => HandlingDataRequest(
              statusRequest: _teamCtrl.status,
              onRetry: () => _teamCtrl.loadAll(),
              widget: _AdminsList(ctrl: _teamCtrl),
            ),
          ),
          GetBuilder<TeamController>(
            builder: (_) => HandlingDataRequest(
              statusRequest: _teamCtrl.status,
              onRetry: () => _teamCtrl.loadAll(),
              widget: _InvitationsList(ctrl: _teamCtrl),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_team',
        onPressed: () =>
            Get.toNamed<dynamic>(AppRoutes.inviteAdmin),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _AdminsList extends StatelessWidget {
  final TeamController ctrl;
  const _AdminsList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (ctrl.admins.isEmpty) {
      return Center(
        child: Text('no_admins_yet'.tr,
            style: AppTextStyles.bodySecondary(context)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s4),
      itemCount: ctrl.admins.length,
      itemBuilder: (_, i) => _AdminCard(
        admin: ctrl.admins[i],
        colors: colors,
        onPermissionsTap: () {
          if (ctrl.admins[i].role == 'general_manager') {
            Get.snackbar(
              'general_manager_permissions_locked'.tr,
              '',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }
          _showAdminPermissionsSheet(
              context, ctrl.admins[i].id, ctrl);
        },
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final AdminModel admin;
  final AppColorScheme colors;
  final VoidCallback onPermissionsTap;

  const _AdminCard({
    required this.admin,
    required this.colors,
    required this.onPermissionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.brandSubtle,
            child: Text(
              admin.name.isNotEmpty ? admin.name[0] : '?',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.brand,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        admin.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _RoleBadge(role: admin.role, colors: colors),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  admin.email,
                  style: AppTextStyles.sm(context),
                  overflow: TextOverflow.ellipsis,
                ),
                if (admin.branchName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 13, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        admin.branchName!,
                        style: AppTextStyles.xs(context),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          if (admin.role != 'general_manager')
            IconButton(
              icon: Icon(Icons.security_outlined,
                  size: 22, color: colors.textSecondary),
              onPressed: onPermissionsTap,
              tooltip: 'edit_permissions'.tr,
            ),
        ],
      ),
    );
  }
}

class _InvitationsList extends StatelessWidget {
  final TeamController ctrl;
  const _InvitationsList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (ctrl.invitations.isEmpty) {
      return Center(
        child: Text('no_pending_invitations'.tr,
            style: AppTextStyles.bodySecondary(context)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s4),
      itemCount: ctrl.invitations.length,
      itemBuilder: (_, i) => _InvitationCard(
        invitation: ctrl.invitations[i],
        colors: colors,
        onCancel: () => ctrl.cancelInvitation(ctrl.invitations[i].id),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final ManagerInvitationModel invitation;
  final AppColorScheme colors;
  final VoidCallback onCancel;

  const _InvitationCard({
    required this.invitation,
    required this.colors,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = invitation.statusKey == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
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
              Expanded(
                child: Text(
                  invitation.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _RoleBadge(role: invitation.role, colors: colors),
              const SizedBox(width: AppSpacing.s2),
              _StatusBadge(statusKey: invitation.statusKey, colors: colors),
            ],
          ),
          const SizedBox(height: 4),
          Text(invitation.email, style: AppTextStyles.sm(context)),
          if (invitation.branchName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.store_outlined, size: 13, color: colors.textTertiary),
                const SizedBox(width: 4),
                Text(invitation.branchName!, style: AppTextStyles.xs(context)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                '${'status_expired'.tr}: ${invitation.expiresAt.substring(0, 16)}',
                style: AppTextStyles.xs(context),
              ),
              const Spacer(),
              if (isPending)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(
                    'cancel_invitation'.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final AppColorScheme colors;
  const _RoleBadge({required this.role, required this.colors});

  @override
  Widget build(BuildContext context) {
    final config = _roleConfig(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.$1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        config.$2,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.$1,
        ),
      ),
    );
  }

  (Color, String) _roleConfig(String role) {
    switch (role) {
      case 'general_manager':
        return (colors.brand, 'general_manager'.tr);
      case 'hr':
        return (colors.success, 'role_hr'.tr);
      case 'branch_manager':
        return (colors.accentWarm, 'role_branch_manager'.tr);
      case 'attendance':
        return (colors.warning, 'role_attendance'.tr);
      case 'viewer':
        return (colors.textTertiary, 'role_viewer'.tr);
      default:
        return (colors.textTertiary, role);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String statusKey;
  final AppColorScheme colors;
  const _StatusBadge({required this.statusKey, required this.colors});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(statusKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.$1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        config.$2,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.$1,
        ),
      ),
    );
  }

  (Color, String) _statusConfig(String key) {
    switch (key) {
      case 'pending':
        return (colors.warning, 'status_pending'.tr);
      case 'accepted':
        return (colors.success, 'status_accepted'.tr);
      case 'cancelled':
        return (colors.error, 'status_cancelled'.tr);
      case 'expired':
        return (colors.textTertiary, 'status_expired'.tr);
      default:
        return (colors.textTertiary, key);
    }
  }
}

void _showAdminPermissionsSheet(
  BuildContext context,
  int adminId,
  TeamController ctrl,
) {
  ctrl.loadAdminPermissions(adminId);

  Get.bottomSheet<void>(
    GetBuilder<TeamController>(
      builder: (_) {
        final colors = AppColors.of(context);

        if (ctrl.permissionsStatus == StatusRequest.loading) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: const Center(
                child: CircularProgressIndicator()),
          );
        }

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'permissions_for_admin'.tr,
                        style: AppTextStyles.h3(context),
                      ),
                    ),
                    if (ctrl.isCustomized)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s2,
                          vertical: AppSpacing.s1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.brandSubtle,
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'customized_permissions'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.brand,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: colors.sunken,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: colors.textTertiary),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: Text(
                          'permissions_override_hint'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                ...ctrl.allPermissions.map((perm) {
                  final isSelected =
                      ctrl.selectedPermissions.contains(perm);
                  final isDefault = ctrl.roleDefaults.contains(perm);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'perm_$perm'.tr,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.success.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              'default_for_role'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colors.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (_) => ctrl.togglePermission(perm),
                  );
                }),
                const SizedBox(height: AppSpacing.s4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok =
                          await ctrl.saveAdminPermissions(adminId);
                      if (ok) {
                        Get.back<void>();
                        Get.snackbar('done'.tr,
                            'permissions_saved'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s3),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'save'.tr,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                if (ctrl.isCustomized)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Get.dialog<void>(
                          AlertDialog(
                            title: Text('reset_to_default'.tr),
                            content: Text(
                                'reset_permissions_confirm'.tr),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Get.back<void>(),
                                child: Text('cancel'.tr),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Get.back<void>();
                                  final ok = await ctrl
                                      .resetAdminPermissions(
                                          adminId);
                                  if (ok) {
                                    Get.back<void>();
                                    Get.snackbar(
                                        'done'.tr,
                                        'permissions_reset'
                                            .tr,
                                        snackPosition:
                                            SnackPosition
                                                .BOTTOM);
                                  }
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor:
                                        colors.error),
                                child: Text('reset_to_default'.tr),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'reset_to_default'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          color: colors.error,
                        ),
                      ),
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
  );
}
