import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/kiosk_theme.dart';
import '../logic/kiosk_controller.dart';

/// The out-of-service screen, in four variants.
///
/// One screen rather than four because the shape is identical and the content
/// is not: a large icon, one sentence a worker can act on, and — for the two
/// states only a supervisor can resolve — a second line saying so explicitly.
///
/// The design rule here is that this screen never lies by omission. A kiosk
/// that cannot record attendance must say that plainly, because the alternative
/// is a queue of people who believe they have clocked in and have not.
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.state});

  final KioskState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kiosk = Get.find<KioskController>();
    final spec = _specFor(state);

    return Scaffold(
      backgroundColor: spec.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(spec.icon, size: 120, color: spec.accent),
                  const SizedBox(height: 40),
                  Text(
                    spec.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: spec.accent,
                      fontSize: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    spec.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  if (spec.supervisorNote != null) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: spec.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: spec.accent),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              spec.supervisorNote!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  // Retrying is safe from every one of these states: the
                  // heartbeat is the thing that decides, and it is idempotent.
                  OutlinedButton.icon(
                    onPressed: kiosk.heartbeat,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StatusSpec _specFor(KioskState state) => switch (state) {
        KioskState.offline => const _StatusSpec(
            icon: Icons.wifi_off_rounded,
            accent: KioskTheme.warning,
            background: Color(0xFFFFFBEB),
            title: 'لا يوجد اتصال',
            // States what CANNOT happen, then what to do instead. A worker who
            // walks away thinking they clocked in is the failure this prevents.
            body: 'لا يمكن تسجيل الحضور من هذا الجهاز الآن.\n'
                'أبلغ المشرف ليسجّل حضورك يدويًا.',
          ),
        KioskState.updateRequired => const _StatusSpec(
            icon: Icons.system_update_rounded,
            accent: KioskTheme.warning,
            background: Color(0xFFFFFBEB),
            title: 'الجهاز يحتاج تحديث',
            body: 'لا يمكن تسجيل الحضور حتى يتم تحديث التطبيق.',
            // Addressed to a supervisor on purpose: this kiosk is installed
            // directly, so there is no store for anyone to update it from.
            supervisorNote: 'إلى المسؤول: هذا الجهاز يعمل بنسخة أقدم من الحد '
                'الأدنى المطلوب. ثبّت النسخة الجديدة على الجهاز.',
          ),
        KioskState.maintenance => const _StatusSpec(
            icon: Icons.build_circle_outlined,
            accent: KioskTheme.brand,
            background: Color(0xFFF0FDFA),
            title: 'صيانة مؤقتة',
            body: 'النظام تحت الصيانة حاليًا.\n'
                'سيعود تسجيل الحضور تلقائيًا بعد انتهائها.',
          ),
        _ => const _StatusSpec(
            icon: Icons.hourglass_empty_rounded,
            accent: KioskTheme.brand,
            background: Color(0xFFF8FAFB),
            title: 'جارٍ التشغيل',
            body: 'لحظات من فضلك.',
          ),
      };
}

class _StatusSpec {
  const _StatusSpec({
    required this.icon,
    required this.accent,
    required this.background,
    required this.title,
    required this.body,
    this.supervisorNote,
  });

  final IconData icon;
  final Color accent;
  final Color background;
  final String title;
  final String body;
  final String? supervisorNote;
}
