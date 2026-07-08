import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/branch_model.dart';
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
  final _searchCtrl = TextEditingController();

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
    _searchCtrl.dispose();
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
              widget: _AdminsTab(ctrl: _teamCtrl, searchCtrl: _searchCtrl),
            ),
          ),
          GetBuilder<TeamController>(
            builder: (_) => HandlingDataRequest(
              statusRequest: _teamCtrl.status,
              onRetry: () => _teamCtrl.loadAll(),
              widget: _InvitationsTab(ctrl: _teamCtrl),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_team',
        onPressed: () => Get.toNamed<dynamic>(AppRoutes.inviteAdmin),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ─────────────────────────── Admins tab ───────────────────────────

class _AdminsTab extends StatelessWidget {
  final TeamController ctrl;
  final TextEditingController searchCtrl;
  const _AdminsTab({required this.ctrl, required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final list = ctrl.filteredAdmins;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, AppSpacing.s2),
          child: TextField(
            controller: searchCtrl,
            onChanged: ctrl.setAdminSearch,
            decoration: InputDecoration(
              hintText: 'search_admins'.tr,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: ctrl.adminSearch.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        searchCtrl.clear();
                        ctrl.setAdminSearch('');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: colors.borderHairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: colors.borderHairline),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ctrl.loadAll,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: AppSpacing.s8),
                      Center(
                        child: Text(
                          ctrl.adminSearch.isEmpty
                              ? 'no_admins_yet'.tr
                              : 'no_results'.tr,
                          style: AppTextStyles.bodySecondary(context),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s4),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _AdminCard(
                      admin: list[i],
                      colors: colors,
                      ctrl: ctrl,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  final AdminModel admin;
  final AppColorScheme colors;
  final TeamController ctrl;

  const _AdminCard({
    required this.admin,
    required this.colors,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = admin.id == ctrl.currentAdminId;

    return Opacity(
      opacity: admin.isActive ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.s3),
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
                      Flexible(
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
                      if (isSelf) ...[
                        const SizedBox(width: AppSpacing.s2),
                        _Pill(text: 'you_label'.tr, color: colors.brand),
                      ],
                      if (!admin.isActive) ...[
                        const SizedBox(width: AppSpacing.s2),
                        _Pill(text: 'inactive_label'.tr, color: colors.error),
                      ],
                      const Spacer(),
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
                        Text(admin.branchName!, style: AppTextStyles.xs(context)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.login_outlined,
                          size: 13, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        admin.lastLoginShort == null
                            ? 'never_logged_in'.tr
                            : '${'last_login'.tr}: ${admin.lastLoginShort}',
                        style: AppTextStyles.xs(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isSelf) _adminMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _adminMenu(BuildContext context) {
    final isGm = admin.role == 'general_manager';
    // You can't manage a team member higher than you in the admin hierarchy.
    // The backend decides this per row (`can_manage`); we fall back to the
    // general-manager guard for older payloads that omit the flag.
    if (!admin.canManage) return const SizedBox.shrink();
    if (isGm && !ctrl.isGeneralManager) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: colors.textSecondary),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            _showEditAdminSheet(context, admin, ctrl);
            break;
          case 'permissions':
            _showAdminPermissionsSheet(context, admin.id, ctrl);
            break;
          case 'toggle':
            await ctrl.setAdminActive(admin.id, !admin.isActive);
            break;
          case 'remove':
            _confirmRemove(context, admin, ctrl);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: _MenuRow(
              icon: Icons.edit_outlined, label: 'edit_role_branch'.tr),
        ),
        if (!isGm)
          PopupMenuItem(
            value: 'permissions',
            child: _MenuRow(
                icon: Icons.security_outlined, label: 'edit_permissions'.tr),
          ),
        PopupMenuItem(
          value: 'toggle',
          child: _MenuRow(
            icon: admin.isActive
                ? Icons.block_outlined
                : Icons.check_circle_outline,
            label: admin.isActive ? 'deactivate'.tr : 'activate'.tr,
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: _MenuRow(
            icon: Icons.person_remove_outlined,
            label: 'remove_from_team'.tr,
            color: colors.error,
          ),
        ),
      ],
    );
  }
}

void _confirmRemove(BuildContext context, AdminModel admin, TeamController ctrl) {
  final colors = AppColors.of(context);
  Get.dialog<void>(
    AlertDialog(
      title: Text('remove_from_team'.tr),
      content: Text('remove_admin_confirm'.trParams({'name': admin.name})),
      actions: [
        TextButton(
          onPressed: () => Get.back<void>(),
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () async {
            Get.back<void>();
            await ctrl.removeAdmin(admin.id);
          },
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: Text('remove_from_team'.tr),
        ),
      ],
    ),
  );
}

// ─────────────────────────── Invitations tab ───────────────────────────

class _InvitationsTab extends StatelessWidget {
  final TeamController ctrl;
  const _InvitationsTab({required this.ctrl});

  static const _filters = [
    ('pending', 'filter_pending'),
    ('accepted', 'filter_accepted'),
    ('expired', 'filter_expired'),
    ('cancelled', 'filter_cancelled'),
    ('all', 'filter_all'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final list = ctrl.filteredInvitations;

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
            children: _filters.map((f) {
              final selected = ctrl.invitationFilter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s2),
                child: ChoiceChip(
                  label: Text(f.$2.tr),
                  selected: selected,
                  onSelected: (_) => ctrl.setInvitationFilter(f.$1),
                  selectedColor: colors.brandSubtle,
                  side: BorderSide(
                    color: selected ? colors.brand : colors.borderHairline,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ctrl.loadAll,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: AppSpacing.s8),
                      Center(
                        child: Text('no_pending_invitations'.tr,
                            style: AppTextStyles.bodySecondary(context)),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s4),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _InvitationCard(
                      invitation: list[i],
                      colors: colors,
                      onCancel: () => ctrl.cancelInvitation(list[i].id),
                      onResend: () async {
                        final code = await ctrl.resendInvitation(list[i].id);
                        if (code != null) _showCodeDialog(code);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

void _showCodeDialog(String code) {
  final context = Get.context!;
  final colors = AppColors.of(context);
  Get.dialog<void>(
    AlertDialog(
      title: Text('invitation_code_label'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s5, vertical: AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.brand, width: 2),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: colors.brand,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text('invitation_valid_for'.tr,
              style: AppTextStyles.sm(context), textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Get.snackbar('done'.tr, 'code_copied'.tr,
                snackPosition: SnackPosition.BOTTOM);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text('copy_code'.tr),
        ),
        TextButton(
          onPressed: () => Get.back<void>(),
          child: Text('done'.tr),
        ),
      ],
    ),
  );
}

class _InvitationCard extends StatelessWidget {
  final ManagerInvitationModel invitation;
  final AppColorScheme colors;
  final VoidCallback onCancel;
  final VoidCallback onResend;

  const _InvitationCard({
    required this.invitation,
    required this.colors,
    required this.onCancel,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final status = invitation.statusKey;
    final isPending = status == 'pending';
    final canResend = status == 'expired' || status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s3),
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
                  invitation.name.isEmpty ? invitation.email : invitation.name,
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
              _StatusBadge(statusKey: status, colors: colors),
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
                '${'invitation_expires_at'.tr}: ${_shortDate(invitation.expiresAt)}',
                style: AppTextStyles.xs(context),
              ),
              const Spacer(),
              if (canResend)
                TextButton.icon(
                  onPressed: onResend,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('resend_code'.tr,
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (isPending)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text('cancel_invitation'.tr,
                      style: const TextStyle(fontSize: 12)),
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

  String _shortDate(String raw) =>
      raw.length >= 16 ? raw.substring(0, 16) : raw;
}

// ─────────────────────────── Shared widgets ───────────────────────────

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.s3),
        Text(label,
            style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, color: color)),
      ],
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

// ─────────────────────────── Edit role / branch sheet ───────────────────────────

void _showEditAdminSheet(
    BuildContext context, AdminModel admin, TeamController ctrl) {
  Get.bottomSheet<void>(
    _EditAdminSheet(admin: admin, ctrl: ctrl),
    isScrollControlled: true,
  );
}

class _EditAdminSheet extends StatefulWidget {
  final AdminModel admin;
  final TeamController ctrl;
  const _EditAdminSheet({required this.admin, required this.ctrl});

  @override
  State<_EditAdminSheet> createState() => _EditAdminSheetState();
}

class _EditAdminSheetState extends State<_EditAdminSheet> {
  late String _role = widget.admin.role;
  late int? _branchId = widget.admin.branchId;
  bool _saving = false;

  static const _roles = [
    ('hr', 'role_hr'),
    ('branch_manager', 'role_branch_manager'),
    ('attendance', 'role_attendance'),
    ('viewer', 'role_viewer'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ctrl = widget.ctrl;
    final roles = [
      if (ctrl.isGeneralManager || widget.admin.role == 'general_manager')
        ('general_manager', 'general_manager'),
      ..._roles,
    ];

    return Material(
      color: colors.surface,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.admin.name, style: AppTextStyles.h3(context)),
              const SizedBox(height: AppSpacing.s4),
              Text('admin_role'.tr, style: AppTextStyles.bodySecondary(context)),
              const SizedBox(height: AppSpacing.s2),
              Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s2,
                children: roles.map((r) {
                  final selected = _role == r.$1;
                  return ChoiceChip(
                    label: Text(r.$2.tr),
                    selected: selected,
                    onSelected: (_) => setState(() => _role = r.$1),
                    selectedColor: colors.brandSubtle,
                    side: BorderSide(
                      color: selected ? colors.brand : colors.borderHairline,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('branch'.tr, style: AppTextStyles.bodySecondary(context)),
              const SizedBox(height: AppSpacing.s2),
              _BranchDropdown(
                branches: ctrl.branches,
                selectedId: _branchId,
                colors: colors,
                onSelect: (id) => setState(() => _branchId = id),
              ),
              const SizedBox(height: AppSpacing.s5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('save'.tr,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final roleChanged = _role != widget.admin.role;
    final branchChanged = _branchId != widget.admin.branchId;
    if (!roleChanged && !branchChanged) {
      Get.back<void>();
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.ctrl.updateAdmin(
      adminId: widget.admin.id,
      role: roleChanged ? _role : null,
      branchId: _branchId,
      branchProvided: branchChanged,
    );
    if (ok) {
      Get.back<void>();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }
}

class _BranchDropdown extends StatelessWidget {
  final List<BranchModel> branches;
  final int? selectedId;
  final AppColorScheme colors;
  final ValueChanged<int?> onSelect;

  const _BranchDropdown({
    required this.branches,
    required this.selectedId,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedId,
          hint: Text('scope_all_branches'.tr,
              style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textSecondary)),
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: [
            DropdownMenuItem<int?>(
              child: Text('scope_all_branches'.tr,
                  style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
            ),
            ...branches.map((b) => DropdownMenuItem<int?>(
                  value: b.id,
                  child: Text(b.name,
                      style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
                )),
          ],
          onChanged: onSelect,
        ),
      ),
    );
  }
}

// ─────────────────────────── Permissions sheet ───────────────────────────

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
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('permissions_for_admin'.tr,
                            style: AppTextStyles.h3(context)),
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
                          child: Text('customized_permissions'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.brand,
                              )),
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
                          child: Text('permissions_override_hint'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 12,
                                color: colors.textSecondary,
                              )),
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
                            child: Text('perm_$perm'.tr,
                                style: const TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 14,
                                )),
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
                              child: Text('default_for_role'.tr,
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: colors.success,
                                  )),
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
                        final ok = await ctrl.saveAdminPermissions(adminId);
                        if (ok) {
                          Get.back<void>();
                          Get.snackbar('done'.tr, 'permissions_saved'.tr,
                              snackPosition: SnackPosition.BOTTOM);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text('save'.tr,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          )),
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
                              content: Text('reset_permissions_confirm'.tr),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back<void>(),
                                  child: Text('cancel'.tr),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Get.back<void>();
                                    final ok = await ctrl
                                        .resetAdminPermissions(adminId);
                                    if (ok) {
                                      Get.back<void>();
                                      Get.snackbar(
                                          'done'.tr, 'permissions_reset'.tr,
                                          snackPosition: SnackPosition.BOTTOM);
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                      foregroundColor: colors.error),
                                  child: Text('reset_to_default'.tr),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text('reset_to_default'.tr,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              color: colors.error,
                            )),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            ),
          ),
        );
      },
    ),
    isScrollControlled: true,
  );
}
