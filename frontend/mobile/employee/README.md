# Permedjat App — تطبيق الموظف

تطبيق **Flutter** للموظفين ضمن منصة **Permedjat** لإدارة الحضور والرواتب (HR SaaS) الموجّهة لسوق مصر وشمال إفريقيا. الواجهة عربية بالكامل (RTL). من خلاله يسجّل الموظف حضوره، ويتابع راتبه ومستنداته، ويقدّم طلبات الإجازات والسلف.

> هذا أحد تطبيقات المنصّة:
> - **permedjat_app** (هذا المشروع) — تطبيق الموظف: الحضور والانصراف، الراتب، المستندات.
> - **permedjat_central** (+ نسخة الويب `permedjat_central_web`) — تطبيق الإدارة/الموارد البشرية: اعتماد الإجازات، تشغيل الرواتب، إدارة الفروع.
> - **permedjat_admin** — لوحة الـ Super Admin للفريق الداخلي.

---

## الوظائف الأساسية

### الدخول والحضور
- **تسجيل الدخول** برقم الهاتف + **رمز التفعيل**، و**الانضمام برمز QR** (Join Scan) لتفعيل الحساب عبر رابط/رمز/QR أحادي الاستخدام.
- **الحضور والانصراف** بعدّة طرق حسب إعداد الشركة (تُحلّ عبر `AttendanceMethodResolver` بترتيب: الموظف ← الفئة ← الفرع ← الشركة):
  - **مسح QR** الخاص بالفرع (`mobile_scanner`) — `qr_gps`.
  - **الموقع الجغرافي** (GPS Check-in) مع التحقق من المسافة من الفرع (`geolocator`) — `gps_only`.
  - **شبكة الفرع (WiFi)** عبر قراءة الـ BSSID (`network_info_plus`) — `wifi_gps`، وهو قيد **إضافي فوق** النطاق الجغرافي لا بديل عنه.
  - **سيلفي الوجه** (`camera` + `google_mlkit_face_detection` + `tflite_flutter`) — `face_selfie`، مع **تسجيل ذاتي للوجه** (Face Enroll) مرّة واحدة.
- **منتقي طريقة الحضور** (Attendance Method Picker) حسب التجاوزات المُعرّفة من الإدارة، و**حالة اليوم** (Status Card) توضح تسجيل الدخول/الخروج والمسافة من الفرع.
- **العمل دون اتصال (Offline):** تخزين عمليات الحضور محليًا عبر `Hive` ومزامنتها تلقائيًا عند عودة الاتصال (`connectivity_plus`) مع شريط تنبيه offline.

> **التحقق يتم على الخادم:** التطبيق يستخرج بصمة الوجه (embedding) فقط، والخادم هو من يحسب التطابق ويقرّر (مع nonce أحادي الاستخدام لمنع الإعادة). كذلك قد ترفض الشركة الموقع المزيّف (`is_mock_location`) وتُحجب المحاولة من الخادم وتُسجَّل.

### الطلبات والخدمات الذاتية
- **الإجازات** (Leaves): تقديم/تعديل طلبات الإجازات ومتابعة حالتها.
- **السلف** (Advances): تقديم طلب سلفة ومتابعته.
- **الاستراحات** (Breaks): تقديم/متابعة فترات الراحة.
- **الراتب** (Payroll): عرض كشف الراتب وتفاصيله.
- **مستنداتي** (My Documents): استعراض المستندات المطلوبة ورفعها.
- **أصولي** (My Assets): الأصول المخصّصة للموظف.
- **ملفّي الشخصي** (My Profile).

### النظام
- **الإشعارات** عبر Firebase Cloud Messaging مع إشعارات محلية.
- **بوابة التحديث الإجباري والصيانة** مدفوعة من Firebase Remote Config.
- **التحقق من سلامة الجهاز** (Device Integrity) عبر `safe_device` (كشف الـ root/VPN/الموقع المزيّف) مع شاشة حجب عند اكتشاف VPN.

---

## البنية المعمارية

نمط **MVVM** باستخدام **GetX**:

```
lib/
├── core/
│   ├── class/        — CRUD, StatusRequest, HandlingData (تغليف نداءات الـ API)
│   ├── constant/     — routes, theme, locale, strings, id (app_links)
│   ├── middleware/   — auth_middleware (حماية المسارات)
│   ├── services/     — initialization, connectivity, location, network (WiFi/BSSID),
│   │                   token storage, push/local notifications, deep_link,
│   │                   device_integrity, update, locale, dark/light,
│   │                   face_embedder + face_liveness (سيلفي الوجه)
│   ├── shared/       — أزرار، حقول إدخال، layout، offline banner
│   ├── utils/        — أدوات مساعدة
│   └── widget/       — update gate / maintenance gate وعناصر مشتركة
├── data/
│   ├── data_source/remote/   — نداء API لكل ميزة (auth, attendance, home, leave,
│   │                            advance, break, payroll, profile, asset,
│   │                            notification)
│   └── model/                — نماذج البيانات
├── logic/
│   ├── bindings/     — حقن التبعيات (GetX)
│   └── controller/   — متحكم لكل ميزة (attendance + face, home, leave, advance,
│                       break, payroll, profile, asset, auth, notification)
└── view/
    └── screen/       — splash, auth, home, attendance (QR/GPS/face check-in +
                        face enroll), leave, advance, break, payroll, documents,
                        asset, profile, settings, notifications, security
```

**تدفّق البيانات:** `Screen → Controller → DataSource → CRUD (HTTP) → Backend PHP` والعكس، مع `StatusRequest` لإدارة حالات التحميل/النجاح/الخطأ.

---

## التقنيات

- **State management:** GetX (`get: ^4.7.2`) — `GetxController`, `GetBuilder`, `Obx`.
- **الشبكة:** فئة `core/class/crud.dart` تُغلّف كل نداءات الـ API؛ كل عمليات الكتابة تستخدم **POST**.
- **Firebase:** Core, Messaging, Analytics, Crashlytics, Remote Config, App Check.
- **التخزين:** `Hive` (طابور الحضور offline)، `flutter_secure_storage` (التوكن)، `shared_preferences`، `get_storage`.
- **الأجهزة والاستشعار:** `geolocator` (الموقع)، `network_info_plus` (BSSID لشبكة الفرع)، `mobile_scanner` (QR)، `camera`، `google_mlkit_face_detection` + `tflite_flutter` + `image` (سيلفي الوجه)، `safe_device`، `permission_handler`.
- **الملفّات والوسائط:** `image_picker`، `file_picker`، `qr_flutter`، `flutter_pdfview`، `open_filex`، `path_provider`.
- **UI:** `flutter_screenutil`، `lottie`، خطوط **IBM Plex Sans Arabic** (عربي) و**Geist** (لاتيني/أرقام)، `intl`، `country_picker`.
- **التحديثات والروابط:** `in_app_update`، `upgrader`، `rate_my_app`، `app_links` (Deep Links)، `url_launcher`، `package_info_plus`.
- **البيئة:** `flutter_dotenv` — ملف `.env` مطلوب.

اللغة الافتراضية **العربية** (RTL) مع دعم الإنجليزية، والثيم الافتراضي **Light** (مع دعم Dark).

**المنصّات المدعومة:** Android و iOS — معرّف التطبيق `com.khawarizmie.permedjat` (منشور أيضًا على Huawei AppGallery).

---

## نموذج التعرّف على الوجه

طريقة `face_selfie` تحتاج ملف **`assets/models/mobilefacenet.tflite`** وهو **غير موجود في المستودع** (المواصفات في `assets/models/README.md`). بدونه تفشل `FaceEmbedder.load()` وتظهر رسالة `face_unavailable` — وهذا سلوك مقصود: الفشل ظاهر ولا يُقبَل الحضور صامتًا.

---

## الباك إند

REST API بلغة **PHP 8.x** في `backend_medjet/` — كل endpoint في ملف منفصل داخل `backend_medjet/app/<module>/`، والمنطق المشترك في `backend_medjet/core/`. القاعدة **MySQL 8** (محليًا عبر MAMP على المنفذ `8889`، قاعدة `permedjat`؛ والخادم الحيّ Hetzner على `api.permedjatapp.com/backend_medjet`).

> **روابط الانضمام (Join):** الرمز + الرابط + الـ QR يتشاركون صفّ تفعيل أحادي الاستخدام، والـ deep links على `permedjatapp.com/join` — مع خطوات نشر يدوية (migration، ملف `.well-known`، capability على iOS).

---

## الإعداد والتشغيل

### المتطلّبات
- Flutter SDK ‏`^3.11.1`
- جهاز/محاكي Android أو iOS
- إعداد Firebase (مشروع `permedjat`) — ملفّات `google-services.json` / `GoogleService-Info.plist`
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
flutter analyze lib                        # التحليل الساكن (احصره في lib)
flutter clean && flutter pub get           # تنظيف وإعادة التثبيت
```
