import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/kiosk_theme.dart';
import '../logic/identify_controller.dart';
import '../logic/kiosk_controller.dart';
import 'admin_screen.dart';
import 'code_entry_view.dart';

/// The screen the branch sees all day.
///
/// Everything here is sized for a wall: the employee's name is the largest
/// thing on the device, and the confirm control is a full-width bar rather than
/// a button, because the person pressing it may be wearing gloves and is
/// certainly not looking closely.
class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key});

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  bool _admin = false;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(IdentifyController());
    final kiosk = Get.find<KioskController>();

    if (_admin) {
      return AdminScreen(onExit: () => setState(() => _admin = false));
    }

    return Scaffold(
      // The way in to the administration area: a long press on the top-start
      // corner. Deliberately undiscoverable rather than secret — it opens
      // nothing on its own, since the next thing it asks for is a single-use
      // code that only an administrator can generate. A visible "Settings"
      // button would invite every employee in the queue to press it.
      body: Stack(
        children: [
          SafeArea(child: _body(c, kiosk)),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => setState(() => _admin = true),
              child: const SizedBox(width: 96, height: 96),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(IdentifyController c, KioskController kiosk) {
    return Obx(() => switch (c.phase.value) {
              IdentifyPhase.idle => _Idle(controller: c, kiosk: kiosk),
              IdentifyPhase.capturing => _Capturing(controller: c),
              IdentifyPhase.thinking => const _Thinking(),
              IdentifyPhase.confirming => _Confirming(controller: c),
              IdentifyPhase.done => _Done(controller: c),
              IdentifyPhase.failed => _Failed(controller: c),
              IdentifyPhase.codeEntry => CodeEntryView(controller: c),
        });
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.controller, required this.kiosk});

  final IdentifyController controller;
  final KioskController kiosk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      // The whole screen is the target. Nobody should have to find a button.
      behavior: HitTestBehavior.opaque,
      onTap: controller.start,
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(Icons.face_retouching_natural,
                size: 160, color: KioskTheme.brand),
            const SizedBox(height: 48),
            Text('اضغط لتسجيل الحضور',
                style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Text('قف أمام الكاميرا واضغط في أي مكان على الشاشة',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center),
            const Spacer(),
            Obx(() => Text(
                  kiosk.branchName.value.isEmpty
                      ? ''
                      : '${kiosk.branchName.value} · ${kiosk.stationName.value}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Capturing extends StatelessWidget {
  const _Capturing({required this.controller});

  final IdentifyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cam = controller.camera;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (cam != null && controller.cameraReady.value)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cam.value.previewSize?.height ?? 720,
              height: cam.value.previewSize?.width ?? 1280,
              child: CameraPreview(cam),
            ),
          )
        else
          const ColoredBox(color: Colors.black),
        Positioned(
          left: 0,
          right: 0,
          bottom: 64,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Obx(() => Text(
                      controller.livenessPrompt.value,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: Colors.white),
                    )),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: controller.cancel,
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white70, fontSize: 20)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 5)),
          SizedBox(height: 32),
          Text('لحظة من فضلك…', style: TextStyle(fontSize: 26)),
        ],
      ),
    );
  }
}

class _Confirming extends StatelessWidget {
  const _Confirming({required this.controller});

  final IdentifyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCheckIn = controller.nextAction.value == 'check_in';

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Spacer(),
          Icon(isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
              size: 96, color: KioskTheme.brand),
          const SizedBox(height: 32),
          // The single most important string on the device: the person confirms
          // or rejects this, and it must be readable across a corridor.
          Text(controller.employeeName.value,
              style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(isCheckIn ? 'تسجيل حضور' : 'تسجيل انصراف',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          FilledButton(
            onPressed: controller.confirm,
            child: Text(isCheckIn ? 'تأكيد الحضور' : 'تأكيد الانصراف'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: controller.cancel,
            child: const Text('لست أنا'),
          ),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.controller});

  final IdentifyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 140, color: KioskTheme.success),
            const SizedBox(height: 40),
            Text(controller.employeeName.value,
                style: theme.textTheme.displayMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('تم التسجيل',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: KioskTheme.success)),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.controller});

  final IdentifyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline_rounded,
                size: 120, color: KioskTheme.warning),
            const SizedBox(height: 40),
            // Guidance, never an error code. This is the most common non-happy
            // path and the one most likely to be read by a tired person.
            Text(controller.messageAr.value,
                style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 48),
            FilledButton(
              onPressed: controller.start,
              child: const Text('حاول مرة أخرى'),
            ),
            if (controller.codeFallbackOffered.value) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: controller.openCodeEntry,
                icon: const Icon(Icons.dialpad_rounded),
                label: const Text('استخدم رمزي الشخصي'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
