# Medjat Central — تطبيق الإدارة والموارد البشرية

تطبيق **Flutter** للمديرين والموارد البشرية في الشركات العميلة ضمن منصّة **Medjat** لإدارة الحضور والرواتب (HR SaaS) الموجّهة لسوق مصر وشمال إفريقيا. هو **مركز التحكّم الكامل للشركة**: إدارة الموظفين والفروع والورديات والإجازات وتشغيل الرواتب والتقارير. يدعم العربية (RTL) والإنجليزية (LTR).

> هذا أحد تطبيقات المنصّة:
> - **medjat_central** (هذا المشروع) — تطبيق الإدارة/الموارد البشرية للشركة.
> - **medjat_central_web** — نسخة الويب من هذا التطبيق (Next.js 16) على `app.medjatapp.com`.
> - **medjat_app** — تطبيق الموظف (الحضور، الراتب، المستندات).
> - **medjat_admin** — لوحة الـ Super Admin للفريق الداخلي.

---

## الوظائف الأساسية

### المنظومة والهيكل
- **التسجيل والمصادقة:** إنشاء حساب الشركة، تسجيل الدخول، توثيق البريد، استعادة كلمة المرور — عبر **Firebase Auth** و**Google Sign-In**، مع شاشة Onboarding.
- **الفروع** (Branches): إدارة الفروع، توليد **ملصق QR للفرع** (Branch QR Poster) للحضور.
- **الفئات** (Categories): تجميع الموظفين بفئات وإسناد إعدادات على مستوى الفئة.
- **الفريق والصلاحيات** (Team): دعوة مديرين، توليد **رمز دعوة** (Invitation Code)، وإدارة الأدوار. (لا يوجد مالك للشركة؛ `general_manager` هو أعلى دور قابل للمنح، مع تطبيق قاعدة «المساوي أو الأدنى» في الـ API.)

### الموظفون
- **الموظفون** (Employees): إضافة/تعديل/عرض تفاصيل الموظف، مستنداته، وتسوية مستحقاته (Settlement)، وإدارة المنتهية خدماتهم.
- **تسجيل القياسات الحيوية** (Biometric Enrollment): متابعة حالة تسجيل **الوجه** وإعادة تعيينه (التسجيل نفسه ذاتي من تطبيق الموظف)، و**بصمة الإصبع** عبر أجهزة ZKTeco.
- **الأداء** (Performance): مؤشرات أداء الفروع والموظفين ضمن لوحة المعلومات. (وحدة **الإنذارات** `warnings` في الباك إند تظهر حاليًا في نسخة الويب فقط.)
- **المستندات** (Documents): المستندات المطلوبة، تتبّع التسليم، وطلب مستند من موظف بعينه.
- **الأصول** (Assets): تخصيص ومتابعة أصول الشركة لدى الموظفين.

### الحضور والورديات
- **الحضور** (Attendance): سجلات الحضور والانصراف وتعديلها.
- **الحضور اللحظي** (Live Attendance): متابعة حالة الموظفين الآن (داخل/خارج الدوام).
- **طرق الحضور** (Attendance Method): `qr_gps` / `gps_only` / `wifi_gps` / `face_selfie` / `device` / `manual` — مع نظام **تجاوزات (Overrides)** بترتيب: الموظف ← الفئة (اتحاد) ← الفرع ← الشركة (Tenant).
- **شبكات الفروع** (Branch Networks): وضع تعلّم يكتشف نقاط الوصول (BSSID) الخاصة بالفرع تلقائيًا ثم اعتمادها. انتبه: الراوتر الواحد يظهر بعدّة BSSID (2.4/5GHz)، والاعتماد الجزئي يحجب الموظفين.
- **أجهزة البصمة** (Devices): ربط أجهزة ZKTeco (ADMS) بالشركة والفرع، وربط موظف بكل *User ID* على الجهاز، ومتابعة البصمات الواردة.
- **الجدول الأسبوعي والورديات** (Weekly Schedule / Shifts): تصميم جداول الورديات الدوّارة، مسوّدة/نشر (draft/publish)، وإسناد الورديات وأعضائها.
- **الفترات/الاستراحات** (Breaks): تعريف وإدارة فترات الراحة.

