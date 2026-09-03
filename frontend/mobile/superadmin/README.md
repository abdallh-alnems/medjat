# Permedjat Admin — لوحة تحكم الـ Super Admin

تطبيق **Flutter** للفريق الداخلي (Super Admin) في منصة **Permedjat** لإدارة الحضور والرواتب (HR SaaS) الموجّهة لسوق مصر وشمال إفريقيا. يُدار من خلاله **كل عملاء المنصّة (Tenants)**، إضافةً إلى الدعم الفني والتحكّم في حالة التطبيقات عن بُعد. الواجهة عربية بالكامل (RTL).

> هذا أحد تطبيقات المنصّة:
> - **permedjat_admin** (هذا المشروع) — لوحة الـ Super Admin للفريق الداخلي.
> - **permedjat_central** (+ نسخة الويب `permedjat_central_web`) — تطبيق الإدارة/الموارد البشرية للشركات العميلة.
> - **permedjat_app** — تطبيق الموظف.

---

## الوظائف الأساسية

| الوحدة | الوصف |
|--------|-------|
| **لوحة المعلومات** (Dashboard) | مؤشرات عامة عن المنصّة: عدد الشركات، النشاط، والنمو. |
| **الشركات** (Tenants) | قائمة العملاء ببحث وترقيم صفحات، وكل بطاقة تعرض الحجم وآخر نشاط وجهة الاتصال. **تشغيل عميل جديد** يُنشئ الشركة + دعوة «مدير عام» لبريد المالك في معاملة واحدة. |
| **ملف الشركة** (Tenant Detail) | كل ما نعرفه عن عميل: الإعدادات (طريقة الحضور، بصمة الوجه، الحضور من المتصفح)، الأحجام، آخر حضور وآخر دخول، جهة الاتصال والملاحظات الداخلية، ومديرو الشركة. ومنها **دعوة مدير** عند فقدان العميل لكل مديريه. |
| **تشخيص الحضور** (Diagnostics) | يُشغَّل عند الطلب من داخل ملف الشركة: إحصاءات مطابقة الوجه ونسبة الرفض وآخر المحاولات، سجلات الحماية (موقع مزيّف/خارج النطاق…)، تغطية شبكات كل فرع، أجهزة ZKTeco والأكشاك وآخر ظهور لها، وتوزيع قنوات التسجيل خلال ٣٠ يومًا. |
| **مديرو الشركات** (Company Admins) | دفتر هاتف العملاء: بحث، اسم الشركة، آخر دخول، واتصال/واتساب/بريد بلمسة. ومنه **إيقاف/تفعيل** حساب، **إرسال رابط إعادة تعيين كلمة المرور**، و**دخول تشخيصي** لحساب العميل. |
| **حسابي** (Account) | بيانات المشرف، آخر دخول والأجهزة النشطة، **تغيير كلمة المرور** (يسجّل خروج بقية الأجهزة)، وإصدار التطبيق. |
| **سجل التدقيق** (Audit) | كل ما فعلناه: منفّذ العملية، الإجراء، الهدف، والتفاصيل (`payload`) — ببحث وفلاتر وترقيم صفحات. |
| **الدعم الفني** (Support) | صندوق وارد للتذاكر ومحادثة لكل تذكرة، مع **مرفقات** (صور/PDF) في الاتجاهين تُخدَم عبر endpoint مُصادَق عليه لا برابط عام. |
| **التحكّم في التطبيق** (App Control) | التحكّم عن بُعد في حالة تطبيقات المنصّة عبر **Firebase Remote Config**: فرض التحديث الإجباري، تفعيل وضع الصيانة، وعرض/تعديل قيم التحكّم (مع رسالة FCM للتأثير الفوري). |
| **الإشعارات** (Notifications) | إرسال إشعار للمنصّة كلها أو لشركة تُختار من قائمة، مع تحديد **الجمهور**: مديرو الشركات أو الموظفون أو الجميع. |

> **ملاحظة:** جداول الاشتراكات والخطط أُزيلت من المخطّط (`2026_06_14_drop_subscriptions_plans.sql`)، ولا توجد شاشات لها في التطبيق حاليًا.

> **الدخول التشخيصي (Impersonation):** يقتصر على دور `superadmin`، ويتطلّب **سببًا مكتوبًا**، ويُسجَّل في سجلّنا **وفي سجل الشركة نفسها**. يُنتِج رمز Firebase مؤقّتًا (ساعة واحدة) تستهلكه صفحة `/impersonate` في `permedjat_central_web`.

