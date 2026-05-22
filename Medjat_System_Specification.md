# Medjat — وثيقة متطلبات المنتج (PRD)
> نظام الحضور والانصراف وإدارة الموارد البشرية والرواتب | HR Attendance, Payroll & Workforce SaaS

---

## معلومات الوثيقة

| البند | التفاصيل |
|-------|----------|
| الإصدار | **2.0 — وثيقة مبنية على الكود الفعلي (Source-of-Truth)** |
| التاريخ | مايو 2026 |
| النوع | SaaS — متعدد الشركات (Multi-Tenant) |
| المنصات | Flutter (Android / iOS) + Backend PHP REST API + MySQL |
| التطبيقات | تطبيق الموظف (`medjat_app`) + تطبيق الإدارة (`medjat_central`) + سوبر أدمن (Backend `admin/`) |
| السوق المستهدف | مصر وشمال أفريقيا |
| المصدر | فحص فعلي لـ `backend_medjet/` (47 جدول، 28 موديل، ~150 endpoint)، `front_end/medjat_central` (48 شاشة، 37 كنترولر)، `front_end/medjat_app` |

> **مبدأ الوثيقة:** هذه نسخة تصف **ما هو مبني فعلاً** في الكود، وتصحّح الافتراضات القديمة في PRD v1.2 (أهمها مصادقة الموظف). عند أي تعارض، **كود `backend_medjet` هو مصدر الحقيقة**.

---

## الفهرس

