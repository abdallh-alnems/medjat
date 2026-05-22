# مراجعة مميزات تطبيق Medjat Central (لوحة الإدارة)

> هذا الملف مراجعة **خطوة بخطوة لكل مميزات** تطبيق `front_end/medjat_central` — وهو تطبيق المدير/الموارد البشرية (HR) لإدارة الحضور والرواتب وشؤون الموظفين.
> المراجعة هنا **للمميزات (Features) وليست مراجعة كود**. كل قسم يوضّح: ماذا تفعل الميزة، الشاشات والمسارات المرتبطة بها، نقاط الـ API، والحالة/الملاحظات.

- **اسم المشروع:** `medjat_central` — "Medjat Central — HR Attendance & Payroll Management App"
- **الإصدار:** 1.0.0+1
- **المنصّة:** Flutter (Dart SDK ^3.11.1)
- **إدارة الحالة:** GetX (Controllers + Bindings + Routing)
- **الخدمات السحابية:** Firebase (Auth، Messaging، Analytics، Crashlytics، Remote Config) + Google Sign-In
- **الواجهة الخلفية:** PHP API (نقاط نهاية `.php` تحت `$base/app/...`، عنوان الخادم من `.env` عبر `API_HOST`)
- **اللغات:** عربية + إنجليزية (مع دعم RTL)

---

## 0) خريطة التطبيق العامة (Bottom Navigation)

التطبيق مبني حول 5 تبويبات سفلية (`TabShell`):

| # | التبويب | الشاشة | الوظيفة |
|---|---------|--------|---------|
| 1 | الرئيسية (home) | `DashboardScreen` | لوحة المؤشرات والإحصائيات |
| 2 | الموظفون (employees) | `EmployeesScreen` | قائمة وإدارة الموظفين |
| 3 | الحضور (attendance) | `AttendanceScreen` | متابعة حضور الفروع |
| 4 | الرواتب (payroll) | `PayrollScreen` | كشوف الرواتب |
| 5 | المزيد (more) | `MoreScreen` | باقي المميزات والإعدادات |

تبويب **"المزيد"** هو بوابة الوصول لباقي المميزات (الورديات، الإجازات، الخطابات، المصروفات، السلف، العُهد، الفروع، الحضور المباشر، التقارير، الإعدادات).

---

## 1) تدفّق بدء التطبيق (Startup Flow)

**الخطوات:**
1. **Splash** (`/splash`) — شاشة بداية تتحقق من حالة الدخول.
2. التوجيه التلقائي:
   - إذا كان المستخدم بحاجة إلى **إعداد شركة** → `Onboarding` (`/onboarding`).
   - إذا كان **مسجّل دخول** → `Home` (`/home`).
   - غير ذلك → `Login` (`/login`).
3. **بوابتان قبل الواجهة الرئيسية:**
   - `MaintenanceGate` — وضع الصيانة (يُتحكم به عبر Firebase Remote Config).
   - `UpdateGate` — التحديث الإجباري/المقترح (in_app_update + upgrader).

**الحالة:** ✅ مكتمل ويعمل.

---

## 2) المصادقة (Authentication)

| الميزة | الشاشة / المسار | نقطة الـ API | الحالة |
|--------|-----------------|--------------|--------|
| تسجيل الدخول | `login_screen` `/login` | `auth/login.php` | ✅ |
| إنشاء حساب | `signup_screen` `/signup` | `auth/login.php` (يعيد بيانات المستخدم) | ✅ |
| توثيق البريد | `verify_email_screen` `/verify-email` | Firebase Auth | ✅ |
| نسيت كلمة المرور (OTP بالبريد) | `forgot_password_screen` `/forgot-password` | `forgot_password.php` → `verify_reset_code.php` → `reset_password.php` | ✅ |
| تسجيل الخروج | عبر زر في "المزيد" | `auth/logout.php` | ⚠️ نقطة الـ API الخلفية مفقودة (TODO في الكود) |
| تحديث الملف الشخصي | إعدادات الحساب | `auth/update_profile.php` | ✅ |
| تخزين الـ Token بأمان | `token_storage_service` + `flutter_secure_storage` | — | ✅ |