### الرواتب والمالية
- **الرواتب** (Payroll): تشغيل دورة الرواتب وعرض كشوف المرتّبات؛ الاعتماد **يُجمّد** أرقام الدورة كاملة (للمعتمد/المدفوع تُعرض القيمة المجمّدة، وللمسوّدة تقدير حيّ).
- **التعديلات الجماعية** (Bulk Adjustments): خصومات/إضافات جماعية بدفعات متتبّعة، بنطاق (الكل/الفرع/الفئة/موظف) وبقيمة ثابتة أو نسبة مئوية.
- **القروض/السلف** (Loans): إدارة قروض الموظفين وأقساطها.
- **قواعد الخصم** (Deduction Rules) و**الإعدادات القانونية للرواتب** (Statutory Payroll Settings).
- **التسويات** (Settlements): تسوية مستحقات نهاية الخدمة.

### الإجازات
- **الإجازات** (Leaves): اعتماد/رفض/تعديل طلبات الإجازات.
- **سياسات ترحيل الرصيد** (Carryover Policies): انتهاء الصلاحية، ترحيل تلقائي عبر cron، تحويل الرصيد لنقد (Encashment) ضمن الرواتب، سياسات متعدّدة المستويات وسقف قانوني.

### التقارير والمتابعة
- **التقارير** (Reports): تقارير الحضور، الموظفين، الإجازات، المستندات، والرواتب — مع **تصدير PDF / Word / DOCX** وطباعة كشوف الرواتب.
- **لوحة المعلومات** (Dashboard): مؤشرات الشركة، الموظفون حسب الحالة، والامتثال المنتهي قريبًا (Expiring Compliance).
- **سجل التدقيق** (Audit Log) و**الدعم الفني** (Support): تذاكر ومحادثة مع فريق Medjat.

### الإعدادات
إعدادات الحساب، إعدادات التطبيق، إعدادات الشركة (Hub موحّد)، طرق الحضور، الإجازات، المستندات المطلوبة، وتفضيلات الإشعارات.

---

## البنية المعمارية

نمط **MVVM** باستخدام **GetX** بطبقات واضحة:

```
lib/
├── core/
│   ├── class/        — CRUD, StatusRequest, HandlingData (تغليف نداءات الـ API)
│   ├── constant/
│   │   ├── routes/   — app_routes, app_pages (+ الـ Bindings)
│   │   ├── locale/   — ترجمات ar / en (AppTranslations)
│   │   ├── theme/    — الألوان والمسافات والثيم
│   │   └── id/       — معرّفات و app_links
│   ├── middleware/   — حماية المسارات
│   ├── services/     — التهيئة، الإشعارات (push/local)، الموقع، اللغة، التوكن،
│   │                   التحديث، والمُصدِّرات: PDF / Word / DOCX (رواتب، حضور، كشوف)
│   ├── shared/       — أزرار، حقول إدخال، layout، dialogs، feedback
│   ├── utils/        — أدوات مساعدة
│   └── widget/       — عناصر واجهة مشتركة
├── data/
│   ├── data_source/remote/   — نداء API لكل وحدة (employee, payroll, leave, shift,
│   │                            attendance, branch, category, loan, document, report،
│   │                            settlement, schedule, biometric, device, support …)
│   └── model/                — نماذج البيانات
├── logic/
│   ├── bindings/     — حقن التبعيات (GetX)
│   └── controller/   — متحكم لكل وحدة وظيفية
└── view/
    ├── screen/       — الشاشات الكاملة (مجموعة لكل وحدة)
    └── widget/       — عناصر واجهة لكل وحدة (dashboard, payroll, report, employee …)
```

**تدفّق البيانات:** `Screen → Controller → DataSource → CRUD (HTTP) → Backend PHP` والعكس، مع `StatusRequest` لإدارة حالات التحميل/النجاح/الخطأ.

---

## التقنيات

