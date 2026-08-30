import 'package:flutter/material.dart';
import '../../../core/constant/theme/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isFullWidth;
  final bool compact;

  /// When provided, the card becomes tappable: it shows a ripple and a chevron
  /// affordance so users know it opens a details screen.
  final VoidCallback? onTap;

  /// Optional change vs a previous period, in percentage points. Rendered as a
  /// small up/down chip; hidden when null or ~0.
  final double? trend;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.isFullWidth = false,
    this.compact = false,
    this.onTap,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.light
        ? AppColors.light
        : AppColors.dark;

    final iconBox = compact ? 28.0 : 36.0;
    final iconSize = compact ? 15.0 : 18.0;
    final valueSize = compact ? 18.0 : 24.0;
    final titleSize = compact ? 11.0 : 13.0;
    final radius = BorderRadius.circular(AppRadius.md);

    final content = Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.s3 : AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: iconSize, color: color),
              ),
              const Spacer(),
              if (trend != null && trend!.abs() >= 0.5) _trendChip(colors),
              if (onTap != null)
                Icon(Icons.chevron_left, size: 18, color: colors.textTertiary),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.s2 : AppSpacing.s3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: valueSize,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: titleSize,
              color: colors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: colors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.borderHairline),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _trendChip(AppColorScheme colors) {
    final up = trend! > 0;
    final c = up ? colors.success : colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: c),
          const SizedBox(width: 2),
          Text(
            '${trend!.abs().toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
