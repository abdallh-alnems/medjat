import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../widget/report/report_export.dart';
import '../../../data/model/document_report_model.dart';
import '../../../data/model/document_stats_model.dart';
import '../../../logic/controller/document/document_reports_controller.dart';

class DocumentsReportScreen extends StatelessWidget {
  const DocumentsReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DocumentReportsController());
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('documents_report'.tr),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'export_as'.tr,
              onPressed: () {
                final allDocs = <DocumentReportModel>[
                  ...ctrl.missingDocuments,
                  ...ctrl.expiringDocuments,
                  ...ctrl.expiredDocuments,
                ];
                exportReportWithFormat(
                  context,
                  title: 'documents_report'.tr,
                  headers: [
                    'documents'.tr,
                    'employee'.tr,
                    'branch'.tr,
                    'status'.tr,
                    'expiry'.tr,
                  ],
                  rows: allDocs
                      .map((r) => [
                            r.documentName,
                            r.employeeName,
                            r.branchName ?? '-',
                            r.status,
                            r.expiresAt != null
                                ? '${r.expiresAt!.year}-${r.expiresAt!.month.toString().padLeft(2, '0')}-${r.expiresAt!.day.toString().padLeft(2, '0')}'
                                : '-',
                          ])
                      .toList(),
                );
              },
            ),
          ],
          bottom: TabBar(
            onTap: ctrl.setTab,
            labelColor: colors.brand,
            unselectedLabelColor: colors.textTertiary,
            indicatorColor: colors.brand,
            labelStyle: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: 'document_missing'.tr),
              Tab(text: 'document_expiring_soon'.tr),
              Tab(text: 'document_expired_tab'.tr),
            ],
          ),
        ),
        body: GetBuilder<DocumentReportsController>(
          builder: (_) {
            return Column(
              children: [
                _StatsBar(stats: ctrl.stats, colors: colors),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MissingTab(ctrl: ctrl, colors: colors),
                      _ExpiringTab(ctrl: ctrl, colors: colors),
                      _ExpiredTab(ctrl: ctrl, colors: colors),
                    ],
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

class _StatsBar extends StatelessWidget {
  final DocumentStatsModel? stats;
  final AppColorScheme colors;
  const _StatsBar({required this.stats, required this.colors});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'document_total_required'.tr,
              value: '${s.totalRequired}',
              color: colors.brand,
              colors: colors,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: _StatCard(
              label: 'document_uploaded_count'.tr,
              value: '${s.totalUploaded}',
              color: colors.success,
              colors: colors,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: _StatCard(
              label: 'document_missing'.tr,
              value: '${s.totalMissing}',
              color: colors.warning,
              colors: colors,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: _StatCard(
              label: 'document_expired_tab'.tr,
              value: '${s.totalExpired}',
              color: colors.error,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppColorScheme colors;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTab extends StatelessWidget {
  final DocumentReportsController ctrl;
  final AppColorScheme colors;
  const _MissingTab({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    return HandlingDataRequest(
      statusRequest: ctrl.missingStatus,
      onRetry: ctrl.loadMissing,
      widget: RefreshIndicator(
        onRefresh: ctrl.loadMissing,
        child: ctrl.missingDocuments.isEmpty
            ? _EmptyState(
                icon: Icons.check_circle_outline,
                message: 'no_missing_documents'.tr,
                colors: colors,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.s3),
                itemCount: ctrl.missingDocuments.length,
                itemBuilder: (_, i) => _ReportRow(
                  row: ctrl.missingDocuments[i],
                  colors: colors,
                  showExpiry: false,
                ),
              ),
      ),
    );
  }
}

class _ExpiringTab extends StatelessWidget {
  final DocumentReportsController ctrl;
  final AppColorScheme colors;
  const _ExpiringTab({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    return HandlingDataRequest(
      statusRequest: ctrl.expiringStatus,
      onRetry: ctrl.loadExpiringSoon,
      widget: RefreshIndicator(
        onRefresh: ctrl.loadExpiringSoon,
        child: ctrl.expiringDocuments.isEmpty
            ? _EmptyState(
                icon: Icons.event_available_outlined,
                message: 'no_expiring_documents'.tr,
                colors: colors,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.s3),
                itemCount: ctrl.expiringDocuments.length,
                itemBuilder: (_, i) => _ReportRow(
                  row: ctrl.expiringDocuments[i],
                  colors: colors,
                  showExpiry: true,
                  accentColor: colors.warning,
                ),
              ),
      ),
    );
  }
}

class _ExpiredTab extends StatelessWidget {
  final DocumentReportsController ctrl;
  final AppColorScheme colors;
  const _ExpiredTab({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    return HandlingDataRequest(
      statusRequest: ctrl.expiredStatus,
      onRetry: ctrl.loadExpired,
      widget: RefreshIndicator(
        onRefresh: ctrl.loadExpired,
        child: ctrl.expiredDocuments.isEmpty
            ? _EmptyState(
                icon: Icons.verified_outlined,
                message: 'no_expired_documents'.tr,
                colors: colors,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.s3),
                itemCount: ctrl.expiredDocuments.length,
                itemBuilder: (_, i) => _ReportRow(
                  row: ctrl.expiredDocuments[i],
                  colors: colors,
                  showExpiry: true,
                  accentColor: colors.error,
                ),
              ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final DocumentReportModel row;
  final AppColorScheme colors;
  final bool showExpiry;
  final Color? accentColor;
  const _ReportRow({
    required this.row,
    required this.colors,
    required this.showExpiry,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? colors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.description_outlined, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.documentName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.employeeName,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                if (row.branchName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.branchName!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showExpiry && row.expiresAt != null)
            Text(
              '${row.expiresAt!.year}-${row.expiresAt!.month.toString().padLeft(2, '0')}-${row.expiresAt!.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final AppColorScheme colors;
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSpacing.s7),
        Center(child: Icon(icon, size: 48, color: colors.success)),
        const SizedBox(height: AppSpacing.s3),
        Center(
          child: Text(
            message,
            style: AppTextStyles.bodySecondary(context),
          ),
        ),
      ],
    );
  }
}
