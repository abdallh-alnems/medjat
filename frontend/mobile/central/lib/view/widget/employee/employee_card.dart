import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback onTap;

  const EmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(employee.status, colors);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.brandSubtle,
              backgroundImage: employee.photoUrl != null
                  ? NetworkImage(employee.photoUrl!)
                  : null,
              child: employee.photoUrl == null
                  ? Text(
                      employee.name.isNotEmpty ? employee.name[0] : '?',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                  if (employee.jobTitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      employee.jobTitle!,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  _buildDocExpiryBadge(context, colors),
                  _buildOnboardingBadge(context, colors),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: AppSpacing.s1,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    employee.statusLabel,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
                if (employee.branchName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    employee.branchName!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Red badge for an expired legal document, orange when expiring within
  /// 30 days, nothing otherwise. Surfaces the most urgent of iqama / passport
  /// / work permit.
  Widget _buildDocExpiryBadge(BuildContext context, AppColorScheme colors) {
    final exp = employee.soonestDocExpiry;
    if (exp == null || exp.daysLeft > 30) return const SizedBox.shrink();

    final expired = exp.daysLeft < 0;
    final color = expired ? colors.error : colors.warning;
    final docName = _docLabel(exp.docKey);
    final text = expired
        ? '$docName ${'doc_expired'.tr}'
        : '$docName ${'doc_expires_in'.tr} ${exp.daysLeft} ${'days_unit'.tr}';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _docLabel(String docKey) {
    switch (docKey) {
      case 'iqama':
        return 'doc_iqama'.tr;
      case 'passport':
        return 'doc_passport'.tr;
      case 'work_permit':
        return 'doc_work_permit'.tr;
      default:
        return docKey;
    }
  }

  /// Onboarding hint: pending activation.
  Widget _buildOnboardingBadge(BuildContext context, AppColorScheme colors) {
    if (employee.status != 'pending_activation') {
      return const SizedBox.shrink();
    }
    final label = 'onboarding_pending'.tr;
    const icon = Icons.hourglass_bottom_outlined;
    final color = colors.warning;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'active':
        return colors.success;
      case 'pending_activation':
        return colors.warning;
      case 'on_leave':
        return colors.accentWarm;
      case 'suspended':
        return colors.error;
      case 'terminated':
        return colors.textTertiary;
      default:
        return colors.textTertiary;
    }
  }
}
