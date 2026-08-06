import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/audit_log_model.dart';
import '../../../logic/controller/audit/audit_controller.dart';
import '../shared/panel_widgets.dart';

/// What we did, when, and to whom — filterable, paginated, and carrying the
/// payload that says what actually changed.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات')),
      body: GetBuilder<AuditController>(
        builder: (controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s3,
                  AppSpacing.s4,
                  0,
                ),
                child: Column(
                  children: [
                    PanelSearchField(
                      hint: 'ابحث في الإجراء أو التفاصيل',
                      onChanged: controller.onSearchChanged,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: AuditLogModel.filterableActions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
                        itemBuilder: (context, index) {
                          final entry = AuditLogModel.filterableActions[index];
                          return _Chip(
                            label: entry.value,
                            selected: controller.actionFilter.value == entry.key,
                            onTap: () => controller.setActionFilter(entry.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: controller.status.value,
                  onRetry: () => controller.loadLogs(),
                  widget: RefreshIndicator(
                    onRefresh: () => controller.loadLogs(),
                    child: controller.logs.isEmpty
                        ? ListView(
                            children: const [
                              EmptyHint(
                                message: 'لا توجد عمليات مطابقة',
                                icon: Icons.history,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              AppSpacing.s3,
                              AppSpacing.s4,
                              AppSpacing.s8,
                            ),
                            itemCount: controller.logs.length + 1,
                            itemBuilder: (context, index) {
                              if (index == controller.logs.length) {
                                return PagerBar(
                                  page: controller.currentPage.value,
                                  totalPages: controller.totalPages.value,
                                  total: controller.total.value,
                                  onPrevious: controller.previousPage,
                                  onNext: controller.nextPage,
                                );
                              }
                              return _AuditCard(log: controller.logs[index]);
                            },
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : Colors.transparent,
          border: Border.all(color: selected ? colors.brand : colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditLogModel log;

  const _AuditCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final dotColor = log.isSensitive ? colors.warning : colors.brand;

    return PanelCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      onTap: log.payload == null ? null : () => _showDetail(log),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.actionLabel,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  [
                    if (log.adminName != null) log.adminName!,
                    if (log.targetTypeLabel != null)
                      '${log.targetTypeLabel}${log.targetId != null ? ' #${log.targetId}' : ''}',
                  ].join(' · '),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                if (log.ip != null)
                  Text(
                    log.ip!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                shortDate(log.createdAt),
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
              if (log.payload != null)
                Text(
                  'التفاصيل',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.brand,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showDetail(AuditLogModel log) {
  final payload = log.payload ?? const <String, dynamic>{};

  Get.bottomSheet<void>(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        color: Get.theme.scaffoldBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.actionLabel,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              '${log.adminName ?? 'مشرف'} · ${shortDate(log.createdAt)} · ${log.ip ?? ''}',
              style: const TextStyle(fontFamily: 'Geist', fontSize: 12),
            ),
            const Divider(height: AppSpacing.s5),
            ...payload.entries.map(
              (e) => InfoRow(label: e.key, value: '${e.value}'),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
    ),
    backgroundColor: Get.theme.scaffoldBackgroundColor,
    isScrollControlled: true,
  );
}
