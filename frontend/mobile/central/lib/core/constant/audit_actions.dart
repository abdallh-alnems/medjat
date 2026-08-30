import 'package:flutter/material.dart';

/// Maps the backend's machine `action` codes (e.g. `loan.approve`) to readable
/// Arabic phrases, a high-level category, and an icon — so the activity log
/// never shows raw codes to the user. The category keys here mirror the
/// `categoryPrefixes` map in `backend/api/app/audit/list.php`; keep them in
/// sync when adding new modules.
class AuditActions {
  AuditActions._();

  static const Map<String, String> categoryLabels = {
    'employees': 'الموظفون',
    'attendance': 'الحضور والانصراف',
    'schedule': 'الورديات والجدول',
    'leaves': 'الإجازات',
    'finance': 'المالية',
    'recruitment': 'التوظيف',
    'performance': 'الأداء',
    'engagement': 'التواصل',
    'settings': 'الإعدادات',
    'other': 'أخرى',
  };

  static const Map<String, IconData> _categoryIcons = {
    'employees': Icons.people_outline,
    'attendance': Icons.access_time_outlined,
    'schedule': Icons.calendar_view_week_outlined,
    'leaves': Icons.event_note_outlined,
    'finance': Icons.account_balance_wallet_outlined,
    'recruitment': Icons.person_search_outlined,
    'performance': Icons.trending_up_outlined,
    'engagement': Icons.campaign_outlined,
    'settings': Icons.settings_outlined,
    'other': Icons.history,
  };

  /// The order categories appear as filter chips.
  static const List<String> categoryOrder = [
    'employees',
    'attendance',
    'schedule',
    'leaves',
    'finance',
    'recruitment',
    'performance',
    'engagement',
    'settings',
  ];

