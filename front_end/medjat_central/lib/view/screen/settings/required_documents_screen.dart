import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../data/model/required_document_model.dart';
import '../../../logic/controller/document/required_documents_controller.dart';

class RequiredDocumentsScreen extends StatelessWidget {
  const RequiredDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(RequiredDocumentsController());

    return Scaffold(
      appBar: AppBar(title: Text('document_required_types'.tr)),
      body: GetBuilder<RequiredDocumentsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadDocuments,
            widget: RefreshIndicator(
              onRefresh: ctrl.loadDocuments,
              child: ctrl.documents.isEmpty
                  ? Center(
                      child: Text('no_document_types'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4,
                        AppSpacing.s5,
                        AppSpacing.s4,
                        AppSpacing.s4,
                      ),
                      itemCount: ctrl.documents.length,
                      itemBuilder: (context, index) {
                        return _DocumentTypeTile(
                          doc: ctrl.documents[index],
                          onTap: () =>
                              _openSubmissions(ctrl.documents[index]),
                          onDetails: () => _showDocumentDetails(
                              context, ctrl, ctrl.documents[index]),
                          onToggle: () =>
                              ctrl.toggleActive(ctrl.documents[index].id),
                          onEdit: () =>
                              _showEditDialog(context, ctrl, ctrl.documents[index]),
                          onDelete: () =>
                              _confirmDelete(context, ctrl, ctrl.documents[index]),
                        );
                      },
                    ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_add_doc_type',
        onPressed: () => _showAddDialog(context, ctrl),
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDialog(BuildContext context, RequiredDocumentsController ctrl) {
    _showDocumentDialog(context, ctrl, null);
  }

  /// Opens the per-document-type submissions screen: who sent this document and
  /// who hasn't, with review / approve / reject from there.
  void _openSubmissions(RequiredDocumentModel doc) {
    Get.toNamed(AppRoutes.requiredDocumentSubmissions, arguments: {
      'required_document_id': doc.id,
      'document_name': doc.name,
    });
  }

  void _showEditDialog(BuildContext context, RequiredDocumentsController ctrl,
      RequiredDocumentModel doc) {
    _showDocumentDialog(context, ctrl, doc);
  }

  void _showDocumentDialog(BuildContext context,
      RequiredDocumentsController ctrl, RequiredDocumentModel? existing) {
    final isEdit = existing != null;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl =
        TextEditingController(text: existing?.description ?? '');
    final notifCtl = TextEditingController(
        text: (existing?.notificationDaysBefore ?? 30).toString());
    String category = existing?.category ?? 'general';
    String scopeType = existing?.scopeType ?? 'all';
    int? scopeBranchId = existing?.scopeBranchId;
    final Set<int> scopeEmployeeIds = {...(existing?.scopeEmployeeIds ?? const <int>[])};
    final Set<int> scopeCategoryIds = {...(existing?.scopeCategoryIds ?? const <int>[])};
    String employeeQuery = '';

    Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.s4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 480,
          ),
          child: StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
              final colors = AppColors.of(dialogCtx);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Text(
                      isEdit ? 'edit_document_type'.tr : 'add_document_type'.tr,
                      style: AppTextStyles.h3(dialogCtx),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, AppSpacing.s2, AppSpacing.s4, AppSpacing.s4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: nameCtl,
                            decoration: InputDecoration(
                              labelText: 'document_type_name'.tr,
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          TextField(
                            controller: descCtl,
                            decoration: InputDecoration(
                              labelText: 'description'.tr,
                              isDense: true,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: InputDecoration(
                              labelText: 'document_category'.tr,
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'identity',
                                  child: Text('category_identity'.tr)),
                              DropdownMenuItem(
                                  value: 'contract',
                                  child: Text('category_contract'.tr)),
                              DropdownMenuItem(
                                  value: 'certificate',
                                  child: Text('category_certificate'.tr)),
                              DropdownMenuItem(
                                  value: 'insurance',
                                  child: Text('category_insurance'.tr)),
                              DropdownMenuItem(
                                  value: 'general',
                                  child: Text('category_general'.tr)),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => category = v!),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          TextField(
                            controller: notifCtl,
                            decoration: InputDecoration(
                              labelText: 'notification_days_hint'.tr,
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.only(
                                top: AppSpacing.s2, bottom: AppSpacing.s2),
                            child: Text('document_scope'.tr,
                                style: AppTextStyles.h3(dialogCtx)),
                          ),
                          _ScopeOption(
                            label: 'doc_scope_all'.tr,
                            subtitle: 'doc_scope_all_hint'.tr,
                            value: 'all',
                            groupValue: scopeType,
                            onChanged: (v) =>
                                setDialogState(() => scopeType = v),
                            colors: colors,
                          ),
                          _ScopeOption(
                            label: 'doc_scope_branch'.tr,
                            subtitle: 'doc_scope_branch_hint'.tr,
                            value: 'branch',
                            groupValue: scopeType,
                            onChanged: (v) =>
                                setDialogState(() => scopeType = v),
                            colors: colors,
                          ),
                          if (scopeType == 'branch') ...[
                            const SizedBox(height: AppSpacing.s2),
                            DropdownButtonFormField<int>(
                              initialValue: scopeBranchId,
                              decoration: InputDecoration(
                                labelText: 'select_branch'.tr,
                                isDense: true,
                              ),
                              items: ctrl.branches
                                  .map((b) => DropdownMenuItem<int>(
                                      value: b.id, child: Text(b.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => scopeBranchId = v),
                            ),
                          ],
                          _ScopeOption(
                            label: 'doc_scope_employees'.tr,
                            subtitle: 'doc_scope_employees_hint'.tr,
                            value: 'employees',
                            groupValue: scopeType,
                            onChanged: (v) =>
                                setDialogState(() => scopeType = v),
                            colors: colors,
                          ),
                          if (scopeType == 'employees') ...[
                            const SizedBox(height: AppSpacing.s2),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'search_employee'.tr,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                isDense: true,
                              ),
                              onChanged: (v) => setDialogState(
                                  () => employeeQuery = v.trim().toLowerCase()),
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            Builder(
                              builder: (_) {
                                final filteredEmployees = employeeQuery.isEmpty
                                    ? ctrl.employees
                                    : ctrl.employees
                                        .where((e) =>
                                            e.name
                                                .toLowerCase()
                                                .contains(employeeQuery) ||
                                            (e.branchName
                                                    ?.toLowerCase()
                                                    .contains(employeeQuery) ??
                                                false))
                                        .toList();
                                return Container(
                              constraints:
                                  const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                border: Border.all(color: colors.borderHairline),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: ctrl.employees.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(
                                          AppSpacing.s3),
                                      child: Text(
                                        'no_employees'.tr,
                                        style: AppTextStyles.bodySecondary(
                                            dialogCtx),
                                      ),
                                    )
                                  : filteredEmployees.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(
                                          AppSpacing.s3),
                                      child: Text(
                                        'no_employees'.tr,
                                        style: AppTextStyles.bodySecondary(
                                            dialogCtx),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredEmployees.length,
                                      itemBuilder: (_, i) {
                                        final e = filteredEmployees[i];
                                        final checked =
                                            scopeEmployeeIds.contains(e.id);
                                        return CheckboxListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.s2),
                                          value: checked,
                                          onChanged: (v) =>
                                              setDialogState(() {
                                            if (v == true) {
                                              scopeEmployeeIds.add(e.id);
                                            } else {
                                              scopeEmployeeIds.remove(e.id);
                                            }
                                          }),
                                          title: Text(
                                            e.name,
                                            style: const TextStyle(
                                              fontFamily:
                                                  'IBM Plex Sans Arabic',
                                              fontSize: 13,
                                            ),
                                          ),
                                          subtitle: e.branchName != null
                                              ? Text(
                                                  e.branchName!,
                                                  style: AppTextStyles.sm(
                                                      dialogCtx),
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            Text(
                              '${scopeEmployeeIds.length} ${'selected_count'.tr}',
                              style: AppTextStyles.sm(dialogCtx),
                            ),
                          ],
                          _ScopeOption(
                            label: 'doc_scope_category'.tr,
                            subtitle: 'doc_scope_category_hint'.tr,
                            value: 'category',
                            groupValue: scopeType,
                            onChanged: (v) =>
                                setDialogState(() => scopeType = v),
                            colors: colors,
                          ),
                          if (scopeType == 'category') ...[
                            const SizedBox(height: AppSpacing.s2),
                            Container(
                              constraints:
                                  const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                border: Border.all(color: colors.borderHairline),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: ctrl.categories.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(
                                          AppSpacing.s3),
                                      child: Text(
                                        'no_categories'.tr,
                                        style: AppTextStyles.bodySecondary(
                                            dialogCtx),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: ctrl.categories.length,
                                      itemBuilder: (_, i) {
                                        final cat = ctrl.categories[i];
                                        final checked =
                                            scopeCategoryIds.contains(cat.id);
                                        return CheckboxListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.s2),
                                          value: checked,
                                          onChanged: (v) =>
                                              setDialogState(() {
                                            if (v == true) {
                                              scopeCategoryIds.add(cat.id);
                                            } else {
                                              scopeCategoryIds.remove(cat.id);
                                            }
                                          }),
                                          title: Text(
                                            cat.name,
                                            style: const TextStyle(
                                              fontFamily:
                                                  'IBM Plex Sans Arabic',
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            Text(
                              '${scopeCategoryIds.length} ${'selected_count'.tr}',
                              style: AppTextStyles.sm(dialogCtx),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Get.back<void>(),
                          child: Text('cancel'.tr),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        ElevatedButton(
                          // The global theme makes ElevatedButton full-width
                          // (Size.fromHeight → infinite width); override so it
                          // sizes to content inside this end-aligned Row.
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () {
                            if (nameCtl.text.trim().isEmpty) {
                              Get.snackbar(
                                  'error'.tr, 'document_type_name'.tr,
                                  snackPosition: SnackPosition.BOTTOM);
                              return;
                            }
                            if (scopeType == 'branch' && scopeBranchId == null) {
                              Get.snackbar(
                                  'error'.tr, 'select_branch'.tr,
                                  snackPosition: SnackPosition.BOTTOM);
                              return;
                            }
                            if (scopeType == 'employees' &&
                                scopeEmployeeIds.isEmpty) {
                              Get.snackbar(
                                  'error'.tr, 'select_employees'.tr,
                                  snackPosition: SnackPosition.BOTTOM);
                              return;
                            }
                            if (scopeType == 'category' &&
                                scopeCategoryIds.isEmpty) {
                              Get.snackbar(
                                  'error'.tr, 'select_categories'.tr,
                                  snackPosition: SnackPosition.BOTTOM);
                              return;
                            }
                            final doc = RequiredDocumentModel(
                              id: existing?.id ?? 0,
                              name: nameCtl.text.trim(),
                              description: descCtl.text.trim().isEmpty
                                  ? null
                                  : descCtl.text.trim(),
                              // Expiry date is set manually per uploaded
                              // document, so this type-level field is no longer
                              // edited here; preserve any existing value.
                              expiryDays: existing?.expiryDays,
                              notificationDaysBefore:
                                  int.tryParse(notifCtl.text.trim()) ?? 30,
                              category: category,
                              // All document types are mandatory by design
                              // (model defaults isRequired to true).
                              scopeType: scopeType,
                              scopeBranchId: scopeType == 'branch'
                                  ? scopeBranchId
                                  : null,
                              scopeEmployeeIds: scopeType == 'employees'
                                  ? scopeEmployeeIds.toList()
                                  : const [],
                              scopeCategoryIds: scopeType == 'category'
                                  ? scopeCategoryIds.toList()
                                  : const [],
                            );
                            if (isEdit) {
                              ctrl.updateDocument(doc);
                            } else {
                              ctrl.createDocument(doc);
                            }
                            Get.back<void>();
                          },
                          child: Text('save'.tr),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDocumentDetails(BuildContext context,
      RequiredDocumentsController ctrl, RequiredDocumentModel doc) {
    final colors = AppColors.of(context);

    String categoryLabel() {
      switch (doc.category) {
        case 'identity':
          return 'category_identity'.tr;
        case 'contract':
          return 'category_contract'.tr;
        case 'certificate':
          return 'category_certificate'.tr;
        case 'insurance':
          return 'category_insurance'.tr;
        default:
          return 'category_general'.tr;
      }
    }

    // Resolve the scope into a human-readable heading + list of names.
    String scopeHeading;
    List<String> scopeNames;
    switch (doc.scopeType) {
      case 'branch':
        scopeHeading = 'doc_scope_branch'.tr;
        final branch = ctrl.branches
            .firstWhereOrNull((b) => b.id == doc.scopeBranchId);
        scopeNames = branch != null ? [branch.name] : [];
        break;
      case 'employees':
        scopeHeading = 'doc_scope_employees'.tr;
        scopeNames = doc.scopeEmployeeNames;
        break;
      case 'category':
        scopeHeading = 'doc_scope_category'.tr;
        scopeNames = doc.scopeCategoryNames;
        break;
      default:
        scopeHeading = 'doc_scope_all'.tr;
        scopeNames = [];
    }

    Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.s4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 480,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Text(doc.name, style: AppTextStyles.h3(context)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (doc.description != null &&
                          doc.description!.isNotEmpty) ...[
                        Text(doc.description!,
                            style: AppTextStyles.bodySecondary(context)),
                        const SizedBox(height: AppSpacing.s3),
                      ],
                      _detailRow('document_category'.tr, categoryLabel()),
                      _detailRow('notification_days_hint'.tr,
                          '${doc.notificationDaysBefore}'),
                      const Divider(height: AppSpacing.s4),
                      Text('document_scope'.tr,
                          style: AppTextStyles.h3(context)),
                      const SizedBox(height: AppSpacing.s1),
                      Row(
                        children: [
                          Icon(_scopeIconFor(doc.scopeType),
                              size: 16, color: colors.brand),
                          const SizedBox(width: AppSpacing.s2),
                          Text(scopeHeading,
                              style: AppTextStyles.body(context)),
                        ],
                      ),
                      if (doc.scopeType == 'all')
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s2),
                          child: Text('doc_scope_all_hint'.tr,
                              style: AppTextStyles.sm(context)),
                        )
                      else if (scopeNames.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s2),
                          child: Text('no_employees'.tr,
                              style: AppTextStyles.sm(context)),
                        )
                      else
                        ...scopeNames.map((n) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16),
                                  const SizedBox(width: AppSpacing.s2),
                                  Expanded(
                                    child: Text(n,
                                        style: AppTextStyles.body(context)),
                                  ),
                                ],
                              ),
                            )),
                      const SizedBox(height: AppSpacing.s4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: Text('close'.tr),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Get.back<void>();
                        _showEditDialog(context, ctrl, doc);
                      },
                      child: Text('update'.tr),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: AppTextStyles.sm(context)),
            ),
            Expanded(
              child: Text(value, style: AppTextStyles.body(context)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _scopeIconFor(String scope) {
    switch (scope) {
      case 'branch':
        return Icons.account_tree_outlined;
      case 'employees':
        return Icons.people_outline;
      case 'category':
        return Icons.category_outlined;
      default:
        return Icons.public;
    }
  }

  void _confirmDelete(BuildContext context, RequiredDocumentsController ctrl,
      RequiredDocumentModel doc) {
    Get.defaultDialog(
      title: 'confirm_delete'.tr,
      middleText: doc.name,
      textConfirm: 'delete'.tr,
      textCancel: 'cancel'.tr,
      buttonColor: AppColors.of(context).error,
      confirmTextColor: Colors.white,
      onConfirm: () {
        ctrl.deleteDocument(doc.id);
        Get.back();
      },
    );
  }
}

class _DocumentTypeTile extends StatelessWidget {
  final RequiredDocumentModel doc;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DocumentTypeTile({
    required this.doc,
    required this.onTap,
    required this.onDetails,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (doc.description != null && doc.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    doc.description!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_scopeIcon(doc.scopeType), size: 12, color: colors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _scopeLabel(doc),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: doc.isActive,
            onChanged: (_) => onToggle(),
            activeColor: colors.brand,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'details') onDetails();
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'details', child: Text('details'.tr)),
              PopupMenuItem(value: 'edit', child: Text('update'.tr)),
              PopupMenuItem(
                value: 'delete',
                child: Text('delete'.tr,
                    style: TextStyle(color: colors.error)),
              ),
            ],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      ),
    );
  }

  IconData _scopeIcon(String scope) {
    switch (scope) {
      case 'branch':
        return Icons.account_tree_outlined;
      case 'employees':
        return Icons.people_outline;
      case 'category':
        return Icons.category_outlined;
      default:
        return Icons.public;
    }
  }

  String _scopeLabel(RequiredDocumentModel d) {
    switch (d.scopeType) {
      case 'branch':
        return 'doc_scope_branch'.tr;
      case 'employees':
        return '${'doc_scope_employees'.tr} (${d.scopeEmployeeIds.length})';
      case 'category':
        return '${'doc_scope_category'.tr} (${d.scopeCategoryIds.length})';
      default:
        return 'doc_scope_all'.tr;
    }
  }
}

class _ScopeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;
  final AppColorScheme colors;

  const _ScopeOption({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s2),
        padding: const EdgeInsets.all(AppSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? colors.brand : colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          selected ? colors.brand : colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
