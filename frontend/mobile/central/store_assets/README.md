# Store Assets — ميدجات للإدارة

كل أصول رفع التطبيق على المتجرين في مكان واحد.

```
store_assets/
├── google_play/   ← أصول Google Play (Android · حزمة com.khawarizmie.medjat_central)
│   ├── icon/                  أيقونة 512×512 + المصدر 1024
│   ├── feature_graphic/       الرسم المميز 1024×500
│   ├── screenshots/           لقطات الهاتف 1080×1920
│   ├── data_safety/           نموذج Data Safety (CSV)
│   ├── make_screenshots.py    سكربت تأطير اللقطات
│   └── README.md              نصوص بطاقة المتجر + بيانات المراجعة
│
└── app_store/     ← أصول App Store (iOS · حزمة com.khawarizmie.medjatCentral)
    ├── icon/                  أيقونة 1024×1024 (بلا شفافية)
    ├── screenshots/iphone_6_9/
    │   ├── en/  (8 لقطات إنجليزي 1320×2868)
    │   └── ar/  (8 لقطات عربي 1320×2868)
    ├── make_screenshots.py    سكربت تأطير اللقطات (للغتين)
    └── README.md              نصوص App Store + روابط + بيانات المراجعة
```

لكل متجر مجلده وتفاصيله في `README.md` بداخله.
