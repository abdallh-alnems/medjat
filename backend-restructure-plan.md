# خطة إعادة تقسيم الباك إند

**الحالة: خطة فقط — لم يُنفَّذ أي تعديل.**
التاريخ: 2026-08-06 · الأرقام في هذا الملف مقيسة من الريبو والسيرفر في نفس اليوم، لا تقديرات.

الهدف: تقسيم `backend_medjet/` من الداخل بحيث تصبح الـ API وحدها، وقاعدة البيانات وحدها،
والمهام المجدولة وحدها. وإعادة تسمية الفولدر نفسه إلى `backend/`.

---

## ١. الوضع الحالي

```
Medjat/backend_medjet/
├── app/          256 endpoint   (تطبيقات الموظف والإدارة، وبداخلها app/cron/)
├── admin/        22  endpoint   (لوحة السوبر أدمن)
├── device/                      (استقبال بصمة ZKTeco على بورت 8090)
├── core/         46  خدمة مشتركة
├── models/       49  ملف
├── migrations/   78  ملف
├── scripts/                     (مخلوطة — انظر القسم ٣)
├── config/ · lang/ · uploads/ · public/ · seeds/ · tests/ · cache_system/
├── join.php · join_team.php · well_known.php
└── deploy.sh · check-drift.sh · composer.json
```

الرابط العام حاليًا:

```
api.medjatapp.com/backend_medjet/app/auth/login.php
```

الـ nginx docroot هو الفولدر الأب (`root /var/www/medjat;`)، **فاسم الفولدر هو نفسه مقطع في الرابط**.
أي تغيير في الاسم أو في التقسيم يغيّر الروابط، إلا إذا عالجناها في nginx صراحةً.

---

## ٢. الشكل المقترح

```
backend/
├── api/
│   ├── app/          256 endpoint  (تبقى app/cron/ بداخلها — انظر القسم ٣)
│   ├── admin/        22  endpoint
│   └── device/       ZKTeco
├── database/
│   ├── models/       49
│   ├── migrations/   78
│   └── seeds/
├── cron/             المهام المجدولة من نوع CLI فقط
├── core/             46 خدمة مشتركة
├── config/           bootstrap · env · firebase · cors
├── lang/ · uploads/ · public/ · tests/
└── tools/            سكربتات يدوية (حذف مستخدم Firebase، seed، اختبارات)
```

سبب اختيار `backend/` وليس `api/` كاسم للفولدر: المحتوى أوسع من API. بداخله كرون، ورفع ملفات،
وتكامل جهاز بصمة، وروابط دعوة عامة، وترجمات. اسم `api/` سيكون وعدًا أضيق من الحقيقة.

---

## ٣. أخطر نقطة في الخطة: الكرون شيئان مختلفان

| النوع | الملفات | طريقة الاستدعاء |
|---|---|---|
| **كرون CLI** | `scripts/cron_leave_rollover.php` | `php8.5 /var/www/.../cron_leave_rollover.php` — مسار مطلق في `/etc/cron.d/medjat` |
| **كرون HTTP** | `app/cron/catchup_absences.php`<br>`app/cron/run_alerts.php`<br>`app/cron/purge_kiosk_captures.php` | `curl https://api.../app/cron/....php?key=…&cron_secret=…` من `/usr/local/bin/medjat-cron-*.sh` |

النوع الثاني **endpoints حقيقية لها روابط عامة**. لو نُقلت إلى فولدر `cron/` يقع تناقض مباشر:

- إن أُضيف `cron` إلى قاعدة المنع في nginx (وهو الصواب لسكربتات CLI) → **تتوقف كرونات HTTP**،
  فتتوقف معها الغيابات التلقائية والتنبيهات اليومية وتنظيف صور الكشك.
- وإن لم يُضف → **تنكشف سكربتات CLI على الإنترنت**.

**القرار:** تبقى `app/cron/` داخل `api/` لأنها endpoints، ويصير `cron/` الجديد للـ CLI فقط.

### `scripts/` ليست نقلة واحدة — تحتاج فرزًا

| الملف | الوجهة |
|---|---|
| `cron_leave_rollover.php` | `cron/` |
| `delete_firebase_user.php` · `seed_superadmin.php` | `tools/` |
| `test_early_leave_deduction.php` · `test_leave_carryover.php` · `test_sync_offline.php` | `tools/` أو `tests/` |
| `seed_all_states.sql` | `database/seeds/` |

