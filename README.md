# Medjat — منصّة إدارة الحضور والرواتب (HR SaaS)

**Medjat** منصّة متكاملة لإدارة الموارد البشرية (الحضور والانصراف، الورديات، الإجازات، الرواتب، المستندات) مصمّمة لسوق **مصر وشمال إفريقيا**، بواجهات عربية (RTL) أولًا مع دعم الإنجليزية في تطبيق الإدارة. المنصّة **متعدّدة المستأجرين (Multi-tenant)**: كل شركة عميلة بياناتها معزولة، وتُدار اشتراكاتها مركزيًا من فريق Medjat.

تتكوّن المنصّة من **باك إند PHP واحد** يخدم **ثلاثة تطبيقات Flutter**:

```
Medjat/
├── backend_medjet/          ← REST API بلغة PHP 8.x (MySQL 8) — قلب المنصّة
└── front_end/
    ├── medjat_app/          ← تطبيق الموظف (Android / iOS)
    ├── medjat_central/      ← تطبيق الإدارة والموارد البشرية للشركة (Android / iOS)
    └── medjat_admin/        ← لوحة الـ Super Admin للفريق الداخلي (Android)
```

> لكل مشروع ملف `README.md` خاص بتفاصيله. هذا الملف يصف المنصّة ككل وكيفية ترابط أجزائها.

---

## المكوّنات

### 1) الباك إند — `backend_medjet/`
REST API بلغة **PHP 8.x** على قاعدة **MySQL 8**، مستضاف على **Hostinger** (استضافة مشتركة). كل endpoint في ملف منفصل داخل `app/<module>/`، والمنطق المشترك في `core/`.

- **الوحدات (`app/`):** auth، employees، attendance، shifts، schedule، breaks، leaves، payroll، deductions، allowances، bonuses، loans، settlements، bulk_adjustments، documents، assets، branches، categories، managers، roles، stations/station، biometric، reports، analytics، dashboard، notifications، settings، tenant، audit، approvals، onboarding، support، admin، admin_support، admin_app_control، cron …
- **النواة (`core/`):** `Auth` / `AdminAuth` / `BaseApi` / `AdminBaseApi`، `TenantMiddleware` + `PermissionMiddleware` (العزل والصلاحيات)، `PayrollCalculator` + `PayrollCache` + `PayslipPdfService` (الرواتب)، `SettlementCalculator`، `AttendanceMethodResolver`، `GpsService`، `StationQrTokenService`، `NotificationService` + `RemoteConfigService` (Firebase عبر `kreait/firebase-php`)، `EmailService`، `RateLimiter`، `Validator`، `Response`.
- **أخرى:** `migrations/` (مخطّط القاعدة)، `models/`، `scripts/`، `lang/` (i18n)، `uploads/`، `cron/` (مهام مجدولة)، `join.php` و`well_known.php` (روابط الانضمام و deep links).

### 2) تطبيق الموظف — `front_end/medjat_app/`
يستخدمه الموظف لتسجيل الحضور (QR / GPS / التعرّف على الوجه)، ومتابعة الراتب والمستندات، وتقديم طلبات الإجازات والسلف، مع وضع **كشك (Kiosk)** للحضور الجماعي وعمل **offline** يُزامن تلقائيًا. (Android + iOS)

### 3) تطبيق الإدارة — `front_end/medjat_central/`
مركز التحكّم الكامل للشركة: إدارة الموظفين والفروع والفئات، تصميم الورديات والجدول الأسبوعي، اعتماد الإجازات، تشغيل الرواتب والتعديلات الجماعية والتسويات، والتقارير مع التصدير (PDF/Word/DOCX). يدعم العربية والإنجليزية. (Android + iOS)

### 4) لوحة الـ Super Admin — `front_end/medjat_admin/`
للفريق الداخلي: إدارة الشركات العميلة (Tenants) والاشتراكات والخطط والمستخدمين، الدعم الفني، سجل التدقيق، والتحكّم عن بُعد في حالة التطبيقات (تحديث إجباري/صيانة) عبر Firebase Remote Config. (Android)

---

## التقنيات المشتركة

