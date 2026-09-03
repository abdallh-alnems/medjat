# أصول متجر Google Play — بيرمدجات (تطبيق الإدارة / Central)

كل ما تحتاجه لرفع بطاقة المتجر لتطبيق **الإدارة** (permedjat_central)، في مكان واحد.

> ملاحظة: هذا تطبيق **المدير / صاحب العمل** لإدارة الموظفين والحضور والرواتب — وليس تطبيق الموظف.
> اسم الحزمة (applicationId): `com.khawarizmie.medjatCentral`

## 📁 محتويات المجلد

```
play_store_assets/
├── icon/
│   ├── app_icon_512.png         ✅ رمز التطبيق (512×512) — ارفعه في "رمز التطبيق"
│   └── icon_master_1024.png     ✅ المصدر الأصلي (1024×1024) للتعديل عند الحاجة
├── feature_graphic/
│   └── feature_graphic_1024x500.png  ✅ الرسم المميز (1024×500) — جاهز للرفع
├── screenshots/
│   ├── raw/                     ⏳ ضع هنا اللقطات الخام من التطبيق (01.png 02.png …)
│   ├── make_screenshots.py      ✅ سكربت يحوّل الخام إلى لقطات متجر مُصمّمة
│   └── (تُنتَج آلياً) 01_dashboard.png … 05_reports.png
└── data_safety/
    └── data_safety_import.csv   ✅ نموذج "أمان البيانات" — استورده في Play Console
```

### ما الجاهز وما المتبقّي
- ✅ **الأيقونة** (512 + المصدر 1024) — منسوخة من `branding/icon_master.png`.
- ✅ **الرسم المميز (Feature graphic)** — مُولّد بنفس أسلوب التطبيق الأول (تدرّج أخضر + أيقونة + "بيرمدجات للإدارة").
- ✅ **أمان البيانات (Data Safety CSV)** — مُولّد من قالب Play الرسمي ومضبوط على بيانات تطبيق الإدارة (783 سطراً). للاستيراد: Play Console → App content → Data safety → Import. أبرز ما صُرّح به: الاسم/البريد/الهاتف/الحساب، الموقع (دقيق+تقريبي عبر geolocator)، المعرّفات (FCM)، الملفات والمستندات، سجلّات الأعطال والأداء (Crashlytics)، تفاعل المستخدم (Analytics) — كله **مُجمَّع وغير مُشارَك** ومشفّر أثناء النقل. طريقة إنشاء الحساب: بريد + كلمة مرور + Google/Apple.
- ⏳ **لقطات الشاشة (الوحيد المتبقّي):** تحتاج صوراً حقيقية من شاشات التطبيق (Google تشترط أن تمثّل التطبيق فعلاً — لا تُختلق). الخطوات:
  1. شغّل التطبيق على حساب المراجعة (بعد ملئه ببيانات تجريبية).
  2. صوّر 5 شاشات وضعها في `screenshots/raw/` باسم `01.png … 05.png` بالترتيب:
     لوحة المعلومات · الموظفون · الحضور · الرواتب · التقارير/الإجازات.
  3. شغّل: `python3 screenshots/make_screenshots.py`
     → ستُنتَج لقطات 1080×1920 مُصمّمة (خلفية خضراء + إطار هاتف + عنوان عربي) جاهزة للرفع.

## 📝 نصوص بطاقة المتجر (عربي)

**اسم التطبيق (≤30):**
```
بيرمدجات للإدارة
```

**الوصف المختصر (≤80):**
```
أدِر موظفيك: حضور، رواتب، إجازات، مستندات وتقارير من مكان واحد لصاحب العمل
```

