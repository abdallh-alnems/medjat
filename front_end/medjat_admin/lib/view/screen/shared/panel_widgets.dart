import 'package:flutter/material.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';

/// Small building blocks shared by the support screens, so a company card, a
/// contact row and a diagnostics panel all read as the same surface.

AppColorScheme panelColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light ? AppColors.light : AppColors.dark;

/// A bordered surface with an optional title and trailing action.
class PanelCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const PanelCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    final content = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: padding ?? const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          child,
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: content,
    );
  }
}

/// A label/value row. Values use Geist so digits and dates line up.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool numeric;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: numeric ? 'Geist' : 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill: green/red/amber/neutral by tone.
enum PillTone { success, error, warning, neutral, brand }

class StatusPill extends StatelessWidget {
  final String text;
  final PillTone tone;

  const StatusPill({super.key, required this.text, this.tone = PillTone.neutral});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final color = switch (tone) {
      PillTone.success => colors.success,
      PillTone.error => colors.error,
      PillTone.warning => colors.warning,
      PillTone.brand => colors.brand,
      PillTone.neutral => colors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A single number with a caption, used in the stats strips.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatTile({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color ?? colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search field used by every list screen.
class PanelSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const PanelSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, size: 20, color: colors.textTertiary),
        isDense: true,
      ),
    );
  }
}

/// Previous/next pager. Hidden entirely while there is only one page, so short
/// lists stay clean.
class PagerBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PagerBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final colors = panelColors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            // RTL: "next" points left.
            onPressed: page < totalPages ? onNext : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'التالي',
          ),
          Text(
            'صفحة $page من $totalPages · $total سجل',
            style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: colors.textSecondary),
          ),
          IconButton(
            onPressed: page > 1 ? onPrevious : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'السابق',
          ),
        ],
      ),
    );
  }
}

/// Empty state for a filtered list.
class EmptyHint extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyHint({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s7),
      child: Column(
        children: [
          Icon(icon, size: 40, color: colors.textTertiary),
          const SizedBox(height: AppSpacing.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "منذ ٣ أيام" style relative age for a timestamp, used everywhere a
/// last-seen / last-login matters.
String relativeAge(String? timestamp, {String never = 'لا يوجد'}) {
  if (timestamp == null || timestamp.isEmpty) return never;
  final parsed = DateTime.tryParse(timestamp.replaceFirst(' ', 'T'));
  if (parsed == null) return timestamp;

  final diff = DateTime.now().difference(parsed);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
  if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()} شهر';
  return 'منذ ${(diff.inDays / 365).floor()} سنة';
}

/// Short date for display (YYYY-MM-DD or the first 16 chars of a datetime).
String shortDate(String? value) {
  if (value == null || value.isEmpty) return '—';
  return value.length > 16 ? value.substring(0, 16) : value;
}
