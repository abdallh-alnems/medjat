import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constant/theme/app_colors.dart';
import '../../constant/theme/app_spacing.dart';

class PrimaryInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  // Shows an "optional" tag next to the label for non-required fields.
  final bool optional;

  const PrimaryInput({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.04,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (optional) ...[
                const SizedBox(width: AppSpacing.s1),
                Text(
                  '(${'optional'.tr})',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          textDirection:
              keyboardType == TextInputType.emailAddress ||
                  keyboardType == TextInputType.number
              ? TextDirection.ltr
              : TextDirection.rtl,
          style: TextStyle(
            fontFamily: keyboardType == TextInputType.emailAddress
                ? 'Geist'
                : 'IBM Plex Sans Arabic',
            fontSize: 16,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}
