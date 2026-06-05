import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/class/status_request.dart';
import '../../../logic/controller/export_template/export_template_controller.dart';

class ExportTemplatesScreen extends StatelessWidget {
  const ExportTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ExportTemplateController>();
    return Scaffold(
      appBar: AppBar(title: Text('export_templates'.tr)),
      body: GetBuilder<ExportTemplateController>(
        builder: (_) {
          if (ctrl.status == StatusRequest.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.templates.isEmpty) {
            return Center(
              child: Text('export_template_no_templates'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    color: AppColors.of(context).textTertiary,
                  )),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s4),
            itemCount: ctrl.templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s2),
            itemBuilder: (context, index) {
              final tpl = ctrl.templates[index];
              final cols = (tpl['columns'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final colSummary = cols.map((c) => c['label'] ?? '').join(' / ');
              return _TemplateCard(
                template: tpl,
                colSummary: colSummary,
                onEdit: () => _showEditor(context, ctrl, existing: tpl),
                onDelete: () => _confirmDelete(context, ctrl, tpl),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ctrl),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ExportTemplateController ctrl, Map<String, dynamic> tpl) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('delete'.tr),
        content: Text('export_template_delete_confirm'.tr),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
          ElevatedButton(
            onPressed: () async {
              Get.back<void>();
              final ok = await ctrl.deleteTemplate(tpl['id'] as int);
              if (ok) {
                Get.snackbar('done'.tr, 'export_template_deleted'.tr,
                    snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  void _showEditor(BuildContext context, ExportTemplateController ctrl,
      {Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtl = TextEditingController(text: existing?['name']?.toString() ?? '');
    var delimiter = existing?['delimiter']?.toString() ?? ',';
    var includeBom = (existing?['include_bom'] ?? 1) == 1;
    var includeHeader = (existing?['include_header_row'] ?? 1) == 1;
    var decimalPlaces = (existing?['decimal_places'] ?? 2) as int;
    var columns = <Map<String, String>>[];

    if (existing != null) {
      final rawCols = existing['columns'] as List?;
      if (rawCols != null) {
        for (final c in rawCols) {
          if (c is Map) {
            columns.add({
              'label': (c['label'] ?? '').toString(),
              'field': (c['field'] ?? '').toString(),
            });
          }
        }
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'export_template_edit'.tr : 'export_template_new'.tr,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameCtl,
                            decoration: InputDecoration(
                              labelText: 'export_template_name'.tr,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          DropdownButtonFormField<String>(
                            value: delimiter,
                            decoration: InputDecoration(
                              labelText: 'export_template_delimiter'.tr,
                              border: const OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: ',', child: Text(', (comma)')),
                              DropdownMenuItem(value: ';', child: Text('; (semicolon)')),
                              DropdownMenuItem(value: '|', child: Text('| (pipe)')),
                              DropdownMenuItem(value: '\t', child: Text('TAB')),
                            ],
                            onChanged: (v) => setModalState(() => delimiter = v ?? ','),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile(
                                  title: Text('export_template_bom'.tr,
                                      style: const TextStyle(
                                          fontFamily: 'IBM Plex Sans Arabic',
                                          fontSize: 13)),
                                  value: includeBom,
                                  onChanged: (v) =>
                                      setModalState(() => includeBom = v),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            title: Text('export_template_header_row'.tr,
                                style: const TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 13)),
                            value: includeHeader,
                            onChanged: (v) =>
                                setModalState(() => includeHeader = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Row(
                            children: [
                              Text('export_template_decimal_places'.tr,
                                  style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 13)),
                              const SizedBox(width: AppSpacing.s3),
                              DropdownButton<int>(
                                value: decimalPlaces,
                                items: [0, 1, 2, 3, 4]
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text('$v')))
                                    .toList(),
                                onChanged: (v) =>
                                    setModalState(() => decimalPlaces = v ?? 2),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Row(
                            children: [
                              Text('export_template_columns'.tr,
                                  style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setModalState(() {
                                    columns.add({'label': '', 'field': ''});
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          ...List.generate(columns.length, (i) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.s2),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: TextEditingController(
                                          text: columns[i]['label']),
                                      decoration: InputDecoration(
                                        labelText:
                                            'export_template_column_label'.tr,
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (v) =>
                                          columns[i]['label'] = v,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s2),
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: columns[i]['field']!.isEmpty
                                          ? null
                                          : columns[i]['field'],
                                      decoration: InputDecoration(
                                        labelText:
                                            'export_template_column_field'.tr,
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: ctrl.fields.map((f) {
                                        return DropdownMenuItem(
                                          value: f['key'] as String,
                                          child: Text(f['label'] as String,
                                              overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          columns[i]['field'] = v;
                                          if (columns[i]['label']!.isEmpty) {
                                            final field = ctrl.fields.firstWhere(
                                                (f) => f['key'] == v,
                                                orElse: () => <String, dynamic>{});
                                            columns[i]['label'] =
                                                (field['label'] ?? '') as String;
                                          }
                                          setModalState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    onPressed: () {
                                      setModalState(() => columns.removeAt(i));
                                    },
                                  ),
                                  if (i > 0)
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward,
                                          size: 18),
                                      onPressed: () {
                                        setModalState(() {
                                          final item = columns.removeAt(i);
                                          columns.insert(i - 1, item);
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: AppSpacing.s5),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final name = nameCtl.text.trim();
                                if (name.isEmpty || columns.isEmpty) return;
                                for (final c in columns) {
                                  if (c['label']!.isEmpty ||
                                      c['field']!.isEmpty) return;
                                }
                                final cols = columns
                                    .where((c) =>
                                        c['label']!.isNotEmpty &&
                                        c['field']!.isNotEmpty)
                                    .toList();
                                bool ok;
                                if (isEdit) {
                                  ok = await ctrl.updateTemplate(
                                    id: existing!['id'] as int,
                                    name: name,
                                    delimiter: delimiter,
                                    includeBom: includeBom ? 1 : 0,
                                    includeHeaderRow: includeHeader ? 1 : 0,
                                    decimalPlaces: decimalPlaces,
                                    columns: cols,
                                  );
                                } else {
                                  ok = await ctrl.createTemplate(
                                    name: name,
                                    delimiter: delimiter,
                                    includeBom: includeBom ? 1 : 0,
                                    includeHeaderRow: includeHeader ? 1 : 0,
                                    decimalPlaces: decimalPlaces,
                                    columns: cols,
                                  );
                                }
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                Get.snackbar(
                                    'done'.tr,
                                    isEdit
                                        ? 'export_template_updated'.tr
                                        : 'export_template_created'.tr,
                                    snackPosition: SnackPosition.BOTTOM);
                              },
                              child: Text('save'.tr,
                                  style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final String colSummary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.colSummary,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: colors.error),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (colSummary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s1),
                child: Text(
                  colSummary,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              children: [
                _chip('${template['delimiter'] == '\t' ? 'TAB' : template['delimiter']}', colors),
                _chip('BOM: ${(template['include_bom'] ?? 1) == 1 ? '✓' : '✗'}', colors),
                _chip('Header: ${(template['include_header_row'] ?? 1) == 1 ? '✓' : '✗'}', colors),
                _chip('Dec: ${template['decimal_places'] ?? 2}', colors),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 11,
            color: colors.textSecondary,
          )),
    );
  }
}
