import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../data/model/terminated_employee_model.dart';
import '../../../logic/controller/employee/terminated_employees_controller.dart';

/// "الموظفون المنتهية خدماتهم" — lists ended-service employees with their
/// details and lets HR re-hire them (restores to pending_activation).
class TerminatedEmployeesScreen extends StatelessWidget {
  const TerminatedEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<TerminatedEmployeesController>(
        TerminatedEmployeesController());

    return Scaffold(
      appBar: AppBar(title: Text('terminated_employees'.tr)),
      body: Column(
        children: [
          _SearchBar(onChanged: ctrl.onSearch),
          Expanded(
            child: GetBuilder<TerminatedEmployeesController>(
              init: ctrl,
              builder: (c) => HandlingDataRequest(
                statusRequest: c.status,
                onRetry: c.load,
                widget: RefreshIndicator(
                  onRefresh: c.load,
                  child: c.employees.isEmpty
                      ? _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          itemCount: c.employees.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.s3),
                          itemBuilder: (_, i) => _TerminatedCard(
                            employee: c.employees[i],
                            currency: c.currency,
                            onRehire: () =>
                                _confirmRehire(context, c, c.employees[i]),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRehire(BuildContext context,
      TerminatedEmployeesController ctrl, TerminatedEmployeeModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('rehire_title'.tr),
        content: Text('rehire_confirm'.trParams({'name': e.name})),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('cancel'.tr)),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: Text('rehire_action'.tr)),
        ],
      ),
    );
    if (ok == true) {
      final result = await ctrl.reactivate(e.id);
      if (result != null && context.mounted) {
        await _showLoginDetails(context, e.name, result);
      }
    }
  }

  /// After a successful re-hire, show the fresh login details (activation code,
  /// login phone, join link) so HR can hand them to the employee.
  Future<void> _showLoginDetails(
      BuildContext context, String name, Map<String, dynamic> data) async {
    final code = data['activation_code'] as String?;
    final joinLink = data['join_link'] as String?;
    final phone = data['login_phone'] as String?;

    void copy(String? value, String toast) {
      if (value == null || value.isEmpty) return;
      Clipboard.setData(ClipboardData(text: value));
      Get.snackbar('done'.tr, toast, snackPosition: SnackPosition.BOTTOM);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          title: Text('rehire_success'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'rehire_login_hint'.trParams({'name': name}),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                Text('login_phone'.tr,
                    style: TextStyle(
                        fontSize: 12, color: colors.textTertiary)),
                const SizedBox(height: 4),
                Text(
                  phone,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              Text('activation_code'.tr,
                  style:
                      TextStyle(fontSize: 12, color: colors.textTertiary)),
              const SizedBox(height: AppSpacing.s2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.brandSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.brand, width: 1.5),
                ),
                child: Text(
                  code ?? '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: colors.brand,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text('single_use_hint'.tr,
                  style: TextStyle(fontSize: 11, color: colors.textTertiary)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => copy(code, 'code_copied'.tr),
              icon: const Icon(Icons.copy, size: 16),
              label: Text('copy_code'.tr),
            ),
            if (joinLink != null && joinLink.isNotEmpty)
              TextButton.icon(
                onPressed: () => copy(joinLink, 'link_copied'.tr),
                icon: const Icon(Icons.link, size: 16),
                label: Text('copy_link'.tr),
              ),
            ElevatedButton(
              onPressed: () => Get.back<void>(),
              child: Text('done'.tr),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, AppSpacing.s1),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'search_employee'.tr,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.work_off_outlined, size: 56, color: colors.textTertiary),
        const SizedBox(height: AppSpacing.s3),
        Text(
          'no_terminated_employees'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 15,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TerminatedCard extends StatelessWidget {
  final TerminatedEmployeeModel employee;
  final String currency;
  final VoidCallback onRehire;

  const _TerminatedCard({
    required this.employee,
    required this.currency,
    required this.onRehire,
  });

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = employee;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.brandSubtle,
                backgroundImage:
                    e.photoUrl != null ? NetworkImage(e.photoUrl!) : null,
                child: e.photoUrl == null
                    ? Text(
                        e.name.isNotEmpty ? e.name[0] : '?',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.brand,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (e.jobTitle != null && e.jobTitle!.isNotEmpty)
                      Text(
                        e.jobTitle!,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _TerminatedBadge(date: _fmtDate(e.terminatedAt)),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s4,
            runSpacing: AppSpacing.s2,
            children: [
              if (e.branchName != null && e.branchName!.isNotEmpty)
                _InfoChip(
                    icon: Icons.business_outlined, label: e.branchName!),
              if (e.hireDate != null)
                _InfoChip(
                    icon: Icons.event_available_outlined,
                    label: '${'hire_date'.tr}: ${_fmtDate(e.hireDate)}'),
              if (e.phone != null && e.phone!.isNotEmpty)
                _InfoChip(icon: Icons.phone_outlined, label: e.phone!),
              if (e.settlementReason != null)
                _InfoChip(
                  icon: Icons.logout_outlined,
                  label:
                      'settlement_reason_${e.settlementReason}'.tr,
                ),
              if (e.settlementNetAmount != null)
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label:
                      '${'settlement_net'.tr}: ${e.settlementNetAmount!.toStringAsFixed(2)} ${currencyLabel(currency)}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRehire,
              icon: const Icon(Icons.replay_outlined, size: 18),
              label: Text('rehire_action'.tr),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminatedBadge extends StatelessWidget {
  final String date;
  const _TerminatedBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: 4),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'terminated_on'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 10,
              color: colors.error,
            ),
          ),
          Text(
            date,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12.5,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
