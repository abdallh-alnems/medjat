# تقرير مراجعة الكود — Rebuild Employee App (phone + activation code)

> **موجّه للنموذج/المطوّر الذي سينفّذ الإصلاحات.** هذا تقرير مراجعة فقط — لم يُعدَّل أي كود إنتاجي. كل النقاط أدناه مُتحقَّق منها بقراءة الكود الفعلي ومقارنته بـ `specs/001-rebuild-employee-app/` (spec.md, plan.md, contracts/, tasks.md).
>
> **التاريخ:** 2026-06-01 | **الفرع:** `001-rebuild-employee-app`
> **النطاق المُراجَع:** backend (`backend_medjet`) + Flutter app (`front_end/medjat_app`).

---

## 0) الخلاصة التنفيذية

التنفيذ **جيد جداً في النواة (auth + الـ endpoints + التطبيق الأساسي)** ومطابق للعقود إلى حد كبير. الاختبارات تمر بالكامل:

- ✅ `flutter analyze` → **0 أخطاء** (47 تحذير/info فقط، أغلبها بسيط).
- ✅ `flutter test` → **161 اختبار، كلها نجحت**.
- ✅ لا أثر لـ `firebase_auth` / `google_sign_in` في `lib/` (FR-022 / SC-010 محقّقان).
- ✅ الـ backend لم يمسّ `Auth::authenticateUser` (القاعدة الذهبية محفوظة).

**لكن توجد مشاكل تمنع اعتبار التنفيذ "مكتملاً على أكمل وجه":**
- **مشكلة حرجة واحدة** (تناقض مع المواصفة + كسر وظيفي): تعديل الملف الشخصي.
- **عدة مشاكل عالية الأثر في الكيوسك (US7):** ثغرات وظيفية تجعل الكيوسك لا يعمل فعلياً كما هو.
- مشاكل متوسطة ومنخفضة (كود ميت، تحذيرات، تفاصيل ناقصة).

**الحكم:** النواة (US1–US6) قابلة للإطلاق بعد إصلاح مشكلة الملف الشخصي. أما **الكيوسك (US7) فغير مكتمل وظيفياً** ويحتاج عملاً إضافياً قبل الاستخدام.

---

## 1) مشاكل حرجة (Critical) — يجب إصلاحها

### C-1 — تعديل الملف الشخصي يخالف المواصفة، وغالباً مكسور وظيفياً
**الملفات:**
- `front_end/medjat_app/lib/view/screen/profile/my_profile_screen.dart` (زر `Icons.edit_outlined` + `_showEditDialog` + `TextField` لتعديل الاسم)
- `front_end/medjat_app/lib/logic/controller/profile/profile_controller.dart` → `updateProfile({name})`
- `front_end/medjat_app/lib/data/data_source/remote/profile_data/profile_data.dart` → يضرب `AppLinks.updateProfile`
- `front_end/medjat_app/lib/core/constant/id/app_links.dart` → `updateProfile => /app/auth/update_profile.php`
- `backend_medjet/app/auth/update_profile.php` → **ما زال يستخدم `Auth::authenticateUser(db())`**

**المشكلة (سببان):**
1. **تناقض مع المواصفة:** المواصفة قرّرت صراحةً (FR-019 + Clarification جلسة 2026-05-31 + قسم Out of Scope) أن **ملف الموظف للعرض فقط، ولا يجوز تعديله من تطبيق الموظف**. لكن الشاشة تعرض زر تعديل ونافذة تحرير الاسم.
2. **كسر وظيفي:** `update_profile.php` يصادق عبر `authenticateUser` (Firebase token الإداري). تطبيق الموظف يرسل `X-Employee-Token` فقط، لذلك أي محاولة تعديل ستُرفض (401/400) — الزر لا يعمل من الأساس.

