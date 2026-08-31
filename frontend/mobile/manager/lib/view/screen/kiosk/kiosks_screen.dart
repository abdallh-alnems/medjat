import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../logic/controller/kiosk/kiosk_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import 'widgets/kiosk_code_dialog.dart';

/// The branch kiosk fleet.
///
/// This screen is the only route into putting a tablet into service — without
/// it the whole feature is unreachable, because a kiosk cannot pair without a
/// code and a code cannot exist without an administrator asking for one.
class KiosksScreen extends StatelessWidget {
  const KiosksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final canManage = auth.user?.canManageKioskDevices ?? false;
    final canAccess = auth.user?.canAccessKiosk ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('kiosks'.tr),
        actions: [
          // Gated on manage_attendance, matching v1/kiosk/recognition-logs.
          if (auth.user?.canManageAttendance ?? false)
            IconButton(
              icon: const Icon(Icons.insights_outlined),
              tooltip: 'kiosk_activity'.tr,
              onPressed: () => Get.toNamed<void>(AppRoutes.kioskActivity),
            ),
        ],
      ),
      // The gate matches what v1/kiosk/pairing-code enforces. If these ever
      // disagree the API answers 403 and the user sees a bare "an error
      // occurred" with nothing pointing at the cause.
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _addKiosk(context),
              icon: const Icon(Icons.add),
              label: Text('kiosk_add'.tr),
            )
          : null,
      body: GetBuilder<KioskFleetController>(
        builder: (c) => HandlingDataRequest(
          statusRequest: c.status,
          onRetry: c.load,
          widget: RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _FleetSummary(controller: c),
                if (c.wouldBlockCount > 0) _VersionWarning(controller: c),
                for (final roster in c.rostersOverCeiling)
                  _RosterWarning(roster: roster),
                const SizedBox(height: 8),
                if (c.stations.isEmpty)
                  _Empty(canManage: canManage)
                else
                  for (final s in c.stations)
                    _KioskTile(
                      station: s,
                      canManage: canManage,
                      canAccess: canAccess,
                      controller: c,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addKiosk(BuildContext context) async {
    final c = Get.find<KioskFleetController>();
    final nameController = TextEditingController();
    int? branchId = c.branches.isNotEmpty ? c.branches.first.id : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('kiosk_add'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: branchId,
                decoration: InputDecoration(labelText: 'branch'.tr),
                items: [
                  for (final b in c.branches)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => branchId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'kiosk_name'.tr,
                  hintText: 'kiosk_name_hint'.tr,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('kiosk_generate_code'.tr),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || branchId == null) return;

    final code = await c.createPairingCode(
      branchId: branchId!,
      name: nameController.text,
    );

    if (code == null || !context.mounted) return;

    // Shown once and never retrievable: the server keeps only the hash.
    await showKioskCodeDialog(
      context,
      code: code,
      title: 'kiosk_pairing_code'.tr,
      explanation: 'kiosk_pairing_code_hint'.tr,
    );

    await c.load();
  }
}

class _FleetSummary extends StatelessWidget {
  const _FleetSummary({required this.controller});

  final KioskFleetController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Stat(
              label: 'kiosk_active'.tr,
              value: '${controller.activeCount}',
              color: theme.colorScheme.primary,
            ),
            _Stat(
              label: 'kiosk_offline'.tr,
              value: '${controller.offlineCount}',
              color: controller.offlineCount > 0
                  ? Colors.orange
                  : theme.colorScheme.onSurfaceVariant,
            ),
            _Stat(
              label: 'kiosk_min_version'.tr,
              value: controller.minVersion,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Shown when raising the minimum version would take tablets out of service.
///
/// This exists because the consequence is invisible otherwise: the store apps
/// send a user to a store, and a directly-installed kiosk has nowhere to be
/// sent — somebody has to physically visit each branch.
class _VersionWarning extends StatelessWidget {
  const _VersionWarning({required this.controller});

  final KioskFleetController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.system_update, color: Colors.orange),
        title: Text('kiosk_version_warning_title'.tr),
        subtitle: Text('kiosk_version_warning_body'
            .trParams({'n': '${controller.wouldBlockCount}'})),
      ),
    );
  }
}

/// Shown when a branch's enrolled roster has grown past the point where
/// face-only identification can hold its accuracy target.
class _RosterWarning extends StatelessWidget {
  const _RosterWarning({required this.roster});

  final Map<String, dynamic> roster;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.groups_outlined, color: Colors.orange),
        title: Text('kiosk_roster_warning_title'.tr),
        subtitle: Text('kiosk_roster_warning_body'.trParams({
          'branch': '${roster['branch_name']}',
          'n': '${roster['enrolled']}',
          'max': '${roster['warn_above']}',
        })),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.tablet_android_outlined,
              size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(canManage ? 'kiosk_empty'.tr : 'kiosk_empty_no_permission'.tr,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _KioskTile extends StatelessWidget {
  const _KioskTile({
    required this.station,
    required this.canManage,
    required this.canAccess,
    required this.controller,
  });

  final Map<String, dynamic> station;
  final bool canManage;
  final bool canAccess;
  final KioskFleetController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revoked = station['status'] != 'active';
    final offline = station['is_offline'] == true;
    final outdated = station['below_min_version'] == true;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: revoked
              ? theme.colorScheme.surfaceContainerHighest
              : offline
                  ? Colors.orange.withValues(alpha: 0.15)
                  : theme.colorScheme.primaryContainer,
          child: Icon(
            revoked ? Icons.block : Icons.tablet_android,
            color: revoked
                ? theme.colorScheme.outline
                : offline
                    ? Colors.orange
                    : theme.colorScheme.primary,
          ),
        ),
        title: Text('${station['name'] ?? ''}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${station['branch']?['name'] ?? ''}'),
            Text(
              [
                if (revoked) 'kiosk_revoked'.tr,
                if (offline && !revoked) 'kiosk_is_offline'.tr,
                if (outdated) 'kiosk_outdated'.tr,
                'v${station['app_version'] ?? '—'}',
                'kiosk_punches'.trParams({'n': '${station['punch_count'] ?? 0}'}),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
        trailing: revoked
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) => _onAction(context, v),
                itemBuilder: (context) => [
                  if (canAccess)
                    PopupMenuItem(
                      value: 'access',
                      child: Text('kiosk_open_settings'.tr),
                    ),
                  if (canManage)
                    PopupMenuItem(
                      value: 'revoke',
                      child: Text('kiosk_revoke_action'.tr),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final stationId = (station['id'] as num).toInt();

    if (action == 'access') {
      final code = await controller.createAccessCode(stationId: stationId);
      if (code == null || !context.mounted) return;

      await showKioskCodeDialog(
        context,
        code: code,
        title: 'kiosk_access_code'.tr,
        explanation: 'kiosk_access_code_hint'.tr,
      );
      return;
    }

    if (action == 'revoke') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('kiosk_revoke_action'.tr),
          // Says what revoking actually does, including the part people get
          // wrong: it takes effect when the tablet next reaches the server, not
          // instantly, because a switched-off device cannot be told anything.
          content: Text('kiosk_revoke_confirm'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text('confirm'.tr),
            ),
          ],
        ),
      );

      if (ok == true) {
        await controller.revoke(stationId: stationId);
      }
    }
  }
}

/// Kept out of the widget tree above so the clipboard import stays local.
class KioskClipboard {
  static void copy(String value) =>
      Clipboard.setData(ClipboardData(text: value));
}
