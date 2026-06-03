import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../logic/controller/support/support_controller.dart';

const _categories = [
  'technical',
  'billing',
  'feature_request',
  'account',
  'other',
];

const _priorities = [
  'low',
  'normal',
  'high',
  'urgent',
];

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _category = 'other';
  String _priority = 'normal';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('new_support_ticket'.tr)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            TextFormField(
              controller: _subjectCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'ticket_subject'.tr,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'enter_subject'.tr;
                if (v.trim().length < 3) return 'subject_min_length'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'ticket_category'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: _categories.map((cat) {
                final isSelected = _category == cat;
                return ChoiceChip(
                  label: Text(
                    'ticket_category_$cat'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: colors.brandSubtle,
                  side: BorderSide(
                    color: isSelected
                        ? colors.brand
                        : colors.borderHairline,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'ticket_priority'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: _priorities.map((p) {
                final isSelected = _priority == p;
                return ChoiceChip(
                  label: Text(
                    'ticket_priority_$p'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _priority = p),
                  selectedColor: colors.brandSubtle,
                  side: BorderSide(
                    color: isSelected
                        ? colors.brand
                        : colors.borderHairline,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'ticket_first_message'.tr,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'enter_message'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s5),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'create_ticket'.tr,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final controller = Get.find<SupportController>();
    final success = await controller.createTicket(
      subject: _subjectCtrl.text.trim(),
      category: _category,
      priority: _priority,
      body: _bodyCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Get.back<void>();
      Get.snackbar(
        'ticket_created'.tr,
        'ticket_created_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
