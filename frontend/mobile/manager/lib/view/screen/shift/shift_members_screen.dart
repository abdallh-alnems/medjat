import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/employee_category_model.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../logic/controller/shift/shift_controller.dart';

/// Shows the employees assigned to a single shift, with the ability to add
/// employees to the shift or remove them from it.
class ShiftMembersScreen extends StatefulWidget {
  const ShiftMembersScreen({super.key});

  @override
  State<ShiftMembersScreen> createState() => _ShiftMembersScreenState();
}

class _ShiftMembersScreenState extends State<ShiftMembersScreen> {
  final ShiftController _shiftCtrl = Get.find<ShiftController>();
  final EmployeeData _empData = Get.find<EmployeeData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  late final ShiftModel shift;

  final members = <EmployeeModel>[].obs;
  final status = StatusRequest.none.obs;
  final busyIds = <int>{}.obs;

  /// Category id → name, for the add-member filter. Loaded once.
  final categories = <int, String>{}.obs;

  @override
  void initState() {
    super.initState();
    shift = Get.arguments as ShiftModel;
    _loadMembers();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final response = await _categoryData.getCategories();
    if (response['status'] != StatusRequest.success) return;
    dynamic body = response['data'];
    if (body is Map && body['data'] != null) body = body['data'];
    List<dynamic>? items;
    if (body is List) {
      items = body;
    } else if (body is Map) {
      for (final key in const ['categories', 'items', 'records', 'list', 'data']) {
        if (body[key] is List) {
          items = body[key] as List;
          break;
        }
      }
    }
    if (items == null) return;
    final map = <int, String>{};
    for (final raw in items.whereType<Map<String, dynamic>>()) {
      final c = EmployeeCategoryModel.fromJson(raw);
      if (c.id != 0) map[c.id] = c.name;
    }
    categories.value = map;
  }

  Future<void> _loadMembers() async {
    status.value = StatusRequest.loading;
    final response = await _empData.getEmployees(shiftId: shift.id);
    if (response['status'] == StatusRequest.success) {
      members.value = _parseEmployees(response['data']);
      status.value = StatusRequest.success;
    } else {
      status.value = StatusRequest.failure;
    }
  }