  static const Map<String, _ActionInfo> _actions = {
    // ── Employees ──
    'employee.create': _ActionInfo('أنشأ موظفًا', 'employees'),
    'employee.update': _ActionInfo('عدّل بيانات موظف', 'employees'),
    'employee.delete': _ActionInfo('حذف موظفًا', 'employees'),
    'employee.suspend': _ActionInfo('أوقف موظفًا', 'employees'),
    'employee.end_suspension': _ActionInfo('أنهى إيقاف موظف', 'employees'),
    'employee.auto_terminate': _ActionInfo('إنهاء خدمة تلقائي لموظف', 'employees'),
    'employee_category.create': _ActionInfo('أنشأ فئة موظفين', 'employees'),
    'employee_category.update': _ActionInfo('عدّل فئة موظفين', 'employees'),
    'employee_category.delete': _ActionInfo('حذف فئة موظفين', 'employees'),
    'employee_category.assign': _ActionInfo('أسند فئة لموظف', 'employees'),
    'document.upload': _ActionInfo('رفع مستندًا', 'employees'),
    'document.update': _ActionInfo('عدّل مستندًا', 'employees'),
    'document.delete': _ActionInfo('حذف مستندًا', 'employees'),
    'document.verify': _ActionInfo('وثّق مستندًا', 'employees'),
    'document.reject': _ActionInfo('رفض مستندًا', 'employees'),
    'document.request': _ActionInfo('طلب مستندًا من موظف', 'employees'),
    'document_type.create': _ActionInfo('أضاف نوع مستند', 'employees'),
    'document_type.update': _ActionInfo('عدّل نوع مستند', 'employees'),
    'document_type.delete': _ActionInfo('حذف نوع مستند', 'employees'),
    'document_type.toggle_active': _ActionInfo('غيّر تفعيل نوع مستند', 'employees'),
    'documents.mark_expired': _ActionInfo('حدّد مستندات كمنتهية', 'employees'),
    'biometric.enroll_face': _ActionInfo('سجّل بصمة وجه', 'employees'),
    'biometric.enroll_fingerprint': _ActionInfo('سجّل بصمة إصبع', 'employees'),
    'biometric.delete': _ActionInfo('حذف بصمة', 'employees'),
    'warning.add': _ActionInfo('أضاف إنذارًا', 'employees'),
    'warning.delete': _ActionInfo('حذف إنذارًا', 'employees'),
    'profile.update': _ActionInfo('حدّث الملف الشخصي', 'employees'),
    'onboarding.generate': _ActionInfo('أنشأ خطة تعيين', 'employees'),
    'onboarding_task.add': _ActionInfo('أضاف مهمة تعيين', 'employees'),
    'onboarding_task.set_status': _ActionInfo('غيّر حالة مهمة تعيين', 'employees'),
    'onboarding_template.create': _ActionInfo('أنشأ قالب تعيين', 'employees'),
    'onboarding_template.update': _ActionInfo('عدّل قالب تعيين', 'employees'),
    'onboarding_template.delete': _ActionInfo('حذف قالب تعيين', 'employees'),

    // ── Attendance ──
    'attendance.manual_check_in': _ActionInfo('سجّل حضورًا يدويًا', 'attendance'),
    'attendance.manual_check_out': _ActionInfo('سجّل انصرافًا يدويًا', 'attendance'),
    'attendance.offline_sync': _ActionInfo('زامن حضورًا دون اتصال', 'attendance'),
    'break.create': _ActionInfo('أنشأ استراحة', 'attendance'),
    'break.approve': _ActionInfo('وافق على استراحة', 'attendance'),
    'break.reject': _ActionInfo('رفض استراحة', 'attendance'),
    'break.postpone': _ActionInfo('أجّل استراحة', 'attendance'),
    'break.postpone_accept': _ActionInfo('قبل تأجيل استراحة', 'attendance'),
    'break.postpone_reject': _ActionInfo('رفض تأجيل استراحة', 'attendance'),

    // ── Schedule & shifts ──
    'schedule.assign': _ActionInfo('أسند وردية في الجدول', 'schedule'),
    'schedule.publish': _ActionInfo('نشر الجدول', 'schedule'),
    'schedule.clear': _ActionInfo('مسح الجدول', 'schedule'),
    'schedule.copy_week': _ActionInfo('نسخ جدول أسبوع', 'schedule'),
    'schedule.availability_set': _ActionInfo('حدّد التوافر', 'schedule'),
    'schedule.availability_add_date': _ActionInfo('أضاف تاريخ توافر', 'schedule'),
    'schedule.availability_delete': _ActionInfo('حذف توافرًا', 'schedule'),
    'schedule.open_shift_create': _ActionInfo('أنشأ وردية مفتوحة', 'schedule'),
    'schedule.open_shift_cancel': _ActionInfo('ألغى وردية مفتوحة', 'schedule'),
    'schedule.open_shift_approve': _ActionInfo('وافق على طلب وردية مفتوحة', 'schedule'),
    'schedule.open_shift_reject': _ActionInfo('رفض طلب وردية مفتوحة', 'schedule'),
    'schedule.open_shift_claim': _ActionInfo('تقدّم لوردية مفتوحة', 'schedule'),
    'schedule.open_shift_withdraw': _ActionInfo('سحب طلب وردية مفتوحة', 'schedule'),
    'schedule.swap_request': _ActionInfo('طلب تبديل وردية', 'schedule'),
    'schedule.swap_approve': _ActionInfo('وافق على تبديل وردية', 'schedule'),
    'schedule.swap_reject': _ActionInfo('رفض تبديل وردية', 'schedule'),
    'schedule.swap_cancel': _ActionInfo('ألغى تبديل وردية', 'schedule'),
    'schedule.swap_respond': _ActionInfo('ردّ على طلب تبديل وردية', 'schedule'),
    'shift.create': _ActionInfo('أنشأ وردية', 'schedule'),
    'shift.update': _ActionInfo('عدّل وردية', 'schedule'),
    'shift.delete': _ActionInfo('حذف وردية', 'schedule'),
    'shift.assign': _ActionInfo('أسند موظفًا لوردية', 'schedule'),
    'shift.unassign': _ActionInfo('ألغى إسناد وردية', 'schedule'),

    // ── Leaves ──
    'leave.create': _ActionInfo('أنشأ طلب إجازة', 'leaves'),
    'leave.approve': _ActionInfo('وافق على إجازة', 'leaves'),
    'leave.reject': _ActionInfo('رفض إجازة', 'leaves'),
    'leave.convert_to_absence': _ActionInfo('حوّل إجازة إلى غياب', 'leaves'),
    'leave.rollover': _ActionInfo('رحّل رصيد الإجازات', 'leaves'),
    'leave.rollover.auto': _ActionInfo('ترحيل تلقائي لرصيد الإجازات', 'leaves'),
    'leave.carryover_policy.save': _ActionInfo('حفظ سياسة ترحيل الإجازات', 'leaves'),
    'leave.carryover_policy.delete': _ActionInfo('حذف سياسة ترحيل الإجازات', 'leaves'),

    // ── Finance ──
    'loan.create': _ActionInfo('أنشأ سلفة', 'finance'),
    'loan.approve': _ActionInfo('وافق على سلفة', 'finance'),
    'loan.request': _ActionInfo('طلب سلفة', 'finance'),
    'loan.cancel_request': _ActionInfo('ألغى طلب سلفة', 'finance'),
    'deduction.manual': _ActionInfo('أضاف خصمًا يدويًا', 'finance'),
    'bonus.manual': _ActionInfo('أضاف مكافأة يدوية', 'finance'),
    'payroll.generate': _ActionInfo('أنشأ مسير رواتب', 'finance'),
    'payroll.approve': _ActionInfo('اعتمد مسير الرواتب', 'finance'),
    'payroll.export_bank_file': _ActionInfo('صدّر ملف البنك للرواتب', 'finance'),
    'settlement.save': _ActionInfo('حفظ تسوية', 'finance'),
    'settlement.approve': _ActionInfo('اعتمد تسوية', 'finance'),
    'settlement.mark_paid': _ActionInfo('حدّد تسوية كمدفوعة', 'finance'),
    'asset.create': _ActionInfo('أضاف عهدة', 'finance'),
    'asset.update': _ActionInfo('عدّل عهدة', 'finance'),
    'asset.delete': _ActionInfo('حذف عهدة', 'finance'),
    'asset.return_request': _ActionInfo('طلب إرجاع عهدة', 'finance'),
    'asset.return_approve': _ActionInfo('وافق على إرجاع عهدة', 'finance'),
    'asset.return_reject': _ActionInfo('رفض إرجاع عهدة', 'finance'),

    // ── Recruitment ──
    'candidate.create': _ActionInfo('أضاف مرشحًا', 'recruitment'),
    'candidate.update': _ActionInfo('عدّل بيانات مرشح', 'recruitment'),
    'candidate.move_stage': _ActionInfo('نقل مرشحًا لمرحلة', 'recruitment'),
    'candidate.convert': _ActionInfo('حوّل مرشحًا إلى موظف', 'recruitment'),
    'job_opening.create': _ActionInfo('أنشأ وظيفة شاغرة', 'recruitment'),
    'job_opening.update': _ActionInfo('عدّل وظيفة شاغرة', 'recruitment'),
    'job_opening.set_status': _ActionInfo('غيّر حالة وظيفة شاغرة', 'recruitment'),

    // ── Performance ──
    'performance_cycle.create': _ActionInfo('أنشأ دورة تقييم', 'performance'),
    'performance_cycle.update': _ActionInfo('عدّل دورة تقييم', 'performance'),
    'performance_cycle.set_status': _ActionInfo('غيّر حالة دورة تقييم', 'performance'),
    'performance_goal.create': _ActionInfo('أضاف هدف أداء', 'performance'),
    'performance_goal.update': _ActionInfo('عدّل هدف أداء', 'performance'),
    'performance_goal.delete': _ActionInfo('حذف هدف أداء', 'performance'),
    'performance_goal.set_progress': _ActionInfo('حدّث تقدّم هدف أداء', 'performance'),
    'performance_review.create': _ActionInfo('أنشأ تقييم أداء', 'performance'),
    'performance_review.update': _ActionInfo('عدّل تقييم أداء', 'performance'),
    'performance_review.delete': _ActionInfo('حذف تقييم أداء', 'performance'),
    'kudos.give': _ActionInfo('منح إشادة', 'performance'),
    'kudos.delete': _ActionInfo('حذف إشادة', 'performance'),
    'survey.create': _ActionInfo('أنشأ استبيانًا', 'performance'),
    'survey.update': _ActionInfo('عدّل استبيانًا', 'performance'),
    'survey.set_status': _ActionInfo('غيّر حالة استبيان', 'performance'),
    'survey.activated': _ActionInfo('فعّل استبيانًا', 'performance'),
    'survey.question_add': _ActionInfo('أضاف سؤالًا لاستبيان', 'performance'),
    'survey.question_update': _ActionInfo('عدّل سؤال استبيان', 'performance'),
    'survey.question_delete': _ActionInfo('حذف سؤال استبيان', 'performance'),

    // ── Engagement ──
    'announcement.create': _ActionInfo('أنشأ إعلانًا', 'engagement'),
    'announcement.update': _ActionInfo('عدّل إعلانًا', 'engagement'),
    'announcement.delete': _ActionInfo('حذف إعلانًا', 'engagement'),
    'announcement.published': _ActionInfo('نشر إعلانًا', 'engagement'),
    'announcement.set_status': _ActionInfo('غيّر حالة إعلان', 'engagement'),
    'analytics.dashboard_save': _ActionInfo('حفظ لوحة تحليلات', 'engagement'),
    'analytics.export': _ActionInfo('صدّر تحليلات', 'engagement'),

    // ── Settings ──
    'tenant.update_settings': _ActionInfo('عدّل إعدادات الشركة', 'settings'),
    'tenant.update_leave_settings': _ActionInfo('عدّل إعدادات الإجازات', 'settings'),
    'tenant.upload_branding': _ActionInfo('حدّث هوية الشركة', 'settings'),
    'branch.create': _ActionInfo('أنشأ فرعًا', 'settings'),
    'branch.update': _ActionInfo('عدّل فرعًا', 'settings'),
    'branch.update_attendance_method': _ActionInfo('عدّل طريقة الحضور لفرع', 'settings'),
    'approval_chain.create': _ActionInfo('أنشأ سلسلة موافقات', 'settings'),
    'approval_chain.update': _ActionInfo('عدّل سلسلة موافقات', 'settings'),
    'approval_chain.delete': _ActionInfo('حذف سلسلة موافقات', 'settings'),
    'approval_chain.set_steps': _ActionInfo('حدّد خطوات سلسلة موافقات', 'settings'),
    'manager.invite': _ActionInfo('دعا مديرًا', 'settings'),
    'manager.cancel_invite': _ActionInfo('ألغى دعوة مدير', 'settings'),
    'admin.permissions_updated': _ActionInfo('حدّث صلاحيات مدير', 'settings'),
    'admin.permissions_reset': _ActionInfo('أعاد ضبط صلاحيات مدير', 'settings'),
  };