**ملاحظة:** يدعم Google Sign-In (الحزمة موجودة).

---

## 3) إعداد الشركة / الانضمام (Tenant Onboarding)

- **الشاشة:** `onboarding_screen` (`/onboarding`).
- **الوظيفة:** إنشاء شركة جديدة أو الانضمام لشركة قائمة (نظام Multi-tenant).
- **نقاط الـ API:** `tenant/create.php`، `tenant/join.php`.
- **الحالة:** ✅ مكتمل.

---

## 4) نظام الأدوار والصلاحيات (Roles & Permissions)

التطبيق يخفي/يُظهر المميزات بناءً على دور المستخدم (`user_model.dart`):

- **الأدوار:** `owner` / `general_manager` (مالك)، `hr` (موارد بشرية)، `branch_manager` (مدير فرع).
- **الصلاحيات المُشتقّة:** `canManageEmployees`، `canManageAttendance`، `canManagePayroll`، `canViewReports`، `canManageBranches`، `canManageLeaves`، `canManageAssets`، `canManageDocuments`.
- كل عنصر في قائمة "المزيد" يظهر فقط لمن يملك الصلاحية المناسبة.

**إدارة الفريق والصلاحيات:**

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| دعوة مدير | `invite_admin_screen` `/team/invite` | `managers/invite.php` |
| كود الدعوة | `invitation_code_screen` `/team/invite/code` | `managers/list_invitations.php` |
| إدارة الفريق + صلاحيات كل أدمن | `team_screen` `/team` | `list_admins.php`, `get/update/reset_admin_permissions.php` |
| الأدوار والصلاحيات | — | `roles/list_permissions.php`, `roles/create_role.php` |

**الحالة:** ✅ مكتمل.

---

## 5) لوحة المؤشرات (Dashboard)

- **الشاشة:** `dashboard_screen` (تبويب الرئيسية).
- **المكوّنات:**
  - ترحيب باسم المستخدم + جرس **الإشعارات** مع عدّاد غير المقروء.
  - بطاقات إحصائية (`StatCard`) للحضور/الموظفين/...الخ.
  - **مقارنة الفروع** (Branch Comparison) — تظهر للمالك أو من يملك صلاحية التقارير وعند وجود أكثر من فرع.
  - **سحب للتحديث** (Pull to refresh).
- **نقاط الـ API:** `dashboard/overview.php`، `dashboard/branch_comparison.php`، `dashboard/live_attendance.php`.
- **الحالة:** ✅ مكتمل.

---

## 6) الموظفون (Employees)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| قائمة الموظفين | `employees_screen` | `employees/list.php` |
| إضافة موظف | `add_employee_screen` `/employee/add` | `employees/create.php` |
| تفاصيل/تعديل موظف | `employee_detail_screen` `/employee/:id` | `get_profile.php` / `update.php` / `delete.php` |
| مستندات الموظف | `employee_documents_screen` `/employee/documents` | `get_documents.php`, `upload/update/verify/reject_document.php` |
| المستندات الناقصة | (ضمن التفاصيل) | `get_missing_documents.php` |
| كود تفعيل الموظف (لتطبيق الموظف) | (ضمن التفاصيل) | `employees/activation_code.php` |
| تسجيل البصمة البيومترية | `biometric_enrollment_screen` `/employee/biometric` | `biometric/enroll_face.php`, `enroll_fingerprint.php` |
| تقييمات الأداء | (ضمن التفاصيل) | `performance/list.php`, `create.php`, `delete.php` |
| الإنذارات | — | `warnings/list.php`, `warnings/add.php` |

**ملاحظة:** نقاط **تقييمات الأداء (Performance)** مُعلّمة بأن الواجهة الخلفية لها مفقودة (TODO) — تحقق من جاهزية الـ API.

**الحالة:** ✅ الأساسيات مكتملة | ⚠️ تقييمات الأداء تحتاج Backend.

---