**الإصلاح المطلوب (اختر A — المطابق للمواصفة):**
- **A (موصى به):** احذف زر التعديل و`_showEditDialog` من `my_profile_screen.dart`، واحذف `updateProfile` من `profile_controller.dart` و`profile_data.dart` و`AppLinks.updateProfile`. اجعل الشاشة عرضاً فقط (FR-019). (لا حاجة لتعديل الـ backend حينها.)
- **B (إن قرّر صاحب المشروع لاحقاً السماح بالتعديل):** غيّر المواصفة أولاً، ثم أنشئ `app/employees/update_my_profile.php` يستخدم `authenticateEmployee`، ولا تستخدم `update_profile.php` المشترك. **لا تعدّل `update_profile.php` الحالي** (يخدم الإدارة).

---

## 2) مشاكل عالية الأثر (High) — الكيوسك (US7) غير مكتمل وظيفياً

> الكيوسك مبني هيكلياً (نماذج + controller + شاشتان + binding + routes) لكن **التدفق غير موصول بالكامل**، فلن يعمل فعلياً.

### H-1 — قائمة الموظفين لا تُحمَّل أبداً (الكيوسك يبقى على "جاري التحميل…")
**الملفات:** `lib/logic/controller/station/station_controller.dart`، `lib/view/screen/kiosk/kiosk_home_screen.dart`
**المشكلة:** الدالتان `loadRoster()` و`syncStation()` معرّفتان لكن **لا تُستدعيان من أي مكان** (تحقّقت بـ grep — الاستدعاء الوحيد هو التعريف نفسه). و`StationController` **لا يملك `onInit/onReady`**. النتيجة: بعد الاقتران (`activate`) ينتقل لـ `kioskHome`، لكن `employees` تبقى فارغة → الشاشة تعرض دائماً مؤشّر "جاري تحميل الموظفين…" بلا نهاية، ولا يمكن تسجيل أي حضور.
**الإصلاح:** استدعِ `syncStation()` ثم `loadRoster()` بعد نجاح `activate` (وفي `onInit` لـ kioskHome عند استعادة جلسة كيوسك محفوظة)، وأضِف دورة تحديث دورية إن لزم.

### H-2 — التحقق البيومتري غير منفّذ (دائماً `fingerprint` بلا تحقق فعلي)
**الملف:** `lib/view/screen/kiosk/kiosk_home_screen.dart` → `_handleCheckIn` يستدعي `checkInOut(employeeId, method: 'fingerprint')` فقط.
**المشكلة:** لا يوجد أي التقاط/مطابقة وجه أو بصمة على الجهاز (FR-027/FR-028)، ولا احترام لـ `station_methods` (face_only/fingerprint_only/both) القادم من إعدادات الفرع، ولا إرسال `confidence`، ولا anti-spoofing. مجرد الضغط على بطاقة الموظف يسجّل حضوراً — وهذا **يخالف نموذج التحقق المطلوب ويسمح بالتلاعب** (أي شخص يضغط اسم أي موظف). الـ `method` ثابت `'fingerprint'` ويتجاهل إعداد الفرع.
**الإصلاح:** نفّذ تدفق المطابقة على الجهاز (T061 spike): قراءة `station.methods`، تشغيل بصمة الإصبع عبر `local_auth` و/أو نموذج وجه على الجهاز، حساب `confidence` ومقارنته بـ `station.confidenceThreshold`، ثم إرسال `method` الصحيح. هذه هي صميم US7.

### H-3 — التسجيل (enrollment) غير موصول بواجهة
**الملف:** `station_data.dart` فيه `enrollBiometric(...)` لكن **لا توجد شاشة/زر يستدعيها** (تحقّقت بـ grep: لا استدعاء في الكود). FR-030 (تسجيل بصمة/وجه الموظف على الكيوسك بحماية PIN) غير منفّذ في الواجهة.
**الإصلاح:** أضِف تدفق enrollment محمي بـ `verifyAdminPin` (شاشة/حوار) يستدعي `enrollBiometric`. (مرتبط بـ H-2 — بلا enrollment لا تنجح المطابقة.)

