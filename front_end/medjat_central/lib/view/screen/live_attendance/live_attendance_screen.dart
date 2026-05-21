import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/live_attendance_model.dart';
import '../../../logic/controller/live_attendance/live_attendance_controller.dart';

class LiveAttendanceScreen extends StatelessWidget {
  const LiveAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<LiveAttendanceController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('live_attendance'.tr, style: AppTextStyles.h3(context)),
        actions: [
          IconButton(
            tooltip: 'refresh'.tr,
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.loadBoard(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ctrl.loadBoard(),
        child: GetBuilder<LiveAttendanceController>(
          builder: (_) {
            return Column(
              children: [
                _LastUpdatedBar(ctrl: ctrl),
                _SummaryBar(summary: ctrl.summary, ctrl: ctrl),
                _FiltersBar(ctrl: ctrl),
                Expanded(
                  child: HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: () => ctrl.loadBoard(),
                    widget: _EmployeeList(ctrl: ctrl),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LastUpdatedBar extends StatelessWidget {
  final LiveAttendanceController ctrl;
  const _LastUpdatedBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final updated = ctrl.lastUpdated;
    final text = updated == null
        ? '—'
        : DateFormat('HH:mm:ss').format(updated);
    return Container(
      width: double.infinity,
      color: colors.sunken,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      child: Row(
        children: [
          Icon(Icons.sync, size: 14, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s2),
          Text(
            '${'last_updated'.tr}: $text',
            style: AppTextStyles.sm(context),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final LiveAttendanceSummary summary;
  final LiveAttendanceController ctrl;
  const _SummaryBar({required this.summary, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = <Widget>[
      _SummaryChip(
        label: 'status_in'.tr,
        count: summary.inside,
        color: colors.success,
        active: ctrl.statusFilter == LiveStatus.inside,
        onTap: () => _toggle(ctrl, LiveStatus.inside),
      ),
      _SummaryChip(
        label: 'status_out'.tr,
        count: summary.out,
        color: colors.textTertiary,
        active: ctrl.statusFilter == LiveStatus.out,
        onTap: () => _toggle(ctrl, LiveStatus.out),
      ),
      _SummaryChip(
        label: 'status_not_in'.tr,
        count: summary.notIn,
        color: colors.accentWarm,
        active: ctrl.statusFilter == LiveStatus.notIn,
        onTap: () => _toggle(ctrl, LiveStatus.notIn),
      ),
      _SummaryChip(
        label: 'status_absent'.tr,
        count: summary.absent,
        color: colors.error,
        active: ctrl.statusFilter == LiveStatus.absent,
        onTap: () => _toggle(ctrl, LiveStatus.absent),
      ),
      _SummaryChip(
        label: 'status_leave'.tr,
        count: summary.leave,
        color: colors.brand,
        active: ctrl.statusFilter == LiveStatus.leave,
        onTap: () => _toggle(ctrl, LiveStatus.leave),
      ),
      _SummaryChip(
        label: 'status_late'.tr,
        count: summary.late,
        color: colors.warning,
        active: false,
        onTap: null,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      child: Row(
        children: [
          for (final c in chips) ...[
            c,
            const SizedBox(width: AppSpacing.s2),
          ],
        ],
      ),
    );
  }

  void _toggle(LiveAttendanceController ctrl, LiveStatus status) {
    ctrl.setStatusFilter(ctrl.statusFilter == status ? null : status);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active ? color : colors.borderHairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final LiveAttendanceController ctrl;
  const _FiltersBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s3),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: ctrl.setSearch,
              style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'search_by_name'.tr,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s2),
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
          const SizedBox(width: AppSpacing.s3),
          _BranchDropdown(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  final LiveAttendanceController ctrl;
  const _BranchDropdown({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: ctrl.selectedBranchId,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            color: colors.textPrimary,
          ),
          items: [
            DropdownMenuItem<int?>(
              child: Text('all_branches'.tr),
            ),
            ...ctrl.branches.map((b) {
              final id = (b['id'] as num?)?.toInt();
              return DropdownMenuItem<int?>(
                value: id,
                child: Text((b['name'] as String?) ?? ''),
              );
            }),
          ],
          onChanged: (v) => ctrl.selectBranch(v),
        ),
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  final LiveAttendanceController ctrl;
  const _EmployeeList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final items = ctrl.filteredEntries;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppSpacing.s7 * 2),
          Center(
            child: Text('no_employees_found'.tr,
                style: AppTextStyles.sm(context)),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s5),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
      itemBuilder: (_, i) => _EmployeeTile(entry: items[i]),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final LiveAttendanceEntry entry;
  const _EmployeeTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final meta = _statusMeta(entry.status, colors);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: entry.isLate ? colors.warning : colors.borderHairline,
          width: entry.isLate ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, size: 20, color: meta.color),
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
                        entry.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isOffline) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Icon(Icons.cloud_off_outlined,
                          size: 14, color: colors.textTertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((entry.jobTitle ?? '').isNotEmpty) entry.jobTitle!,
                    if ((entry.branchName ?? '').isNotEmpty) entry.branchName!,
                  ].join(' • '),
                  style: AppTextStyles.sm(context),
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.checkInTime != null || entry.checkOutTime != null) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Row(
                    children: [
                      if (entry.checkInTime != null) ...[
                        Icon(Icons.login, size: 13, color: colors.success),
                        const SizedBox(width: 2),
                        Text(_fmt(entry.checkInTime),
                            style: _timeStyle(colors)),
                      ],
                      if (entry.checkOutTime != null) ...[
                        const SizedBox(width: AppSpacing.s3),
                        Icon(Icons.logout, size: 13, color: colors.textTertiary),
                        const SizedBox(width: 2),
                        Text(_fmt(entry.checkOutTime),
                            style: _timeStyle(colors)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: meta.color,
                  ),
                ),
              ),
              if (entry.isLate) ...[
                const SizedBox(height: 2),
                Text(
                  '${'late'.tr} ${entry.lateMinutes}${'minutes_short'.tr}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _timeStyle(AppColorScheme colors) => TextStyle(
        fontFamily: 'Geist',
        fontSize: 12,
        color: colors.textSecondary,
      );

  // Times come from MySQL as HH:mm:ss; show HH:mm.
  String _fmt(String? time) {
    if (time == null) return '';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  _StatusMeta _statusMeta(LiveStatus status, AppColorScheme colors) {
    switch (status) {
      case LiveStatus.inside:
        return _StatusMeta('status_in'.tr, Icons.login, colors.success);
      case LiveStatus.out:
        return _StatusMeta('status_out'.tr, Icons.logout, colors.textTertiary);
      case LiveStatus.notIn:
        return _StatusMeta(
            'status_not_in'.tr, Icons.schedule, colors.accentWarm);
      case LiveStatus.absent:
        return _StatusMeta(
            'status_absent'.tr, Icons.cancel_outlined, colors.error);
      case LiveStatus.leave:
        return _StatusMeta(
            'status_leave'.tr, Icons.beach_access_outlined, colors.brand);
      case LiveStatus.unknown:
        return _StatusMeta('—', Icons.help_outline, colors.textTertiary);
    }
  }
}

class _StatusMeta {
  final String label;
  final IconData icon;
  final Color color;
  _StatusMeta(this.label, this.icon, this.color);
}