- **State management:** GetX (`get: ^4.7.2`) — `GetxController`, `GetBuilder`, `Obx`، و`Bindings`.
- **الشبكة:** فئة `core/class/crud.dart`؛ كل عمليات الكتابة تستخدم **POST** لا PUT (`Auth::requirePost` على الباك إند).
- **المصادقة:** Firebase Auth + Google Sign-In.
- **Firebase:** Core, Auth, Messaging, Analytics, Crashlytics, Remote Config.
- **الإشعارات:** `firebase_messaging` (Push) + `flutter_local_notifications` (محلية) مع `flutter_timezone` / `timezone`.
- **التخزين:** `flutter_secure_storage` (التوكن)، `shared_preferences`، `get_storage`.
- **الأجهزة:** `geolocator` (الموقع)، `permission_handler`، `qr_flutter` (توليد QR)، `country_picker`.
- **التصدير:** `pdf` + `printing` (كشوف الرواتب والتقارير)، `flutter_pdfview`، `open_filex`، `path_provider`، `share_plus`، `file_picker`.
- **UI:** `flutter_screenutil`، `lottie`، خطوط **IBM Plex Sans Arabic** (عربي) و**Geist** (لاتيني/أرقام)، `intl`.
- **التحديثات:** `in_app_update`، `upgrader`، `package_info_plus`، `url_launcher`، `app_links`.

**اللغات:** العربية (RTL، افتراضي) والإنجليزية (LTR) عبر `LocaleService`؛ الاتجاه يتبدّل تلقائيًا. **الثيم:** يتبع النظام (Light/Dark).

**المنصّات المدعومة:** Android و iOS — معرّف التطبيق `com.khawarizmie.medjatCentral`.

---

## الباك إند

REST API بلغة **PHP 8.x** في `backend_medjet/` — كل endpoint في ملف منفصل داخل `backend_medjet/app/<module>/`، والمنطق المشترك في `backend_medjet/core/`. القاعدة **MySQL 8** (محليًا عبر MAMP على المنفذ `8889`، المستخدم/كلمة المرور `root/root`، قاعدة `medjat`؛ والخادم الحيّ Hetzner على `api.medjatapp.com/backend_medjet`).

> بعض الميزات (التعديلات الجماعية، تجاوزات طرق الحضور، ترحيل الإجازات المتقدّم، الجلسة الواحدة النشطة، أجهزة البصمة) تتطلّب **migrations مكتوبة يدويًا** تُشغَّل على قاعدة MySQL 8 الحيّة، لأن `schema.sql` يستخدم صياغة `ADD COLUMN IF NOT EXISTS` الخاصة بـ MariaDB.

> **صلاحيات الواجهة يجب أن تطابق الباك إند:** أي عنصر تنقّل/تبويب يظهر لمستخدم لا يملك صلاحية الـ endpoint سيُنتج 403 يظهر كرسالة «حدث خطأ» عامة.

---

## الإعداد والتشغيل

### المتطلّبات
- Flutter SDK ‏`^3.11.1`
- جهاز/محاكي Android أو iOS
- إعداد Firebase (مشروع `medjat`) — ملفّات `google-services.json` / `GoogleService-Info.plist`
- باك إند Medjat قيد التشغيل (محليًا عبر MAMP أو على الخادم)

### الخطوات

```bash
flutter pub get
```

أنشئ ملف `.env` في جذر المشروع:

```env
API_HOST = "http://192.168.1.3:8888"
SECURITY_KEY = ""
SECURITY_USER = ""
```

> عند الاختبار على جهاز Android حقيقي مقابل MAMP، قد تحتاج `adb reverse` ومنح cleartext في manifest وضع debug.

ثم شغّل التطبيق:

```bash
flutter run
```

> `.env` مُعرّف ضمن `assets` في `pubspec.yaml` ويُحمَّل عند الإقلاع في `initialServices()`.

---

## الأوامر

```bash
flutter run                        # تشغيل
flutter build apk --release        # بناء APK
flutter build appbundle --release  # بناء App Bundle
flutter build ipa --release        # بناء iOS
flutter test                       # الاختبارات
flutter analyze                    # التحليل الساكن
flutter clean && flutter pub get   # تنظيف وإعادة التثبيت
```
