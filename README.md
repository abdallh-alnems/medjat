# Permedjat — منصّة إدارة الحضور والرواتب (HR SaaS)

**Permedjat** منصّة متكاملة لإدارة الموارد البشرية (الحضور والانصراف، الورديات، الإجازات، الرواتب، المستندات) مصمّمة لسوق **مصر وشمال إفريقيا**، بواجهات عربية (RTL) أولًا مع دعم الإنجليزية في تطبيق الموظف وتطبيق الإدارة ونسخة الويب (لوحة الـ Super Admin بالعربية فقط). المنصّة **متعدّدة المستأجرين (Multi-tenant)**: كل شركة عميلة بياناتها معزولة، وتُدار اشتراكاتها مركزيًا من فريق Permedjat.

تتكوّن المنصّة من **باك إند PHP واحد** يخدم **ثلاثة تطبيقات Flutter** و**نسخة ويب** بـ Next.js:

```
Permedjat/
├── backend_medjet/          ← REST API بلغة PHP 8.x (MySQL 8) — قلب المنصّة
├── frontend/
│   ├── mobile/              ← تطبيقات Flutter — أداة `flutter`
│   │   ├── employee/        ← تطبيق الموظف (Android / iOS)
│   │   ├── manager/         ← تطبيق الإدارة والموارد البشرية للشركة (Android / iOS)
│   │   ├── kiosk/           ← كشك الفرع (تابلت Android) — حضور بجهاز مشترك
│   │   ├── superadmin/      ← لوحة الـ Super Admin للفريق الداخلي (Android)
│   │   └── shared/          ← حزمة `permedjat_shared` المشتركة بين تطبيقات Flutter
│   ├── web/                 ← أداة `npm`
│   │   ├── manager/         ← نسخة الويب من تطبيق الإدارة (Next.js 16)
│   │   └── site/            ← الموقع التعريفي والصفحات الثابتة (الخصوصية، حذف الحساب، الدعم)
│   └── desktop/
│       └── manager/         ← غلاف Electron فوق web/manager → ‏.dmg / .exe
└── specs/                   ← مواصفات الميزات (spec-kit)
```

> لكل مشروع ملف `README.md` خاص بتفاصيله. هذا الملف يصف المنصّة ككل وكيفية ترابط أجزائها.

---

## المكوّنات

### 1) الباك إند — `backend_medjet/`
REST API بلغة **PHP 8.x** على قاعدة **MySQL 8**، مستضاف على **خادم Hetzner (VPS)** خلف Cloudflare. كل endpoint في ملف منفصل داخل `app/<module>/`، والمنطق المشترك في `core/`.

- **الوحدات (`app/`):** auth، employees، attendance، shifts، schedule، breaks، leaves، payroll، deductions، allowances، bonuses، loans، settlements، bulk_adjustments، documents، assets، branches، categories، managers، roles، biometric، devices، performance، warnings، reports، dashboard، notifications، settings، tenant، audit، support، admin، admin_support، admin_app_control، cron.
- **النواة (`core/`):** `Auth` / `AdminAuth` / `BaseApi` / `AdminBaseApi`، `TenantMiddleware` + `PermissionMiddleware` (العزل والصلاحيات)، `PayrollCalculator` + `PayrollCache` + `PayslipPdfService` (الرواتب)، `SettlementCalculator`، `AttendanceMethodResolver`، `GpsService`، `NetworkVerifier` (شبكات WiFi)، `FaceMatchService` + `BiometricEnrollment` (الوجه)، `ZktecoAdms` + `DevicePunchIngestor` (أجهزة البصمة)، `TenantClock` (توقيت كل شركة)، `NotificationService` + `RemoteConfigService` + `SmartAlertService` (Firebase عبر `kreait/firebase-php`)، `EmailService` / `AuthEmail`، `I18n`، `RateLimiter`، `Validator`، `Response`.
- **أخرى:** `migrations/` (المخطّط + migrations مؤرّخة)، `models/`، `scripts/`، `lang/` (i18n)، `uploads/`، `app/cron/` (مهام مجدولة)، `join.php` و`well_known.php` (روابط الانضمام و deep links)، `device/iclock.php` (نقطة اتصال أجهزة الحضور — راجع `device/README.md`).

### 2) تطبيق الموظف — `frontend/mobile/employee/`
يستخدمه الموظف لتسجيل الحضور (QR / GPS / شبكة WiFi / سيلفي الوجه)، ومتابعة الراتب والمستندات، وتقديم طلبات الإجازات والسلف، مع عمل **offline** يُزامن تلقائيًا. الدخول برقم الهاتف + رمز تفعيل (أو رمز/رابط/QR انضمام). (Android + iOS)

