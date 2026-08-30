import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/kiosk_theme.dart';
import '../logic/identify_controller.dart';

/// The personal-code keypad — the fallback for the day a face will not resolve.
///
/// An on-screen keypad rather than the system keyboard: a wall-mounted tablet in
/// immersive mode should never summon an OS surface an employee could swipe out
/// of, and 72dp keys are usable with gloves and wet hands, which the system
/// keyboard is not.
///
/// Digits are masked. The person typing is standing in a queue.
class CodeEntryView extends StatefulWidget {
  const CodeEntryView({super.key, required this.controller});

  final IdentifyController controller;

  @override
  State<CodeEntryView> createState() => _CodeEntryViewState();
}

class _CodeEntryViewState extends State<CodeEntryView> {
  static const _length = 6;
  String _code = '';

  void _press(String digit) {
    if (_code.length >= _length) return;
    setState(() => _code += digit);

    if (_code.length == _length) {
      // Submit on the last digit: asking for a confirm tap after six digits is
      // a step that earns nothing.
      widget.controller.submitCode(_code);
      _code = '';
    }
  }

  void _backspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text('أدخل رمزك الشخصي', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Obx(() {
            final error = widget.controller.messageAr.value;
            return SizedBox(
              height: 32,
              child: error.isEmpty
                  ? null
                  : Text(error,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: KioskTheme.danger)),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_length, (i) {
              final filled = i < _code.length;
              return Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? KioskTheme.brand : Colors.transparent,
                  border: Border.all(color: KioskTheme.brand, width: 2),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var d = 1; d <= 9; d++) _Key(label: '$d', onTap: () => _press('$d')),
                _Key(icon: Icons.close_rounded, onTap: widget.controller.cancel),
                _Key(label: '0', onTap: () => _press('0')),
                _Key(icon: Icons.backspace_outlined, onTap: _backspace),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 32)
              : Text(label!,
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