  /// Readable Arabic phrase for an action. Falls back to a generic label for
  /// any code not yet mapped (no raw codes are ever shown).
  static String labelFor(String action) =>
      _actions[action]?.label ?? 'إجراء إداري';

  static String categoryFor(String action) =>
      _actions[action]?.category ?? 'other';

  static String categoryLabel(String key) => categoryLabels[key] ?? 'أخرى';

  static IconData iconFor(String action) =>
      _categoryIcons[categoryFor(action)] ?? Icons.history;

  /// Whether this target refers to a person (so the subject reads as "to whom"),
  /// versus an entity like a branch or shift.
  static bool isPersonTarget(String? targetType) => const {
        'employee',
        'asset',
        'loan',
        'leave',
        'break',
        'candidate',
      }.contains(targetType);

  /// A short Arabic summary of the useful fields inside an action's `payload`
  /// (amounts, counts, names…), skipping technical/internal keys. Returns an
  /// empty string when there is nothing worth showing.
  static String payloadSummary(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return '';
    final parts = <String>[];

    void add(String key, String label) {
      final v = payload[key];
      if (v == null) return;
      final text = v.toString().trim();
      if (text.isEmpty || text == 'null') return;
      parts.add('$label: $text');
    }

    add('name', 'العنصر');
    add('total_amount', 'المبلغ');
    add('amount', 'المبلغ');
    add('installments', 'عدد الأقساط');
    add('days', 'عدد الأيام');
    add('base_salary', 'الراتب');
    add('processed', 'تمت المعالجة');

    final reason = payload['reason'];
    if (reason is String && reason.trim().isNotEmpty) {
      final r = reason.trim();
      parts.add('السبب: ${r.length > 40 ? '${r.substring(0, 40)}…' : r}');
    }

    return parts.join('  ·  ');
  }
}

class _ActionInfo {
  final String label;
  final String category;
  const _ActionInfo(this.label, this.category);
}
