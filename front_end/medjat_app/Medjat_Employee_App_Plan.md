# Medjat — تطبيق الموظف (Employee App)
> خطة تنفيذية تفصيلية لبناء تطبيق الموظف

---

## معلومات الوثيقة

| البند | التفاصيل |
|-------|----------|
| الإصدار | 1.0 |
| التاريخ | مايو 2026 |
| المرجع | [Medjat_PRD.md](./Medjat_PRD.md) — [Medjat_Development_Plan.md](./Medjat_Development_Plan.md) |
| نوع التطبيق | Flutter Mobile (Android + iOS) |
| المستخدم | الموظف العادي فقط |
| Entry Point | `lib/main_employee.dart` |
| المدة المتوقعة | أسبوع كامل (Sprint 2) |

---

## الفهرس

1. [نظرة عامة وفلسفة التصميم](#١-نظرة-عامة-وفلسفة-التصميم)
2. [User Personas والسيناريوهات](#٢-user-personas-والسيناريوهات)
3. [بنية الـ Navigation](#٣-بنية-الـ-navigation)
4. [الشاشات بالتفصيل](#٤-الشاشات-بالتفصيل)
5. [User Flows مفصلة](#٥-user-flows-مفصلة)
6. [الـ Controllers](#٦-الـ-controllers)
7. [الـ Models](#٧-الـ-models)
8. [الـ API Endpoints المستخدمة](#٨-الـ-api-endpoints-المستخدمة)
9. [Offline Mode](#٩-offline-mode)
10. [الإشعارات (Push Notifications)](#١٠-الإشعارات-push-notifications)
11. [Widgets قابلة لإعادة الاستخدام](#١١-widgets-قابلة-لإعادة-الاستخدام)
12. [States و Error Handling](#١٢-states-و-error-handling)
13. [خطة التنفيذ اليومية](#١٣-خطة-التنفيذ-اليومية)
14. [Acceptance Criteria](#١٤-acceptance-criteria)

---

## ١. نظرة عامة وفلسفة التصميم

### ١.١ فلسفة التطبيق

تطبيق الموظف هو **أبسط الـ 3 تطبيقات** وأكثرهم استخداماً يومياً. لذلك:

- **بساطة قصوى:** لا يحتاج تدريب — أي موظف يفتحه يفهم في دقائق.
- **سرعة:** الحضور لازم يتسجل في **أقل من 3 ثوان** من فتح التطبيق.
- **Offline-first:** يعمل بدون إنترنت لأن السوق المصري إنترنته غير مستقر.
- **عربي 100%:** كل النصوص بالعربية، RTL، خط Cairo.
- **شاشات قليلة:** 5-7 شاشات فقط — لا تضخيم.

### ١.٢ المبدأ الذهبي

> الموظف يفتح التطبيق مرتين في اليوم: حضور وانصراف. كل شيء آخر ثانوي.

الشاشة الرئيسية = **زر حضور كبير في النص**. باقي الميزات في الجانب.

### ١.٣ ما لا يحتويه التطبيق (Out of Scope)

- ❌ تعديل بيانات الموظف الشخصية (يقدمها HR فقط)
- ❌ رفع الأوراق (يرفعها HR — الموظف يشاهد فقط)
- ❌ طلب إجازة (في النسخة الحالية — يضاف v2)
- ❌ مراسلة الزملاء (مش app social)
- ❌ Face Recognition (v2)

---

## ٢. User Personas والسيناريوهات

### ٢.١ Personas

#### محمد — موظف في مصنع
- 32 سنة، تعليم متوسط
- موبايل Android متوسط
- إنترنت ضعيف في مكان العمل
- يحتاج: يحضر وينصرف بسرعة بدون تعقيد

#### سارة — موظفة مكتبية
- 26 سنة، خريجة جامعة
- iPhone، إنترنت ممتاز
- تحب تتابع راتبها وخصوماتها بالتفصيل
- تحتاج: شفافية كاملة في الراتب والحضور

### ٢.٢ سيناريوهات الاستخدام

| السيناريو | المعدل | الأولوية |
|-----------|-------|----------|
| تسجيل حضور صباحاً | يومياً مرة | 🔴 P0 |
| تسجيل انصراف مساءً | يومياً مرة | 🔴 P0 |
| مراجعة سجل الحضور | أسبوعياً | 🟡 P1 |
| مراجعة كشف الراتب | شهرياً (آخر الشهر) | 🟡 P1 |
| التحقق من الأوراق المطلوبة | عند الانضمام | 🟢 P2 |
| تغيير كلمة السر | نادراً | 🟢 P2 |

---

## ٣. بنية الـ Navigation

### ٣.١ Bottom Navigation Bar (4 تابز)

```
┌────────────────────────────────────────────┐
│                                            │
│            محتوى الشاشة                    │
│                                            │
│                                            │
├────────────────────────────────────────────┤
│  🏠 الرئيسية │ 📋 سجلي │ 💰 راتبي │ 👤 حسابي │
└────────────────────────────────────────────┘
```

| التاب | الأيقونة | الشاشة |
|-------|---------|--------|
| الرئيسية | home | Home Screen (الحضور) |
| سجلي | history | Attendance History |
| راتبي | payments | Payroll Screen |
| حسابي | person | Profile + Settings |

### ٣.٢ شجرة الـ Routes

```
/splash                          ← فحص version + token
/login                           ← تسجيل دخول
/forgot-password                 ← نسيت كلمة السر
/force-update                    ← شاشة تحديث إجباري

/home                            ← الـ shell (Bottom Nav)
├── tab[0]: HomeScreen
├── tab[1]: AttendanceHistoryScreen
├── tab[2]: PayrollScreen
└── tab[3]: ProfileScreen

/scan-qr                         ← شاشة كاميرا الـ QR (push)
/attendance-success              ← شاشة تأكيد نجاح (push, auto-dismiss)
/attendance-detail/:id           ← تفاصيل يوم معين
/payroll-detail/:month           ← تفاصيل راتب شهر
/my-documents                    ← أوراقي
/document-viewer                 ← عرض ورقة
/settings                        ← الإعدادات
/change-password                 ← تغيير كلمة السر
/notifications                   ← الإشعارات
/about                           ← عن التطبيق
```

---

## ٤. الشاشات بالتفصيل

### ٤.١ Splash Screen

```
┌─────────────────────────┐
│                         │
│                         │
│       [Medjat Logo]     │
│                         │
│   جاري التحميل...       │
│   ⠋ (loading)           │
│                         │
│                         │
└─────────────────────────┘
```

**الوظائف عند الفتح:**
1. تحميل `flutter_dotenv`
2. تهيئة Firebase
3. فحص Remote Config (`min_version_employee`)
4. لو النسخة قديمة → `/force-update`
5. فحص `token` في `flutter_secure_storage`
6. لو موجود + صالح → `/home`
7. لو غير موجود → `/login`

**المدة:** 1.5 ثانية كحد أقصى.

---

### ٤.٢ Login Screen

```
┌─────────────────────────┐
│                         │
│      [Medjat Logo]      │
│                         │
│   مرحباً بك في Medjat   │
│                         │
│  ┌───────────────────┐  │
│  │ 📧 البريد/الهاتف  │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │ 🔒 كلمة السر    👁  │  │
│  └───────────────────┘  │
│                         │
│        نسيت كلمة السر؟  │
│                         │
│  ┌───────────────────┐  │
│  │     تسجيل الدخول   │  │
│  └───────────────────┘  │
│                         │
│   ────────  أو  ────────│
│                         │
│  ┌───────────────────┐  │
│  │  🔍 Google         │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Validations:**
- البريد/الهاتف: required + format check
- كلمة السر: required + min 6 حروف
- زر "تسجيل الدخول" disabled حتى يصح الفورم

**Edge Cases:**
- شركة موقوفة → "الشركة متوقفة، تواصل مع الإدارة"
- بيانات خاطئة → "بيانات الدخول غير صحيحة"
- مفيش إنترنت → snackbar أحمر + يبقى disable

**ملاحظات تصميم:**
- زر التسجيل مرتفع عن الـ keyboard دائماً
- خط Cairo، الـ inputs لها label واضح
- لون primary (هندحدد لون Medjat)

---

### ٤.٣ Home Screen (الشاشة الرئيسية)

هذه الشاشة الأهم — يجب أن تكون فائقة الوضوح.

```
┌─────────────────────────┐
│  🔔     مرحباً، محمد    │  ← AppBar
├─────────────────────────┤
│                         │
│   اليوم — الخميس        │
│   ١٦ مايو ٢٠٢٦          │
│                         │
│  ┌─────────────────┐    │
│  │  حالتك اليوم    │    │  ← Status Card
│  │  ✅ مسجل الحضور │    │
│  │  ٨:٠٢ صباحاً    │    │
│  │  لم تنصرف بعد   │    │
│  └─────────────────┘    │
│                         │
│                         │
│      ┌──────────┐       │
│      │          │       │
│      │  📷 QR   │       │  ← الزر الرئيسي
│      │          │       │
│      │ انصراف   │       │  (يتبدل: حضور/انصراف)
│      │          │       │
│      └──────────┘       │
│                         │
│                         │
│   فرعك: المعادي         │
│   📍 200م من الفرع      │  ← لو GPS مفعل
│                         │
│   ⚠️ بدون إنترنت        │  ← لو offline
│                         │
└─────────────────────────┘
```

**عناصر الشاشة:**

| العنصر | التفاصيل |
|--------|----------|
| AppBar | أيقونة إشعارات (badge) + اسم الموظف |
| التاريخ | يوم الأسبوع + التاريخ الميلادي (والهجري اختياري) |
| Status Card | حالة الحضور الحالية مع الوقت |
| الزر الرئيسي | كبير (200x200), دائري, لون primary |
| نص الزر | "تسجيل الحضور" / "تسجيل الانصراف" / "تم اليوم" |
| فرعك | اسم الفرع + المسافة الحالية لو GPS متاح |
| Indicator الإنترنت | فقط لو offline (شريط أصفر تحت AppBar) |

**حالات الزر الرئيسي:**

```
1. لم يحضر بعد            → "تسجيل الحضور"     (لون primary)
2. حضر ولم ينصرف          → "تسجيل الانصراف"  (لون brown/orange)
3. حضر وانصرف             → "تم اليوم ✅"     (disabled, لون grey)
4. خارج نطاق GPS         → نفس الكلام (الفلتر بيتطبق بعد المسح)
5. Offline                → "تسجيل الحضور (offline)" (تحذير صفر)
```

**Pull to refresh:** يحدّث الـ status من الـ API.

---

### ٤.٤ Scan QR Screen

```
┌─────────────────────────┐
│  ←      مسح QR Code     │  ← AppBar
├─────────────────────────┤
│                         │
│  ┌───────────────────┐  │
│  │                   │  │
│  │   [Camera View]   │  │
│  │                   │  │
│  │   ┌─────────┐     │  │
│  │   │         │     │  │  ← الـ scan area
│  │   │   ▣     │     │  │
│  │   │         │     │  │
│  │   └─────────┘     │  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│   وجّه الكاميرا لـ QR   │
│   المعلق في الفرع       │
│                         │
│  💡 Flash:         🔦   │
│                         │
└─────────────────────────┘
```

**السلوك:**
- يفتح الكاميرا مباشرة
- يظهر إطار scan في النص
- عند detection → اهتزاز خفيف + يقفل الكاميرا فوراً
- يتحقق من GPS بالتوازي (يكون استدعاه قبلها)
- لو الـ token صالح + GPS سليم → `/attendance-success`
- لو فيه خطأ → bottom sheet أحمر

**Permissions:**
- الكاميرا: لو مرفوضة → modal "افتح الإعدادات"
- الموقع: نفس الكلام

---

### ٤.٥ Attendance Success Screen

```
┌─────────────────────────┐
│                         │
│       ✅ (animated)     │
│                         │
│   تم تسجيل الحضور       │
│                         │
│      ٨:٠٢ صباحاً        │
│   الخميس ١٦ مايو ٢٠٢٦   │
│                         │
│   فرع المعادي           │
│                         │
│   ┌────────────────┐    │
│   │      تمام      │    │
│   └────────────────┘    │
│                         │
└─────────────────────────┘
```

- Lottie animation للنجاح
- Auto-dismiss بعد 3 ثوان (أو زر "تمام")
- يرجع لـ Home

**نسخة Offline:**
- نص إضافي: "سيتم المزامنة عند الاتصال بالإنترنت"
- أيقونة سحابة بسهم

---

### ٤.٦ Attendance History Screen (سجلي)

```
┌─────────────────────────┐
│        سجل حضوري        │
├─────────────────────────┤
│  مايو ٢٠٢٦  ▼           │  ← Month picker
├─────────────────────────┤
│  ملخص الشهر:            │
│  ✅ ١٢ يوم حضور         │
│  ⏰ ٢ تأخير             │
│  ❌ ١ غياب              │
│  🏖 ١ إجازة             │
├─────────────────────────┤
│  ▼ القائمة              │
│                         │
│  الخميس ١٦ مايو         │
│   ٨:٠٢ ص — لم تنصرف     │
│   ────────────────      │
│  الأربعاء ١٥ مايو       │
│   ٨:١٥ ص — ٥:٠٠ م       │
│   ⏰ تأخر ١٥ دقيقة      │
│   ────────────────      │
│  الثلاثاء ١٤ مايو       │
│   🏖 إجازة              │
│   ────────────────      │
│  الإثنين ١٣ مايو        │
│   ❌ غياب               │
│   ────────────────      │
│  ...                    │
└─────────────────────────┘
```

**العناصر:**
- Month picker في الأعلى (شهر/سنة)
- ملخص الشهر (cards صغيرة)
- قائمة الأيام (ListView)
- ضغطة على يوم → `/attendance-detail/:id`

**Filters (اختياري v1.5):**
- كل الأيام
- الحضور فقط
- التأخيرات
- الغياب

---

### ٤.٧ Attendance Detail Screen

```
┌─────────────────────────┐
│  ←    تفاصيل اليوم      │
├─────────────────────────┤
│   الأربعاء ١٥ مايو ٢٠٢٦  │
│                         │
│   الحضور: ٨:١٥ ص        │
│   الانصراف: ٥:٠٠ م      │
│   المدة: ٨ ساعات ٤٥ د   │
│                         │
│   ━━━━━━━━━━━━━━━━━     │
│                         │
│   ⏰ تأخر ١٥ دقيقة      │
│   خصم: ٢٥ جنيه          │
│                         │
│   ━━━━━━━━━━━━━━━━━     │
│                         │
│   الفرع: المعادي        │
│   📍 على بُعد ٥٠م       │
│   الطريقة: QR + GPS     │
│                         │
└─────────────────────────┘
```

---

### ٤.٨ Payroll Screen (راتبي)

```
┌─────────────────────────┐
│         راتبي           │
├─────────────────────────┤
│  ┌───────────────────┐  │
│  │  مايو ٢٠٢٦         │  │  ← الشهر الحالي
│  │  ━━━━━━━━━━━━━━━  │  │
│  │  ٥,٠٠٠ ج (متوقع)   │  │
│  │  جاري الحساب...    │  │
│  └───────────────────┘  │
│                         │
│   الشهور السابقة:       │
│                         │
│  ┌───────────────────┐  │
│  │  أبريل ٢٠٢٦       │  │
│  │  ٤,٨٧٥ ج    ✅   ▶ │  │  ← تم الصرف
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │  مارس ٢٠٢٦        │  │
│  │  ٤,٩٥٠ ج    ✅   ▶ │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │  فبراير ٢٠٢٦      │  │
│  │  ٥,٠٠٠ ج    ✅   ▶ │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

---

### ٤.٩ Payroll Detail Screen

```
┌─────────────────────────┐
│  ←   راتب أبريل ٢٠٢٦    │
├─────────────────────────┤
│                         │
│  الراتب الأساسي         │
│  ٥,٠٠٠ ج                │
│                         │
│  ━━━━━━━━━━━━━━━━━━━━   │
│                         │
│  الخصومات (-١٢٥ ج):     │
│  • تأخير ١٥ مايو: ٢٥ ج  │
│  • تأخير ٢٢ مايو: ٢٥ ج  │
│  • غياب ٢٧ مايو: ٧٥ ج   │
│                         │
│  ━━━━━━━━━━━━━━━━━━━━   │
│                         │
│  الإضافي (+٠ ج):        │
│  لا يوجد                │
│                         │
│  ━━━━━━━━━━━━━━━━━━━━   │
│                         │
│  ╔══════════════════╗   │
│  ║ الصافي: ٤,٨٧٥ ج  ║   │
│  ╚══════════════════╝   │
│                         │
│  ┌───────────────────┐  │
│  │  📄 تحميل كشف PDF  │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

---

### ٤.١٠ Profile Screen (حسابي)

```
┌─────────────────────────┐
│         حسابي           │
├─────────────────────────┤
│                         │
│       👤 (avatar)       │
│                         │
│       محمد علي          │
│   موظف — فرع المعادي    │
│   كود: EMP-0123         │
│                         │
│  ━━━━━━━━━━━━━━━━━━━━   │
│                         │
│  📋 بياناتي         ▶  │
│  📄 أوراقي          ▶  │
│  🔔 الإشعارات       ▶  │
│  🔒 تغيير كلمة السر ▶  │
│  🌙 الوضع الليلي    ◯  │
│  📞 الدعم الفني     ▶  │
│  ℹ️ عن التطبيق      ▶  │
│                         │
│  ━━━━━━━━━━━━━━━━━━━━   │
│                         │
│  🚪 تسجيل الخروج        │
│                         │
└─────────────────────────┘
```

---

### ٤.١١ My Profile Details Screen

```
┌─────────────────────────┐
│  ←        بياناتي       │
├─────────────────────────┤
│                         │
│  الاسم:                 │
│  محمد علي حسن           │
│                         │
│  الوظيفة:               │
│  فني صيانة              │
│                         │
│  الفرع:                 │
│  المعادي                │
│                         │
│  تاريخ التعيين:         │
│  ١ يناير ٢٠٢٤           │
│                         │
│  البريد:                │
│  m.ali@example.com      │
│                         │
│  الهاتف:                │
│  ٠١٠١٢٣٤٥٦٧٨            │
│                         │
│  الراتب الأساسي:        │
│  ٥,٠٠٠ ج                │
│                         │
│  💡 لتعديل بياناتك،     │
│  تواصل مع HR            │
│                         │
└─────────────────────────┘
```

**ملاحظة:** كل الحقول read-only — التعديل من تطبيق الإدارة.

---

### ٤.١٢ My Documents Screen

```
┌─────────────────────────┐
│  ←        أوراقي        │
├─────────────────────────┤
│                         │
│  ✅ صورة البطاقة         │
│  مرفوعة في ٢ يناير      │
│  ━━━━━━━━━━━━━━━━━━━    │
│  ✅ شهادة الميلاد        │
│  مرفوعة في ٢ يناير      │
│  ━━━━━━━━━━━━━━━━━━━    │
│  ✅ شهادة التخرج         │
│  مرفوعة في ٢ يناير      │
│  ━━━━━━━━━━━━━━━━━━━    │
│  ⏳ شهادة صحية           │
│  مطلوبة — تواصل مع HR  │
│  ━━━━━━━━━━━━━━━━━━━    │
│  ❌ رخصة القيادة         │
│  انتهت في ١ مارس ٢٠٢٦   │
│                         │
└─────────────────────────┘
```

- ضغطة على ورقة مرفوعة → عرض الصورة/PDF
- الورقة المطلوبة/المنتهية → فقط معلومات (الموظف لا يرفع بنفسه)

---

### ٤.١٣ Notifications Screen

```
┌─────────────────────────┐
│  ←       الإشعارات      │
├─────────────────────────┤
│                         │
│  • تم إصدار راتب أبريل  │
│    قبل ٣ ساعات          │
│  ━━━━━━━━━━━━━━━━━━━    │
│  • تأخير ١٥ دقيقة اليوم │
│    قبل يومين            │
│  ━━━━━━━━━━━━━━━━━━━    │
│  • تذكير: الانصراف      │
│    قبل أسبوع            │
│  ━━━━━━━━━━━━━━━━━━━    │
│                         │
└─────────────────────────┘
```

---

### ٤.١٤ Force Update Screen

```
┌─────────────────────────┐
│                         │
│       📲 (icon)         │
│                         │
│   تحديث مطلوب           │
│                         │
│   هناك نسخة جديدة من    │
│   التطبيق. يرجى التحديث │
│   للاستمرار.            │
│                         │
│  ┌───────────────────┐  │
│  │  التحديث الآن     │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

- ينقل لـ Play Store / App Store
- لا يوجد زر إغلاق

---

## ٥. User Flows مفصلة

### ٥.١ Flow تسجيل الحضور (الأهم)

```
[Home Screen]
   │
   │ Tap "تسجيل الحضور"
   ↓
[Check Camera Permission]
   │
   ├── Denied → Modal: "افتح الإعدادات"
   │
   └── Granted ↓
[Check Location Permission]
   │
   ├── Denied → Modal: "افتح الإعدادات"
   │
   └── Granted ↓
[Get Current Location] (parallel)
   │
   ↓
[Scan QR Screen]
   │
   │ User scans
   ↓
[QR Detected]
   │
   ├── Invalid QR → bottom sheet "QR غير صالح" + retry
   │
   └── Valid ↓
[Check Internet]
   │
   ├── Online ↓
   │   [POST /attendance/check-in]
   │      │
   │      ├── 200 OK → [Success Screen] → [Home]
   │      ├── 422 (out of range) → "أنت بعيد عن الفرع" + retry
   │      ├── 409 (already) → "مسجل بالفعل اليوم"
   │      └── Error → bottom sheet error
   │
   └── Offline ↓
       [Save to Hive Queue]
          │
       [Success Screen (Offline)] → [Home]
          │
          (later) → [Auto Sync]
```

### ٥.٢ Flow الـ Auto Sync

```
[App opens] OR [Connectivity restored]
   │
   ↓
[ConnectivityService.onConnect]
   │
   ↓
[Check Hive Queue]
   │
   ├── Empty → Done
   │
   └── Has items ↓
[POST /attendance/sync (batch)]
   │
   ├── 200 → Remove from Hive + Show notification "تم مزامنة X سجل"
   │
   └── Error → Retry بعد دقيقة
```

### ٥.٣ Flow تسجيل الدخول

```
[Login Screen]
   │
   │ Enter credentials + Submit
   ↓
[Validate locally] → invalid → error
   │ valid
   ↓
[POST /auth/login]
   │
   ├── 200 → Save token (secure storage)
   │            ↓
   │       Save user data + permissions
   │            ↓
   │       Register FCM token
   │            ↓
   │       [Home Screen]
   │
   ├── 401 → "بيانات خاطئة"
   ├── 403 → "الشركة موقوفة"
   └── Error → snackbar
```

---

## ٦. الـ Controllers

### ٦.١ قائمة الـ Controllers

| Controller | Scope | Responsibilities |
|-----------|-------|------------------|
| `AppController` | Global (permanent) | Locale, theme, connectivity |
| `AuthController` | Global (permanent) | User, token, permissions |
| `HomeController` | Home tab | Today status, branch info |
| `AttendanceController` | Scan + Home | Check-in/out logic, GPS, QR |
| `AttendanceHistoryController` | History tab | Month logs, filters |
| `PayrollController` | Payroll tab | List + selected month detail |
| `ProfileController` | Profile tab | User profile + settings |
| `DocumentsController` | Documents screen | List + viewer |
| `NotificationsController` | Notifications screen | List + mark read |

### ٦.٢ AttendanceController (الأهم)

```dart
class AttendanceController extends GetxController {
  final CRUD crud = Get.find();

  // State
  StatusRequest status = StatusRequest.none;
  TodayStatus todayStatus = TodayStatus.notCheckedIn;
  AttendanceLog? todayLog;
  double? distanceFromBranch;
  bool isOffline = false;

  @override
  void onInit() {
    super.onInit();
    loadTodayStatus();
    _listenToConnectivity();
  }

  Future<void> loadTodayStatus() async { ... }

  Future<void> startCheckInFlow() async {
    if (!await _ensurePermissions()) return;
    final position = await LocationService.getCurrentPosition();
    Get.toNamed('/scan-qr', arguments: position);
  }

  Future<void> processQrScan(String qrToken, Position position) async {
    status = StatusRequest.loading;
    update();

    final isCheckOut = todayStatus == TodayStatus.checkedIn;
    final url = isCheckOut ? AppLinks.checkOut : AppLinks.checkIn;

    if (await ConnectivityService.isOnline()) {
      final response = await crud.postData(url, {
        'qr_token': qrToken,
        'lat': position.latitude,
        'lng': position.longitude,
      });
      status = handleResponse(response);
      if (status == StatusRequest.success) {
        await loadTodayStatus();
        Get.offNamed('/attendance-success', arguments: response);
      }
    } else {
      await OfflineQueueService.add(
        type: isCheckOut ? 'check_out' : 'check_in',
        qrToken: qrToken,
        position: position,
      );
      Get.offNamed('/attendance-success', arguments: {'offline': true});
    }
    update();
  }
}
```

---

## ٧. الـ Models

### ٧.١ Models المطلوبة

```dart
// data/model/user_model.dart
class UserModel {
  final int id;
  final int tenantId;
  final int branchId;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String roleKey;
  final List<String> permissions;
  // ...
}

// data/model/employee_model.dart
class EmployeeModel {
  final int id;
  final String employeeCode;
  final String jobTitle;
  final DateTime hireDate;
  final double baseSalary;
  final BranchModel branch;
  // ...
}

// data/model/branch_model.dart
class BranchModel {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int gpsRadiusMeters;
  // ...
}

// data/model/attendance_log_model.dart
class AttendanceLogModel {
  final int id;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final String method;
  final bool isLate;
  final int lateMinutes;
  final double? lat;
  final double? lng;
  // ...
}

// data/model/payroll_model.dart
class PayrollModel {
  final int id;
  final int month;
  final int year;
  final double baseSalary;
  final double totalDeductions;
  final double totalBonuses;
  final double netSalary;
  final String status;  // pending/paid
  final String? pdfUrl;
  final List<PayrollItem> deductionItems;
  final List<PayrollItem> bonusItems;
  // ...
}

// data/model/document_model.dart
class DocumentModel {
  final int id;
  final String name;
  final String? fileUrl;
  final String status;  // uploaded/required/expired
  final DateTime? uploadedAt;
  final DateTime? expiresAt;
  // ...
}

// data/model/pending_attendance_model.dart  (Hive)
@HiveType(typeId: 0)
class PendingAttendance {
  @HiveField(0) final String id;
  @HiveField(1) final String type;
  @HiveField(2) final String qrToken;
  @HiveField(3) final double lat;
  @HiveField(4) final double lng;
  @HiveField(5) final DateTime timestamp;
  // ...
}
```

---

## ٨. الـ API Endpoints المستخدمة

| Endpoint | Method | الشاشة |
|---------|--------|--------|
| `/auth/login` | POST | Login |
| `/auth/logout` | POST | Profile |
| `/auth/refresh` | POST | (auto) |
| `/auth/forgot-password` | POST | Forgot Password |
| `/auth/change-password` | POST | Change Password |
| `/me` | GET | Splash, Profile |
| `/me/today` | GET | Home |
| `/attendance/check-in` | POST | Scan QR |
| `/attendance/check-out` | POST | Scan QR |
| `/attendance/sync` | POST | Offline Sync |
| `/me/attendance-logs?month=...` | GET | History |
| `/me/attendance-logs/{id}` | GET | Attendance Detail |
| `/me/payrolls` | GET | Payroll List |
| `/me/payrolls/{month}/{year}` | GET | Payroll Detail |
| `/me/payrolls/{id}/pdf` | GET | Download PDF |
| `/me/documents` | GET | Documents |
| `/me/notifications` | GET | Notifications |
| `/me/notifications/{id}/read` | POST | Notifications |
| `/devices/register-fcm` | POST | بعد Login |

---

## ٩. Offline Mode

### ٩.١ ما يعمل Offline

| الميزة | Offline؟ |
|--------|---------|
| تسجيل حضور (QR + GPS) | ✅ نعم |
| تسجيل انصراف | ✅ نعم |
| عرض حالة اليوم | ✅ (آخر cache) |
| عرض سجل الحضور | ✅ (آخر cache) |
| عرض الراتب | ✅ (آخر cache) |
| عرض البيانات الشخصية | ✅ (آخر cache) |
| Login | ❌ يحتاج إنترنت |
| تغيير كلمة السر | ❌ |

### ٩.٢ بنية الـ Hive Boxes

```
Box: pending_attendance       — الحضور المعلق
Box: cached_today_status      — حالة اليوم (cache)
Box: cached_attendance_logs   — سجل الحضور (cache آخر 3 شهور)
Box: cached_payrolls          — كشوف الرواتب
Box: cached_profile           — بيانات المستخدم
```

### ٩.٣ Sync Strategy

- **عند الفتح:** فحص الـ pending → sync لو online
- **عند استعادة الاتصال:** listener على `connectivity_plus`
- **Manual:** زر "تحديث" في الإعدادات (Pull to refresh)
- **التكرار:** كل 5 دقايق لو فيه pending items
- **Retry:** Exponential backoff (1s, 2s, 4s, 8s, max 60s)

### ٩.٤ Edge Cases

| الحالة | المعالجة |
|--------|---------|
| سجل حضور offline + الـ token غير صالح | الـ backend يرفض، يظهر للمستخدم |
| سجل حضور offline + كان فعلاً بعيد عن الفرع | الـ backend يرفض ويسجل warning |
| سجل offline لشهر قديم | الـ backend يقبل لكن يحدد timestamp الفعلي |
| Duplicate (سجل حضور online ثم offline قديم) | الـ backend dedupes بـ uuid |

---

## ١٠. الإشعارات (Push Notifications)

### ١٠.١ أنواع الإشعارات

| النوع | المحتوى | الإجراء |
|------|---------|---------|
| إصدار راتب | "تم إصدار راتب شهر X" | فتح Payroll Detail |
| تذكير انصراف | "لم تنصرف بعد، الوقت 6 م" | فتح Home |
| تأخير | "تم تسجيل تأخير X دقيقة" | فتح Attendance Detail |
| إجازة معتمدة | "تم تحويل غياب لإجازة" | فتح History |
| رسالة من الإدارة | "رسالة من HR: ..." | فتح Notifications |
| تحديث متاح | "نسخة جديدة متاحة" | فتح Play Store |

### ١٠.٢ Firebase Cloud Messaging

```
عند Login → احصل على FCM token → POST /devices/register-fcm
عند Logout → POST /devices/unregister-fcm
عند فتح إشعار → Deep link حسب نوع الإشعار
```

---

## ١١. Widgets قابلة لإعادة الاستخدام

```
core/shared/
├── buttons/
│   ├── primary_button.dart
│   ├── secondary_button.dart
│   ├── attendance_big_button.dart   ← الزر الرئيسي
│   └── icon_text_button.dart
│
├── input_fields/
│   ├── primary_input.dart
│   ├── password_input.dart
│   └── otp_input.dart
│
├── cards/
│   ├── status_card.dart             ← حالة اليوم
│   ├── attendance_day_card.dart     ← يوم في السجل
│   ├── payroll_summary_card.dart    ← كشف شهر
│   ├── document_card.dart
│   └── info_row.dart                ← سطر "الاسم: قيمة"
│
├── dialogs/
│   ├── confirmation_dialog.dart
│   ├── error_bottom_sheet.dart
│   ├── permission_dialog.dart
│   └── success_dialog.dart
│
├── empty_states/
│   ├── empty_history.dart
│   ├── empty_payrolls.dart
│   └── empty_notifications.dart
│
├── loading/
│   ├── shimmer_attendance_list.dart
│   ├── shimmer_payroll_card.dart
│   └── loading_overlay.dart
│
├── feedback/
│   ├── offline_banner.dart          ← شريط "بدون إنترنت"
│   ├── pending_sync_badge.dart      ← عدد pending items
│   └── success_lottie.dart
│
└── layout/
    ├── app_scaffold.dart
    ├── tab_shell.dart               ← Bottom Nav wrapper
    └── handling_data_request.dart   ← wrapper لكل state
```

---

## ١٢. States و Error Handling

### ١٢.١ مبدأ الـ HandlingDataRequest

كل شاشة تعرض بيانات من API تستخدم:

```dart
GetBuilder<HomeController>(
  builder: (c) => HandlingDataRequest(
    statusRequest: c.status,
    widget: HomeContent(),
  ),
)
```

### ١٢.٢ الحالات

| State | الواجهة |
|-------|---------|
| `none` | الـ content العادي |
| `loading` | Shimmer / spinner |
| `offline` | Banner أصفر + cached data |
| `serverFailure` | Empty state + زر إعادة |
| `failure` | Snackbar أحمر |
| `success` | الـ content |

### ١٢.٣ Errors بالعربية

| الكود | الرسالة |
|------|---------|
| 401 | جلستك انتهت، يرجى تسجيل الدخول مجدداً |
| 403 | ليس لديك صلاحية |
| 404 | لم يتم العثور على البيانات |
| 422 | البيانات غير صحيحة |
| 500 | حدث خطأ، حاول مرة أخرى |
| no_internet | لا يوجد اتصال بالإنترنت |
| out_of_range | أنت خارج نطاق الفرع |
| invalid_qr | QR Code غير صالح |
| already_checked_in | تم تسجيل الحضور مسبقاً |

---

## ١٣. خطة التنفيذ اليومية

### Sprint 2 — تطبيق الموظف (٧ أيام)

#### اليوم ١ — Setup + Auth
- [ ] إنشاء `main_employee.dart` + Flavor
- [ ] إعداد GetMaterialApp + RTL + theme
- [ ] إنشاء كل الـ routes (مع placeholder screens)
- [ ] Splash Screen + version check
- [ ] Login Screen + AuthController
- [ ] Token storage (`flutter_secure_storage`)
- [ ] Auth middleware

#### اليوم ٢ — Home + Layout
- [ ] Tab Shell + Bottom Nav
- [ ] Home Screen UI
- [ ] HomeController + `loadTodayStatus()`
- [ ] Status Card
- [ ] Attendance Big Button
- [ ] Pull to refresh

#### اليوم ٣ — Attendance Flow (Online)
- [ ] LocationService + permissions
- [ ] ConnectivityService
- [ ] Scan QR Screen (mobile_scanner)
- [ ] AttendanceController — check-in flow
- [ ] Check-in API call
- [ ] Attendance Success Screen
- [ ] Error handling (out of range, invalid QR, إلخ)

#### اليوم ٤ — Offline Mode
- [ ] Hive setup + boxes
- [ ] PendingAttendance model + adapter
- [ ] OfflineQueueService
- [ ] Sync logic (auto + manual)
- [ ] Offline banner + indicators
- [ ] اختبار scenarios offline

#### اليوم ٥ — History + Detail
- [ ] AttendanceHistoryController
- [ ] History Screen + Month picker
- [ ] Monthly summary
- [ ] AttendanceDayCard
- [ ] Attendance Detail Screen
- [ ] Caching الشهر الحالي + السابق

#### اليوم ٦ — Payroll + Documents
- [ ] PayrollController + Screen
- [ ] Payroll Detail Screen
- [ ] PDF download (open_filex)
- [ ] DocumentsController + Screen
- [ ] Document Viewer (image/pdf)

#### اليوم ٧ — Profile + Polish
- [ ] Profile Screen
- [ ] My Profile Details
- [ ] Change Password Screen
- [ ] Settings + Dark mode toggle
- [ ] Notifications Screen + FCM setup
- [ ] Force Update Screen
- [ ] اختبار End-to-end + إصلاح bugs

---

## ١٤. Acceptance Criteria

تطبيق الموظف يُعتبر **مكتمل MVP** عندما:

### ١٤.١ الوظائف الأساسية
- [ ] الموظف يقدر يسجل دخوله بالبريد/الهاتف وكلمة السر.
- [ ] يقدر يسجل حضوره وانصرافه بـ QR + GPS في **أقل من 5 ثوان**.
- [ ] التطبيق يرفض الحضور لو الموظف خارج نطاق GPS.
- [ ] التطبيق يعمل **بدون إنترنت** ويزامن تلقائياً عند العودة.
- [ ] يقدر يشوف سجل حضور أي شهر بكل التفاصيل.
- [ ] يقدر يشوف كشف الراتب بكل تفاصيل الخصومات والإضافي.
- [ ] يقدر يحمل PDF كشف الراتب.
- [ ] يقدر يشوف أوراقه وحالة كل ورقة.
- [ ] يقدر يستقبل إشعارات (FCM).
- [ ] يقدر يغير كلمة السر.

### ١٤.٢ الـ UX
- [ ] التطبيق RTL 100%، خط Cairo.
- [ ] كل النصوص بالعربية (لا English في الـ UI).
- [ ] كل شاشة لها loading + empty + error states.
- [ ] الـ Offline indicator واضح في كل وقت.
- [ ] Pull-to-refresh على القوائم.
- [ ] لا توجد crashes في الـ Crashlytics لمدة أسبوع.

### ١٤.٣ الأداء
- [ ] فتح التطبيق < 2 ثانية.
- [ ] الانتقال بين الشاشات < 300 ms.
- [ ] حجم الـ APK < 30 MB.
- [ ] استهلاك الذاكرة < 150 MB في الاستخدام العادي.

### ١٤.٤ الأمان
- [ ] الـ token محفوظ في `flutter_secure_storage` (مش `SharedPreferences`).
- [ ] كل الـ requests تستخدم HTTPS.
- [ ] لا يتم تسجيل بيانات حساسة في الـ logs.
- [ ] الـ session تنتهي تلقائياً عند الـ token expiry.

---

## ١٥. الخطوة التالية

1. مراجعة الخطة والموافقة عليها.
2. تحديد الـ design system (الألوان، الخطوط) — قبل بدء الـ UI.
3. التأكد من جاهزية الـ Backend endpoints المطلوبة.
4. بدء **Sprint 2 — اليوم ١** فوراً بعد إكمال Sprint 0 و 1.

> **Medjat Employee App Plan v1.0** — مايو 2026