## 7) الحضور (Attendance)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| حضور الفرع | `attendance_screen` | `get_branch_attendance.php` |
| تسجيل حضور يدوي | `/attendance/manual` | `manual_check_in.php` |
| تسجيل دخول/خروج | — | `check_in.php`, `check_out.php` |
| مزامنة الحضور دون اتصال | — | `sync_offline.php` |
| الحضور المباشر (Live) | `live_attendance_screen` `/dashboard/live-attendance` | `dashboard/live_attendance.php` |

**نقاط الحضور البيومترية (Stations):**

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| إدارة الأجهزة/المحطات | `stations_management_screen` `/stations` | `stations/list.php`, `create/update/delete.php`, `regenerate_qr.php`, `unlock.php` |
| إعدادات المحطة (طريقة التعرف، نطاق GPS، حساسية التطابق، مكافحة الانتحال، PIN) | `_StationSettingsScreen` `/stations/settings` | `stations/update_branch_settings.php` |
| سجلات التعرّف | `recognition_logs_screen` `/stations/logs` | `stations/logs.php` |

**الحالة:** ✅ مكتمل (يشمل دعم العمل دون اتصال والتعرف على الوجه/البصمة).

---

## 8) الرواتب (Payroll)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| كشوف الرواتب | `payroll_screen` | `payroll/list_slips.php` |
| توليد كشف | — | `payroll/generate.php` |
| حساب الراتب | — | `payroll/calculate.php` |
| اعتماد الكشف | — | `payroll/approve.php?id=` |
| كشف شهر معين | `/payroll/:month/:year` | `get_slip.php?month=&year=` |
| تصدير ملف البنك + معاينته | — | `export_bank_file.php`, `bank_file_preview.php` |
| الإعدادات القانونية (تأمينات/ضرائب) | `/settings/statutory-payroll` | `settings/statutory_settings.php`, `load_template.php?country=` |
| مكافأة نهاية الخدمة (EOSB) | — | `payroll/eosb_calculate.php` |

**الخصومات والمكافآت المرتبطة بالرواتب:**
- قواعد الخصم: `deduction_rules_screen` `/settings/deduction-rules` → `deductions/get_rules.php`, `update_rules.php`, `add_manual.php`.
- قواعد المكافآت: `bonuses/get_rules.php`, `update_rules.php`, `add_manual.php`.

**الحالة:** ✅ مكتمل وشامل (يشمل قوالب قانونية حسب الدولة وملف بنكي وEOSB).

---

## 9) الإجازات (Leaves)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| إدارة/قائمة الإجازات | `leave_screen` `/leave/manage` | `leaves/list.php` |
| تقديم إجازة | — | `leaves/apply.php` / `create.php` |
| اعتماد/رفض | — | `approve.php?id=`, `reject.php?id=` |
| رصيد الإجازات | — | `get_balance.php` |
| تحويل غياب لإجازة | — | `convert_absence.php` |
| إجازات متكررة | — | `create_recurring.php` |
| ترحيل الرصيد (Rollover) | — | `leaves/rollover.php` |
| إعدادات الإجازات | `leave_settings_screen` `/settings/leave` | `settings/leave_settings.php` |

**الحالة:** ✅ مكتمل وشامل.

---

## 10) المميزات المالية والإدارية الإضافية ("المزيد")

| الميزة | الشاشة / المسار | نقطة الـ API | الوصف |
|--------|-----------------|--------------|-------|
| **المصروفات** | `expenses_screen` `/expenses` | `expenses/list.php`, `create/approve/reject/reimburse.php` | مطالبات مصروفات بإيصالات + اعتماد وصرف |
| **السلف** | `loans_screen` `/loans` | `loans/list.php`, `create/get/approve/cancel.php` | سلف تُخصم على أقساط تلقائياً |
| **العُهد والأصول** | `assets_screen` `/assets` | `assets/list.php`, `create/approve_return/reject_return.php` | عُهد تُسلّم للموظفين وإدارة إرجاعها |
| **الفروع** | `branch_screen` `/branch/manage` | `branches/list.php`, `create/update/delete.php`, `update_gps.php`, `update_attendance_method.php` | إدارة الفروع وموقع GPS وطريقة الحضور |
| **بوستر QR للفرع** | `branch_qr_poster_screen` `/branch/qr-poster` | `branches/get_qr.php?id=` | توليد بوستر QR قابل للطباعة لتسجيل الحضور |