- **الباك إند:** PHP 8.x، MySQL 8، `kreait/firebase-php` (FCM + Remote Config)، استضافة Hostinger.
- **الواجهات:** Flutter / Dart 3.11، إدارة الحالة **GetX**، نمط **MVVM** (طبقات `core / data / logic / view`).
- **الشبكة:** كل تطبيق يغلّف نداءات الـ API في `core/class/crud.dart`، وكل عمليات الكتابة تستخدم **POST** (PUT غير موثوق على Hostinger).
- **Firebase:** مشروع `medjat` — Messaging، Analytics، Crashlytics، Remote Config (+ Auth/Google Sign-In في تطبيق الإدارة، App Check في تطبيق الموظف).
- **التصميم:** خطوط **IBM Plex Sans Arabic** (عربي) و**Geist** (لاتيني/أرقام)، `flutter_screenutil`، `lottie`، دعم Light/Dark.

---

## مفاهيم أساسية في المنصّة

- **تعدّد المستأجرين:** عزل بيانات كل شركة عبر `TenantMiddleware`؛ والصلاحيات عبر `PermissionMiddleware`.
- **نموذج الأدوار دون مالك:** لا يوجد «مالك» للشركة؛ `general_manager` أعلى دور قابل للمنح لأي شخص، مع تطبيق قاعدة «المساوي أو الأدنى» في الـ API.
- **طرق الحضور وتجاوزاتها:** QR / GPS / الوجه، مع حلّ التجاوزات بترتيب: الموظف ← الفئة (اتحاد) ← الفرع ← الشركة، عبر `AttendanceMethodResolver`.
- **قفل الرواتب عند الاعتماد:** الاعتماد يُجمّد أرقام الدورة كاملة؛ يُعرض الرقم المجمّد للمعتمد/المدفوع وتقدير حيّ للمسوّدة.
- **روابط الانضمام:** الرمز + الرابط + الـ QR يتشاركون صفّ تفعيل أحادي الاستخدام، و deep links على `medjatapp.com/join`.
- **التحكّم عن بُعد:** قيم التحديث الإجباري/الصيانة في Firebase Remote Config، يُحرّرها فريق الـ Admin وتقرؤها التطبيقات عند الإقلاع.

---

## الإعداد للتطوير المحلّي

### المتطلّبات
- PHP 8.x + MySQL 8 (الأسهل عبر **MAMP**)
- Flutter SDK ‏`^3.11.1`
- إعداد Firebase (مشروع `medjat`) لملفّات التطبيقات

### 1) قاعدة البيانات والباك إند (MAMP)
- شغّل MAMP — MySQL على المنفذ **`8889`**، المستخدم/كلمة المرور `root/root`، القاعدة `medjat`.
- طبّق المخطّط/الـ migrations من `backend_medjet/migrations/`.
  > ملاحظة: `schema.sql` يستخدم صياغة `ADD COLUMN IF NOT EXISTS` الخاصة بـ MariaDB؛ على MySQL 8 الحيّة تُكتب بعض الـ migrations يدويًا.
- لتشغيل/فحص PHP محليًا استخدم نسخة MAMP (مثال): `/Applications/MAMP/bin/php/php8.x/bin/php`.

### 2) أي تطبيق Flutter
داخل مجلد التطبيق (`front_end/medjat_app` أو `medjat_central` أو `medjat_admin`):

```bash
flutter pub get
```

أنشئ ملف `.env` في جذر التطبيق:

```env
API_HOST = "http://192.168.1.3:8888"
SECURITY_KEY = ""
SECURITY_USER = ""
```

ثم شغّل:

```bash
# medjat_admin / medjat_central (يحمّلان .env كـ asset عند الإقلاع)
flutter run

# medjat_app
flutter run --dart-define-from-file=.env
```

> عند الاختبار على جهاز Android حقيقي مقابل MAMP، استخدم `adb reverse` وامنح cleartext في manifest وضع debug.

---

## معرّفات التطبيقات والمنصّات

| التطبيق | المنصّات | معرّف التطبيق (Android) |
|---------|----------|--------------------------|
| medjat_app | Android · iOS | `com.khawarizmie.medjat` |
| medjat_central | Android · iOS | `com.khawarizmie.medjatCentral` |
| medjat_admin | Android | `com.khawarizmie.medjat_admin` |

---

## البنية والاستضافة

- **الاستضافة:** الباك إند على **Hostinger** (استضافة مشتركة، بلا VPS).
- **النطاق والبريد:** `medjatapp.com` موثّق بالكامل للبريد (Hostinger SMTP + نطاق مخصّص لـ Firebase).
- **Firebase:** مشروع `medjat` (FCM + Remote Config + Analytics/Crashlytics).
