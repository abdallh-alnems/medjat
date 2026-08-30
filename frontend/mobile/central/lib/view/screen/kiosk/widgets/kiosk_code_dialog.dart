import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Shows a code that exists exactly once.
///
/// Both kiosk codes — pairing and access — are returned in plaintext by the
/// server and stored only as hashes. There is no second chance to read one, so
/// this dialog is deliberately blunt about that: it cannot be dismissed by
/// tapping outside, it says the code expires, and it offers a copy button
/// rather than expecting anyone to transcribe it correctly from a phone held at
/// arm's length next to a tablet.
Future<void> showKioskCodeDialog(
  BuildContext context, {
  required String code,
  required String title,
  required String explanation,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(explanation,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'kiosk_code_once'.tr,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Get.snackbar('done'.tr, 'copied'.tr,
                  snackPosition: SnackPosition.BOTTOM);
            },
            icon: const Icon(Icons.copy),
            label: Text('copy'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('done'.tr),
          ),
        ],
      );
    },
  );
}
