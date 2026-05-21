import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../data/model/employee_category_model.dart';
import '../../../logic/controller/category/category_controller.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CategoryController());

    return Scaffold(
      appBar: AppBar(title: Text('employee_categories'.tr)),
      body: GetBuilder<CategoryController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadCategories,
            widget: RefreshIndicator(
              onRefresh: ctrl.loadCategories,
              child: ctrl.categories.isEmpty
                  ? Center(
                      child: Text('no_categories'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      itemCount: ctrl.categories.length,
                      itemBuilder: (context, index) {
                        return _CategoryTile(
                          cat: ctrl.categories[index],
                          onEdit: () => _showEditDialog(
                              context, ctrl, ctrl.categories[index]),
                          onDelete: () =>
                              _confirmDelete(context, ctrl, ctrl.categories[index]),
                        );
                      },
                    ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_add_category',
        onPressed: () => _showAddDialog(context, ctrl),
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDialog(BuildContext context, CategoryController ctrl) {
    _showCategoryDialog(context, ctrl, null);
  }

  void _showEditDialog(
      BuildContext context, CategoryController ctrl, EmployeeCategoryModel cat) {
    _showCategoryDialog(context, ctrl, cat);
  }

  void _showCategoryDialog(BuildContext context, CategoryController ctrl,
      EmployeeCategoryModel? existing) {
    final isEdit = existing != null;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final colorCtl = TextEditingController(text: existing?.color ?? '');

    Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.s4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: 480,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Text(
                  isEdit ? 'edit_category'.tr : 'add_category'.tr,
                  style: AppTextStyles.h3(context),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtl,
                        decoration: InputDecoration(
                          labelText: 'category_name'.tr,
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
                      TextField(
                        controller: colorCtl,
                        decoration: InputDecoration(
                          labelText: 'category_color_hint'.tr,
                          isDense: true,
                          prefixIcon: Icon(Icons.color_lens_outlined,
                              size: 20,
                              color: _parseColor(colorCtl.text)),
                        ),
                      ),
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
                      onPressed: () {
                        if (nameCtl.text.trim().isEmpty) return;
                        final cat = EmployeeCategoryModel(
                          id: existing?.id ?? 0,
                          name: nameCtl.text.trim(),
                          description: descCtl.text.trim().isEmpty
                              ? null
                              : descCtl.text.trim(),
                          color: colorCtl.text.trim().isEmpty
                              ? null
                              : colorCtl.text.trim(),
                        );
                        if (isEdit) {
                          ctrl.updateCategory(cat);
                        } else {
                          ctrl.createCategory(cat);
                        }
                        Get.back<void>();
                      },
                      child: Text('save'.tr),
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

  void _confirmDelete(BuildContext context, CategoryController ctrl,
      EmployeeCategoryModel cat) {
    Get.defaultDialog(
      title: 'confirm_delete'.tr,
      middleText: cat.name,
      textConfirm: 'delete'.tr,
      textCancel: 'cancel'.tr,
      buttonColor: AppColors.of(context).error,
      confirmTextColor: Colors.white,
      onConfirm: () {
        ctrl.deleteCategory(cat.id);
        Get.back();
      },
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return HexColor.fromHex(hex);
    } catch (_) {
      return null;
    }
  }
}

class HexColor extends Color {
  HexColor._(int value) : super(value);
  static Color? fromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final val = int.tryParse(hex, radix: 16);
    if (val == null) return null;
    return Color(val);
  }
}

class _CategoryTile extends StatelessWidget {
  final EmployeeCategoryModel cat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.cat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
          if (cat.color != null && cat.color!.isNotEmpty)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: AppSpacing.s2, right: AppSpacing.s2),
              decoration: BoxDecoration(
                color: _parseColor(cat.color) ?? colors.brand,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (cat.description != null &&
                    cat.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    cat.description!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${cat.employeeCount} ${'employees_count'.tr}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
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
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return HexColor.fromHex(hex);
    } catch (_) {
      return null;
    }
  }
}
