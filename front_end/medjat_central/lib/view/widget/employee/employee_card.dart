import 'package:flutter/material.dart';
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
