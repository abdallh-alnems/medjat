import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/attendance_device_model.dart';
import '../../../data/model/employee_model.dart';
import '../../../logic/controller/devices/device_users_controller.dart';

/// Links the User IDs stored on a terminal to Medjat employees, and shows the
/// raw punch feed for when someone insists the machine did not record them.
///
/// Two tabs without a TabController: GetBuilder already rebuilds on `setTab`,
/// and a controller here would only duplicate that state.
class DeviceUsersScreen extends StatelessWidget {
  const DeviceUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: GetBuilder<DeviceUsersController>(
          builder: (c) => Text(c.deviceLabel),
        ),
      ),
      body: GetBuilder<DeviceUsersController>(
        builder: (c) {
          if (c.status == StatusRequest.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _Tabs(colors: colors, ctrl: c),
              Expanded(
                child: c.tab == 0
                    ? _UsersTab(colors: colors, ctrl: c)
                    : _PunchesTab(colors: colors, ctrl: c),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.colors, required this.ctrl});

  final AppColorScheme colors;
  final DeviceUsersController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.s4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabButton(
            colors: colors,
            label: 'device_tab_users'.tr,
            selected: ctrl.tab == 0,
            onTap: () => ctrl.setTab(0),
          ),
          _TabButton(
            colors: colors,
            label: 'device_tab_punches'.tr,
            selected: ctrl.tab == 1,
            onTap: () => ctrl.setTab(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppColorScheme colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.textPrimary : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.colors, required this.ctrl});

  final AppColorScheme colors;
  final DeviceUsersController ctrl;

  @override
  Widget build(BuildContext context) {
    if (ctrl.users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Text(
          'device_no_users'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.6,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ctrl.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s5),
        children: [
          if (ctrl.pending.isNotEmpty) ...[
            _SectionLabel(
              colors: colors,
              text: 'device_users_pending'
                  .trParams({'n': '${ctrl.pending.length}'}),
            ),
            for (final u in ctrl.pending)
              _UserTile(colors: colors, ctrl: ctrl, user: u),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (ctrl.linked.isNotEmpty) ...[
            _SectionLabel(
              colors: colors,
              text:
                  'device_users_linked'.trParams({'n': '${ctrl.linked.length}'}),
            ),
            for (final u in ctrl.linked)
              _UserTile(colors: colors, ctrl: ctrl, user: u),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.colors, required this.text});

  final AppColorScheme colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.colors,
    required this.ctrl,
    required this.user,
  });

  final AppColorScheme colors;
  final DeviceUsersController ctrl;
  final DeviceUserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isLinked ? colors.borderHairline : colors.warning,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              user.deviceUserId,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.brand,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.isLinked
                      ? (user.employeeName ?? '')
                      : (user.deviceName ?? 'device_unlinked_user'.tr),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: user.isLinked ? colors.textPrimary : colors.warning,
                  ),
                ),
                if (user.isLinked && user.deviceName != null)
                  Text(
                    'device_name_on_device'
                        .trParams({'name': user.deviceName!}),
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                if (!user.isLinked && user.unmatchedPunches > 0)
                  Text(
                    'device_waiting_punches'
                        .trParams({'n': '${user.unmatchedPunches}'}),
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickEmployee(context),
            child: Text(user.isLinked ? 'change'.tr : 'device_link'.tr),
          ),
        ],
      ),
    );
  }

  void _pickEmployee(BuildContext context) {
    final candidates = ctrl.availableEmployees(user.employeeId);
    final searchCtrl = TextEditingController();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchCtrl.text.trim();
          final filtered = query.isEmpty
              ? candidates
              : candidates
                  .where((e) => e.name.contains(query))
                  .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  'device_link_title'
                      .trParams({'id': user.deviceUserId}),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: 'search'.tr,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                if (user.isLinked)
                  TextButton.icon(
                    onPressed: () {
                      Get.back<void>();
                      ctrl.link(user.id, null);
                    },
                    icon: const Icon(Icons.link_off),
                    label: Text('device_unlink'.tr),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _EmployeeRow(
                      employee: filtered[i],
                      colors: colors,
                      onTap: () {
                        Get.back<void>();
                        ctrl.link(user.id, filtered[i].id);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.employee,
    required this.colors,
    required this.onTap,
  });

  final EmployeeModel employee;
  final AppColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        employee.name,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
          color: colors.textPrimary,
        ),
      ),
      subtitle: employee.jobTitle == null
          ? null
          : Text(
              employee.jobTitle!,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textTertiary,
              ),
            ),
    );
  }
}

class _PunchesTab extends StatelessWidget {
  const _PunchesTab({required this.colors, required this.ctrl});

  final AppColorScheme colors;
  final DeviceUsersController ctrl;

  @override
  Widget build(BuildContext context) {
    if (ctrl.punches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Text(
          'device_no_punches'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.6,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: ctrl.loadPunches,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s5),
        itemCount: ctrl.punches.length,
        itemBuilder: (_, i) {
          final p = ctrl.punches[i];
          final stateColor = switch (p.state) {
            'applied' => colors.success,
            'duplicate' => colors.textTertiary,
            'failed' => colors.error,
            _ => colors.warning,
          };

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s2),
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                Icon(
                  p.direction == 'out' ? Icons.logout : Icons.login,
                  size: 18,
                  color: stateColor,
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.employeeName ??
                            'device_user_number'
                                .trParams({'id': p.deviceUserId}),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        p.punchedAt,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                      if (p.note != null)
                        Text(
                          p.note!,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: stateColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'device_punch_state_${p.state}'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: stateColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
