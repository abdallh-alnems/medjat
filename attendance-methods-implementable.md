# طرق الحضور والانصراف القابلة للتنفيذ في مجات

> مرجع تنفيذي (Implementation Roadmap) — مبني على فحص الكود الفعلي، مش على السوق بس.
> آخر تحديث: 2026-07-31 (خريطة الطريق الأصلية بتاريخ 2026-07-24).

المقصود بـ«قابلة للتنفيذ»: طرق تناسب معمارية مجات الحالية (تطبيق Flutter + backend PHP
+ تكامل أجهزة اختياري)، ومش محتاجة هاردوير متخصص نادر في مصر ولا تقنيات بحثية.
الطرق المستبعدة (iris / palm vein / UWB / gait / CCTV AI / blockchain / voice) **مش** في الملف ده.

---

## 0) الوضع الحالي (تحديث 2026-07-31)

**اتنفّذ من الخريطة دي خلال أسبوع واحد (2026-07-28 → 07-31):**

| البند في الخريطة | الحالة |
|---|---|
| أ-1 سيلفي + وجه + liveness | ✅ **اتبنى** — `face_selfie` (ناقص ملف `mobilefacenet.tflite` بس) |
| ج-3 تحقق WiFi BSSID | ✅ **اتبنى** — `wifi_gps` مع وضع تعلّم لاكتشاف نقاط الوصول |
| ج-1 تكامل ZKTeco | ✅ **اتبنى** — `device` عبر ADMS push (`device/iclock.php`)؛ لسه محتاج خطوات نشر يدوية |
| ملاحظة 3 (تحويل الـ flags لرفض) | ✅ **اتنفّذت لـ mock location** — `tenants.reject_mock_location` |
| أ-2 Station (تابلت في الفرع) | ❌ **اتلغت** — نظام الـ station/kiosk اتشال بالكامل (`2026_06_14_remove_kiosk_system.sql`) |

**طرق شغّالة فعلاً** (الموظف بيسجّل بيها النهاردة، والـ backend بيتحقق منها):

| الطريقة | الكود | نقطة الدخول |
|---|---|---|
| QR + GPS | `qr_gps` | `app/attendance/check_in.php` → `GpsService::validateCheckIn` |
| GPS فقط | `gps_only` | نفس المسار بدون QR |
| WiFi + GPS | `wifi_gps` | نفس المسار + `NetworkVerifier::verify` (قيد **فوق** الـ geofence مش بديل عنه) |
| سيلفي الوجه | `face_selfie` | نفس المسار + `FaceMatchService::verify` (nonce أحادي الاستخدام) |
| جهاز بصمة | `device` | `device/iclock.php` → `DevicePunchIngestor` |
| يدوي (Manual) | `manual` | `app/attendance/manual_check_in.php` (لصاحب صلاحية) |

**البنية اللي بتخدم أي طريقة جديدة:**
- `core/AttendanceMethodResolver.php` — بيحدد الطريقة لكل موظف: **موظف ← فئة (union) ← فرع ← الشركة**.
  `ALLOWED` دلوقتي = `['qr_gps','gps_only','face_selfie','wifi_gps','device','manual']`.
- كشف التحايل: `is_vpn` / `is_mock_location` / `is_rooted_device` + جدول
  `attendance_security_logs` (اتعمل فعليًا على القاعدة الحيّة 2026-07-31 — قبل كده كان كل سجل بيتبهدل صامت).
  رفض الـ mock location اختياري لكل شركة و**على Android بس**؛ الـ root **متعمّد إنه ما يتحجبش**.
- Geofence لكل فرع بنصف قطر (`GpsService`, `DEFAULT_GPS_RADIUS`).
- التوقيت لكل شركة عبر `core/TenantClock.php` (مش `date()`/`NOW()` مباشرة).

> أي طريقة جديدة لازم تتضاف لـ `ALLOWED` + في واجهات الاختيار (tenant/branch/category/employee)
> + في `check_in.php`/`check_out.php` عشان تظهر وتتحقق.

---

## المجموعة أ — نص مبنية بالفعل (أسرع مكسب) 🟢