### H-4 — `kiosk_pair_screen` لا يمسح QR رغم وجود `mobile_scanner`
**الملف:** `lib/view/screen/kiosk/kiosk_pair_screen.dart` — إدخال يدوي نصّي فقط لـ `qr_payload`.
**المشكلة:** المواصفة (US7 سيناريو 1) والعقد ينصّان على **مسح رمز QR** من لوحة الإدارة. الحزمة `mobile_scanner` متاحة في `pubspec`. الإدخال اليدوي وحده غير عملي لـ `qr_payload` (عادةً نص طويل/مشفّر).
**الإصلاح:** أضِف مسح QR عبر `mobile_scanner` (مع إبقاء الإدخال اليدوي كخيار احتياطي).

### H-5 — لا يوجد heartbeat/استعادة جلسة عند فتح كيوسك مُقترن مسبقاً
**الملف:** `station_controller.dart` — `_startHeartbeat()` يُستدعى فقط داخل `activate()`. لو أُعيد فتح التطبيق على جهاز كيوسك مُقترن سابقاً (يوجد `station_token` محفوظ)، **لا شيء يوجّهه إلى `kioskHome`** (الـ splash يوجّه فقط حسب `auth_token` للموظف)، ولا heartbeat يبدأ.
**الإصلاح:** في `splash_screen._init()` تحقّق من `getStationToken()` ووجّه إلى `kioskHome` إن وُجد؛ وفي `onInit` لـ kioskHome ابدأ heartbeat + sync.

### H-6 — تعارض في إعداد الاعتماديات: `StationData` مُسجّلة مرتين، و`StationController` قد لا يُحقن في وقت `activate`
**الملفات:** `lib/core/constant/routes/app_pages.dart` (يسجّل `StationData` في `AppBindings` **و** في route binding)، `lib/logic/bindings/station_binding.dart`.
**المشكلة:**
- `StationData` تُسجَّل عبر `Get.lazyPut` في `AppBindings` (سطر 52) **وأيضاً** في `StationBinding` و route binding — ازدواج غير ضروري (يعمل لكنه فوضوي).
- الأهم: في `kiosk_pair_screen` يُستدعى `Get.find<StationController>()`. `StationController` يُسجَّل عبر `StationBinding` المربوط بـ route `kioskPair`/`kioskHome`. تأكّد أن الـ binding يُنفَّذ فعلاً قبل أول `Get.find` (يبدو سليماً عبر `GetPage.binding`، لكن وجود `StationData` في مكانين قد يسبب لبساً عند الصيانة). راجِع وثبّت مصدراً واحداً للحقن.
**الإصلاح:** أبقِ تسجيل station في `StationBinding` فقط، واحذف `Get.lazyPut<StationData>` من `AppBindings`.

---

## 3) مشاكل متوسطة (Medium)

### M-1 — كود ميت ومضلّل في `station_data.dart`
**الملف:** `lib/data/data_source/remote/station_data/station_data.dart`
**المشكلة:** الكلاس `AppLinksStation` بالكامل (أسطر ~5–33) والحقل `StationData._baseHost` (أسطر ~38–45) **غير مستخدمين إطلاقاً** ويرجعان سلسلة فارغة؛ كما أن `AppLinksStation._base()` فيه متغيّر `linkBase` غير مستخدم. المسارات الفعلية تُبنى عبر `_stationUrl()` باستخدام `AppLinks.base` (وهذا الصحيح). الكود الميت يولّد تحذيرات `unused_element` ويربك المراجعة.
**الإصلاح:** احذف `AppLinksStation` كاملاً و`_baseHost`. (هذا ما اقترحه المراجع؛ لم يُطبَّق بناءً على طلبك بعدم التعديل.)

### M-2 — `home_controller` يجب التأكد أنه يقرأ حالة اليوم من `get_my_attendance`
**المهمة المرجعية:** T040. لم أتحقق من تفاصيل `home_controller.dart` في هذه المراجعة. تأكّد أن الرئيسية تعرض حالة اليوم (checked_in/out) فعلياً من `attendanceMonth(...)`، وأن check_in/out يحدّثانها.
**الإصلاح:** مراجعة يدوية + اختبار.

