import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/theme/kiosk_theme.dart';
import '../logic/enrollment_controller.dart';

/// The kiosk's administration area.
///
/// Reached only by a supervisor holding a code generated seconds earlier in the
/// management app, and closed automatically when nobody touches it.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EnrollmentController());

    return Scaffold(
      body: SafeArea(
        child: Obx(() => switch (c.phase.value) {
              AdminPhase.locked => _Unlock(controller: c, onExit: onExit),
              AdminPhase.roster => _Roster(controller: c, onExit: onExit),
              AdminPhase.capturing => _Capture(controller: c),
              AdminPhase.saving => const _Saving(),
              AdminPhase.result => _Result(controller: c),
            }),
      ),
    );
  }
}

class _Unlock extends StatefulWidget {
  const _Unlock({required this.controller, required this.onExit});

  final EnrollmentController controller;
  final VoidCallback onExit;

  @override
  State<_Unlock> createState() => _UnlockState();
}

class _UnlockState extends State<_Unlock> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 88, color: KioskTheme.brand),
              const SizedBox(height: 28),
              Text('إعدادات الكيوسك',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'أدخل كود الدخول من تطبيق الإدارة ← الفرع ← فتح إعدادات الكيوسك',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Obx(() => TextField(
                    controller: _field,
                    autofocus: true,
                    enabled: !widget.controller.busy.value,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 12),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: '······',
                      errorText: widget.controller.error.value.isEmpty
                          ? null
                          : widget.controller.error.value,
                      errorMaxLines: 3,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onSubmitted: widget.controller.unlock,
                  )),
              const SizedBox(height: 28),
              Obx(() => FilledButton(
                    onPressed: widget.controller.busy.value
                        ? null
                        : () => widget.controller.unlock(_field.text),
                    child: const Text('فتح'),
                  )),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onExit,
                child: const Text('رجوع'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.controller, required this.onExit});

  final EnrollmentController controller;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تسجيل الموظفين', style: theme.textTheme.titleLarge),
                    Obx(() => Text(
                          'بإذن: ${controller.authorisedBy.value}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        )),
                  ],
                ),
              ),
              IconButton.filledTonal(
                iconSize: 32,
                onPressed: () async {
                  await controller.close();
                  onExit();
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Obx(() {
            if (controller.busy.value && controller.roster.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.roster.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = controller.roster[i];
                final enrolled = e['face_enrolled'] == true;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  tileColor: theme.colorScheme.surfaceContainerHighest,
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: enrolled
                        ? KioskTheme.success.withValues(alpha: 0.15)
                        : KioskTheme.warning.withValues(alpha: 0.15),
                    child: Icon(
                      enrolled ? Icons.how_to_reg_rounded : Icons.person_add_alt,
                      color: enrolled ? KioskTheme.success : KioskTheme.warning,
                      size: 28,
                    ),
                  ),
                  title: Text(e['name'] as String? ?? '',
                      style: theme.textTheme.titleLarge),
                  subtitle: Text(
                    enrolled ? 'مسجّل' : 'غير مسجّل',
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_left, size: 32),
                  onTap: () => controller.select(e),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _Capture extends StatelessWidget {
  const _Capture({required this.controller});

  final EnrollmentController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cam = controller.camera;
    final name = controller.selected?['name'] as String? ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('تسجيل وجه: $name', style: theme.textTheme.titleLarge),
        ),
        Expanded(
          child: (cam != null && controller.cameraReady.value)
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cam.value.previewSize?.height ?? 720,
                    height: cam.value.previewSize?.width ?? 1280,
                    child: CameraPreview(cam),
                  ),
                )
              : const ColoredBox(color: Colors.black),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('اطلب من الموظف النظر إلى الكاميرا مباشرة',
                  style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.captureAndEnroll,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('التقاط وتسجيل'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: controller.backToRoster,
                child: const Text('رجوع'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Saving extends StatelessWidget {
  const _Saving();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('جارٍ التسجيل…', style: TextStyle(fontSize: 22)),
          ],
        ),
      );
}

class _Result extends StatelessWidget {
  const _Result({required this.controller});

  final EnrollmentController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = controller.resultOk.value;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 110,
                color: ok ? KioskTheme.success : KioskTheme.warning),
            const SizedBox(height: 32),
            Text(controller.resultMessage.value,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 40),
            // Replacing an existing enrollment is a separate, deliberate press.
            if (controller.needsReplaceConfirm.value)
              FilledButton(
                onPressed: () =>
                    controller.captureAndEnroll(confirmReplace: true),
                child: const Text('استبدال الوجه المسجّل'),
              )
            else if (!ok)
              FilledButton(
                onPressed: controller.captureAndEnroll,
                child: const Text('حاول مرة أخرى'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.backToRoster,
              child: const Text('العودة للقائمة'),
            ),
          ],
        ),
      ),
    );
  }
}