**الحالة:** ✅ مكتمل.

---

## 11) الخطابات والشهادات (Letters & Certificates)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| مركز الخطابات | `letters_hub_screen` `/letters` | `letters/requests_list.php` |
| تعديل قالب خطاب | `letter_template_edit_screen` `/letters/template/edit` | `templates_list.php`, `template_create/update.php`, `template_delete.php` |
| طلب خطاب | — | `request_create.php`, `request_approve/reject.php` |
| تصدير الخطاب PDF | — | `request_pdf.php?id=` |
| رفع شعار/هوية الشركة | — | `settings/upload_branding.php` |

**الحالة:** ✅ مكتمل (قوالب + طلبات + اعتماد + PDF + هوية مؤسسية).

---

## 12) المستندات المطلوبة وتقاريرها (Documents)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| أنواع المستندات المطلوبة (على مستوى الشركة) | `required_documents_screen` `/settings/required-documents` | `documents/get_required.php`, `create/update/delete/toggle_required.php`, `mark_expired.php` |
| تقرير المستندات (قريبة الانتهاء / منتهية / ناقصة / إحصائيات) | `documents_report_screen` `/reports/documents` | `reports_expiring_soon/expired/missing/stats.php` |

**الحالة:** ✅ مكتمل.

---

## 13) التقارير (Reports)

- **مركز التقارير:** `report_screen` (`/reports`).

| التقرير | الشاشة / المسار | نقطة الـ API |
|---------|-----------------|--------------|
| الحضور | `attendance_report_screen` `/reports/attendance` | `reports/attendance.php` |
| الرواتب | `payroll_report_screen` `/reports/payroll` | `reports/payroll.php` |
| الموظفون | `employees_report_screen` `/reports/employees` | `reports/employees.php` |
| الإجازات | `leaves_report_screen` `/reports/leaves` | `reports/leaves.php` |
| المستندات | `documents_report_screen` `/reports/documents` | (انظر القسم 12) |

- **تصدير PDF:** عبر `pdf_export_service` (حزم `pdf` + `printing`).
- **الحالة:** ✅ مكتمل.

---

## 14) الفئات (Categories)

- **الشاشة:** `categories_screen` (`/settings/categories`).
- **الوظيفة:** تصنيف الموظفين إلى فئات وتعيينهم لها.
- **نقاط الـ API:** `categories/list.php`, `create/update/delete.php`, `assign.php`.
- **الحالة:** ✅ مكتمل.

---

## 15) الورديات (Shifts)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| قائمة الورديات | `shifts_screen` `/shifts` | `shifts/list.php`, `create/update/delete.php` |
| تعيين وردية لموظف | `assign_shift_screen` `/shifts/assign` | `shifts/assign.php` |

**الحالة:** ✅ مكتمل.

---

## 16) الإشعارات (Notifications)

| الميزة | الشاشة / المسار | نقطة الـ API |
|--------|-----------------|--------------|
| قائمة الإشعارات + عدّاد غير المقروء | `notifications_screen` `/notifications` | `notifications/list.php`, `read.php?id=` |
| تفضيلات الإشعارات | `notification_prefs_screen` `/notifications/prefs` | `auth/notification_prefs.php` |
| إشعارات Push (FCM) | `push_notification_service` | `auth/update_fcm_token.php` |

**الحالة:** ✅ مكتمل (Firebase Messaging + تفضيلات).

---

## 17) الإعدادات (Settings)