---

## ٤. الشغل المطلوب

| # | البند | الحجم المقيس |
|---|---|---|
| 1 | إعادة كتابة الـ includes | **282 ملف**: 274 بـ `__DIR__ . '/../../config/bootstrap.php'`، 4 بعمق 1، 4 بعمق 3 |
| 2 | قاعدة المنع في nginx | `location ~* /(config\|core\|models\|vendor\|migrations\|seeds\|scripts\|lang)/ { deny all; }` — تُعاد كتابتها بالكامل |
| 3 | مسار كرون الـ CLI | `/etc/cron.d/medjat` (مسار مطلق) |
| 4 | روابط كرون HTTP | ٣ ملفات في `/usr/local/bin/medjat-cron-*.sh` |
| 5 | سكربتات النشر | `deploy.sh` · `check-drift.sh` · `migrations/migrate.sh` |
| 6 | ملفات `.env` | ٤ ملفات + إعادة بناء تطبيقات Flutter (إن تغيّرت الروابط) |
| 7 | مسارات الرفع | ثوابت مثل `__DIR__ . '/../../uploads/documents/'` |
| 8 | التوثيق | 34 ملفًا يذكر `backend_medjet` |

### تفصيل البند ١

الـ includes نسبية وتحسب عمقها يدويًا. أي ملف ينزل مستوى أعمق (مثل `app/` → `api/app/`)
يحتاج `../` إضافية. العملية ميكانيكية وقابلة للأتمتة بسكربت يحسب العمق الجديد لكل ملف،
لكنها تلمس 282 ملفًا فلا تُنفَّذ يدويًا.

---

## ٥. قراران مطلوبان قبل التنفيذ

**أ. هل تتغير الروابط العامة؟**
`app/auth/login.php` ستصبح `api/app/auth/login.php`. الخيارات:

1. قبول التغيير، وتحديث الـ `.env` الأربعة وإعادة بناء التطبيقات.
2. جعل nginx يخدم الشكلين معًا أثناء الانتقال، فلا ينكسر شيء ويُحذف القديم لاحقًا.

الخيار ٢ أأمن، وهو المقترح.

**ب. لا بد من `commit` أولًا.**
شغل الـ admin/support الحالي ما زال `M` و `??` في git رغم أنه **منشور فعلًا على الإنتاج**.
تحريك 282 ملفًا فوق شغل غير محفوظ يعني أن أي خطأ لا توجد نقطة رجوع منه.

---

## ٦. التحقق بعد التنفيذ

1. `check-drift.sh` — يجب أن يخرج أخضر على الأضلاع الثلاثة.
2. اختبار endpoint من كل مجموعة: يجب أن يرد **401** لا **500**
   (500 تعني أن الـ include انكسر).
3. `curl` يدوي لكرونات HTTP الثلاثة بالمفتاح الصحيح.
4. تشغيل كرون الـ CLI يدويًا: `php8.5 <المسار الجديد>/cron_leave_rollover.php`.
5. **اختبار قاعدة المنع صراحةً** — يجب أن تُرفض هذه كلها:
   `/config/env.php` · `/core/Auth.php` · `/database/migrations/` · `/cron/`
   (خطأ هنا يكشف `config/env.php` وبداخله كلمة سر قاعدة البيانات و `JWT_SECRET` و `OTP_HMAC_SECRET`).
6. فتح لوحة السوبر أدمن وتطبيق الموظف والويب، والتأكد من تسجيل الدخول وتسجيل الحضور.

---

## ٧. رأي مسجَّل للأمانة

الفصل بين الطبقات **موجود بالفعل** في الشكل الحالي، لكنه مسطَّح لا متداخل:
`app/` + `admin/` طبقة HTTP، و`core/` طبقة الخدمات، و`models/` طبقة قاعدة البيانات،
و`migrations/` هي الـ schema. التقسيم المقترح يضيف مستوى تداخل فوق حدود قائمة، لا حدودًا جديدة.

المكسب تنظيمي وبصري، والتكلفة 282 ملفًا وقاعدة أمان في nginx وأربعة مسارات على السيرفر.
وهذا قرار صاحب المشروع، وقد اتُّخذ — والخطة أعلاه تنفّذه بأقل مخاطرة ممكنة.

أرخص وقت لتنفيذها هو الآن، بينما التطبيق تحت التطوير. وكلما تأخرت زادت التكلفة.