### M-3 — معالجة 401 المركزية قد تتعارض مع تدفّق الكيوسك
**الملف:** `lib/main.dart` → `CRUD.onSessionExpired` يمسح جلسة الموظف ويذهب لـ `login`.
**المشكلة:** نداءات الكيوسك تستخدم `X-Station-Token`. لو رجع الخادم 401 على نداء كيوسك (token محطة غير صالح)، سيُشغّل نفس المعالج فيذهب لـ `login` ويمسح جلسة الموظف — سلوك غير صحيح لجهاز كيوسك. الخادم لمحطة مقفلة يرجع 403 (مُعالَج)، لكن token محطة ملغى قد يرجع 401.
**الإصلاح:** ميّز نداءات المحطة (مثلاً لا تُطلق `onSessionExpired` عندما `useStationToken == true`، وبدلاً من ذلك عالج 401 محلياً في `StationController`).

### M-4 — `device_info_plus` غير مضافة؛ `device_model` يرسل اسم نظام التشغيل فقط
**الملف:** `auth_data.dart` → `deviceModel = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'`.
**المشكلة:** ليست خطأً (الخطة جعلت `device_info_plus` اختيارية)، لكن `device_model` لن يكون موديل الجهاز الحقيقي. مقبول لـ v1؛ وثّقه فقط.

---

## 4) مشاكل منخفضة (Low) / تحسينات

### L-1 — 47 تحذير/info في `flutter analyze`
أبرزها: `unawaited_futures` (splash, controllers, main) — يُفضّل لفّها بـ `unawaited(...)` أو `await`؛ imports غير مستخدمة في ملفات الاختبار؛ `prefer_const`؛ `deprecated_member_use` (`value:` في `leave_screen.dart:91` → استبدله بـ `initialValue:`). لا شيء منها يكسر البناء.

### L-2 — `kiosk_pair_screen` import غير مستخدم
`import '../../../../core/class/status_request.dart';` غير مستخدم (تحذير).

### L-3 — رسائل/أكواد الأخطاء
الرسائل العربية مطابقة للعقد في login (403/404). جيد. تأكّد فقط أن شاشة الراتب تعرض "لا توجد قسيمة لهذا الشهر" على 404 (T046) — يحتاج تأكيد يدوي في `payroll_screen.dart`.

### L-4 — ملف `CLAUDE.md` في الجذر
أنشأه سكربت تحديث سياق الوكيل من قالب (untracked، فيه placeholders). غير ضارّ. احذفه أو املأه. `front_end/medjat_app/CLAUDE.md` سليم ولم يُمسّ.

---

## 5) ما تم تنفيذه بشكل صحيح (للتأكيد — لا تلمسه)

**Backend:**
- `Auth::authenticateEmployee` مطابق للعقد تماماً، و`authenticateUser` لم يُمسّ. ✅
- `EmployeeAuthTokenModel`: `issue` / `findActiveByPlain` (يحدّث `last_used_at`) / `revokeByPlain` — كلها مطابقة. ✅
- `ActivationCodeModel::markUsedByDevice` يخزّن `'device:'+id`، و`markUsed` القديمة باقية. ✅
- `employee_login.php`: تطبيع الهاتف، معاملة واحدة (transaction)، إعادة الحالة إلى `active`، إنشاء/ربط admin خفيف بـ `firebase_uid='employee:'+id` (يتفادى قيد UNIQUE على NULL)، يستخدم `AdminModel::create` الموجود فعلاً، يصدر token. مطابق للعقد. ✅
- `employee_logout.php` ✅.
- تبديل المصادقة في: `leaves/apply.php` (+409 overlap)، `attendance/{check_in,check_out,get_my_attendance,sync_offline}`، `payroll/get_slip`، `auth/update_fcm_token`، `auth/notification_prefs`، `notifications/{list,read}` — كلها تحوّلت إلى `authenticateEmployee`. ✅
- siblings جديدة بدل تعديل المشترك: `leaves/my_balance.php`، `employees/my_profile.php`. ✅
- `activate_employee.php` القديم حُذف (مقبول — Firebase activation لم يعد مستخدماً).