### 3) تطبيق الإدارة — `frontend/mobile/manager/`
مركز التحكّم الكامل للشركة: إدارة الموظفين والفروع والفئات، تصميم الورديات والجدول الأسبوعي، اعتماد الإجازات، تشغيل الرواتب والتعديلات الجماعية والتسويات، ضبط طرق الحضور وشبكات الفروع وأجهزة البصمة، والتقارير مع التصدير (PDF/Word/DOCX). يدعم العربية والإنجليزية. (Android + iOS)

### 4) نسخة الويب — `frontend/web/manager/`
منفذ ويب لتطبيق الإدارة بـ **Next.js 16 (App Router)** و React 19 و TypeScript، يتحدّث إلى **نفس الباك إند ونفس مشروع Firebase** عبر وسيط `/api/[...path]` يحقن بيانات الـ Basic-auth على الخادم. مُستضاف ذاتيًا على نفس خادم Hetzner على `app.permedjat.com`.

### 5) لوحة الـ Super Admin — `frontend/mobile/superadmin/`
للفريق الداخلي: إدارة الشركات العميلة (Tenants) والمستخدمين الداخليين، الدعم الفني، سجل التدقيق، والتحكّم عن بُعد في حالة التطبيقات (تحديث إجباري/صيانة) عبر Firebase Remote Config. (Android)

---

## التقنيات المشتركة

- **الباك إند:** PHP 8.x، MySQL 8، `kreait/firebase-php` (FCM + Remote Config)، `mpdf/mpdf` و`phpoffice/phpword` (التصدير). الخادم الحيّ يعمل بـ PHP 8.5 / MySQL 8.4 / Nginx.
- **الواجهات:** Flutter / Dart 3.11، إدارة الحالة **GetX**، نمط **MVVM** (طبقات `core / data / logic / view`).
- **الويب:** Next.js 16 · React 19 · TypeScript · TanStack Query · Zustand · shadcn + Tailwind · RTL.
- **الشبكة:** كل تطبيق يغلّف نداءات الـ API في `core/class/crud.dart`، وكل عمليات الكتابة تستخدم **POST** (وليس PUT).
- **Firebase:** مشروع `permedjat` — Messaging، Analytics، Crashlytics، Remote Config (+ Auth/Google Sign-In في تطبيق الإدارة، App Check في تطبيق الموظف).
- **التصميم:** خطوط **IBM Plex Sans Arabic** (عربي) و**Geist** (لاتيني/أرقام)، `flutter_screenutil`، `lottie`، دعم Light/Dark.

---

## مفاهيم أساسية في المنصّة

- **تعدّد المستأجرين:** عزل بيانات كل شركة عبر `TenantMiddleware`؛ والصلاحيات عبر `PermissionMiddleware`. لا بد أن تطابق بوابات الواجهة (القوائم/التبويبات) صلاحية كل endpoint، وإلا ظهر خطأ 403 عام للمستخدم محدود الصلاحية.
- **نموذج الأدوار دون مالك:** لا يوجد «مالك» للشركة؛ `general_manager` أعلى دور قابل للمنح لأي شخص، مع تطبيق قاعدة «المساوي أو الأدنى» في الـ API.
- **طرق الحضور وتجاوزاتها:** `qr_gps` / `gps_only` / `wifi_gps` / `face_selfie` / `device` / `manual`، مع حلّ التجاوزات بترتيب: الموظف ← الفئة (اتحاد) ← الفرع ← الشركة، عبر `AttendanceMethodResolver`.
- **التحقق يتم على الخادم:** الهاتف يستخرج بصمة الوجه (embedding) لكن **الخادم** هو من يحسب التطابق ويقرّر، مع nonce أحادي الاستخدام لمنع الإعادة. وشبكة الـ WiFi قيد **إضافي** فوق النطاق الجغرافي لا بديل عنه.
- **مكافحة التلاعب:** رفض الموقع المزيّف (`is_mock_location`) اختياري لكل شركة وعلى Android فقط، وكل محاولة محجوبة تُسجَّل في `attendance_security_logs`.
- **التوقيت لكل شركة:** كل حساب للوقت يمرّ عبر `TenantClock` (من `tenants.timezone`) لا عبر `date()`/`NOW()` المباشرة، وباسم المنطقة الزمنية لا بإزاحة ثابتة.
- **قفل الرواتب عند الاعتماد:** الاعتماد يُجمّد أرقام الدورة كاملة؛ يُعرض الرقم المجمّد للمعتمد/المدفوع وتقدير حيّ للمسوّدة.
- **روابط الانضمام:** الرمز + الرابط + الـ QR يتشاركون صفّ تفعيل أحادي الاستخدام، و deep links على `permedjat.com/join`.
- **التحكّم عن بُعد:** قيم التحديث الإجباري/الصيانة في Firebase Remote Config، يُحرّرها فريق الـ Admin وتقرؤها التطبيقات عند الإقلاع (مع رسالة FCM للتأثير الفوري).

