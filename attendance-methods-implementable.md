# طرق الحضور والانصراف القابلة للتنفيذ في مجات

> مرجع تنفيذي (Implementation Roadmap) — مبني على فحص الكود الفعلي، مش على السوق بس.
> آخر تحديث: 2026-07-24

المقصود بـ«قابلة للتنفيذ»: طرق تناسب معمارية مجات الحالية (تطبيق Flutter + backend PHP على
Hostinger + تكامل أجهزة اختياري)، ومش محتاجة هاردوير متخصص نادر في مصر ولا تقنيات بحثية.
الطرق المستبعدة (iris / palm vein / UWB / gait / CCTV AI / blockchain / voice) **مش** في الملف ده.

---

## 0) الوضع الحالي (الأساس)

**طرق شغّالة فعلاً** (الموظف بيسجّل بيها النهاردة، والـ backend بيتحقق منها):

| الطريقة | الكود | نقطة الدخول |
|---|---|---|
| QR + GPS | `qr_gps` | `app/attendance/check_in.php` → `GpsService::validateCheckIn` |
| GPS فقط | `gps_only` | نفس المسار بدون QR |
| يدوي (Manual) | `manual` | `app/attendance/manual_check_in.php` (لصاحب صلاحية) |

**البنية اللي بتخدم أي طريقة جديدة (موجودة خلاص):**
- `core/AttendanceMethodResolver.php` — بيحدد الطريقة لكل موظف: **موظف ← فئة (union) ← فرع ← الشركة**.
  إضافة أي طريقة جديدة = تضاف لثابت `ALLOWED` + مسار check-in.
- كشف تحايل مبدئي (advisory flags): `is_vpn` / `is_mock_location` / `is_rooted_device`
  (migration `2026_06_13_attendance_security_flags.sql`) + `AttendanceSecurityModel`.
- Geofence لكل فرع بنصف قطر (`GpsService`, `DEFAULT_GPS_RADIUS`).

> ملاحظة مهمة: التوسّع في الطرق مبني على `AttendanceMethodResolver::ALLOWED`
> (`['qr_gps','gps_only','manual']` حالياً). أي طريقة جديدة لازم تتضاف هناك + في واجهات
> الاختيار (tenant/branch/category/employee) عشان تظهر وتتحقق.

---

## المجموعة أ — نص مبنية بالفعل (أسرع مكسب) 🟢

عندك سباكة جاهزة اتعملت خلاص بس **مفيش check-in flow فعلي بيستخدمها لسه**.

### أ-1) سيلفي + تعرّف على الوجه بالموبايل مع Liveness ⭐ (الأولوية القصوى)
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

### أ-2) بصمة / وجه عبر Station (تابلت مثبّت في الفرع) 🟢
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

### ج-1) تكامل ZKTeco / Hikvision ⭐ (استراتيجي للسوق المصري)
- **كيف تشتغل:** الشركة عندها جهاز بصمة/وجه ZKTeco أو Hikvision؛ نستقبل الـ punches عبر
  SDK / push protocol ونطابقها بالموظفين.
- **المطلوب:** خدمة استقبال (push SDK أو polling) + ربط device user_id بموظف مجات + استيراد السجلات.
- **الجهد:** كبير. **الأولوية: 2** (ZKTeco مسيطرة على السوق المصري — أهم تكامل تجاري).

### ج-2) RFID / Proximity / Barcode badges
- عبر نفس ترمينالات ZKTeco/Hikvision أو قارئ مستقل. **الجهد:** متوسط (بعد ج-1). **الأولوية: 9**.

### ج-3) تحقق WiFi BSSID / IP (لفرق المكاتب والـ BPO)
- **كيف تشتغل:** الموظف ما يقدرش يسجّل إلا وهو متصل بشبكة/راوتر الشركة (BSSID) أو IP معتمد.
- **المطلوب:** قراءة BSSID/IP في التطبيق + قائمة معتمدة لكل فرع + تحقق backend.
- **الجهد:** متوسط. **الأولوية: 10**.

### ج-4) Bluetooth Beacon (auto check-in للمكاتب المغلقة)
- **كيف تشتغل:** BLE beacon مثبّت في الفرع، التطبيق يلتقطه ويعمل check-in تلقائي.
- **المطلوب:** beacon هاردوير رخيص + قراءة BLE + تحقق UUID.
- **الجهد:** متوسط. **الأولوية: 11** (بديل داخلي للـ GPS الضعيف جوّه المباني).

---

## جدول الأولويات الملخّص

| # | الطريقة | المجموعة | الحالة الحالية | الجهد |
|---|---|---|---|---|
| 1 | سيلفي + وجه + Liveness | أ | نص مبنية (enroll جاهز) | متوسط–كبير |
| 2 | تكامل ZKTeco / Hikvision | ج | من الصفر | كبير |
| 3 | Station بصمة/وجه (تابلت) | أ | نص مبنية (جداول جاهزة) | كبير |
| 4 | Geofencing تلقائي | ب | جزئي (geofence موجود) | متوسط |
| 5 | QR ثابت في الموقع | ب | تبسيط للموجود | صغير |
| 6 | NFC بالموبايل | ب | من الصفر | متوسط |
| 7 | PIN kiosk | ب | جزئي | متوسط |
| 8 | بوابة ويب self-service | ب | البنية موجودة | متوسط |
| 9 | RFID / Barcode badges | ج | يعتمد على ج-1 | متوسط |
| 10 | WiFi BSSID / IP | ج | من الصفر | متوسط |
| 11 | Bluetooth Beacon | ج | من الصفر | متوسط |

---

## ملاحظات تنفيذية عامة

1. **Liveness مش رفاهية:** أي طريقة وجه (موبايل أو station) لازم liveness detection ضد الصور —
   ده اللي بيقفل ثغرة الـ buddy punching. عندك أعمدة `anti_spoofing` جاهزة تستخدمها.
2. **نقطة التوسّع الواحدة:** كل طريقة جديدة = تضاف لـ `AttendanceMethodResolver::ALLOWED` +
   تظهر في واجهات الاختيار (شركة/فرع/فئة/موظف) عشان الـ resolver والـ check-in يعرفوها.
3. **رفع الـ flags لرفض فعلي:** حالياً `is_vpn/is_mock_location/is_rooted` بتتسجّل بس (advisory).
   ممكن تحويلها لرفض اختياري لكل شركة (خصوصاً mock location مع الطرق المعتمدة على GPS).
4. **الامتثال (قانون العمل 14/2025):** الطرق البيومترية والـ GPS بتتطلب موافقة صريحة من الموظف
   وسياسة احتفاظ بيانات (حفظ الملفات ≥ 5 سنين). يُراعى قبل إطلاق الوجه/السيلفي.
5. **الخصوصية والأداء للوجه:** يُفضّل المطابقة on-device (embedding يتطابق على الموبايل) وإرسال
   نتيجة + درجة ثقة بس للسيرفر، بدل رفع الصور كل مرة.

---

## التوصية المختصرة

ابدأ بالترتيب: **(1) سيلفي + وجه + Liveness** لأن نص السباكة جاهزة →
**(2) تكامل ZKTeco** لتغطية السوق المصري →
**(3) Station** بإعادة استخدام منطق مطابقة الوجه.
الباقي إضافات تكتيكية حسب طلب العملاء.
