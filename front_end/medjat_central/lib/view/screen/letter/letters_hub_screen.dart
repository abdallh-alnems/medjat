import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../logic/controller/letter/letter_request_controller.dart';
import '../../../logic/controller/letter/letter_template_controller.dart';
import '../../../data/model/document_request_model.dart';
import '../../../data/model/document_template_model.dart';
import '../../../data/model/employee_model.dart';

class LettersHubScreen extends StatelessWidget {
  const LettersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requestCtrl = Get.find<LetterRequestController>();
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('letters'.tr),
          bottom: TabBar(
            tabs: [
              Tab(text: 'letter_requests'.tr),
              Tab(text: 'letter_templates'.tr),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_letter',
          backgroundColor: colors.brand,
          onPressed: () => _showIssueSheet(context, requestCtrl),
          icon: const Icon(Icons.note_add_outlined, color: Colors.white),
          label: Text('letter_issue'.tr,
              style: const TextStyle(color: Colors.white)),
        ),
        body: const TabBarView(
          children: [
            _RequestsTab(),
            _TemplatesTab(),
          ],
        ),
      ),
    );
  }

  void _showIssueSheet(BuildContext context, LetterRequestController ctrl) {
    final templateCtrl = Get.find<LetterTemplateController>();
    ctrl.loadEmployees();

    int? employeeId;
    int? templateId;
    final bankCtrl = TextEditingController();
    final addressedCtrl = TextEditingController();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheet) {
          final colors = AppColors.of(context);
          DocumentTemplateModel? selectedTemplate;
          for (final t in templateCtrl.activeTemplates) {
            if (t.id == templateId) {
              selectedTemplate = t;
              break;
            }
          }
          final needsBank = selectedTemplate?.needsBankName ?? false;

          return Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('letter_issue_title'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  _label('select_employee'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  GetBuilder<LetterRequestController>(
                    builder: (_) {
                      if (ctrl.employeesLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.s3),
                          child: Center(
                              child: CircularProgressIndicator.adaptive()),
                        );
                      }
                      return _dropdown<int>(
                        hint: 'select_employee'.tr,
                        value: employeeId,
                        colors: colors,
                        items: ctrl.employees
                            .map((EmployeeModel e) => DropdownMenuItem<int>(
                                  value: e.id,
                                  child: Text(e.name,
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 14,
                                      )),
                                ))
                            .toList(),
                        onChanged: (v) => setSheet(() => employeeId = v),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _label('letter_template'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  GetBuilder<LetterTemplateController>(
                    builder: (_) => _dropdown<int>(
                      hint: 'letter_template'.tr,
                      value: templateId,
                      colors: colors,
                      items: templateCtrl.activeTemplates
                          .map((t) => DropdownMenuItem<int>(
                                value: t.id,
                                child: Text(t.displayName,
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                    )),
                              ))
                          .toList(),
                      onChanged: (v) => setSheet(() => templateId = v),
                    ),
                  ),
                  if (needsBank) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _label('letter_bank_name'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _textField(bankCtrl, 'letter_bank_name'.tr, colors),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  _label('letter_addressed_to'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  _textField(addressedCtrl, 'letter_addressed_to_hint'.tr, colors),
                  const SizedBox(height: AppSpacing.s4),
                  GetBuilder<LetterRequestController>(
                    builder: (_) => PrimaryButton(
                      text: 'letter_issue'.tr,
                      isLoading: ctrl.actionLoading,
                      onPressed: () async {
                        if (employeeId == null || templateId == null) {
                          Get.snackbar('error'.tr, 'letter_select_required'.tr,
                              snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        final extra = <String, String>{};
                        if (bankCtrl.text.trim().isNotEmpty) {
                          extra['bank_name'] = bankCtrl.text.trim();
                        }
                        if (addressedCtrl.text.trim().isNotEmpty) {
                          extra['addressed_to'] = addressedCtrl.text.trim();
                        }
                        final ok = await ctrl.issueDocument(
                          employeeId: employeeId!,
                          templateId: templateId!,
                          extraFields: extra.isEmpty ? null : extra,
                        );
                        if (ok) Get.back<void>();
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  static Widget _label(String text, AppColorScheme colors) => Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      );

  static Widget _textField(
      TextEditingController c, String hint, AppColorScheme colors) {
    return TextField(
      controller: c,
      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 14,
          color: colors.textTertiary,
        ),
        filled: true,
        fillColor: colors.sunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colors.borderHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colors.borderHairline),
        ),
      ),
    );
  }

  static Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required AppColorScheme colors,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              )),
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<LetterRequestController>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
          child: GetBuilder<LetterRequestController>(
            builder: (_) => Row(
              children: [
                _Chip(
                    label: 'all'.tr,
                    selected: ctrl.statusFilter == null,
                    onTap: () => ctrl.filterByStatus(null)),
                const SizedBox(width: AppSpacing.s2),
                _Chip(
                    label: 'status_pending'.tr,
                    selected: ctrl.statusFilter == 'pending',
                    onTap: () => ctrl.filterByStatus('pending')),
                const SizedBox(width: AppSpacing.s2),
                _Chip(
                    label: 'status_approved'.tr,
                    selected: ctrl.statusFilter == 'approved',
                    onTap: () => ctrl.filterByStatus('approved')),
                const SizedBox(width: AppSpacing.s2),
                _Chip(
                    label: 'status_rejected'.tr,
                    selected: ctrl.statusFilter == 'rejected',
                    onTap: () => ctrl.filterByStatus('rejected')),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ctrl.loadRequests,
            child: GetBuilder<LetterRequestController>(
              builder: (_) => HandlingDataRequest(
                statusRequest: ctrl.status,
                onRetry: ctrl.loadRequests,
                widget: ctrl.requests.isEmpty
                    ? _empty(context, Icons.description_outlined,
                        'letter_no_requests'.tr)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s4, 0,
                            AppSpacing.s4, AppSpacing.s7),
                        itemCount: ctrl.requests.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.s2),
                        itemBuilder: (_, i) => _RequestTile(
                          request: ctrl.requests[i],
                          onApprove: () => ctrl.approveRequest(ctrl.requests[i].id),
                          onReject: () =>
                              _rejectDialog(context, ctrl, ctrl.requests[i].id),
                          onOpen: () => ctrl.openPdf(ctrl.requests[i]),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _rejectDialog(
      BuildContext context, LetterRequestController ctrl, int id) {
    final reasonCtrl = TextEditingController();
    final colors = AppColors.of(context);
    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('letter_reject'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'rejection_reason'.tr,
              hintStyle: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textTertiary),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.rejectRequest(id,
                    reason: reasonCtrl.text.trim().isNotEmpty
                        ? reasonCtrl.text.trim()
                        : null);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('reject'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<LetterTemplateController>();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: ctrl.loadTemplates,
          child: GetBuilder<LetterTemplateController>(
            builder: (_) => HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadTemplates,
              widget: ctrl.templates.isEmpty
                  ? _empty(context, Icons.article_outlined,
                      'letter_no_templates'.tr)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, 96),
                      itemCount: ctrl.templates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (_, i) => _TemplateTile(
                        template: ctrl.templates[i],
                        onEdit: () => Get.toNamed<void>(
                            AppRoutes.letterTemplateEdit,
                            arguments: ctrl.templates[i]),
                        onToggle: () => ctrl.toggleActive(ctrl.templates[i]),
                        onDelete: () => ctrl.deleteTemplate(ctrl.templates[i]),
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.s4,
          bottom: AppSpacing.s4,
          child: FloatingActionButton(
            heroTag: 'fab_template',
            backgroundColor: AppColors.of(context).brand,
            onPressed: () => Get.toNamed<void>(AppRoutes.letterTemplateEdit),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

Widget _empty(BuildContext context, IconData icon, String text) {
  final colors = AppColors.of(context);
  return ListView(
    children: [
      const SizedBox(height: 120),
      Icon(icon, size: 48, color: colors.textTertiary),
      const SizedBox(height: AppSpacing.s3),
      Center(child: Text(text, style: AppTextStyles.bodySecondary(context))),
    ],
  );
}

class _RequestTile extends StatelessWidget {
  final DocumentRequestModel request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpen;

  const _RequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(request.status, colors);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.employeeName ?? 'employee'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  request.statusLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 14, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  request.documentName,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (request.requestedByEmployee)
                Text('letter_from_employee'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    )),
            ],
          ),
          if (request.status == 'rejected' &&
              (request.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(request.rejectionReason!,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: colors.error,
                      )),
                ),
              ],
            ),
          ],
          if (request.status == 'pending') ...[
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onApprove,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40)),
                    child: Text('letter_approve_issue'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        minimumSize: const Size.fromHeight(40)),
                    child: Text('reject'.tr),
                  ),
                ),
              ],
            ),
          ],
          if (request.status == 'approved' && request.hasPdf) ...[
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40)),
                label: Text('letter_view_pdf'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'pending':
        return colors.warning;
      case 'approved':
        return colors.success;
      case 'rejected':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }
}

class _TemplateTile extends StatelessWidget {
  final DocumentTemplateModel template;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TemplateTile({
    required this.template,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.displayName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (template.isSystem)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                  decoration: BoxDecoration(
                    color: colors.brandSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('letter_system_template'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 10,
                        color: colors.brand,
                      )),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            template.bodyAr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sm(context),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('edit'.tr),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(template.isActive ? 'active'.tr : 'inactive'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: colors.textTertiary,
                      )),
                  Switch.adaptive(
                    value: template.isActive,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
              if (!template.isSystem)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: colors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: selected ? colors.brand : colors.borderHairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
