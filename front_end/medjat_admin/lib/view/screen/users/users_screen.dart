import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/user_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/user/user_controller.dart';
import '../shared/panel_widgets.dart';

/// The client contact book: every administrator of every company, who to call,
/// when they last signed in, and what we can do for them without SSH.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Get.find<AuthController>().admin;
    final canWrite = admin?.canWrite ?? false;
    final isSuperAdmin = admin?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('مديرو الشركات')),
      body: GetBuilder<UserController>(
        builder: (controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s3,
                  AppSpacing.s4,
                  0,
                ),
                child: PanelSearchField(
                  hint: 'ابحث بالاسم أو الشركة أو الهاتف أو البريد',
                  onChanged: controller.onSearchChanged,
                ),
              ),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: controller.status.value,
                  onRetry: () => controller.loadUsers(),
                  widget: RefreshIndicator(
                    onRefresh: () => controller.loadUsers(),
                    child: controller.users.isEmpty
                        ? ListView(
                            children: const [
                              EmptyHint(
                                message: 'لا يوجد مديرون مطابقون للبحث',
                                icon: Icons.person_search,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              AppSpacing.s3,
                              AppSpacing.s4,
                              AppSpacing.s8,
                            ),
                            itemCount: controller.users.length + 1,
                            itemBuilder: (context, index) {
                              if (index == controller.users.length) {
                                return PagerBar(
                                  page: controller.currentPage.value,
                                  totalPages: controller.totalPages.value,
                                  total: controller.total.value,
                                  onPrevious: controller.previousPage,
                                  onNext: controller.nextPage,
                                );
                              }
                              return _ContactCard(
                                user: controller.users[index],
                                controller: controller,
                                canWrite: canWrite,
                                isSuperAdmin: isSuperAdmin,
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final UserModel user;
  final UserController controller;
  final bool canWrite;
  final bool isSuperAdmin;

  const _ContactCard({
    required this.user,
    required this.controller,
    required this.canWrite,
    required this.isSuperAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final phone = user.callablePhone;

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colors.brandSubtle,
                child: Text(
                  user.name.isNotEmpty ? user.name[0] : '?',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontWeight: FontWeight.w600,
                    color: colors.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user.tenantName ?? 'بلا شركة',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (user.email != null)
                      Text(
                        user.email!,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    text: user.isActiveUser ? 'نشط' : 'موقوف',
                    tone: user.isActiveUser ? PillTone.success : PillTone.error,
                  ),
                  const SizedBox(height: 4),
                  if (user.roleLabelAr != null)
                    Text(
                      user.roleLabelAr!,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Icon(Icons.login, size: 14, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'آخر دخول ${relativeAge(user.lastLoginAt, never: 'لم يدخل قط')}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              if (phone != null)
                _Action(
                  icon: Icons.phone,
                  label: 'اتصال',
                  onTap: () => ContactActions.call(phone),
                ),
              if (phone != null)
                _Action(
                  icon: Icons.chat,
                  label: 'واتساب',
                  onTap: () => ContactActions.whatsapp(phone),
                ),
              if ((user.email ?? '').isNotEmpty)
                _Action(
                  icon: Icons.mail_outline,
                  label: 'بريد',
                  onTap: () => ContactActions.email(user.email!),
                ),
              if (canWrite && user.canResetPassword)
                _Action(
                  icon: Icons.lock_reset,
                  label: 'إعادة تعيين كلمة المرور',
                  onTap: () => _confirmReset(controller, user),
                ),
              if (canWrite)
                _Action(
                  icon: user.isActiveUser ? Icons.block : Icons.check_circle_outline,
                  label: user.isActiveUser ? 'إيقاف' : 'تفعيل',
                  danger: user.isActiveUser,
                  onTap: () => controller.setActive(user, !user.isActiveUser),
                ),
              if (isSuperAdmin && user.tenantId != null)
                _Action(
                  icon: Icons.open_in_new,
                  label: 'دخول تشخيصي',
                  onTap: () => _askImpersonationReason(controller, user),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void _confirmReset(UserController controller, UserModel user) {
  Get.dialog<void>(
    AlertDialog(
      title: const Text('إعادة تعيين كلمة المرور'),
      content: Text(
        'سيصل رابط إعادة التعيين إلى ${user.email}. لا نغيّر كلمة المرور بأنفسنا — حسابات العملاء تُدار عبر Firebase.',
        style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13, height: 1.6),
      ),
      actions: [
        TextButton(onPressed: () => Get.back<void>(), child: const Text('إلغاء')),
        TextButton(
          onPressed: () {
            Get.back<void>();
            controller.sendPasswordReset(user);
          },
          child: const Text('إرسال'),
        ),
      ],
    ),
  );
}

/// The reason is mandatory: it is written to the *client's* audit log, which is
/// what makes entering their account defensible.
void _askImpersonationReason(UserController controller, UserModel user) {
  final reasonCtl = TextEditingController();

  Get.dialog<void>(
    AlertDialog(
      title: const Text('دخول تشخيصي'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ستفتح لوحة ${user.tenantName ?? 'الشركة'} في المتصفح بحساب ${user.name} لمدة ساعة. '
            'يُسجَّل ذلك في سجل الشركة نفسها.',
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            controller: reasonCtl,
            decoration: const InputDecoration(labelText: 'السبب (إلزامي)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back<void>(), child: const Text('إلغاء')),
        TextButton(
          onPressed: () {
            final reason = reasonCtl.text.trim();
            if (reason.isEmpty) {
              Get.snackbar('مطلوب', 'اكتب سبب الدخول', snackPosition: SnackPosition.BOTTOM);
              return;
            }
            Get.back<void>();
            controller.impersonate(user, reason);
          },
          child: const Text('فتح'),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final color = danger ? colors.error : colors.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