**الوصف الكامل (≤4000):**
```
بيرمدجات للإدارة — تطبيق صاحب العمل ومدير الموارد البشرية لإدارة فريقك بالكامل من هاتفك.

بيرمدجات للإدارة مخصّص لأصحاب الأعمال والمديرين لإدارة شؤون الموظفين والحضور والرواتب في مكان واحد، بواجهة عربية بسيطة.

أبرز المزايا:

• لوحة معلومات فورية
تابع الحضور المباشر وأعداد الموظفين وأهم المؤشرات في لمحة.

• إدارة الموظفين
أضِف الموظفين، وزّعهم على الفروع والأقسام، وأدِر مستنداتهم وعقودهم.

• الحضور والانصراف
راجع سجلات الحضور، وأضِف تسجيلاً يدوياً، واضبط طرق الحضور (GPS / QR) لكل فرع.

• الرواتب وكشوف الأجر
احتسب الرواتب والبدلات والخصومات، واعتمد كشوف الأجر، وصدّرها بصيغة PDF أو ملف بنكي.

• الإجازات والاستراحات والسلف
راجع طلبات الإجازة والاستراحات والسلف ووافق عليها أو ارفضها.

• المستندات والمستلزمات والعُهد
تابع مستندات الموظفين ومواعيد انتهائها، وأدِر العُهد المسلّمة.

• التقارير
أصدِر تقارير الحضور والرواتب والموظفين والإجازات.

• صلاحيات وإشعارات
امنح المديرين صلاحيات محددة، وابقَ على اطّلاع عبر تنبيهات فورية.

خصوصيتك وأمانك:
تُنقل بياناتك عبر اتصال مشفّر، وتقتصر صلاحية الوصول على المديرين المصرّح لهم.

ملاحظة مهمة:
هذا التطبيق مخصّص لأصحاب الأعمال والمديرين المشتركين في نظام بيرمدجات. ينشئ صاحب العمل شركته ويدير موظفيه من داخل التطبيق.
```

## 📝 Store listing text (English — en-US)

**App name (≤30):**
```
Permedjat Manager
```

**Short description (≤80):**
```
Manage your team: attendance, payroll, leaves, documents & reports in one app
```

**Full description (≤4000):**
```
Permedjat Manager — the employer & HR app to run your whole team from your phone.

Permedjat Manager is built for business owners and managers to handle employees, attendance and payroll in one place, with a simple Arabic-first interface.

Key features:

• Real-time dashboard
Follow live attendance, headcount and key metrics at a glance.

• Employee management
Add employees, organize them across branches and categories, and manage their documents and contracts.

• Attendance
Review attendance records, add manual entries, and set the attendance method (GPS / QR) per branch.

• Payroll & payslips
Calculate salaries, allowances and deductions, approve payslips, and export them as PDF or a bank file.

• Leaves, breaks & advances
Review and approve or reject leave, break and salary-advance requests.

• Documents, assets & custody
Track employee documents and expiry dates, and manage handed-over assets.

• Reports
Generate attendance, payroll, employee and leave reports.

• Roles & notifications
Grant managers specific permissions and stay informed with instant alerts.

Your privacy & security:
Your data is transmitted over an encrypted connection, and access is limited to authorized managers only.

Please note:
This app is intended for business owners and managers subscribed to the Permedjat system. The owner creates the company and manages employees from within the app.
```

## 🔑 بيانات مراجعة المتجر (للمراجعين) — App access

أنشئ هذا الحساب وفعّل بريده وأضف له شركة فيها بيانات، ثم لا تسجّل الدخول به حتى تنتهي المراجعة
(التطبيق يسمح بجلسة نشطة واحدة فقط لكل حساب):

- **البريد:** `review@permedjat.com`
- **كلمة المرور:** `Permedjat#Review2026`
- طريقة الدخول: **بريد + كلمة مرور** (وليس Google أو Apple).

**نص خانة "App access → Other instructions" (إنجليزي، <500 حرف):**
```
Sign in with the EMAIL and PASSWORD above ("Sign in with email"). Do NOT use Google or Apple sign-in.

The email is already verified — no OTP, 2FA or biometric needed.

This is a general-manager account linked to a demo company with sample employees, attendance and payroll, so all features are accessible.

Please do not change the password. The app allows only one active session per account, so we will not log in during your review.
```

## 📋 إجابات نماذج Play Console
- **الإعلانات (Ads):** لا — التطبيق **لا يحتوي على إعلانات** (لا توجد مكتبات إعلانات في المشروع).
- **App access:** نعم، الوصول مقيّد → قدّم بيانات الحساب أعلاه.
- **Target audience:** بالغون (تطبيق أعمال — ليس موجّهاً للأطفال).
