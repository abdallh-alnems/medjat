# Medjat App — تطبيق الموظف

تطبيق **Flutter** للموظفين ضمن منصة **Medjat** لإدارة الحضور والرواتب (HR SaaS) الموجّهة لسوق مصر وشمال إفريقيا. الواجهة عربية بالكامل (RTL). من خلاله يسجّل الموظف حضوره، ويتابع راتبه ومستنداته، ويقدّم طلبات الإجازات والسلف، إضافةً إلى وضع **الكشك (Kiosk)** للحضور الجماعي على جهاز مشترك.

> هذا أحد ثلاثة تطبيقات في المنصّة:
> - **medjat_app** (هذا المشروع) — تطبيق الموظف: الحضور والانصراف، الراتب، المستندات.
> - **medjat_central** — تطبيق الإدارة/الموارد البشرية: اعتماد الإجازات، تشغيل الرواتب، إدارة الفروع.
> - **medjat_admin** — لوحة الـ Super Admin للفريق الداخلي.

---

## الوظائف الأساسية

### الدخول والحضور
- **تسجيل الدخول** عبر بريد/كلمة مرور مع استعادة كلمة المرور، و**الانضمام برمز QR** (Join Scan) لتفعيل الحساب عبر رابط/رمز/QR أحادي الاستخدام.
- **الحضور والانصراف** بعدّة طرق حسب إعداد الشركة:
  - **مسح QR** الخاص بالفرع (`mobile_scanner`).
  - **الموقع الجغرافي** (GPS Check-in) مع التحقق من المسافة من الفرع (`geolocator`).
  - **التعرّف على الوجه** (face) عبر `google_mlkit_face_detection` + `tflite_flutter`.
- **منتقي طريقة الحضور** (Attendance Method Picker) حسب التجاوزات المُعرّفة من الإدارة، و**حالة اليوم** (Status Card) توضح تسجيل الدخول/الخروج والمسافة من الفرع.
- **العمل دون اتصال (Offline):** تخزين عمليات الحضور محليًا عبر `Hive` ومزامنتها تلقائيًا عند عودة الاتصال (`connectivity_plus`) مع شريط تنبيه offline.

### وضع الكشك (Kiosk)
جهاز مشترك في الفرع للحضور الجماعي: **إقران الجهاز** (Pair)، الصفحة الرئيسية، الحضور **بالوجه** أو **بالـ QR**، وإعدادات الكشك.

### الطلبات والخدمات الذاتية
- **الإجازات** (Leaves): تقديم/تعديل طلبات الإجازات ومتابعة حالتها.
- **السلف** (Advances): تقديم طلب سلفة ومتابعته.
- **الاستراحات** (Breaks): تقديم/متابعة فترات الراحة.
- **الراتب** (Payroll): عرض كشف الراتب وتفاصيله.
- **مستنداتي** (My Documents): استعراض المستندات المطلوبة ورفعها.
- **أصولي** (My Assets): الأصول المخصّصة للموظف.
- **محطة QR** (My Station QR) و**ملفّي الشخصي** (My Profile).

### النظام
- **الإشعارات** عبر Firebase Cloud Messaging مع إشعارات محلية.
- **بوابة التحديث الإجباري والصيانة** مدفوعة من Firebase Remote Config.
- **التحقق من سلامة الجهاز** (Device Integrity) عبر `safe_device` (كشف الـ root/الأجهزة المخترقة).

---

## البنية المعمارية

نمط **MVVM** باستخدام **GetX**:

```
lib/
├── core/
│   ├── class/        — CRUD, StatusRequest, HandlingData (تغليف نداءات الـ API)
│   ├── constant/     — routes, theme, locale, strings, id (app_links)
│   ├── middleware/   — auth_middleware (حماية المسارات)
│   ├── services/     — initialization, connectivity, location, token storage,
│   │                   push/local notifications, deep_link, device_integrity,
│   │                   update, locale, dark/light, face (التعرّف على الوجه)
│   ├── shared/       — أزرار، حقول إدخال، layout، offline banner
│   ├── utils/        — أدوات مساعدة
│   └── widget/       — update gate / maintenance gate وعناصر مشتركة
├── data/
│   ├── data_source/remote/   — نداء API لكل ميزة (auth, attendance, home, leave,
│   │                            advance, break, payroll, profile, asset, station,
│   │                            notification)
│   └── model/                — نماذج البيانات
├── logic/
│   ├── bindings/     — حقن التبعيات (GetX)
│   └── controller/   — متحكم لكل ميزة (attendance, home, leave, advance, break,
│                       payroll, profile, asset, station, auth, notification)
└── view/
    └── screen/       — splash, auth, home, attendance, kiosk, leave, advance,
                        break, payroll, documents, asset, station, profile,
                        settings, notifications
```

**تدفّق البيانات:** `Screen → Controller → DataSource → CRUD (HTTP) → Backend PHP` والعكس، مع `StatusRequest` لإدارة حالات التحميل/النجاح/الخطأ.

---

## التقنيات

- **State management:** GetX (`get: ^4.7.2`) — `GetxController`, `GetBuilder`, `Obx`.
- **الشبكة:** فئة `core/class/crud.dart` تُغلّف كل نداءات الـ API؛ كل عمليات الكتابة تستخدم **POST**.
- **Firebase:** Core, Messaging, Analytics, Crashlytics, Remote Config, App Check.
- **التخزين:** `Hive` (طابور الحضور offline)، `flutter_secure_storage` (التوكن)، `shared_preferences`، `get_storage`.
- **الأجهزة والاستشعار:** `geolocator` (الموقع)، `mobile_scanner` (QR)، `camera`، `google_mlkit_face_detection` + `tflite_flutter` (التعرّف على الوجه)، `safe_device`، `permission_handler`.
- **الملفّات والوسائط:** `image_picker`، `file_picker`، `qr_flutter`، `flutter_pdfview`، `open_filex`، `path_provider`.
- **UI:** `flutter_screenutil`، `lottie`، خطوط **IBM Plex Sans Arabic** (عربي) و**Geist** (لاتيني/أرقام)، `intl`، `country_picker`.
- **التحديثات والروابط:** `in_app_update`، `upgrader`، `rate_my_app`، `app_links` (Deep Links)، `url_launcher`، `package_info_plus`.
- **البيئة:** `flutter_dotenv` — ملف `.env` مطلوب.

اللغة الافتراضية **العربية** فقط (RTL)، والثيم الافتراضي **Light** (مع دعم Dark).

**المنصّات المدعومة:** Android و iOS — معرّف التطبيق `com.khawarizmie.medjat`.

---

## الباك إند

REST API بلغة **PHP 8.x** في `backend_medjat/` — كل endpoint في ملف منفصل داخل `backend_medjat/app/`، والـ queries في `backend_medjat/core/queries/`. القاعدة **MySQL 8** (محليًا عبر MAMP على المنفذ `8889`، قاعدة `medjat`).

> **روابط الانضمام (Join):** الرمز + الرابط + الـ QR يتشاركون صفّ تفعيل أحادي الاستخدام، والـ deep links على `medjatapp.com/join` — مع خطوات نشر يدوية (migration، ملف `.well-known`، capability على iOS).

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

> عند الاختبار على جهاز Android حقيقي مقابل MAMP، استخدم `adb reverse` وامنح cleartext في manifest وضع debug.

ثم شغّل التطبيق:

```bash
flutter run --dart-define-from-file=.env
```

---

## الأوامر

```bash
flutter run --dart-define-from-file=.env   # تشغيل
flutter build apk --release                # بناء APK
flutter build appbundle --release          # بناء App Bundle
flutter build ipa --release                # بناء iOS
flutter test                               # الاختبارات
flutter analyze                            # التحليل الساكن
flutter clean && flutter pub get           # تنظيف وإعادة التثبيت
```