| الميزة | الشاشة / المسار | الوصف |
|--------|-----------------|-------|
| مركز إعدادات الشركة | `company_settings_hub_screen` `/settings/company-hub` | بوابة لكل إعدادات الشركة (للمالك فقط) |
| إعدادات الشركة | `company_settings_screen` `/settings/company` | بيانات الشركة العامة — ⚠️ `settings/company.php` مُعلّمة كـ TODO (backend) |
| طريقة الحضور | `attendance_method_screen` `/settings/attendance-method` | GPS / QR / بيومتري |
| قواعد الخصم | `deduction_rules_screen` | (انظر القسم 8) |
| إعدادات الإجازات | `leave_settings_screen` | (انظر القسم 9) |
| المستندات المطلوبة | `required_documents_screen` | (انظر القسم 12) |
| إعدادات الحساب الشخصي | `account_settings_screen` `/settings/account` | الملف الشخصي وكلمة المرور |
| إعدادات التطبيق | `app_settings_screen` `/settings/app` | اللغة، الثيم، ...الخ |

**الحالة:** ✅ معظمها مكتمل | ⚠️ `company.php` تحتاج تأكيد جاهزية الـ Backend.

---

## 18) المميزات العامة الشاملة (Cross-cutting)

| الميزة | الملف/الخدمة | الوصف |
|--------|--------------|-------|
| تعدد اللغات (ar/en) + RTL | `locale/translations.dart`, `locale_service` | تبديل اللغة فوري |
| الوضع الفاتح/الداكن | `dark_light_service`, `app_theme` | ثيم متكامل بنظام ألوان `AppColors.light/dark` |
| كشف الاتصال + بانر دون اتصال | `connectivity_service`, `offline_banner` | تنبيه عند انقطاع الإنترنت |
| وضع الصيانة | `maintenance_gate` + Remote Config | إيقاف التطبيق وقت الصيانة |
| التحديث الإجباري/المقترح | `update_gate`, `update_service`, `in_app_update`, `upgrader` | فرض تحديث الإصدار |
| الأعطال والتحليلات | Firebase Crashlytics + Analytics | مراقبة الاستقرار والاستخدام |
| تصدير PDF والطباعة | `pdf_export_service` + `printing` | للتقارير والخطابات والبوسترات |
| الروابط العميقة | `app_links` | فتح التطبيق عبر روابط |
| التخزين الآمن | `flutter_secure_storage`, `get_storage`, `shared_preferences` | حفظ التوكن والتفضيلات |

---

## 19) ملخص الحالة والملاحظات (Action Items)

### ✅ مميزات مكتملة وجاهزة
المصادقة، إعداد الشركة، الأدوار والصلاحيات، لوحة المؤشرات، الموظفون، الحضور (شامل البيومتري والمحطات والعمل دون اتصال)، الرواتب (شامل الملف البنكي وEOSB والقوالب القانونية)، الإجازات، المصروفات، السلف، العُهد، الفروع، الخطابات، المستندات، التقارير، الفئات، الورديات، الإشعارات، الإعدادات العامة، تعدد اللغات والثيمات.

### ⚠️ نقاط تحتاج متابعة (Backend / TODO مذكورة في الكود)
1. **`auth/logout.php`** — نقطة تسجيل الخروج الخلفية مفقودة (مُعلّمة TODO).
2. **تقييمات الأداء (Performance Reviews)** — `performance/list.php` و `create.php` و `delete.php` مُعلّمة بأن الـ Backend مفقود.
3. **`settings/company.php`** — مُعلّمة كـ TODO (تأكد من تنفيذها في الخادم).
4. **تفاصيل فرع مفرد** — لا توجد نقطة `branch detail`؛ يُستخدم `list.php?id=` كحل بديل.
5. **`employees/get_profile.php` مقابل `update/delete`** — التعليق يشير إلى ضرورة تأكد طبقة البيانات من استدعاء النقطة الصحيحة لكل طريقة (GET/PUT/DELETE).

### 🔎 توصيات للمراجعة اليدوية
- التأكد من تطابق أسماء وصلاحيات الأدوار بين التطبيق والـ Backend.
- اختبار مسار العمل دون اتصال (Offline) للحضور ومزامنته.
- التحقق من جاهزية كل النقاط المُعلّمة TODO قبل الإطلاق.

---

*تم إنشاء هذه المراجعة بناءً على المسارات (`app_routes.dart`)، نقاط الـ API (`app_links.dart`)، البنية الكاملة لمجلد `lib`، وقائمة "المزيد" (`MoreScreen`).*
