import 'package:flutter/material.dart';
import '../../constant/theme/app_colors.dart';
import 'primary_input.dart';

class PasswordInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PasswordInput({
    super.key,
    this.label = 'كلمة السر',
    this.hint,
    required this.controller,
    this.validator,
    this.onChanged,
  });

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return PrimaryInput(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      onChanged: widget.onChanged,
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: Theme.of(context).brightness == Brightness.light
              ? AppColors.light.textTertiary
              : AppColors.dark.textTertiary,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