**App (النواة):**
- `crud.dart`: إزالة Firebase، `X-Employee-Token` + `X-Station-Token` (عبر `useStationToken`)، `X-Tenant-Id`، معالج 401 مركزي (`onSessionExpired`). ✅
- `token_storage_service.dart`: `getOrCreateDeviceId` (UUID آمن)، `clearSession` (يبقي device_id)، `clearAll` (يعيد كتابة device_id)، station token. ✅
- `app_links.dart` مطابق للعقد (المسار الصحيح `constant/id/`). ✅
- `auth_data` / `auth_controller` / `login_screen` / `splash_screen`: تدفّق الهاتف+الكود، حفظ token+user، تسجيل FCM بعد الدخول، 403/404 → رسائل عربية. ✅
- إزالة `firebase_auth`/`google_sign_in` من pubspec مع إبقاء messaging/crashlytics/analytics/remote_config/app_check. ✅
- الاختبارات: 161 ناجحة (login screen تتحقق من غياب Google/email — حارس SC-010). ✅

---

## 6) خريطة الإصلاحات مقابل المهام (tasks.md)

| المهمة | الحالة | ملاحظة |
|---|---|---|
| T005–T009 (backend auth core) | ✅ مكتمل | مطابق للعقد |
| T010–T012 (employee_login/logout + curl) | ✅ مكتمل (curl يحتاج تشغيل يدوي على MAMP) | |
| T013–T023 (app auth core US1) | ✅ مكتمل | |
| T024–T027 (US2 session/401) | ✅ مكتمل | راجع M-3 (تعارض مع الكيوسك) |
| T028–T034 (US3 leave) | ✅ مكتمل | |
| T035–T043 (US4 attendance) | ✅ غالباً | راجع M-2 (حالة اليوم بالرئيسية) |
| T044–T046 (US5 payroll) | ⚠️ راجع L-3 (حالة لا قسيمة) | |
| T047–T054 (US6 profile/docs/notif/fcm) | ⚠️ **C-1**: الملف للعرض فقط مخالَف | |
| T055–T062 (US7 kiosk) | ❌ **غير مكتمل**: H-1..H-6 | الهيكل موجود، التدفق ناقص |
| T063–T069 (polish) | جزئي | analyze فيه تحذيرات؛ smoke test الإدارة لم يُؤكَّد |

---

## 7) قائمة إصلاح مرتّبة بالأولوية (افعلها بهذا الترتيب)

1. **C-1**: اجعل الملف الشخصي للعرض فقط (احذف زر/حوار التعديل + `updateProfile` + `AppLinks.updateProfile`). [حرج، يخالف المواصفة]
2. **H-1**: استدعِ `syncStation()` + `loadRoster()` بعد `activate` وفي `onInit` لـ kioskHome. [بدونها الكيوسك لا يعمل]
3. **H-2 + H-3**: نفّذ المطابقة البيومترية على الجهاز + تدفّق enrollment محمي بـ PIN، مع احترام `station_methods`/`confidenceThreshold`. [صميم US7]
4. **H-5**: توجيه splash إلى kioskHome عند وجود station_token + بدء heartbeat.
5. **H-4**: مسح QR في kiosk_pair عبر `mobile_scanner`.
6. **H-6 + M-1 + M-3**: تنظيف حقن station، حذف الكود الميت، وعزل 401 الكيوسك عن معالج جلسة الموظف.
7. **M-2 / L-3**: تأكيد حالة اليوم بالرئيسية وحالة "لا قسيمة" بالراتب.
8. **L-1/L-2/L-4**: تنظيف التحذيرات والـ imports وملف CLAUDE.md الجذري.
9. شغّل **بوابة curl** في `quickstart.md` على MAMP، و**smoke test لتطبيق الإدارة** (FR-023/SC-008).

---

## 8) كيف تحقّقت (للمراجع التالي)
- `flutter analyze` و`flutter test` فعلياً (النتائج أعلاه).
- قراءة كل ملفات الـ backend الجديدة/المعدّلة ومقارنتها بـ `contracts/`.
- قراءة ملفات التطبيق الأساسية والكيوسك بالكامل.
- `grep` للتأكد من: غياب Firebase Auth، استدعاءات `loadRoster/syncStation/enrollBiometric`، طريقة مصادقة `update_profile.php`.
- لم يُعدَّل أي كود إنتاجي أثناء المراجعة.
