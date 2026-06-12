import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/audit_actions.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/audit_log_model.dart';
import '../../../logic/controller/audit/audit_controller.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<AuditController>(AuditController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('activity_log'.tr),
        actions: [
          GetBuilder<AuditController>(
            builder: (c) => c.actors.length > 1
                ? _ActorFilterButton(ctrl: c)
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryChips(ctrl: ctrl),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadActivity,
              child: GetBuilder<AuditController>(
                builder: (c) => HandlingDataRequest(
                  statusRequest: c.status,
                  onRetry: c.loadActivity,
                  widget: c.entries.isEmpty
                      ? _EmptyState(colors: colors)
                      : _ActivityList(ctrl: c),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final AuditController ctrl;
  const _ActivityList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 &&
            ctrl.hasMore &&
            ctrl.moreStatus != StatusRequest.loading) {
          ctrl.loadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s2,
          AppSpacing.s4,
          AppSpacing.s7,
        ),
        itemCount: ctrl.entries.length + (ctrl.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
        itemBuilder: (_, i) {
          if (i >= ctrl.entries.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.s4),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          return _ActivityTile(entry: ctrl.entries[i]);
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AuditLogModel entry;
  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = AuditActions.labelFor(entry.action);
    final icon = AuditActions.iconFor(entry.action);
    final details = AuditActions.payloadSummary(entry.payload);
    final isPerson = AuditActions.isPersonTarget(entry.targetType);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderHairline),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colors.brand),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (entry.subject != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        isPerson
                            ? Icons.badge_outlined
                            : Icons.label_outline,
                        size: 13,
                        color: colors.brand,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.subject!,
                          style: AppTextStyles.sm(context).copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: AppTextStyles.xs(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 13, color: colors.textTertiary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        entry.adminName.isNotEmpty ? entry.adminName : 'مدير',
                        style: AppTextStyles.xs(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('  ·  ', style: AppTextStyles.xs(context)),
                    Text(
                      _relativeTime(entry.createdAt),
                      style: AppTextStyles.xs(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final AuditController ctrl;
  const _CategoryChips({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuditController>(
      builder: (c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s2,
        ),
        child: Row(
          children: [
            _Chip(
              label: 'all'.tr,
              selected: c.categoryFilter == null,
              onTap: () => c.filterByCategory(null),
            ),
            for (final key in AuditActions.categoryOrder) ...[
              const SizedBox(width: AppSpacing.s2),
              _Chip(
                label: AuditActions.categoryLabel(key),
                selected: c.categoryFilter == key,
                onTap: () => c.filterByCategory(key),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActorFilterButton extends StatelessWidget {
  final AuditController ctrl;
  const _ActorFilterButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = ctrl.adminFilter != null;
    return PopupMenuButton<int?>(
      icon: Icon(
        Icons.filter_alt_outlined,
        color: active ? colors.brand : null,
      ),
      tooltip: 'filter_by_admin'.tr,
      onSelected: (value) => ctrl.filterByAdmin(value),
      itemBuilder: (_) => [
        PopupMenuItem<int?>(
          child: Text('all_admins'.tr),
        ),
        for (final actor in ctrl.actors)
          PopupMenuItem<int?>(
            value: actor.id,
            child: Text(actor.name),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.brand : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.sm(context).copyWith(
            color: selected ? Colors.white : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColorScheme colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.history, size: 48, color: colors.textTertiary),
        const SizedBox(height: AppSpacing.s3),
        Center(
          child: Text(
            'no_activity'.tr,
            style: AppTextStyles.bodySecondary(context),
          ),
        ),
      ],
    );
  }
}

/// Arabic relative time ("منذ ٣ ساعات"), falling back to an absolute date for
/// anything older than a week.
String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return DateFormat('yyyy/MM/dd').format(dt);
}
