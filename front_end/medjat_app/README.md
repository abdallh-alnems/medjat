# Medjat App — تطبيق الموظف

تطبيق **Flutter** للموظفين ضمن منصة **Medjat** لإدارة الحضور والرواتب (HR SaaS) الموجّهة لسوق مصر وشمال إفريقيا. الواجهة عربية بالكامل (RTL).

> هذا أحد ثلاثة تطبيقات في المنصة:
> - **medjat_app** — تطبيق الموظف (هذا المشروع): الحضور والانصراف، الراتب، المستندات.
> - **medjat_central** — تطبيق الإدارة/الموارد البشرية: اعتماد الإجازات، تشغيل الرواتب، إدارة الفروع.
> - تطبيق الـ Super Admin — للفريق الداخلي.

## الوظائف الأساسية

- **تسجيل الدخول** عبر بريد/كلمة مرور، مع استعادة كلمة المرور.
- **الحضور والانصراف** بمسح رمز QR الخاص بالفرع (`mobile_scanner`) مع التحقق من **الموقع الجغرافي** (`geolocator`) والمسافة من الفرع.
- **العمل دون اتصال (Offline)**: تخزين عمليات الحضور محليًا عبر `Hive` ومزامنتها تلقائيًا عند عودة الاتصال (`connectivity_plus`) مع شريط تنبيه offline.
- **حالة اليوم** (Today Status) تعرض ما إذا كان الموظف مسجّل الدخول/الخروج والمسافة من الفرع.
- **الإشعارات** عبر Firebase Cloud Messaging.
- **بوابة التحديث الإجباري والصيانة** (`update_gate` / `maintenance_gate`) مدفوعة من Firebase Remote Config.

## البنية المعمارية

نمط **MVVM** باستخدام **GetX**:

```
lib/
├── core/
│   ├── class/       — CRUD, StatusRequest, HandlingData (تغليف نداءات الـ API)
│   ├── constant/    — routes, theme, firebase_options, app_links
│   ├── middleware/  — auth_middleware
│   ├── services/    — connectivity, location, token storage, update, dark/light
│   ├── shared/      — أزرار، حقول إدخال، layout, offline banner
│   └── widget/      — update_gate, maintenance_gate
├── data/
│   ├── data_source/remote/  — نداءات API لكل ميزة (auth, attendance, home)
│   └── model/               — user_model, today_status_model
├── logic/
│   ├── bindings/    — حقن التبعيات (GetX)
│   └── controller/  — متحكمات auth / attendance / home
└── view/
    └── screen/      — splash, auth, home, attendance
```

## التقنيات

- **State management:** GetX (`get: ^4.7.2`) — `GetxController`, `GetBuilder`, `Obx`.
- **HTTP:** فئة `core/class/crud.dart` تُغلّف كل نداءات الـ API، والاستجابات تُدار عبر enum `StatusRequest`.
- **Firebase:** Core, Messaging, Analytics, Crashlytics, Remote Config, App Check.
- **التخزين:** `Hive` (طابور الحضور offline)، `flutter_secure_storage` (التوكن)، `shared_preferences`.
- **الأجهزة:** `geolocator` (الموقع)، `mobile_scanner` (QR)، `permission_handler`.
- **UI:** `flutter_screenutil`، خطوط **IBM Plex Sans Arabic** (عربي) و **Geist** (لاتيني/أرقام)، `lottie`.
- **التحديثات:** `in_app_update`، `upgrader`، `rate_my_app`.
- **البيئة:** `flutter_dotenv` — ملف `.env` مطلوب.

اللغة الافتراضية **العربية** فقط، والاتجاه RTL، والثيم الافتراضي **Light** (مع دعم Dark).

## الباك إند

REST API بلغة **PHP** في `backend_medjat/` — كل endpoint في ملف منفصل داخل `backend_medjat/app/`.

## الإعداد والتشغيل

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
flutter run --dart-define-from-file=.env
```

## الأوامر

```bash
flutter run --dart-define-from-file=.env   # تشغيل
flutter build apk --release                # بناء APK
flutter build appbundle --release          # بناء App Bundle
flutter test                               # الاختبارات
flutter analyze                            # التحليل الساكن
flutter clean && flutter pub get           # تنظيف وإعادة التثبيت
```
