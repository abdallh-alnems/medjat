# frontend — واجهات Medjat

المجلدات مقسّمة **بالتقنية**، لأن ده الفرق اللي بيهمّك في الشغل اليومي: أوامر البناء
والاختبار مختلفة تمامًا بين Flutter و npm.

```
frontend/
├── mobile/      تطبيقات Flutter — أداة `flutter`
│   ├── employee/    تطبيق الموظف (Android / iOS)
│   ├── central/     تطبيق إدارة الشركة (Android / iOS)
│   ├── kiosk/       كشك الفرع (تابلت Android)
│   ├── admin/       لوحة الـ Super Admin الداخلية (Android)
│   └── shared/      حزمة `medjat_shared` — كود مشترك بين تطبيقات Flutter
├── web/         أداة `npm`
│   ├── central/     نسخة الويب من تطبيق الإدارة (Next.js 16)
│   └── site/        الموقع التعريفي والصفحات الثابتة (HTML)
└── desktop/
    └── central/     غلاف Electron فوق web/central → ‏.dmg / .exe
```

`central` بتتكرر تحت `mobile/` و`web/` و`desktop/` عن قصد: دي **نفس المنتج بتلات واجهات**.
نسخة الويب منفذ لتطبيق الموبايل، وتطبيق سطح المكتب غلاف حوالين نسخة الويب — يعني التلاتة
بيتغيّروا مع بعض غالبًا.

## أوامر سريعة

```bash
# أي تطبيق Flutter (من داخل مجلده)
flutter pub get
flutter analyze lib          # لا تستخدم `flutter analyze` وحدها — بتفحص build/ وتطلع أخطاء وهمية

# نسخة الويب
cd web/central && npm run dev

# تطبيق سطح المكتب
cd desktop/central && npm run dev
```

## ملاحظات تخصّ التقسيم

- **اسم مجلد ≠ اسم حزمة.** أسماء حزم Dart لسه زي ما هي (`medjat_app`، `medjat_central`،
  `medjat_admin`، `medjat_kiosk`، `medjat_shared`)، وكذلك `"name"` في package.json
  (`medjat_central_web`، `medjat_central_desktop`). تغييرها كان هيكسر كل `import`
  و`package:` في المشروع، فاتساب المجلدات اتغيّر بس.
- **الحزمة المشتركة** مربوطة بـ `path: ../shared` في pubspec بتاع `employee` و`kiosk`.
  أي نقل تاني لازم يعدّل السطر ده في المشروعين.
- **أصول الحزمة المشتركة** بتتقري بمفتاح
  `packages/medjat_shared/assets/models/mobilefacenet.tflite` — ده اسم الحزمة مش مسار
  مجلد، فما بيتغيّرش مع إعادة التقسيم.
- **`deploy-web.sh`** بيحدد مكانه بـ `dirname $0`، فبيتحرك مع المجلد من غير تعديل.