> **الحالة دلوقتي:** أ-1 **اتبنت واتنشرت**، وأ-2 **اتلغت** مع شيل نظام الـ station/kiosk.
> اللي تحت ده وصف الخطة الأصلية قبل التنفيذ — متسيبش الجدول ده يقنعك إن الوجه لسه ناقص.

### أ-1) سيلفي + تعرّف على الوجه بالموبايل مع Liveness ⭐ (الأولوية القصوى) — ✅ اتنفّذ
- **كيف تشتغل:** الموظف ياخد سيلفي وقت الحضور → مطابقة الـ face embedding المخزّن + كشف حياة
  (liveness) ضد الصور/الفيديو → يتجمع مع الـ GPS الموجود.
- **الحالة في الكود:**
  - ✅ تسجيل الوجه شغّال: `app/biometric/enroll_face.php` (بيخزّن embedding + صورة + quality_score)،
    `BiometricModel::enrollFace`، صلاحية `biometric_enroll`.
  - ✅ أعمدة anti-spoofing في `branches` (`station_anti_spoofing_enabled`, `station_confidence_threshold`).
  - ✅ جدول `station_recognition_logs` بنتائج منها `spoofing_detected`.
  - ❌ ناقص: التقاط السيلفي وقت الحضور + المطابقة + قرار قبول/رفض + إضافة `face_selfie` لـ `ALLOWED`.
- **المطلوب:** موديل مطابقة embeddings (يفضّل on-device للخصوصية والسرعة) + liveness (active أو passive) +
  تعديل `check_in.php` أو مسار جديد.
- **الجهد:** متوسط–كبير. **الأولوية: 1** (الملف الأصلي بيعتبر liveness إلزامي في 2026).

### أ-2) بصمة / وجه عبر Station (تابلت مثبّت في الفرع) — ❌ اتلغت
- **كيف تشتغل:** جهاز مشترك في الفرع (تابلت) بيتعرّف على الموظفين بالوجه أو البصمة.
- **الحالة في الكود:**
  - ✅ جداول كاملة: `attendance_stations` (device_token, activation QR, heartbeat, lock) +
    `station_recognition_logs` (`migration 2026_05_20`).
  - ✅ أعمدة في `branches`: `station_enabled`, `station_methods (face_only/fingerprint_only/both_available)`,
    `station_gps_radius_meters`, `station_confidence_threshold`, `station_admin_pin_hash`.
  - ✅ أعمدة في `attendance`: `recognition_method (station_face/station_fingerprint/station_both)`,
    `recognition_confidence`, `station_id`.
  - ✅ تسجيل البصمة: `app/biometric/enroll_fingerprint.php` (template).
  - ❌ ناقص: تطبيق الـ station نفسه + endpoints التفعيل والمطابقة والـ check-in.
- **المطلوب:** تطبيق station (Flutter/Web) + endpoints: تفعيل جهاز، heartbeat، recognize+check-in.
- **الجهد:** كبير. **الأولوية: 3** (بعد ما الوجه بالموبايل يشتغل، نفس منطق المطابقة يُعاد استخدامه).

---

## المجموعة ب — إضافات مباشرة على الموجود 🟢

### ب-1) Geofencing تلقائي (Auto check-in/out عند الدخول/الخروج)
- **الحالة:** الـ geofence نفسه موجود (`GpsService` + نصف قطر لكل فرع). ناقص المنطق التلقائي.
- **المطلوب:** background location + trigger عند عبور الحدود (يراعي استهلاك البطارية وصلاحيات iOS/Android).
- **الجهد:** متوسط. **الأولوية: 4**.

### ب-2) مسح QR ثابت في الموقع (بدون تحقق فرع صارم)
- **الحالة:** `qr_gps` موجود؛ دي مجرد تبسيط (QR مطبوع ثابت في الفرع).
- **الجهد:** صغير. **الأولوية: 5**.

