import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/live_attendance_model.dart';

class LiveEmployeeTile extends StatelessWidget {
  final LiveAttendanceEntry entry;
  const LiveEmployeeTile({super.key, required this.entry});

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
                  ].join(' \u2022 '),
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
                        Text(_fmt(entry.checkInTime), style: _timeStyle(colors)),
                      ],
                      if (entry.checkOutTime != null) ...[
                        const SizedBox(width: AppSpacing.s3),
                        Icon(Icons.logout, size: 13, color: colors.textTertiary),
                        const SizedBox(width: 2),
                        Text(_fmt(entry.checkOutTime), style: _timeStyle(colors)),
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

  String _fmt(String? time) {
    if (time == null) return '';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  static _StatusMeta _statusMeta(LiveStatus status, AppColorScheme colors) {
    switch (status) {
      case LiveStatus.inside:
        return _StatusMeta('status_in'.tr, Icons.login, colors.success);
      case LiveStatus.out:
        return _StatusMeta('status_out'.tr, Icons.logout, colors.textTertiary);
      case LiveStatus.notIn:
        return _StatusMeta(
            'status_not_in'.tr, Icons.schedule, colors.accentWarm);
      case LiveStatus.preShift:
        return _StatusMeta(
            'status_pre_shift'.tr, Icons.bedtime_outlined, colors.textTertiary);
      case LiveStatus.absent:
        return _StatusMeta(
            'status_absent'.tr, Icons.cancel_outlined, colors.error);
      case LiveStatus.leave:
        return _StatusMeta(
            'status_leave'.tr, Icons.beach_access_outlined, colors.brand);
      case LiveStatus.unknown:
        return _StatusMeta('\u2014', Icons.help_outline, colors.textTertiary);
    }
  }
}

class _StatusMeta {
  final String label;
  final IconData icon;
  final Color color;
  _StatusMeta(this.label, this.icon, this.color);
}
