import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/handling_data_request.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/kiosk/kiosk_activity_controller.dart';

/// Kiosk identification activity: what happened, and the scores behind it.
///
/// Two audiences in one screen. An HR person asking "why couldn't Ahmed clock
/// in?" reads the list. Whoever is tuning the branch reads the distribution —
/// and without that, the matching threshold stays whatever shipped, which was
/// derived from a public dataset rather than from this company's faces.
class KioskActivityScreen extends StatelessWidget {
  const KioskActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final canSeeEvidence = auth.user?.canViewKioskEvidence ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('kiosk_activity'.tr)),
      body: GetBuilder<KioskActivityController>(
        builder: (c) => HandlingDataRequest(
          statusRequest: c.status,
          onRetry: c.load,
          widget: RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (c.failureRateAbnormal) _FailureWarning(controller: c),
                _Distribution(controller: c),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('kiosk_activity'.tr,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    FilterChip(
                      selected: c.onlyFailures,
                      label: Text('kiosk_only_failures'.tr),
                      onSelected: (_) => c.toggleOnlyFailures(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (c.visibleLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('kiosk_no_activity'.tr)),
                  )
                else
                  for (final log in c.visibleLogs)
                    _AttemptTile(
                      log: log,
                      controller: c,
                      canSeeEvidence: canSeeEvidence,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Raised when a branch is failing to recognise people far more often than
/// normal — usually a smeared lens or a dead light above the tablet, not a
/// threshold that needs tightening.
class _FailureWarning extends StatelessWidget {
  const _FailureWarning({required this.controller});

  final KioskActivityController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text('kiosk_failure_rate_title'.tr),
        subtitle: Text('kiosk_failure_rate_body'.trParams({
          'pct': (controller.failureRate * 100).toStringAsFixed(0),
        })),
      ),
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.controller});

  final KioskActivityController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = controller.buckets;

    final maxAttempts = buckets.fold<int>(
      0,
      (m, b) => ((b['attempts'] as num?)?.toInt() ?? 0) > m
          ? ((b['attempts'] as num?)?.toInt() ?? 0)
          : m,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('kiosk_score_distribution'.tr,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('kiosk_score_distribution_hint'.tr,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (buckets.isEmpty)
              Text('kiosk_no_scores_yet'.tr,
                  style: theme.textTheme.bodyMedium)
            else
              // A bare histogram rather than a chart dependency: what matters is
              // where accepted and rejected attempts stop overlapping, and bars
              // show that as well as anything.
              for (final b in buckets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text('${b['bucket']}',
                            style: theme.textTheme.bodySmall),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: maxAttempts == 0
                              ? 0
                              : ((b['attempts'] as num?)?.toInt() ?? 0) /
                                  maxAttempts,
                          minHeight: 14,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: b['result'] == 'matched'
                              ? Colors.green
                              : b['result'] == 'ambiguous'
                                  ? Colors.orange
                                  : theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text('${b['attempts']}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Text(
              'kiosk_current_defaults'.trParams({
                't': controller.defaultThreshold.toStringAsFixed(3),
                'm': controller.defaultMargin.toStringAsFixed(3),
              }),
              style: theme.textTheme.bodySmall,
            ),
            if (controller.ambiguousCount > 0) ...[
              const SizedBox(height: 6),
              // Worth calling out separately: these are the attempts a
              // threshold-only design would have assigned to the wrong person.
              Text(
                'kiosk_ambiguous_count'
                    .trParams({'n': '${controller.ambiguousCount}'}),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({
    required this.log,
    required this.controller,
    required this.canSeeEvidence,
  });

  final Map<String, dynamic> log;
  final KioskActivityController controller;
  final bool canSeeEvidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matched = log['result'] == 'matched';
    final ambiguous = log['result'] == 'ambiguous';
    final employee = log['employee'];
    final hasCapture = log['has_capture'] == true;

    final score = (log['match_score'] as num?)?.toDouble();
    final runnerUp = (log['runner_up'] as num?)?.toDouble();
    final gap = (log['margin_gap'] as num?)?.toDouble();

    return Card(
      child: ListTile(
        leading: Icon(
          matched
              ? Icons.check_circle
              : ambiguous
                  ? Icons.help_outline
                  : Icons.cancel_outlined,
          color: matched
              ? Colors.green
              : ambiguous
                  ? Colors.orange
                  : theme.colorScheme.outline,
        ),
        title: Text(
          employee is Map
              ? '${employee['name']}'
              : 'kiosk_unidentified'.tr,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([
              '${log['result']}',
              '${log['method']}',
              '${log['created_at']}',
            ].join(' · '), style: theme.textTheme.bodySmall),
            if (score != null)
              Text(
                // The runner-up and the gap are the whole story of a 1:N
                // decision — a high score alone means nothing if somebody else
                // scored almost as high.
                'kiosk_scores'.trParams({
                  's': score.toStringAsFixed(3),
                  'r': runnerUp?.toStringAsFixed(3) ?? '—',
                  'g': gap?.toStringAsFixed(3) ?? '—',
                  'n': '${log['candidates'] ?? '—'}',
                }),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        isThreeLine: true,
        trailing: (canSeeEvidence && hasCapture)
            ? IconButton(
                icon: const Icon(Icons.image_outlined),
                tooltip: 'kiosk_view_capture'.tr,
                onPressed: () => _showCapture(context),
              )
            : null,
      ),
    );
  }

  Future<void> _showCapture(BuildContext context) async {
    final id = (log['id'] as num).toInt();

    await showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder<String?>(
        future: controller.capture(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AlertDialog(
              content: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final uri = snapshot.data;
          return AlertDialog(
            title: Text('kiosk_view_capture'.tr),
            content: uri == null
                // Expiry is the designed outcome, not a failure — say so
                // rather than showing a broken image.
                ? Text('kiosk_capture_expired'.tr)
                : Image.memory(
                    base64Decode(uri.split(',').last),
                    fit: BoxFit.contain,
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('close'.tr),
              ),
            ],
          );
        },
      ),
    );
  }
}
