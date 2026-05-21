import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../logic/controller/letter/letter_template_controller.dart';
import '../../../data/model/document_template_model.dart';

class LetterTemplateEditScreen extends StatefulWidget {
  const LetterTemplateEditScreen({super.key});

  @override
  State<LetterTemplateEditScreen> createState() =>
      _LetterTemplateEditScreenState();
}

class _LetterTemplateEditScreenState extends State<LetterTemplateEditScreen> {
  final LetterTemplateController _ctrl = Get.find<LetterTemplateController>();
  late final DocumentTemplateModel? _existing;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bodyCtrl;
  bool _isActive = true;
  bool _saving = false;

  /// Fallback variable list if the server list hasn't loaded.
  static const _fallbackVars = [
    'employee_name', 'job_title', 'national_id', 'hire_date', 'branch_name',
    'base_salary', 'currency', 'company_name', 'commercial_register',
    'date_today', 'bank_name', 'addressed_to',
  ];

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    _existing = arg is DocumentTemplateModel ? arg : null;
    _nameCtrl = TextEditingController(text: _existing?.nameAr ?? '');
    _bodyCtrl = TextEditingController(text: _existing?.bodyAr ?? '');
    _isActive = _existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _insertVariable(String name) {
    final token = '{{$name}}';
    final selection = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (selection.isValid && selection.start >= 0) {
      final newText =
          text.replaceRange(selection.start, selection.end, token);
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: selection.start + token.length),
      );
    } else {
      _bodyCtrl.text = text + token;
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'letter_template_required'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _saving = true);
    final ok = await _ctrl.saveTemplate(
      id: _existing?.id,
      nameAr: _nameCtrl.text.trim(),
      bodyAr: _bodyCtrl.text.trim(),
      isActive: _isActive,
    );
    if (mounted) setState(() => _saving = false);
    if (ok) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final vars = _ctrl.variables.isNotEmpty ? _ctrl.variables : _fallbackVars;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null
            ? 'letter_template_new'.tr
            : 'letter_template_edit'.tr),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('letter_template_name'.tr, colors),
            const SizedBox(height: AppSpacing.s2),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
              decoration: _decoration(colors, 'letter_template_name'.tr),
            ),
            const SizedBox(height: AppSpacing.s4),
            _label('letter_template_body'.tr, colors),
            const SizedBox(height: AppSpacing.s1),
            Text('letter_template_body_hint'.tr,
                style: AppTextStyles.xs(context)),
            const SizedBox(height: AppSpacing.s2),
            TextField(
              controller: _bodyCtrl,
              maxLines: 10,
              minLines: 6,
              style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, height: 1.7),
              decoration: _decoration(colors, 'letter_template_body'.tr),
            ),
            const SizedBox(height: AppSpacing.s3),
            _label('letter_variables'.tr, colors),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: vars
                  .map((v) => ActionChip(
                        label: Text('{{$v}}',
                            style: const TextStyle(
                                fontFamily: 'Geist', fontSize: 12)),
                        backgroundColor: colors.sunken,
                        side: BorderSide(color: colors.borderHairline),
                        onPressed: () => _insertVariable(v),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Text('active'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      color: colors.textSecondary,
                    )),
                const Spacer(),
                Switch.adaptive(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            PrimaryButton(
              text: 'save'.tr,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, AppColorScheme colors) => Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      );

  InputDecoration _decoration(AppColorScheme colors, String hint) =>
      InputDecoration(
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colors.brand),
        ),
      );
}
