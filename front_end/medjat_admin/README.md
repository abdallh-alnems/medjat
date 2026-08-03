# Medjat Admin — لوحة تحكم الـ Super Admin

تطبيق **Flutter** للفريق الداخلي (Super Admin) في منصة **Medjat** لإدارة الحضور والرواتب (HR SaaS) الموجّهة لسوق مصر وشمال إفريقيا. يُدار من خلاله **كل عملاء المنصّة (Tenants)**، إضافةً إلى الدعم الفني والتحكّم في حالة التطبيقات عن بُعد. الواجهة عربية بالكامل (RTL).

> هذا أحد تطبيقات المنصّة:
> - **medjat_admin** (هذا المشروع) — لوحة الـ Super Admin للفريق الداخلي.
> - **medjat_central** (+ نسخة الويب `medjat_central_web`) — تطبيق الإدارة/الموارد البشرية للشركات العميلة.
> - **medjat_app** — تطبيق الموظف.

---

## الوظائف الأساسية

| الوحدة | الوصف |
|--------|-------|
| **لوحة المعلومات** (Dashboard) | مؤشرات عامة عن المنصّة: عدد الشركات، النشاط، والنمو. |
| **الشركات** (Tenants) | عرض/إنشاء/تعديل/تعليق الشركات العميلة ومتابعة حالة كل شركة. |
| **المستخدمون** (Users) | إدارة حسابات الـ Super Admin الداخليين. |
| **حسابي** (Admin Account) | بيانات حساب المسؤول وكلمة المرور والجهاز النشط. |
| **سجل التدقيق** (Audit) | استعراض عمليات التدقيق والأحداث الحسّاسة عبر المنصّة. |
| **الدعم الفني** (Support) | صندوق وارد للتذاكر (Inbox) ومحادثة لكل تذكرة (Thread) مع الشركات. |
| **التحكّم في التطبيق** (App Control) | التحكّم عن بُعد في حالة تطبيقات المنصّة عبر **Firebase Remote Config**: فرض التحديث الإجباري، تفعيل وضع الصيانة، وعرض/تعديل قيم التحكّم (مع رسالة FCM للتأثير الفوري). |
| **الإشعارات** (Notifications) | إرسال واستعراض الإشعارات، مع استقبال إشعارات الدعم عبر FCM. |

> **ملاحظة:** جداول الاشتراكات والخطط أُزيلت من المخطّط (`2026_06_14_drop_subscriptions_plans.sql`)، ولا توجد شاشات لها في التطبيق حاليًا.

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

**المنصّات المدعومة:** Android فقط — معرّف التطبيق `com.khawarizmie.medjat_admin`.

---

## الباك إند

REST API بلغة **PHP 8.x** في `backend_medjet/` — كل endpoint في ملف منفصل داخل `backend_medjet/app/<module>/` (وحدات المسؤول: `admin`، `admin_support`، `admin_app_control`). تعتمد المصادقة على `AdminAuth` / `AdminBaseApi`، والقاعدة **MySQL 8** (محليًا عبر MAMP؛ والخادم الحيّ Hetzner على `api.medjatapp.com/backend_medjet`). كل عمليات الكتابة تستخدم **POST** (وليس PUT).

---

## الإعداد والتشغيل

### المتطلّبات
- Flutter SDK ‏`^3.11.1`
- جهاز/محاكي Android
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