  Future<void> _removeMember(EmployeeModel emp) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('shift_remove_member'.tr),
        content: Text('${'shift_remove_member_confirm'.tr} "${emp.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.of(context).error),
            child: Text('remove'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    busyIds.add(emp.id);
    final count = await _shiftCtrl.unassignEmployees(shift.id, [emp.id]);
    busyIds.remove(emp.id);

    if (count > 0) {
      members.removeWhere((m) => m.id == emp.id);
      members.refresh();
      await _shiftCtrl.loadShifts();
      Get.snackbar('done'.tr, 'shift_member_removed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openAddSheet() async {
    final empStatus = StatusRequest.none.obs;
    final candidates = <EmployeeModel>[].obs;
    final selected = <int>{}.obs;
    final isAssigning = false.obs;

    // Load employees not already in this shift.
    Future<void> load() async {
      empStatus.value = StatusRequest.loading;
      final response = await _empData.getEmployees();
      if (response['status'] == StatusRequest.success) {
        candidates.value = _parseEmployees(response['data'])
            .where((e) => e.shiftId != shift.id)
            .toList();
        empStatus.value = StatusRequest.success;
      } else {
        empStatus.value = StatusRequest.failure;
      }
    }

    unawaited(load());

    await Get.bottomSheet<void>(
      _AddMembersSheet(
        shiftName: shift.name,
        candidates: candidates,
        selected: selected,
        empStatus: empStatus,
        isAssigning: isAssigning,
        categories: categories,
        onAssign: () async {
          if (selected.isEmpty) return;

          // Assigning sets the employee's shift, overwriting any previous one.
          // Warn before moving employees who already belong to another shift.
          final reassigned = candidates
              .where((e) => selected.contains(e.id) && e.shiftId != null)
              .toList();
          if (reassigned.isNotEmpty) {
            final confirmed = await _confirmReassign(reassigned);
            if (confirmed != true) return;
          }

          isAssigning.value = true;
          final count = await _shiftCtrl.assignEmployees(
            shift.id,
            selected.toList(),
          );
          isAssigning.value = false;
          if (count > 0) {
            Get.back<void>();
            await _shiftCtrl.loadShifts();
            await _loadMembers();
            Get.snackbar('done'.tr, 'shift_assigned_success'.tr,
                snackPosition: SnackPosition.BOTTOM);
          }
        },
      ),
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
    );
  }

  Future<bool> _confirmReassign(List<EmployeeModel> employees) async {
    final colors = AppColors.of(context);
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('shift_reassign_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'shift_reassign_warning'.tr,
              style: AppTextStyles.bodySecondary(context),
            ),
            const SizedBox(height: AppSpacing.s3),
            ...employees.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e.shiftName != null && e.shiftName!.isNotEmpty
                        ? '• ${e.name}  —  ${e.shiftName}'
                        : '• ${e.name}',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            style: TextButton.styleFrom(foregroundColor: colors.brand),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  List<EmployeeModel> _parseEmployees(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(shift.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: Text(
              '${_formatTime(shift.startTime)} - ${_formatTime(shift.endTime)}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_shift_members',
        onPressed: _openAddSheet,
        backgroundColor: colors.brand,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text(
          'shift_add_member'.tr,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMembers,
        child: Obx(() {
          if (status.value == StatusRequest.loading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (status.value == StatusRequest.failure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('error'.tr,
                      style: AppTextStyles.bodySecondary(context)),
                  const SizedBox(height: AppSpacing.s3),
                  TextButton(
                    onPressed: _loadMembers,
                    child: Text('retry'.tr),
                  ),
                ],
              ),
            );
          }
          if (members.isEmpty) {
            return Stack(
              children: [
                ListView(), // enables pull-to-refresh on empty
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 48, color: colors.textTertiary),
                      const SizedBox(height: AppSpacing.s3),
                      Text('shift_no_members'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s7,
            ),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
            itemBuilder: (_, i) {
              final emp = members[i];
              return Obx(() => _MemberTile(
                    employee: emp,
                    isBusy: busyIds.contains(emp.id),
                    onRemove: () => _removeMember(emp),
                  ));
            },
          );
        }),
      ),
    );
  }

  String _formatTime(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
  }
}

class _MemberTile extends StatelessWidget {
  final EmployeeModel employee;
  final bool isBusy;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.employee,
    required this.isBusy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
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
            backgroundImage:
                (employee.photoUrl != null && employee.photoUrl!.isNotEmpty)
                    ? NetworkImage(employee.photoUrl!)
                    : null,
            child: (employee.photoUrl == null || employee.photoUrl!.isEmpty)
                ? Text(
                    employee.name.isNotEmpty
                        ? employee.name.characters.first
                        : '?',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontWeight: FontWeight.w700,
                      color: colors.brand,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (employee.jobTitle != null &&
                    employee.jobTitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    employee.jobTitle!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isBusy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(Icons.person_remove_outlined,
                  size: 22, color: colors.error),
              tooltip: 'remove'.tr,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _AddMembersSheet extends StatefulWidget {
  final String shiftName;
  final RxList<EmployeeModel> candidates;
  final RxSet<int> selected;
  final Rx<StatusRequest> empStatus;
  final RxBool isAssigning;
  final RxMap<int, String> categories;
  final Future<void> Function() onAssign;

  const _AddMembersSheet({
    required this.shiftName,
    required this.candidates,
    required this.selected,
    required this.empStatus,
    required this.isAssigning,
    required this.categories,
    required this.onAssign,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _branchId;
  int? _categoryId;
  bool _onlyUnassigned = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Distinct branches present among the candidates, for the branch filter.
  Map<int, String> _branchOptions(List<EmployeeModel> all) {
    final map = <int, String>{};
    for (final e in all) {
      if (e.branchName != null && e.branchName!.isNotEmpty) {
        map[e.branchId] = e.branchName!;
      }
    }
    return map;
  }

  List<EmployeeModel> _filter(List<EmployeeModel> all) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      if (_onlyUnassigned && e.shiftId != null) return false;
      if (_branchId != null && e.branchId != _branchId) return false;
      if (_categoryId != null && !e.categoryIds.contains(_categoryId)) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${e.name} ${e.jobTitle ?? ''} ${e.employeeCode ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s5,
        right: AppSpacing.s5,
        top: AppSpacing.s5,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'shift_add_member'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Obx(() => widget.selected.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      '${widget.selected.length} ${'selected_count'.tr}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    )),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'search_employee'.tr,
              prefixIcon: Icon(Icons.search, color: colors.textTertiary),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, color: colors.textTertiary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
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
          const SizedBox(height: AppSpacing.s3),
          // Filters + list react to candidate / category loading.
          Obx(() {
            final all = widget.candidates.toList();
            final branchOptions = _branchOptions(all);
            final categoryOptions = widget.categories;

            final dropdowns = <Widget>[
              if (branchOptions.length > 1)
                _filterDropdown(
                  context,
                  value: _branchId,
                  hint: 'all_branches'.tr,
                  options: branchOptions,
                  onChanged: (v) => setState(() => _branchId = v),
                ),
              if (categoryOptions.isNotEmpty)
                _filterDropdown(
                  context,
                  value: _categoryId,
                  hint: 'all_categories'.tr,
                  options: categoryOptions,
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dropdowns.isNotEmpty) ...[
                  Row(
                    children: [
                      for (var i = 0; i < dropdowns.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.s2),
                        Expanded(child: dropdowns[i]),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilterChip(
                    label: Text('shift_filter_unassigned'.tr),
                    selected: _onlyUnassigned,
                    onSelected: (v) => setState(() => _onlyUnassigned = v),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      color:
                          _onlyUnassigned ? colors.brand : colors.textSecondary,
                    ),
                    selectedColor: colors.brandSubtle,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.42,
                  ),
                  child: _buildList(context, all),
                ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.s4),
          Obx(() => PrimaryButton(
                text: 'assign_selected'.tr,
                isLoading: widget.isAssigning.value,
                enabled: widget.selected.isNotEmpty,
                onPressed: widget.onAssign,
              )),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    BuildContext context, {
    required int? value,
    required String hint,
    required Map<int, String> options,
    required ValueChanged<int?> onChanged,
  }) {
    final colors = AppColors.of(context);
    TextStyle itemStyle() => const TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          hint: Text(hint,
              style: itemStyle().copyWith(color: colors.textSecondary)),
          items: [
            DropdownMenuItem<int?>(child: Text(hint, style: itemStyle())),
            ...options.entries.map((e) => DropdownMenuItem<int?>(
                  value: e.key,
                  child: Text(e.value,
                      overflow: TextOverflow.ellipsis, style: itemStyle()),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<EmployeeModel> all) {
    final colors = AppColors.of(context);

    if (widget.empStatus.value == StatusRequest.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.s6),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Center(
          child: Text('shift_no_available_employees'.tr,
              style: AppTextStyles.bodySecondary(context)),
        ),
      );
    }

    final filtered = _filter(all);
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Center(
          child: Text('no_employees_found'.tr,
              style: AppTextStyles.bodySecondary(context)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final emp = filtered[i];
        return Obx(() => CheckboxListTile(
              value: widget.selected.contains(emp.id),
              title: Text(
                emp.name,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: emp.shiftName != null
                  ? Text(
                      '${'shift'.tr}: ${emp.shiftName}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    )
                  : null,
              onChanged: (v) {
                if (v == true) {
                  widget.selected.add(emp.id);
                } else {
                  widget.selected.remove(emp.id);
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ));
      },
    );
  }
}