### ب-3) NFC tap بالموبايل (للفرق الميدانية)
- **كيف تشتغل:** الموظف يقرّب تاج/كارت NFC من موبايله بدل QR.
- **المطلوب:** قراءة NFC في تطبيق الموظف + طريقة `nfc_gps` في `ALLOWED` (نفس تحقق GPS).
- **الجهد:** متوسط. **الأولوية: 6**.

### ب-4) PIN kiosk (fallback رخيص)
- **كيف تشتغل:** جهاز مشترك في الفرع، الموظف يدخّل PIN.
- **الحالة:** `station_admin_pin_hash` موجود كفكرة؛ محتاج PIN لكل موظف + مسار kiosk.
- **الجهد:** متوسط. **الأولوية: 7** (أضعف أماناً — عرضة للـ buddy punching).

### ب-5) بوابة ويب self-service
- **الحالة:** `medjat_central_web` (Next.js) جاهز يستضيف بوابة check-in ويب مع GPS/صورة.
- **الجهد:** متوسط. **الأولوية: 8** (للمكاتب والريموت).

---

## المجموعة ج — تكامل أجهزة (شغل أكبر بس ضمن السوق) 🟡

### ج-1) تكامل ZKTeco / Hikvision ⭐ (استراتيجي للسوق المصري) — ✅ اتنفّذ (ZKTeco)
- **كيف تشتغل:** الشركة عندها جهاز بصمة/وجه ZKTeco أو Hikvision؛ نستقبل الـ punches عبر
  SDK / push protocol ونطابقها بالموظفين.
- **المطلوب:** خدمة استقبال (push SDK أو polling) + ربط device user_id بموظف مجات + استيراد السجلات.
- **الجهد:** كبير. **الأولوية: 2** (ZKTeco مسيطرة على السوق المصري — أهم تكامل تجاري).

### ج-2) RFID / Proximity / Barcode badges
- عبر نفس ترمينالات ZKTeco/Hikvision أو قارئ مستقل. **الجهد:** متوسط (بعد ج-1). **الأولوية: 9**.

### ج-3) تحقق WiFi BSSID / IP (لفرق المكاتب والـ BPO) — ✅ اتنفّذ
- **كيف تشتغل:** الموظف ما يقدرش يسجّل إلا وهو متصل بشبكة/راوتر الشركة (BSSID) أو IP معتمد.
- **المطلوب:** قراءة BSSID/IP في التطبيق + قائمة معتمدة لكل فرع + تحقق backend.
- **الجهد:** متوسط. **الأولوية: 10**.

### ج-4) Bluetooth Beacon (auto check-in للمكاتب المغلقة)
- **كيف تشتغل:** BLE beacon مثبّت في الفرع، التطبيق يلتقطه ويعمل check-in تلقائي.
- **المطلوب:** beacon هاردوير رخيص + قراءة BLE + تحقق UUID.
- **الجهد:** متوسط. **الأولوية: 11** (بديل داخلي للـ GPS الضعيف جوّه المباني).

---

## جدول الأولويات الملخّص

(الترتيب الأصلي، مع الحالة بعد تنفيذ 2026-07-28 → 07-31)

| # | الطريقة | المجموعة | الحالة الحالية | الجهد |
|---|---|---|---|---|
| 1 | سيلفي + وجه + Liveness | أ | ✅ شغّالة (`face_selfie`) — ناقص ملف الموديل | متوسط–كبير |
| 2 | تكامل ZKTeco / Hikvision | ج | ✅ ZKTeco شغّال (`device`) — Hikvision لسه | كبير |
| 3 | Station بصمة/وجه (تابلت) | أ | ❌ ملغي (اتشال نظام الـ kiosk) | — |
| 4 | Geofencing تلقائي | ب | جزئي (geofence موجود) | متوسط |
| 5 | QR ثابت في الموقع | ب | تبسيط للموجود | صغير |
| 6 | NFC بالموبايل | ب | من الصفر | متوسط |
| 7 | PIN kiosk | ب | ❌ ملغي مع الـ kiosk | — |
| 8 | بوابة ويب self-service | ب | البنية موجودة | متوسط |
| 9 | RFID / Barcode badges | ج | يعتمد على ج-1 (بقى ممكن) | متوسط |
| 10 | WiFi BSSID / IP | ج | ✅ شغّالة (`wifi_gps`) | متوسط |
| 11 | Bluetooth Beacon | ج | من الصفر | متوسط |