---

## الإعداد للتطوير المحلّي

### المتطلّبات
- PHP 8.x + MySQL 8 (الأسهل عبر **MAMP**)
- Flutter SDK ‏`^3.11.1`
- Node.js 22+ (لنسخة الويب)
- إعداد Firebase (مشروع `permedjat`) لملفّات التطبيقات

### 1) قاعدة البيانات والباك إند (MAMP)
- شغّل MAMP — MySQL على المنفذ **`8889`**، المستخدم/كلمة المرور `root/root`، القاعدة `permedjat`.
- طبّق المخطّط/الـ migrations من `backend_medjet/migrations/`.
  > ملاحظة: `schema.sql` يستخدم صياغة `ADD COLUMN IF NOT EXISTS` الخاصة بـ MariaDB؛ على MySQL 8 الحيّة تُكتب الـ migrations الجديدة يدويًا وتُشغَّل يدويًا.
- لتشغيل/فحص PHP محليًا استخدم نسخة MAMP: `/Applications/MAMP/bin/php/php8.4.15/bin/php`.

### 2) أي تطبيق Flutter
داخل مجلد التطبيق (`frontend/mobile/employee` أو `frontend/mobile/manager` أو `frontend/mobile/superadmin`):

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
# mobile/superadmin و mobile/manager (يحمّلان .env كـ asset عند الإقلاع)
flutter run

# mobile/employee
flutter run --dart-define-from-file=.env
```

> عند الاختبار على جهاز Android حقيقي مقابل MAMP، استخدم `adb reverse` وامنح cleartext في manifest وضع debug.
> للتحليل الساكن استخدم `flutter analyze lib` (التحليل الكامل يفحص ملفات أمثلة FlutterFire داخل `build/` ويظهر أخطاء وهمية).

### 3) نسخة الويب

```bash
cd frontend/web/manager
npm install
cp .env.local.example .env.local   # ثم املأ SECURITY_USER/KEY و NEXT_PUBLIC_*
npm run dev
```

---

## معرّفات التطبيقات والمنصّات

| التطبيق | المنصّات | معرّف التطبيق (Android) |
|---------|----------|--------------------------|
| permedjat_app | Android · iOS | `com.khawarizmie.medjat` |
| permedjat_central | Android · iOS | `com.khawarizmie.medjatCentral` |
| permedjat_admin | Android | `com.khawarizmie.medjat_admin` |
| permedjat_central_web | الويب | `app.permedjat.com` |

---

## البنية والاستضافة

كل شيء يعمل على **خادم Hetzner واحد** (Ubuntu 26.04 — PHP 8.5 / MySQL 8.4 / Nginx) خلف **Cloudflare** (كل السجلات المرئية proxied، وضع Full strict، وجدار ناري يسمح بـ 80/443 من نطاقات Cloudflare فقط). النشر يدوي عبر `rsync`.

| النطاق | الخدمة |
|--------|--------|
| `api.permedjat.com/backend_medjet` | الباك إند PHP |
| `app.permedjat.com` | نسخة الويب (Next.js عبر systemd `permedjat-web.service`) |
| `permedjat.com` + `www` | الموقع التعريفي الثابت + `/join` و`/.well-known/*` |
| `grafana.permedjat.com` | مراقبة (Grafana + Prometheus) |
| `db.permedjat.com` | Adminer لعرض القاعدة (خلف basic-auth) |
| المنفذ `8090` (بـ IP مباشرة) | أجهزة البصمة ZKTeco — HTTP عادي خارج Cloudflare |

- **المهام المجدولة:** `/etc/cron.d/permedjat` بتوقيت القاهرة — ترحيل أرصدة الإجازات 00:00/00:30، تدارك الغياب 23:50، التنبيهات اليومية 07:00، ونسخة احتياطية للقاعدة 02:00 (يُحتفظ بها 14 يومًا).
- **النطاق والبريد:** `permedjat.com` موثّق بالكامل للبريد (SMTP من Hostinger + نطاق مخصّص لـ Firebase)؛ سجلات البريد تبقى DNS-only ولا تُمرَّر عبر Cloudflare.
- **Firebase:** مشروع `permedjat` (FCM + Remote Config + Analytics/Crashlytics + Auth).
