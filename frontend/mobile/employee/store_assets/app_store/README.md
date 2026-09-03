# أصول App Store — بيرمدجات (تطبيق الموظف) iOS

تطبيق الموظف (bundle `com.khawarizmie.permedjat`). iPhone.

## 📁 المحتويات
```
app_store/
├── icon/app_icon_1024.png        ← أيقونة 1024×1024 (بلا شفافية)
├── make_screenshots.py            ← سكربت التأطير (للغتين)
└── screenshots/
    ├── raw/{en,ar}/               ← اللقطات الخام من المحاكي
    ├── iphone_6_9/{en,ar}/        ← نهائية 1320×2868 (شاشة 6.9")
    └── iphone_6_5/{en,ar}/        ← نهائية 1284×2778 (شاشة 6.5") ← ارفع هذه إن طلب الخطأ
```
8 لقطات لكل لغة: الحضور · بياناتي · راتبي · الإجازات · المستندات · السُلَف · العُهد · حسابي.

## 📝 نصوص App Store
**اسم التطبيق (≤30):** عربي `بيرمدجات للموارد البشرية` · EN `Permedjat HR & Attendance`
**Subtitle (≤30):** عربي `حضور ورواتب وإجازات` · EN `Attendance, payslips & leaves`
**Keywords (≤100):**
```
HR,attendance,payslip,salary,leaves,clock in,QR,documents,advance,employee
موارد بشرية,حضور,راتب,إجازات,مستندات,سلفة,موظف
```
**الوصف:** (نفس وصف Google Play في `../../play_store_assets/README.md`)

## 🔗 روابط App Store Connect
- Privacy Policy: `https://permedjat.com/privacy-policy`
- Support: `https://permedjat.com`

## 🔑 بيانات مراجعة (Sign-in) — دائمة لا تنتهي
- رقم الهاتف: `+201000000000` (بعد +20 اكتب `1000000000`)
- كود التفعيل: `PERMEDJAT2026`
```
Sign in with the phone number and activation code above (Egypt +20). No SMS/OTP.
This is a permanent reviewer employee account with sample data; all screens are accessible.
```

## ملاحظات
- لقطات iOS التُقطت على محاكي بعد تعطيل `mobile_scanner` مؤقتاً (GoogleMLKit بلا arm64 للمحاكي) — أُعيد بعد الالتقاط. لا يؤثر على بناء الإصدار للجهاز.
- في الواجهة الإنجليزية قد يظهر سبب خصم "غياب يوم" بالعربي (يولّده الـbackend) — تجميلي فقط.
