import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/branch_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/team/team_controller.dart';

class InviteAdminScreen extends StatefulWidget {
  const InviteAdminScreen({super.key});

  @override
  State<InviteAdminScreen> createState() => _InviteAdminScreenState();
}

class _InviteAdminScreenState extends State<InviteAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final roleCtrl = Rx<String>('viewer');
  final branchIdCtrl = Rx<int?>(null);
  final status = StatusRequest.none.obs;
  List<BranchModel> branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final branchData = Get.find<BranchData>();
    final response = await branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] != null) payload = payload['data'];
      List<dynamic> list = const [];
      if (payload is List) {
        list = payload;
      } else if (payload is Map) {
        for (final key in const ['branches', 'items', 'records', 'list', 'data']) {
          if (payload[key] is List) {
            list = payload[key] as List;
            break;
          }
        }
      }
      branches = list
          .whereType<Map<String, dynamic>>()
          .map(BranchModel.fromJson)
          .toList();
      setState(() {});
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('invite_admin'.tr)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrimaryInput(
                label: 'admin_email'.tr,
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr;
                  if (!GetUtils.isEmail(v.trim())) return 'invalid_email'.tr;
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('admin_role'.tr, style: AppTextStyles.h3(context)),
              const SizedBox(height: AppSpacing.s3),
              Obx(() => _RoleSelector(
                    selected: roleCtrl.value,
                    onChanged: (v) => roleCtrl.value = v,
                    colors: colors,
                    // Only a general manager (full access) may grant the top role.
                    includeGeneralManager:
                        Get.find<AuthController>().user?.isGeneralManager ??
                            false,
                  )),
              const SizedBox(height: AppSpacing.s4),
              Text('branch'.tr, style: AppTextStyles.h3(context)),
              const SizedBox(height: AppSpacing.s3),
              Obx(() => _BranchSelector(
                    branches: branches,
                    selectedId: branchIdCtrl.value,
                    onSelect: (id) => branchIdCtrl.value = id,
                    colors: colors,
                  )),
              const SizedBox(height: AppSpacing.s6),
              Obx(() => PrimaryButton(
                    text: 'send_invitation'.tr,
                    isLoading: status.value == StatusRequest.loading,
                    onPressed: _submit,
                  )),
              const SizedBox(height: AppSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    status.value = StatusRequest.loading;

    final ctrl = Get.find<TeamController>();
    final code = await ctrl.createInvitation(
      email: emailCtrl.text.trim(),
      role: roleCtrl.value,
      branchId: branchIdCtrl.value,
    );

    status.value = StatusRequest.none;

    if (code != null) {
      Get.offNamed<dynamic>(AppRoutes.invitationCode, arguments: code);
    }
  }
}

class _RoleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final AppColorScheme colors;
  final bool includeGeneralManager;

  const _RoleSelector({
    required this.selected,
    required this.onChanged,
    required this.colors,
    this.includeGeneralManager = false,
  });

  static const _roles = [
    ('hr', 'role_hr', Icons.badge_outlined),
    ('branch_manager', 'role_branch_manager', Icons.store_outlined),
    ('attendance', 'role_attendance', Icons.schedule_outlined),
    ('viewer', 'role_viewer', Icons.visibility_outlined),
  ];

  static const _generalManagerRole =
      ('general_manager', 'role_general_manager', Icons.workspace_premium_outlined);

  @override
  Widget build(BuildContext context) {
    final roles = [
      if (includeGeneralManager) _generalManagerRole,
      ..._roles,
    ];
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: roles.map((r) {
        final isSelected = selected == r.$1;
        return ChoiceChip(
          label: Text(r.$2.tr),
          avatar: Icon(r.$3, size: 16),
          selected: isSelected,
          onSelected: (_) => onChanged(r.$1),
          selectedColor: colors.brandSubtle,
          side: BorderSide(
            color: isSelected ? colors.brand : colors.borderHairline,
          ),
        );
      }).toList(),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final List<BranchModel> branches;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final AppColorScheme colors;

  const _BranchSelector({
    required this.branches,
    required this.selectedId,
    required this.onSelect,
    required this.colors,
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
          hint: Text(
            'scope_all_branches'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'scope_all_branches'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ),
            ...branches.map((b) => DropdownMenuItem<int?>(
                  value: b.id,
                  child: Text(
                    b.name,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )),
          ],
          onChanged: onSelect,
        ),
      ),
    );
  }
}
