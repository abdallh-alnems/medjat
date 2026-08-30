# Medjat App

تطبيق Flutter للموظف. الواجهة عربية RTL.

## هيكل المشروع

```
Medjat/
├── frontend/mobile/employee/    — تطبيق Flutter (هذا المشروع)
└── backend_medjet/          — PHP REST API
```

## Architecture

MVVM باستخدام GetX:

```
lib/
├── core/
│   ├── class/       — CRUD, StatusRequest, HandlingData
│   ├── constant/    — routes, theme, locale, api, ad IDs
│   ├── middleware/  — حماية المسارات
│   ├── services/    — initialization, notifications, permissions, location,
│   │                  network (WiFi/BSSID), face_embedder + face_liveness,
│   │                  device_integrity, deep_link, update
│   └── shared/      — shared widgets
├── data/
│   ├── data_source/remote/  — API calls per feature
│   └── model/
├── logic/
│   ├── bindings/    — GetX dependency injection
│   └── controller/  — GetX controllers
└── view/
    ├── screen/      — full screens
    └── widget/      — reusable widgets
```

## Tech Stack

- **State:** GetX (`get: ^4.7.2`) — GetxController, GetBuilder, Obx
- **HTTP:** `core/class/crud.dart` — CRUD class wraps all API calls; كل الكتابة **POST**
- **Auth:** رقم الهاتف + رمز تفعيل (أو رمز/رابط/QR انضمام) — لا Google Sign-In هنا
- **Firebase:** Core, Messaging, Analytics, Crashlytics, Remote Config, App Check
- **Attendance:** `mobile_scanner` (QR)، `geolocator` (GPS)، `network_info_plus` (BSSID لطريقة
  `wifi_gps`)، `camera` + `google_mlkit_face_detection` + `tflite_flutter` (سيلفي الوجه)
- **Offline:** `Hive` لطابور الحضور + `connectivity_plus` للمزامنة عند عودة الاتصال
- **UI:** flutter_screenutil، خطوط IBM Plex Sans Arabic (عربي) + Geist (لاتيني/أرقام)،
  flutter_svg، lottie
- **Localization:** العربية (ar) افتراضيًا + الإنجليزية، `flutter_localizations`
- **Env:** flutter_dotenv — ملف `.env` مطلوب

## Conventions

- Controllers: `*Controller` extends `GetxController`
- Models: `*Model` suffix
- Bindings: `*Binding` suffix
- API responses handled via `StatusRequest` enum + `HandlingData`
- Light/Dark mode via `DarkLightService`
- **لا تُصدِّق حكم العميل:** الهاتف يستخرج بصمة الوجه فقط، والخادم يحسب التطابق ويقرّر.
  إرسال `matched: true` من التطبيق ليس مصدر ثقة.

## Commands

```bash
flutter run --dart-define-from-file=.env
flutter build apk --release
flutter build appbundle --release
flutter test
flutter analyze lib   # احصر التحليل في كودك؛ flutter analyze (كامل) يفحص ملفات أمثلة FlutterFire داخل build/ ويظهر أخطاء وهمية
flutter clean && flutter pub get
```

## Backend PHP

كل endpoint في ملف منفصل داخل `backend_medjet/app/<module>/`، والمنطق المشترك في `backend_medjet/core/`.

## ملاحظات

- **بصمة الوجه انتقلت إلى حزمة مشتركة.** `FaceEmbedder` و`LivenessDetector` وملف الموديل
  `mobilefacenet.tflite` صاروا في `frontend/mobile/shared/`، ويستوردهم التطبيق عبر
  `package:medjat_shared/medjat_shared.dart`. السبب: تطبيق الكيوسك يرسل embeddings إلى نفس
  العمود (`employees.face_embedding`)، فلو وُجدت نسختان من كود الاستخراج وتباعدتا، يتوقف
  التطابق **بصمت** دون خطأ في أي مكان.
  - الموديل يُحمَّل من `packages/medjat_shared/assets/models/mobilefacenet.tflite`؛ المسار
    المجرّد لا يعمل لأن الأصل يملكه package.
  - عند تعديل الحزمة شغّل `flutter pub get` في **كلا** التطبيقين — مسار path لا يُعاد حلّه تلقائيًا.
  - إن فشل التحميل تظهر `face_unavailable` — وهذا مقصود: الفشل ظاهر ولا يُقبَل الحضور صامتًا.
- `SCREENSHOT_MODE` (dart-define) يخفي الإعلانات لالتقاط صور المتجر.