> **تنبيه — Firebase غير مُهيّأ على أندرويد في هذا التطبيق:** لا يوجد `android/app/google-services.json` ولا إضافة `google-services` في Gradle، لذا يفشل `Firebase.initializeApp()` بصمت — وهذا يعني أن **إشعارات الدعم (FCM) لا تصل فعليًا**، وأن Crashlytics (المُضاف في الكود) لن يعمل حتى تُضاف التهيئة. الخطوات مكتوبة في تعليق أعلى `lib/main.dart`.

> يعتمد التطبيق سياسة **جلسة واحدة نشطة لكل مسؤول** (single active session): أحدث جهاز يسجّل الدخول يُلغي ما عداه، عبر `active_device_id` وترويسة `X-Device-Id`.

---

## البنية المعمارية

نمط **MVVM** باستخدام **GetX** بطبقات واضحة:

```
lib/
├── core/
│   ├── class/        — CRUD, StatusRequest, HandlingData (تغليف نداءات الـ API)
│   ├── constant/
│   │   ├── routes/   — app_routes.dart, app_pages.dart (+ الـ Bindings لحقن التبعيات)
│   │   ├── theme/    — الألوان، المسافات (app_spacing)، الثيم
│   │   └── id/       — معرّفات ثابتة
│   ├── middleware/   — auth_middleware (حماية المسارات)
│   ├── services/     — connectivity, dark_light, push_notification, token storage
│   └── shared/       — أزرار، حقول إدخال، layout، عناصر feedback مشتركة
├── data/
│   ├── data_source/remote/   — نداء API لكل وحدة (tenant, user, admin_account,
│   │                            audit, support, app_control, dashboard, notification,
│   │                            admin_auth, device)
│   └── model/                — نماذج البيانات
├── logic/
│   ├── bindings/     — حقن التبعيات (GetX)
│   └── controller/   — متحكم لكل وحدة (tenant, user, audit, support, app_control,
│                       dashboard, notification, auth)
└── view/
    └── screen/       — splash, auth, dashboard, tenants, users, admin_account,
                        audit, support, app_control, notifications
```

**تدفّق البيانات:** `Screen → Controller → DataSource → CRUD (HTTP) → Backend PHP` والعكس، مع إدارة حالات التحميل/النجاح/الخطأ عبر `StatusRequest`.

---

## التقنيات

- **State management:** GetX (`get: ^4.7.2`) — `GetxController`, `GetBuilder`, `Obx`، و`Bindings` لحقن التبعيات في `app_pages.dart`.
- **الشبكة:** فئة `core/class/crud.dart` تُغلّف كل نداءات الـ HTTP، والاستجابات تُدار عبر enum `StatusRequest`.
- **Firebase:** `firebase_core` + `firebase_messaging` (استقبال إشعارات الدعم، وقراءة قيم التحكّم من Remote Config على جهة الباك إند).
- **التخزين:** `flutter_secure_storage` (التوكن)، `shared_preferences`.
- **UI:** `flutter_screenutil`، `lottie`، خطوط **IBM Plex Sans Arabic** (عربي) و**Geist** (لاتيني/أرقام)، `intl`.
- **أخرى:** `connectivity_plus`، `package_info_plus`، `flutter_dotenv`.

اللغة الافتراضية **العربية** فقط (RTL)، والثيم الافتراضي **Light** (مع دعم Dark).

**المنصّات المدعومة:** Android فقط — معرّف التطبيق `com.khawarizmie.permedjat_admin`.

---

## الباك إند

REST API بلغة **PHP 8.x** في `backend_medjet/` — كل endpoint في ملف منفصل داخل `backend_medjet/app/<module>/` (وحدات المسؤول: `admin`، `admin_support`، `admin_app_control`). تعتمد المصادقة على `AdminAuth` / `AdminBaseApi`، والقاعدة **MySQL 8** (محليًا عبر MAMP؛ والخادم الحيّ Hetzner على `api.permedjatapp.com/backend_medjet`). كل عمليات الكتابة تستخدم **POST** (وليس PUT).

---

## الإعداد والتشغيل

### المتطلّبات
- Flutter SDK ‏`^3.11.1`
- جهاز/محاكي Android
- باك إند Permedjat قيد التشغيل (محليًا عبر MAMP أو على الخادم)

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

ثم شغّل التطبيق:

```bash
flutter run
```

> `.env` مُعرّف ضمن `assets` في `pubspec.yaml` ويُحمَّل عبر `dotenv.load()` عند الإقلاع.

---

## الأوامر

```bash
flutter run                        # تشغيل
flutter build apk --release        # بناء APK
flutter build appbundle --release  # بناء App Bundle
flutter test                       # الاختبارات
flutter analyze                    # التحليل الساكن
flutter clean && flutter pub get   # تنظيف وإعادة التثبيت
```