1. [نظرة عامة](#١-نظرة-عامة)
2. [معمارية النظام](#٢-معمارية-النظام)
3. [المصادقة والحسابات](#٣-المصادقة-والحسابات)
4. [الصلاحيات والأدوار](#٤-الصلاحيات-والأدوار)
5. [تطبيق الإدارة — الوحدات بالتفصيل](#٥-تطبيق-الإدارة--الوحدات-بالتفصيل)
6. [تطبيق الموظف — الشاشات بالتفصيل](#٦-تطبيق-الموظف--الشاشات-بالتفصيل)
7. [نظام الحضور والانصراف](#٧-نظام-الحضور-والانصراف)
8. [نظام الرواتب](#٨-نظام-الرواتب)
9. [نظام الإجازات](#٩-نظام-الإجازات)
10. [المستندات والامتثال](#١٠-المستندات-والامتثال)
11. [المصاريف والسلف والعُهد](#١١-المصاريف-والسلف-والعهد)
12. [الخطابات الرسمية](#١٢-الخطابات-الرسمية)
13. [الإشعارات والتنبيهات الذكية](#١٣-الإشعارات-والتنبيهات-الذكية)
14. [السوبر أدمن والاشتراكات](#١٤-السوبر-أدمن-والاشتراكات)
15. [نموذج البيانات](#١٥-نموذج-البيانات)
16. [ملخص واجهة الـ API](#١٦-ملخص-واجهة-الـ-api)
17. [حالة التنفيذ والفجوات المعروفة](#١٧-حالة-التنفيذ-والفجوات-المعروفة)
18. [التسعير](#١٨-التسعير)

---

## ١. نظرة عامة

نظام SaaS متكامل لإدارة الموارد البشرية موجّه للشركات الصغيرة والمتوسطة في السوق المصري والعربي. يجمع بين: تسجيل الحضور بطرق متعددة، ملف الموظف الكامل، قواعد خصم/إضافي مرنة، حساب رواتب تلقائي يشمل الاستقطاعات القانونية (تأمينات + ضرائب + مكافأة نهاية الخدمة)، إدارة الإجازات والمستندات والمصاريف والسلف والعُهد والخطابات الرسمية — كل ذلك معزول لكل شركة (Multi-Tenant) وبواجهة عربية RTL.

### ١.١ المشكلة

- لا يوجد نظام عربي متكامل يجمع الحضور + ملف الموظف + الرواتب القانونية بسعر معقول للسوق المصري.
- الأنظمة القائمة معقدة أو مكلفة أو غير مدعومة بالعربية.
- الشركات الصغيرة تعتمد على Excel والورق ⇒ أخطاء كثيرة.

### ١.٢ الميزة التنافسية

| الميزة | المنافسون | Medjat |
|--------|-----------|--------|
| ملف موظف كامل + مستندات + امتثال | محدود | ✅ كامل |
| رواتب تلقائية + استقطاعات قانونية مصرية (تأمينات/ضرائب/EOSB) | جزئي | ✅ كامل |
| حضور متعدد الطرق (QR/GPS/Kiosk/Biometric/Offline) | جزئي | ✅ كامل |
| مصاريف + سلف بأقساط + عُهد + خطابات رسمية بـ PDF | ❌ | ✅ موجود |
| صلاحيات مخصصة مرنة + نطاق فروع | محدود | ✅ كامل |
| عربي + سوق مصري + دفع محلي | ❌ | ✅ مخطط (Paymob) |

---

## ٢. معمارية النظام

```
┌──────────────────────────────────────────────────────────┐
│  تطبيق الموظف (Flutter)   │   تطبيق الإدارة (Flutter)      │
│  medjat_app              │   medjat_central               │
└───────────────┬──────────────────────┬───────────────────┘
                │                       │
                ▼                       ▼
        ┌───────────────────────────────────────┐
        │     Backend PHP REST API (app/*.php)  │
        │  Firebase Auth + Multi-Tenant + RBAC  │
        └───────────────────┬───────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
     ┌──────────────┐          ┌────────────────────┐
     │  MySQL 8     │          │  Super Admin (admin/)│
     │ (معزول لكل   │          │  إدارة الشركات      │
     │  tenant)     │          └────────────────────┘
     └──────────────┘
```

### ٢.١ التطبيقات الثلاثة

| التطبيق | المستخدم | الوظيفة | الحجم |
|---------|----------|---------|-------|
| **الموظف** (`medjat_app`) | الموظف فقط | حضور/انصراف، بياناتي، راتبي، أوراقي، إجازاتي، إشعارات | خفيف — وظيفته الأساسية الحضور |
| **الإدارة** (`medjat_central`) | مدير عام / HR / Manager / Attendance / Viewer | إدارة كاملة للشركة | شامل — 48 شاشة |
| **السوبر أدمن** (`backend_medjet/admin`) | فريق التطوير | إدارة كل الشركات + الاشتراكات + التحكم التقني | لوحة ويب |

### ٢.٢ العزل متعدد الشركات (Multi-Tenant)

- كل شركة لها `tenant_id`. كل صف بيانات مرتبط بـ `tenant_id`.
- كل طلب API (عدا التفعيل وقائمة الإشعارات) يحمل `X-Tenant-Id` (أو query/body `tenant_id`)، ويُفرض عبر `TenantMiddleware::requireTenant()`.
- شركة لا ترى بيانات شركة أخرى إطلاقاً.

### ٢.٣ المكدّس التقني (الفعلي)

| الطبقة | التقنية |
|--------|---------|
| التطبيقات | Flutter + Dart، نمط **MVVM عبر GetX** (Controller/Binding/Model/data_source) |
| الحالة | GetX (`GetxController`, `Obx`, `GetBuilder`) |
| الـ HTTP | كلاس `CRUD` موحّد (`core/class/crud.dart`) يضيف الهيدرز ويعالج الأخطاء عبر `StatusRequest` + `HandlingData` |
| الباك إند | PHP REST — كل endpoint ملف مستقل في `app/<feature>/<action>.php`، موديلات في `models/`، منطق مشترك في `core/` |
| قاعدة البيانات | MySQL 8 (الترحيلات في `migrations/`) |
| المصادقة | **Firebase Auth** (ID Token) + بوابة `Authorization: Basic` + عزل tenant |
| التخزين المحلي | `flutter_secure_storage` (التوكن/المستخدم)، `Hive` (طابور الحضور offline)، `shared_preferences` |
| الإشعارات | Firebase Cloud Messaging (FCM) |
| المراقبة | Firebase Crashlytics + Analytics + Remote Config (بوابة تحديث/صيانة) |
| الحضور | `mobile_scanner` (QR) + `geolocator` (GPS) + `permission_handler` |
| الرواتب PDF | تُحمَّل عبر `get_slip.php?format=pdf` وتُعرض بـ `open_filex` |
| الخطابات PDF | `LetterPdfService` في الباك إند |
| الوجه/البصمة | تسجيل بيومتري عبر محطات Kiosk (`station/*`, `biometric/*`) |
| الدفع | Paymob (مخطط — `payment_transactions`, `subscriptions`, `plans`) |

### ٢.٤ بوابات التشغيل (Remote Config)

تطبيقا الموظف والإدارة يقرآن من Firebase Remote Config:
- `*_min_version` ⇒ **تحديث إجباري** (يمنع النسخ القديمة).
- `*_maintenance_enabled` ⇒ شاشة صيانة.

---

## ٣. المصادقة والحسابات

> ⚠️ **تصحيح جوهري لـ PRD v1.2:** النظام **لا يستخدم** «توكن دائم + Device Binding بدون Firebase» للموظف. **كل** المستخدمين (إدارة وموظفين) يُصادَقون عبر **Firebase ID Token** (`core/Auth.php :: authenticateUser`)، حيث يُطابَق `firebase_uid` بصف في جدول `admins`، ويُربط الموظف عبر `employees.admin_id`.

### ٣.١ آلية المصادقة الموحّدة (الباك إند)

كل طلب محمي يحمل:
1. `Authorization: Basic base64(SECURITY_USER:SECURITY_KEY)` — بوابة عامة على مستوى الـ API.
2. `X-Firebase-Token: <Firebase ID Token>` (أو query/body `token`) — هوية المستخدم.
3. `X-Tenant-Id: <tenant_id>` (أو query/body `tenant_id`) — عزل الشركة.

بالإضافة لـ: `RateLimiter::enforceIpLimit()`، التحقق من الصلاحية عبر `PermissionMiddleware::check($auth, '<permission>')`، وتسجيل العمليات الحساسة في `audit_log`.

### ٣.٢ تطبيق الإدارة — التسجيل والدخول

| العنصر | التفاصيل |
|--------|----------|
| التسجيل | ذاتي (`signup_screen`) عبر Firebase: Email/Password + Google (+ Apple على iOS) |
| تفعيل الإيميل | رابط تحقق من Firebase (`verify_email_screen`) |
| الدخول | `login.php` يستقبل `{token}` (Firebase idToken) ويطابقه بصف admin |
| استعادة كلمة السر | عبر Firebase (`forgot_password_screen`) |
| بعد الدخول | إنشاء شركة جديدة (`tenant/create.php` ⇒ يصبح **مدير عام**) أو الانضمام لواحدة (`tenant/join.php`) |
| تنبيهات الدخول | `LoginAlertService` + جداول `login_attempts`, `admin_sessions`, `admin_devices` |

### ٣.٣ تطبيق الموظف — التفعيل والدخول (الفعلي)

```
الموظف يفتح التطبيق لأول مرة
   ↓
يسجّل دخول Firebase (Email/Password أو Google) بنفس الإيميل الذي أضافته به الشركة
   ↓
يحصل التطبيق على Firebase idToken
   ↓
POST app/auth/activate_employee.php   body: { token, activation_code: "8K3M9P" }
   ↓
الرد: employee { id, name, tenant_id, tenant_name, branch_id, branch_name, job_title }
   ↓
يُخزَّن tenant_id + بيانات الموظف محلياً (لإرسال X-Tenant-Id لاحقاً)
   ↓
كل النداءات التالية: Firebase idToken (متجدد تلقائياً) + X-Tenant-Id ⇒ Auto-login
   ↓
الخروج/تغيير الجهاز: FirebaseAuth.signOut() + مسح التخزين، ويتطلب كود تفعيل جديد من الإدارة
```

**مواصفات كود التفعيل** (`employee_activation_codes`, `ActivationCodeModel`):

| العنصر | التفاصيل |
|--------|----------|
| الصيغة | 6 خانات (أرقام + حروف كابيتال)، مثال `8K3M9P` |
| الصلاحية | محدودة زمنياً (افتراضياً 24 ساعة) — `activation_expires_at` |
| الاستخدام | مرة واحدة — يُحرق فور التفعيل (`markUsed`) |
| إعادة التوليد | من تطبيق الإدارة (`employees/activation_code.php`) عند الفقد/الانتهاء |
| التكلفة | صفر — يُرسَل يدوياً (واتساب/طباعة) |

### ٣.٤ السوبر أدمن

- لوحة منفصلة (`backend_medjet/admin`) بجداول مستقلة: `super_admins`, `super_admin_sessions`, `super_admin_audit_log`.
- دخول Email + Password (محدود لفريق التطوير، لا تسجيل ذاتي).

---

## ٤. الصلاحيات والأدوار

النظام يعتمد **RBAC مرن** عبر `PermissionMiddleware` وجدول `custom_roles` (`RoleModel`).

### ٤.١ الصلاحيات (Permissions) المعروفة في الكود

`manage_employees`, `manage_attendance`, `manage_payroll`, `manage_leaves`, `manage_documents`, `manage_company_settings`, `view_reports`, `manage_users` (دعوة الأدمن)، وغيرها يفرضها كل endpoint عبر `PermissionMiddleware::check($auth, '<permission>')`.

### ٤.٢ الأدوار الافتراضية

| الدور | النطاق | الصلاحيات |
|-------|--------|-----------|
| **مدير عام** (منشئ الشركة) | كل الفروع | كل الصلاحيات بلا قيود |
| **HR** | كل الفروع | كل شيء عدا دعوة الأدمن وإعدادات الشركة (قابل للتخصيص) |
| **Branch Manager** | فرعه فقط | موظفون + حضور + مستندات + تقارير الفرع |
| **Attendance** | فرعه فقط | تسجيل الحضور اليدوي فقط |
| **Viewer** | حسب التخصيص | مشاهدة التقارير فقط |
| **Employee** | بياناته فقط | تطبيق الموظف فقط |

### ٤.٣ إدارة الفريق والدعوات

- `managers/invite.php` يدعو أدمن جديد + تحديد الدور/الصلاحيات/النطاق (`manager_invitations`).
- `managers/list_invitations.php`, `cancel_invitation.php`, `list_admins.php`.
- `managers/get_admin_permissions.php`, `update_admin_permissions.php`, `reset_admin_permissions.php`.
- `roles/create_role.php`, `roles/list_permissions.php`.
- شاشات الإدارة: `team_screen`, `invite_admin_screen`, `invitation_code_screen`.

---

## ٥. تطبيق الإدارة — الوحدات بالتفصيل

48 شاشة و37 كنترولر. الوحدات:

### ٥.١ Dashboard
- `dashboard/overview.php` — ملخص (موظفون، حضور اليوم، رواتب…).
- `dashboard/live_attendance.php` — حضور لحظي.
- `dashboard/branch_comparison.php` — مقارنة أداء الفروع (نسب حضور، رواتب، تأخير).
- شاشات: `dashboard_screen`, `live_attendance_screen`.

### ٥.٢ الموظفون
- إنشاء/تعديل/حذف: `employees/create.php`, `update.php`, `delete.php`, `list.php`, `get_profile.php`.
- ملف الموظف: بيانات أساسية + وظيفية + بنكية (`2026_05_21_add_employee_bank_fields`) + امتثال (`2026_05_24_add_employee_compliance_fields`).
- شاشات: `employees_screen`, `add_employee_screen`, `employee_detail_screen`, `employee_documents_screen`, `biometric_enrollment_screen`.

### ٥.٣ الفروع
- `branches/create.php`, `update.php`, `delete.php`, `list.php`.
- `branches/get_qr.php` — QR الفرع (للطباعة عبر `branch_qr_poster_screen`).
- `branches/update_gps.php` — نطاق GPS بالمتر.
- `branches/update_attendance_method.php` — طرق الحضور المسموحة (انظر §٧).
- شاشات: `branch_screen`, `branch_qr_poster_screen`.

### ٥.٤ الفئات والورديات
- **الفئات** (`employee_categories`): `categories/create|update|delete|list|assign.php` — تصنيف الموظفين. شاشة `categories_screen`.
- **الورديات** (`shifts`): `shifts/create|update|delete|list|assign.php` — جداول العمل. شاشات `shifts_screen`, `assign_shift_screen`.

### ٥.٥ الحضور (إدارة)
- `attendance/get_branch_attendance.php` — حضور الفرع.
- `attendance/manual_check_in.php` — تحضير يدوي.
- `attendance/sync_offline.php` — استقبال طابور الموظف offline.
- شاشة `attendance_screen`, `live_attendance_screen`.

### ٥.٦ الرواتب
- `payroll/calculate.php` — حساب راتب موظف لشهر.
- `payroll/generate.php` — توليد كشوف الشهر للكل.
- `payroll/approve.php` — اعتماد.
- `payroll/get_slip.php`, `list_slips.php` — الكشوف.
- `payroll/load_template.php` — قالب.
- `payroll/eosb_calculate.php` — مكافأة نهاية الخدمة.
- `payroll/bank_file_preview.php`, `export_bank_file.php` — ملف تحويل بنكي.
- شاشة `payroll_screen` (+ تقرير `payroll_report_screen`).

### ٥.٧ قواعد الخصم والإضافي
- **خصومات** (`deduction_rules`, `manual_deductions`): `deductions/get_rules|update_rules|add_manual.php`. شاشة `deduction_rules_screen`.
- **مكافآت/إضافي** (`bonus_rules`, `manual_bonuses`): `bonuses/get_rules|update_rules|add_manual.php`.

### ٥.٨ الإجازات (إدارة)
- `leaves/list|approve|reject|create|create_recurring|convert_absence|rollover|get_balance.php`.
- إعدادات: `settings/leave_settings.php` (`leave_year_balances`, `recurring_leaves`, `holidays`).
- شاشة `leave_screen` (+ تقرير `leaves_report_screen`).

### ٥.٩ المستندات والامتثال
- مطلوبات: `documents/create_required|update_required|delete_required|get_required|toggle_required.php` (`required_documents`, `required_document_categories`, `required_document_employees`).
- مستندات الموظف: `employees/upload_document|update_document|verify_document|reject_document|get_documents|get_missing_documents.php`.
- قوالب: `document_templates`, `document_requests`.
- تقارير: `documents/reports_expired|reports_expiring_soon|reports_missing|reports_stats.php`, `mark_expired.php`, `employees/expiring_compliance.php`.
- شاشات: `required_documents_screen`, `employee_documents_screen`, `documents_report_screen`.

### ٥.١٠ المصاريف والسلف والعُهد
- **مصاريف** (`expense_claims`): `expenses/create|list|approve|reject|reimburse.php`. شاشة `expenses_screen`.
- **سلف بأقساط** (`employee_loans`, `loan_installments`): `loans/create|approve|cancel|get|list.php`. شاشة `loans_screen`.
- **عُهد/أصول** (`asset_custody`): `assets/create|list|request_return|approve_return|reject_return.php`. شاشة `assets_screen`.

### ٥.١١ الخطابات الرسمية
- قوالب: `letters/template_create|update|delete.php`, `templates_list.php` (`document_templates`).
- طلبات: `letters/request_create|approve|reject|pdf.php`, `requests_list.php` — توليد PDF عبر `LetterPdfService`.
- شاشات: `letters_hub_screen`, `letter_template_edit_screen`.

### ٥.١٢ المحطات (Kiosk) والبيومترية
- محطات: `stations/create|update|delete|get|list|logs|regenerate_qr|unlock|update_branch_settings.php` (`attendance_stations`).
- تشغيل المحطة: `station/activate|heartbeat|sync|check_in_out|branch_employees|verify_admin_pin|enroll_employee_biometric|log_recognition.php`.
- بيومترية: `biometric/enroll_face|enroll_fingerprint|status|delete.php` (`BiometricModel`).
- سجل التعرف: `station_recognition_logs` (`StationRecognitionLogModel`).
- شاشات: `stations_management_screen`, `recognition_logs_screen`, `biometric_enrollment_screen`.

### ٥.١٣ الأداء والتحذيرات
- **تقييمات** (`PerformanceModel`): `performance/add_review.php`.
- **تحذيرات** (`warnings`): `warnings/add|list.php` — تشمل أحداث تغيير الجهاز.

### ٥.١٤ التقارير
- `reports/attendance|employees|leaves|payroll.php`.
- شاشات: `report_screen`, `attendance_report_screen`, `employees_report_screen`, `leaves_report_screen`, `payroll_report_screen`, `documents_report_screen`.

### ٥.١٥ الإعدادات
- `settings/company.php` — بيانات الشركة + شعار (`upload_branding.php`).
- `settings/statutory_settings.php` — الاستقطاعات القانونية (§٨).
- `settings/leave_settings.php` — إعدادات الإجازات.
- شاشات: `company_settings_hub_screen`, `company_settings_screen`, `account_settings_screen`, `app_settings_screen`, `attendance_method_screen`, `deduction_rules_screen`, `leave_settings_screen`, `required_documents_screen`.

### ٥.١٦ الإشعارات
- `auth/notification_prefs.php` (تفضيلات الأدمن — `admin_notification_prefs`).
- `notifications/list|read.php`, `auth/update_fcm_token.php`.
- شاشات: `notifications_screen`, `notification_prefs_screen`.

---

## ٦. تطبيق الموظف — الشاشات بالتفصيل

النطاق (PRD §2.1): **حضور + بياناتي + راتبي + أوراقي** + إجازات + إشعارات + إعدادات. عربي RTL أحادي اللغة.

| # | الشاشة | المصدر | الوصف |
|---|--------|--------|-------|
| 1 | **Splash** | Remote Config + Auto-login | بوابة تحديث/صيانة ثم توجيه (دخول/رئيسية) |
| 2 | **تفعيل/دخول** (`login_screen`) | Firebase + `activate_employee.php` | دخول Firebase (Email/Google) + إدخال كود التفعيل |
| 3 | **الرئيسية — الحضور** (`home_screen`) | `get_my_attendance.php?month=` | حالة اليوم (مشتقة client-side) + زر مسح QR + إشعارات |
| 4 | **مسح QR** (`scan_qr_screen`) | `mobile_scanner` + `geolocator` | مسح QR ⇒ التقاط GPS ⇒ check_in/out |
| 5 | **نجاح الحضور** (`attendance_success_screen`) | — | تأكيد + علامة offline إن لزم |
| 6 | **بياناتي** (`my_profile_screen`) | `get_profile.php` | بيانات وظيفية + تحذيرات + رصيد إجازات + فئات |
| 7 | **أوراقي** (`my_documents_screen`) | `get_profile.php` → documents | حالة كل مستند (مرفوع/مطلوب/منتهٍ) |
| 8 | **راتبي** (`payroll_screen`) | `get_slip.php?month=` (+`format=pdf`) | عرض الكشف + تنزيل PDF |
| 9 | **الإجازات** (`leave_screen`) | `apply.php` + `get_balance.php` | تقديم طلب + عرض الرصيد |
| 10 | **الإشعارات** (`notifications_screen`) | `notifications/list|read.php` | قائمة + تعليم كمقروء + تفضيلات |
| 11 | **الإعدادات** (`settings_screen`) | محلي + `notification_prefs.php` | Light/Dark + تفضيلات الإشعارات + خروج |

**الحضور Offline:** عند انقطاع النت يُحفظ السجل في Hive box `offline_attendance` ويُزامن عبر `sync_offline.php` عند عودة الاتصال. **(انظر §١٧ — حالة التنفيذ).**

---

## ٧. نظام الحضور والانصراف

### ٧.١ طرق الحضور (الفعلية في الكود)

تُضبط لكل فرع أو تُورَّث من إعدادات الشركة (`branches/update_attendance_method.php`، القيم المسموحة):

| الطريقة | المفتاح | الوصف |
|---------|---------|-------|
| **QR + GPS** ✅ | `qr_gps` | الطريقة الأساسية — مسح QR الفرع + التحقق من GPS لحظياً |
| **GPS فقط** | `gps_only` | تحقق موقع بدون QR |
| **يدوي** | `manual` | تحضير من المدير/Attendance (`manual_check_in.php`) |
| **محطة Kiosk** | `station` | تابلت ثابت بالفرع + تعرّف بيومتري (وجه/بصمة) |
| **Offline** | (وضع) | QR+GPS دون تحقق فوري ⇒ يُحفظ ويُزامن لاحقاً |

> نطاق الـ GPS قابل للضبط بين 10 و5000 متر (`gps_radius_meters`، افتراضي 100).

### ٧.٢ تدفّق check-in (الباك إند `check_in.php`)

```
POST check_in.php { branch_id, latitude, longitude, qr_code }
   1. مصادقة + tenant + إيجاد الموظف عبر admin_id
   2. إيجاد الفرع
   3. التحقق: qr_code == branch.qr_code  (وإلا 400 "Invalid QR")
   4. GpsService::validateCheckIn(...)   (وإلا 400 code=GPS_OUT_OF_RANGE)
   5. AttendanceModel::checkIn(..., method='qr_gps')
   ⇒ { message, time, branch }
```

`check_out.php` بلا body (auth فقط) ⇒ `{ message, time }`.

### ٧.٣ سجل الحضور والـ Offline
- `get_my_attendance.php?month=YYYY-MM` ⇒ `{ records[], month, employee_id }`. حالة اليوم تُشتق client-side (لا بارامتر `today`).
- `sync_offline.php` ⇒ `{ synced, failed }`. شكل الـ record يطابق `AttendanceModel::syncOffline`.
- حالات السجل تشمل: `present`, `absent`, تأخير (`late_minutes`) — تُستخدم في حساب الرواتب.

### ٧.٤ الحماية ضد Buddy Punching
- Firebase UID مرتبط بصف admin واحد + كود التفعيل لمرة واحدة على جهاز واحد.
- طريقة `station` تضيف تعرّف بيومتري (وجه/بصمة) للتحقق من الهوية.

---

## ٨. نظام الرواتب

### ٨.١ المعادلة الأساسية (`core/PayrollCalculator.php`)

```
صافي الراتب = الراتب الأساسي − إجمالي الخصومات + إجمالي الإضافي   (− الاستقطاعات القانونية)
```
- المعدل اليومي = `base_salary / 30`، المعدل بالساعة = `daily / 8`.

### ٨.٢ الخصومات (`deduction_rules`)

| النوع | القاعدة |
|-------|---------|
| **غياب** | `absence_multiplier` (افتراضي 1.5) × المعدل اليومي لكل يوم `absent` |
| **تأخير نسبي** | `ceil(late_minutes / late_unit_minutes)` × `late_deduction_per_unit` (افتراضي ربع يوم لكل 15 دقيقة) |
| **تأخير ثابت** | `late_fixed_amount` (افتراضي 50) لكل يوم تأخير |
| **خصم يدوي** | `manual_deductions` (مبلغ + سبب + تاريخ) |

### ٨.٣ الإضافي/المكافآت (`bonus_rules`, `manual_bonuses`)
قواعد إضافي + مكافآت يدوية (بدلات/حوافز).

### ٨.٤ الاستقطاعات القانونية (`payroll_statutory_settings`، `settings/statutory_settings.php`)

تُضبط لكل شركة وتُطبَّق في `applyStatutory(...)`:

| البند | الحقول |
|-------|--------|
| **التأمينات الاجتماعية** | `social_insurance_enabled`, `si_employee_rate`, `si_employer_rate`, `si_min_wage`, `si_max_wage` |
| **ضريبة الدخل** | `income_tax_enabled`, `income_tax_brackets` (شرائح JSON), `tax_personal_exemption` |
| **مكافأة نهاية الخدمة (EOSB)** | `eosb_enabled`, `eosb_days_per_year` (تُحسب عبر `eosb_calculate.php`) |

> التحقق: عند تفعيل أي بند تُصبح حقوله المطلوبة إلزامية (مثلاً `si_employee_rate > 0`).

### ٨.٥ التوليد والاعتماد والتحويل البنكي
- `generate.php` (كل الموظفين) → `approve.php` (اعتماد) → `get_slip.php` / `list_slips.php`.
- التحويل البنكي: `bank_file_preview.php` ثم `export_bank_file.php` (يعتمد الحقول البنكية للموظف).
- تطبيق الموظف يرى كشفه فقط عبر `get_slip.php?month=` (بدون صلاحية إدارية) + PDF.

---

## ٩. نظام الإجازات

### ٩.١ الأنواع والآليات
- أنواع الطلب: `annual`, `sick`, `personal`, `unpaid`.
- **متكررة** (`recurring_leaves`): تتكرر تلقائياً (`create_recurring.php`).
- **مرة واحدة** (`create.php` / `apply.php`).
- **تحويل غياب لإجازة** (`convert_absence.php`): يُزيل خصم الغياب من الكشف.
- **ترحيل رصيد** (`rollover.php`) + أرصدة سنوية (`leave_year_balances`) + عطلات (`holidays`).

### ٩.٢ من جهة الموظف
- تقديم: `apply.php` `{date, type, reason?, start_date?, end_date?}` ⇒ `{leave_id, message}`؛ تداخل ⇒ كود `leave_overlap` (409).
- الرصيد: `get_balance.php?year=` (بدون `employee_id` للموظف نفسه).

### ٩.٣ من جهة الإدارة
- `list.php`, `approve.php`, `reject.php`, إعدادات عبر `settings/leave_settings.php`.

---

## ١٠. المستندات والامتثال

- **الأوراق المطلوبة:** يحدد المدير قائمة (`required_documents`) قابلة للتصنيف (`required_document_categories`) والربط بموظفين (`required_document_employees`).
- **حالة كل مستند:** مرفوع ✅ / مطلوب ⏳ / منتهٍ ❌.
- **دورة الحياة:** رفع (`upload_document`) → تحقق (`verify_document`) / رفض (`reject_document`) → تعليم منتهٍ (`mark_expired`).
- **تقارير الامتثال:** منتهية / قاربت الانتهاء / ناقصة / إحصاءات + `expiring_compliance`.

---

## ١١. المصاريف والسلف والعُهد

### ١١.١ المصاريف (`expense_claims`)
طلب مصروف → موافقة/رفض → صرف (`reimburse`). مسارات `expenses/*`.

### ١١.٢ السلف بالأقساط (`employee_loans`, `loan_installments`)
إنشاء سلفة → موافقة/إلغاء → خصم أقساط (تنعكس على الرواتب). مسارات `loans/*`.

### ١١.٣ العُهد/الأصول (`asset_custody`)
تسليم عهدة → طلب إرجاع → موافقة/رفض إرجاع. مسارات `assets/*`.

---

## ١٢. الخطابات الرسمية

- **قوالب** (`document_templates`): إنشاء/تعديل/حذف/قائمة.
- **طلبات** (`document_requests`): إنشاء → موافقة/رفض → توليد PDF (`request_pdf.php` عبر `LetterPdfService`).
- شاشات الإدارة: `letters_hub_screen`, `letter_template_edit_screen`.

---

## ١٣. الإشعارات والتنبيهات الذكية

- **FCM** عبر `auth/update_fcm_token.php` (`{fcm_token, platform, device_id}`).
- **قائمة الإشعارات** (`notifications/list.php`) ⇒ `{notifications[{id,type,title,title_ar,body,body_ar,data,read_at,created_at}], unread_count}` + `read.php`.
- **التفضيلات** (`auth/notification_prefs.php`): `late_absence`, `missing_checkout`, `document_expiry`, `leave_events`, `payroll_events`.
- **خدمات الباك إند:** `NotificationService`, `SmartAlertService`, `LoginAlertService`, و`cron/run_alerts.php` (تنبيهات دورية: تأخر/غياب/نسيان انصراف/انتهاء مستندات).

---

## ١٤. السوبر أدمن والاشتراكات

- لوحة `backend_medjet/admin` (جداول `super_admins`, `super_admin_sessions`, `super_admin_audit_log`).
- إدارة الشركات (`tenants`), إيقاف/تفعيل, مراقبة.
- الاشتراكات: `plans`, `subscriptions`, `payment_transactions`, `SubscriptionModel` (Paymob — مخطط).
- التحديث الإجباري عبر Remote Config.

---

## ١٥. نموذج البيانات

47 جدول. أهمها مجمّعة حسب المجال:

| المجال | الجداول |
|--------|---------|
| **الشركات والمصادقة** | `tenants`, `admins`, `admin_sessions`, `admin_devices`, `login_attempts`, `super_admins`, `super_admin_sessions` |
| **الموظفون** | `employees`, `employee_categories`, `employee_category_assignments`, `employee_activation_codes`, `employee_auth_tokens`, `activation_codes` |
| **الفروع والورديات** | `branches`, `shifts` |
| **الحضور** | `attendance`, `attendance_stations`, `station_recognition_logs` |
| **الرواتب** | `payroll`, `payroll_statutory_settings`, `deduction_rules`, `bonus_rules`, `manual_deductions`, `manual_bonuses` |
| **الإجازات** | `leaves`, `recurring_leaves`, `leave_year_balances`, `holidays` |
| **المستندات** | `required_documents`, `required_document_categories`, `required_document_employees`, `employee_documents`, `document_templates`, `document_requests` |
| **المالية** | `expense_claims`, `employee_loans`, `loan_installments`, `asset_custody` |
| **الأداء والامتثال** | `warnings`, `audit_log`, `super_admin_audit_log` |
| **الإشعارات** | `notifications`, `admin_notification_prefs` |
| **الصلاحيات** | `custom_roles`, `manager_invitations` |
| **الاشتراكات** | `plans`, `subscriptions`, `payment_transactions` |
| **البيومترية** | (عبر `BiometricModel`) |

> ⚠️ ملاحظة تشغيلية: `schema.sql` يستخدم صيغة `ADD COLUMN IF NOT EXISTS` (MariaDB) — قاعدة MySQL 8 الحية تحتاج ترحيلات يدوية (انظر `migrations/2026_05_22_sync_mysql8_missing.sql`).

---

## ١٦. ملخص واجهة الـ API

كل المسارات تحت `app/<feature>/`. كل النداءات (عدا التفعيل وقائمة الإشعارات) تتطلب Basic + Firebase token + `X-Tenant-Id`. الردود عبر `Response::success(...)` / `Response::fail(msg, code, errorCode?)`.

| المجال | أبرز النقاط |
|--------|-------------|
| auth | `activate_employee`, `login`, `update_profile`, `update_fcm_token`, `notification_prefs` |
| attendance | `check_in`, `check_out`, `get_my_attendance`, `get_branch_attendance`, `manual_check_in`, `sync_offline` |
| employees | `create/update/delete/list`, `get_profile`, `upload/verify/reject/update/get_documents`, `expiring_compliance` |
| branches | `create/update/delete/list`, `get_qr`, `update_gps`, `update_attendance_method` |
| payroll | `calculate`, `generate`, `approve`, `get_slip`, `list_slips`, `eosb_calculate`, `bank_file_preview`, `export_bank_file` |
| deductions/bonuses | `get_rules`, `update_rules`, `add_manual` |
| leaves | `apply`, `get_balance`, `list`, `approve`, `reject`, `create`, `create_recurring`, `convert_absence`, `rollover` |
| documents | `*_required`, `reports_*`, `mark_expired` |
| expenses/loans/assets | `create`, `approve/reject`, `reimburse` / `cancel/get` / `request_return`, `approve/reject_return` |
| letters | `template_*`, `request_*`, `requests_list` |
| stations/biometric/station | إدارة المحطات + التشغيل + التسجيل البيومتري |
| settings | `company`, `statutory_settings`, `leave_settings`, `upload_branding` |
| managers/roles | `invite`, `list_admins`, `*_admin_permissions`, `create_role`, `list_permissions` |
| dashboard/reports | `overview`, `live_attendance`, `branch_comparison` / `attendance`, `employees`, `leaves`, `payroll` |
| notifications | `list`, `read` |
| tenant | `create`, `join` |
| cron | `run_alerts` |

---

## ١٧. حالة التنفيذ والفجوات المعروفة

### ١٧.١ منجَز ويعمل
- مصادقة Firebase + tenant + Basic في التطبيقين.
- تطبيق الإدارة: 48 شاشة تغطي كل الوحدات أعلاه.
- تطبيق الموظف: التفعيل، الحضور (online)، بياناتي، راتبي + PDF، الإجازات (تقديم+رصيد)، الإشعارات.

### ١٧.٢ فجوات في تطبيق الموظف (مرصودة من الكود)
| # | الفجوة | الخطورة |
|---|--------|---------|
| 1 | شاشتا **«أوراقي» و«الإجازات»** مبنيتان لكن **لا رابط تنقّل لهما** (التبويبات السفلية 4 فقط) | 🔴 |
| 2 | **مزامنة الحضور offline** (`syncOfflineRecords()`) معرّفة لكن **لا تُستدعى أبداً** | 🔴 |
| 3 | تسجيل **FCM token** يحدث قبل تسجيل الدخول (بلا tenant) فيفشل؛ ولا إعادة تسجيل بعد التفعيل | 🟠 |
| 4 | لا معالجة للإشعارات في الخلفية/عند النقر (`onBackgroundMessage`/`onMessageOpenedApp`) | 🟠 |
| 5 | **تعديل بياناتي** غير منفّذ (endpoint موجود) | 🟡 |
| 6 | رفع المستندات من الموظف — يحتاج تأكيد صلاحية `upload_document.php` | 🟡 |
| 7 | نمذجة الردود ناقصة (معظمها `Map` خام) — دَين معماري | 🟡 |

### ١٧.٣ فجوات الباك إند
- **لا endpoint «سجل إجازاتي» للموظف** — `leaves/list.php` يتطلب `manage_leaves` (إدارة). يلزم endpoint جديد (مثل `leaves/my_list.php`) لعرض سجل طلبات الموظف.

---

## ١٨. التسعير

| الباقة | الشهري | الموظفون | الفروع |
|--------|--------|----------|--------|
| Starter | 199 ج | حتى 10 | فرع واحد |
| Growth | 399 ج | حتى 30 | حتى 3 |
| Pro | 699 ج | حتى 100 | غير محدود |
| Enterprise | مخصص | +100 | غير محدود + دعم |

> الدفع عبر **Paymob** (فيزا/ماستر/ميزا/محافظ). في البداية الاستخدام مجاني بلا حدود؛ الاشتراك يُفعَّل لاحقاً.

---

> **Medjat** — ميدجات | PRD v2.0 (مبني على الكود الفعلي) — مايو 2026
>
> عند أي تعارض بين هذه الوثيقة والكود، **كود `backend_medjet` هو مصدر الحقيقة**.