**الباقي على الطاولة:** Geofencing تلقائي، NFC، بوابة ويب self-service، RFID badges، BLE beacon،
وتكامل Hikvision.

---

## ملاحظات تنفيذية عامة

1. **Liveness مش رفاهية:** أي طريقة وجه (موبايل أو station) لازم liveness detection ضد الصور —
   ده اللي بيقفل ثغرة الـ buddy punching. عندك أعمدة `anti_spoofing` جاهزة تستخدمها.
2. **نقطة التوسّع الواحدة:** كل طريقة جديدة = تضاف لـ `AttendanceMethodResolver::ALLOWED` +
   تظهر في واجهات الاختيار (شركة/فرع/فئة/موظف) عشان الـ resolver والـ check-in يعرفوها.
3. **رفع الـ flags لرفض فعلي:** ✅ اتنفّذ لـ **mock location** (2026-07-31) — رفض اختياري لكل شركة
   (`tenants.reject_mock_location`) قبل التحقق من الـ geofence، وكل محاولة محجوبة تتسجّل في
   `attendance_security_logs`. حدوده: العلامة جاية من العميل (تقف تطبيق "Fake GPS" مش APK معدّل)،
   و**iOS ما بيبلّغش بيها أصلاً**. الـ root **متعمّد ما يتحجبش** (الروت شائع على أجهزة رخيصة ومش دليل غش).
4. **الامتثال (قانون العمل 14/2025):** الطرق البيومترية والـ GPS بتتطلب موافقة صريحة من الموظف
   وسياسة احتفاظ بيانات (حفظ الملفات ≥ 5 سنين). يُراعى قبل إطلاق الوجه/السيلفي.
5. **الخصوصية والأداء للوجه:** التنفيذ الفعلي **خالف** التوصية الأصلية عن قصد: الموبايل بيستخرج
   الـ embedding بس، و**السيرفر** هو اللي بيحسب التشابه ويقرّر. حكم جاي من العميل (`matched: true`)
   ممكن يتزوّر من APK معدّل — يبقى مش مصدر ثقة. (الصور مش بتترفع كل مرة برضه.)

---

## التوصية المختصرة (اتنفّذت)

الترتيب الأصلي كان: **(1) سيلفي + وجه + Liveness** → **(2) تكامل ZKTeco** → **(3) Station**.
اتنفّذ 1 و2 (+ WiFi)، و3 اتلغي مع شيل نظام الـ kiosk.

**الخطوات المتبقية للي اتبنى — اتقفلت كلها 2026-08-01:**
- ✅ `assets/models/mobilefacenet.tflite` اتضاف (BSD-3، مطابق للعقد `[1,112,112,3]` → `[1,192]`).
  **لكن** القياس على LFW بيقول إن `FaceMatchService::DEFAULT_THRESHOLD = 0.650` عالية أوي
  للموديل ده (بترفض ~52% من المحاولات الصحيحة) — راجع `assets/models/README.md` وظبّط العتبة
  من `face_verification_logs` قبل التحويل لـ `enforce`. ابدأ من ~0.45.
- ✅ أجهزة ZKTeco: الميجريشن كان مطبّق أصلاً؛ اتنشر `device/nginx-devices.conf` على
  `/etc/nginx/sites-available/medjat-devices`، و`limit_req_zone` راح
  `/etc/nginx/conf.d/medjat-devices-zone.conf`، و`ufw allow 8090/tcp` اتفتح، والـ endpoint
  متحقَّق منه من بره (`http://178.104.90.133:8090/iclock/cdata?SN=…` → 200 نص عادي، و`/` → 404).
  الباقي = ضبط جهاز فعلي على IP الخادم:8090 وتبنّيه من شاشة الأجهزة.

الباقي (Geofencing تلقائي، NFC، بوابة ويب، RFID، BLE، Hikvision) إضافات تكتيكية حسب طلب العملاء.
