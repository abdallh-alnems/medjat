import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/theme/kiosk_theme.dart';
import '../logic/kiosk_controller.dart';

/// First screen a fresh tablet shows: type the pairing code from the management
/// app.
///
/// Also where a revoked tablet lands, which is why it explains itself rather
/// than just presenting a box — whoever finds this device may not know why it
/// stopped working.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _controller = TextEditingController();
  final _kiosk = Get.find<KioskController>();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await _kiosk.pair(code);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure == null ? null : _message(failure);
      if (failure == null) _controller.clear();
    });
  }

  /// The server sends a message key; the tablet renders the sentence. Keys are
  /// resolved here rather than shown raw because a worker reading
  /// `kiosk_pair_code_spent` off a wall learns nothing.
  String _message(String key) => switch (key) {
        'kiosk_pair_code_spent' =>
          'هذا الكود غير صالح أو تم استخدامه. اطلب كودًا جديدًا من تطبيق الإدارة.',
        'kiosk_pair_branch_disabled' =>
          'الكيوسك غير مفعّل على هذا الفرع. فعّله من إعدادات الفرع أولًا.',
        'kiosk_offline' =>
          'لا يوجد اتصال بالإنترنت. تأكد من الشبكة ثم حاول مرة أخرى.',
        _ => 'تعذّر ربط الجهاز. حاول مرة أخرى.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.tablet_android_rounded,
                      size: 96, color: KioskTheme.brand),
                  const SizedBox(height: 32),
                  Text('ربط جهاز الكيوسك',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Text(
                    'افتح تطبيق الإدارة ← الفرع ← إضافة كيوسك، ثم أدخل الكود الظاهر.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_busy,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                    inputFormatters: [
                      UpperCaseFormatter(),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX',
                      errorText: _error,
                      errorMaxLines: 3,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('ربط الجهاز'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Codes are generated from an unambiguous uppercase alphabet, so lowercase
/// input is a keyboard artefact rather than a different code.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
