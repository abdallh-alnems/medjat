# خطة إعادة بناء تطبيق الموظف (Medjat App) — تسجيل الدخول بالهاتف + الكود

> **هذا الملف موجّه لنموذج/مطوّر آخر سينفّذ الكود.** اقرأه بالكامل قبل البدء.
> اتبع الترتيب: **Backend أولاً ثم Flutter**. لا تبدأ Flutter قبل أن تعمل الـ endpoints.
> اللغة في الكود وواجهة المستخدم: **عربي RTL** (موجود مسبقاً). التعليقات التقنية بالإنجليزية مقبولة.

---

## 0) السياق والقرار المعماري

### المشروعان
- **تطبيق الإدارة (المرجع):** `front_end/medjat_central` — منه نأخذ المعمارية والأنماط (CRUD، GetX، الثيم، طبقة البيانات).
- **تطبيق الموظف (الهدف):** `front_end/medjat_app` — مبني جزئياً، لكن مصادقته الحالية عبر **Firebase (Google/Email) + كود تفعيل**. سنغيّرها.
- **الـ Backend:** `backend_medjet` (PHP). يخدم التطبيقين.

### المشكلة الحالية
المصادقة الحالية في كل endpoints الموظف تمر عبر `Auth::authenticateUser()` التي:
1. تتحقق من **Firebase ID token**،
2. تبحث في جدول `admins` عن `firebase_uid`،
3. ترجع `admin_id`،
4. ثم تحلّ الموظف عبر `EmployeeModel::findByAdminId($adminId, $tenantId)`.

أي أن الموظف يجب أن يسجّل عبر Firebase ويكون مربوطاً بسجل `admin`. **هذا ما سنستبدله.**

### القرارات المعتمدة (من صاحب المشروع)
1. **النطاق:** ملف التنفيذ يشمل **Backend + Flutter** معاً.
2. **Firebase:** نزيل **مصادقة Firebase فقط** (Google/Email/Activation عبر Firebase token). نُبقي **Firebase Messaging (FCM)** للإشعارات و **Crashlytics/Analytics**.
3. **آلية الجلسة:** **دخول أول بالهاتف + كود التفعيل**، ثم يُصدر الخادم **token دائم مرتبط بالجهاز** يُخزَّن في جدول `employee_auth_tokens` (الجدول جاهز فعلاً في قاعدة البيانات). يبقى الموظف مسجلاً حتى يُلغى الـ token (عند إعادة توليد الكود من الإدارة أو تسجيل الخروج).

### نظرة عامة على التدفق الجديد
```
الإدارة (medjat_central) تنشئ الموظف وتولّد كود تفعيل 6 خانات (24 ساعة)  ← موجود
        │
        ▼
الموظف يفتح medjat_app → يُدخل [رقم الهاتف] + [كود التفعيل] + [device info]
        │  POST /app/auth/employee_login.php
        ▼
الخادم: يتحقق أن الكود فعّال وغير مستخدم، وأن هاتف الموظف صاحب الكود = الهاتف المُدخل
        → status = active
        → يلغي أي token قديم للموظف
        → يولّد token عشوائي، يخزّن SHA-256(token) في employee_auth_tokens (device_id, platform...)
        → يربط/ينشئ سجل admin خفيف للموظف (role='employee') حتى تعمل الإشعارات
        → يرجع: token (نص صريح، يُحفظ بالجهاز) + بيانات الموظف
        │
        ▼
كل طلب لاحق: header  X-Employee-Token: <token>  +  X-Tenant-Id: <tenant_id>
        → Auth::authenticateEmployee() يهشّ الـ token ويجد الموظف مباشرة
```

---

## القسم أ — تغييرات الـ Backend (`backend_medjet`)

> القاعدة الذهبية: **لا تكسر تطبيق الإدارة.** `Auth::authenticateUser()` تبقى كما هي تماماً.
> نضيف مساراً موازياً `Auth::authenticateEmployee()` ونعدّل **فقط** endpoints التي يستدعيها تطبيق الموظف.

### الجداول الجاهزة (لا تنشئها — موجودة في `migrations/schema.sql`)
- `employee_activation_codes` (code, expires_at, used_at, used_by_firebase_uid, employee_id, tenant_id)
- `employee_auth_tokens` (token_hash UNIQUE, device_id, device_model, platform enum('android','ios'), app_version, issued_at, last_used_at, revoked_at, revoke_reason, employee_id, tenant_id) — قيد `uniq_active_token_per_emp(employee_id, revoked_at)` يضمن token فعّال واحد لكل موظف.
- `employees.phone` فريد لكل tenant: `UNIQUE(tenant_id, phone)`.

### أ-1) توسيع `models/EmployeeAuthTokenModel.php`
الموديل الحالي فيه `findActiveForEmployee()` و`revokeForEmployee()` فقط. **أضف** الدوال التالية:

```php
// توليد token جديد وتخزين هاشه. يرجع النص الصريح ليُرسل للتطبيق مرة واحدة.
public static function issue(
    int $tenantId, int $employeeId, string $deviceId,
    ?string $deviceModel, string $platform, ?string $appVersion
): string {
    // اضمن token فعّال واحد فقط (القيد uniq_active_token_per_emp)
    self::revokeForEmployee($employeeId, 'reissued_on_login');

    $plain = bin2hex(random_bytes(32));          // 64 hex chars
    $hash  = hash('sha256', $plain);

    Database::execute(
        "INSERT INTO employee_auth_tokens
           (tenant_id, employee_id, token_hash, device_id, device_model, platform, app_version)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
        [$tenantId, $employeeId, $hash, $deviceId, $deviceModel, $platform, $appVersion]
    );
    return $plain;
}

// إيجاد token فعّال عبر النص الصريح (للمصادقة). يحدّث last_used_at.
public static function findActiveByPlain(string $plain): ?array {
    $hash = hash('sha256', $plain);
    $row = Database::fetchOne(
        "SELECT id, tenant_id, employee_id, device_id, platform
         FROM employee_auth_tokens
         WHERE token_hash = ? AND revoked_at IS NULL LIMIT 1",
        [$hash]
    );
    if ($row) {
        Database::execute(
            "UPDATE employee_auth_tokens SET last_used_at = NOW() WHERE id = ?",
            [$row['id']]
        );
    }
    return $row ?: null;
}

public static function revokeByPlain(string $plain, string $reason): void {
    $hash = hash('sha256', $plain);
    Database::execute(
        "UPDATE employee_auth_tokens SET revoked_at = NOW(), revoke_reason = ?
         WHERE token_hash = ? AND revoked_at IS NULL",
        [$reason, $hash]
    );
}
```

> **ملاحظة على القيد `uniq_active_token_per_emp(employee_id, revoked_at)`:** لأن `revoked_at` NULL لا يُعتبر مكرراً في بعض إصدارات MySQL، فإن استدعاء `revokeForEmployee` قبل `INSERT` يكفي. إن ظهر خطأ تكرار، فالسبب وجود token فعّال لم يُلغَ — تأكد من ترتيب الاستدعاء.

### أ-2) توسيع `models/ActivationCodeModel.php`
الدالة `markUsed($codeId, $firebaseUid)` تأخذ firebase_uid. سنسجّل الجهاز بدل الـ uid:

```php
public static function markUsedByDevice(int $codeId, string $deviceId): void {
    Database::execute(
        "UPDATE employee_activation_codes
         SET used_at = NOW(), used_by_firebase_uid = ?  -- نعيد استخدام العمود لتخزين device_id
         WHERE id = ?",
        ['device:' . $deviceId, $codeId]
    );
}
```
(لا تغيّر `markUsed` القديمة حتى لا تكسر `activate_employee.php` القديم — يمكن إبقاؤه أو حذفه لاحقاً.)

### أ-3) المصادقة الجديدة في `core/Auth.php`
**أضف** دالة جديدة (لا تلمس `authenticateUser`):

```php
// مصادقة الموظف عبر X-Employee-Token. ترجع شكلاً متوافقاً مع authenticateUser
// لكن مع employee_id محلولاً مسبقاً، حتى تسهل تعديلات endpoints.
public static function authenticateEmployee(PDO $con): array {
    $input = json_decode(file_get_contents('php://input'), true) ?: [];

    $token = $_SERVER['HTTP_X_EMPLOYEE_TOKEN']
           ?? $input['employee_token']
           ?? $_GET['employee_token']
           ?? null;
    if (!$token) {
        Response::fail('Employee token is required', 401);
    }

    $row = EmployeeAuthTokenModel::findActiveByPlain($token);
    if (!$row) {
        Response::fail('جلستك انتهت، يرجى تسجيل الدخول مجدداً', 401);
    }

    $employee = EmployeeModel::findById((int) $row['employee_id'], (int) $row['tenant_id']);
    if (!$employee) {
        Response::fail('Employee not found', 404);
    }
    if (in_array($employee['status'], ['terminated'], true)) {
        Response::fail('Account terminated', 403);
    }

    return [
        'employee_id' => (int) $employee['id'],
        'employee'    => $employee,
        'tenant_id'   => (int) $employee['tenant_id'],
        'branch_id'   => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
        'admin_id'    => $employee['admin_id'] ? (int) $employee['admin_id'] : null,
        'input'       => $input,
    ];
}
```

### أ-4) endpoint تسجيل الدخول الجديد: `app/auth/employee_login.php`
ملف جديد. **لا يستخدم Firebase إطلاقاً.**

```php
<?php
require_once __DIR__ . '/../../config/bootstrap.php';

RateLimiter::enforceIpLimit();
Auth::requirePost();

$input = json_decode(file_get_contents('php://input'), true) ?: [];
$phone       = trim((string)($input['phone'] ?? ''));
$code        = strtoupper(trim((string)($input['activation_code'] ?? '')));
$deviceId    = trim((string)($input['device_id'] ?? ''));
$deviceModel = $input['device_model'] ?? null;
$platform    = in_array($input['platform'] ?? '', ['android','ios'], true) ? $input['platform'] : 'android';
$appVersion  = $input['app_version'] ?? null;

if ($phone === '')    Response::fail('رقم الهاتف مطلوب', 422);
if ($code === '')     Response::fail('كود التفعيل مطلوب', 422);
if ($deviceId === '') Response::fail('Device ID required', 422);

// 1) الكود فعّال وغير مستخدم
$codeRow = ActivationCodeModel::findByCode($code);   // يبحث في كل الـ tenants، ويتحقق expires_at + used_at
if (!$codeRow) {
    Response::fail('كود التفعيل غير صالح أو منتهي', 404);
}

// 2) الموظف صاحب الكود، وهاتفه يطابق المُدخل (طبّع الأرقام قبل المقارنة)
$employee = Database::fetchOne(
    "SELECT e.*, b.name AS branch_name, t.name AS tenant_name
     FROM employees e
     LEFT JOIN branches b ON b.id = e.branch_id
     LEFT JOIN tenants  t ON t.id = e.tenant_id
     WHERE e.id = ? LIMIT 1",
    [(int) $codeRow['employee_id']]
);
if (!$employee) {
    Response::fail('الموظف غير موجود', 404);
}

$norm = fn(string $p) => preg_replace('/[\s\-\+]/', '', $p);   // إزالة مسافات/شرطات/+
if ($norm($employee['phone'] ?? '') !== $norm($phone)) {
    Response::fail('رقم الهاتف لا يطابق كود التفعيل', 403);
}

$tenantId   = (int) $employee['tenant_id'];
$employeeId = (int) $employee['id'];

$pdo = db();
try {
    $pdo->beginTransaction();

    // 3) تفعيل الموظف
    Database::execute(
        "UPDATE employees SET status = 'active', has_linked_account = 1, updated_at = NOW() WHERE id = ?",
        [$employeeId]
    );

    // 4) اضمن سجل admin خفيف للموظف (تعمل عليه الإشعارات الحالية المرتبطة بـ admin_id)
    $adminId = $employee['admin_id'] ? (int) $employee['admin_id'] : null;
    if (!$adminId) {
        Database::execute(
            "INSERT INTO admins (tenant_id, branch_id, name, phone, role, is_active, last_login_at)
             VALUES (?, ?, ?, ?, 'employee', 1, NOW())",
            [$tenantId, $employee['branch_id'], $employee['name'], $employee['phone']]
        );
        $adminId = (int) Database::lastInsertId();
        Database::execute("UPDATE employees SET admin_id = ? WHERE id = ?", [$adminId, $employeeId]);
    } else {
        Database::execute("UPDATE admins SET last_login_at = NOW(), is_active = 1 WHERE id = ?", [$adminId]);
    }

    // 5) علّم الكود مستخدماً، وأصدر token الجهاز
    ActivationCodeModel::markUsedByDevice((int) $codeRow['id'], $deviceId);
    $token = EmployeeAuthTokenModel::issue(
        $tenantId, $employeeId, $deviceId, $deviceModel, $platform, $appVersion
    );

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('employee_login failed: ' . $e->getMessage());
    Response::fail('تعذّر تسجيل الدخول', 500);
}

Response::success([
    'success' => true,
    'token'   => $token,                 // يُحفظ بالجهاز مرة واحدة فقط
    'employee' => [
        'id'          => $employeeId,
        'name'        => $employee['name'],
        'phone'       => $employee['phone'],
        'tenant_id'   => $tenantId,
        'tenant_name' => $employee['tenant_name'],
        'branch_id'   => $employee['branch_id'] ? (int) $employee['branch_id'] : null,
        'branch_name' => $employee['branch_name'],
        'job_title'   => $employee['job_title'],
        'profile_image' => $employee['profile_image'] ?? null,
    ],
]);
```

> **متطلب على تطبيق الإدارة:** عند إنشاء الموظف يجب أن يُدخَل رقم الهاتف (موجود في النموذج). وعند توليد الكود (`employees/activation_code.php`) — موجود ويعمل. لا تغيير مطلوب هناك سوى التأكد أن الإدارة تعرض الكود + الهاتف للموظف لتسليمه.

### أ-5) endpoint تسجيل الخروج: `app/auth/employee_logout.php`
```php
<?php
require_once __DIR__ . '/../../config/bootstrap.php';
RateLimiter::enforceIpLimit();
Auth::requirePost();
$token = $_SERVER['HTTP_X_EMPLOYEE_TOKEN'] ?? '';
if ($token !== '') {
    EmployeeAuthTokenModel::revokeByPlain($token, 'employee_logout');
}
Response::success(['success' => true]);
```

### أ-6) تعديل endpoints الموظف لتستخدم المصادقة الجديدة
لكل ملف من القائمة التالية: **استبدل** سطر المصادقة وحلّ الموظف.

**النمط القديم:**
```php
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
...
$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) { Response::fail('Employee profile not found', 404); }
```
**النمط الجديد:**
```php
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];           // مأخوذ من الـ token، موثوق
$employee = $auth['employee'];            // محلول مسبقاً
```
> احذف استدعاء `TenantMiddleware::requireTenant()` من هذه الملفات (الـ token هو مصدر الثقة)، أو أبقه إن أردت فحص حالة الاشتراك — لكن انتبه أنه يقرأ `X-Tenant-Id` من الـ header (سيرسله التطبيق).

الملفات المطلوب تعديلها:
| الملف | الوظيفة | ملاحظة |
|---|---|---|
| `app/leaves/apply.php` | تقديم طلب إجازة | استخدم `$auth['employee']`؛ يبقى إشعار المدراء كما هو |
| `app/leaves/get_balance.php` | رصيد الإجازات | فرع `employee_id` من الإدارة يبقى عبر `authenticateUser`؛ أنشئ نسخة موظف أو افصل المنطق (انظر أدناه) |
| `app/attendance/check_in.php` | حضور | — |
| `app/attendance/check_out.php` | انصراف | — |
| `app/attendance/get_my_attendance.php` | حضوري الشهري | — |
| `app/attendance/sync_offline.php` | مزامنة حضور غير متصل | — |
| `app/payroll/get_slip.php` | قسيمة راتبي | — |
| `app/auth/update_fcm_token.php` | تسجيل FCM | انظر أ-7 |
| `app/auth/notification_prefs.php` | تفضيلات الإشعارات | استخدم `admin_id` من `$auth` |
| `app/notifications/list.php` | قائمة الإشعارات | تستخدم `admin_id`؛ مرّر `$auth['admin_id']` |
| `app/notifications/read.php` | تعليم مقروء | `admin_id` |

> **بخصوص `get_balance.php` و`get_profile.php`:** هذان يخدمان الإدارة **والموظف**. الأبسط: أنشئ **endpoints مخصّصة للموظف** بدل تعديل المشتركة، لتفادي كسر الإدارة:
> - `app/leaves/my_balance.php` → يستخدم `authenticateEmployee` ويرجع نفس شكل `get_balance.php`.
> - `app/employees/my_profile.php` → يستخدم `authenticateEmployee`، يرجع `$auth['employee']` + `leave_balance` + `documents` (نسخة مبسطة من `get_profile.php`).
> هذا أنظف من حقن منطق فرعين في ملف واحد. **اعتمد هذا النهج للملفات المشتركة فقط؛** الملفات الخاصة بالموظف (check_in/out, apply, get_my_attendance, get_slip) عدّلها مباشرة.

### أ-7) FCM للموظف (`update_fcm_token.php`)
الإشعارات مرتبطة بـ `admin_id` وتُخزَّن في `admin_devices` و`notifications`. بما أننا أنشأنا سجل admin خفيف للموظف (خطوة أ-4)، يكفي:
```php
$auth = Auth::authenticateEmployee(db());
$adminId = $auth['admin_id'];           // مضمون بعد employee_login
if (!$adminId) Response::fail('No linked account', 409);
// ... باقي المنطق كما هو، باستخدام $adminId
```
هكذا تصل إشعارات الإدارة (الموافقة على الإجازة، الرواتب...) للموظف عبر نفس البنية دون تعديل `SmartAlertService`.

### أ-8) فحص قبول الـ Backend (افعلها قبل Flutter)
استخدم `curl` على بيئة محلية:
```bash
# 1) من الإدارة: ولّد كوداً لموظف هاتفه معروف (عبر activation_code.php)
# 2) سجّل دخول الموظف:
curl -sX POST "$HOST/app/auth/employee_login.php" \
  -H 'Content-Type: application/json' \
  -d '{"phone":"0501234567","activation_code":"AB23CD","device_id":"dev-test-1","platform":"android","app_version":"1.0.0"}'
# توقّع: success=true + token
# 3) جرّب endpoint محمي:
curl -s "$HOST/app/attendance/get_my_attendance.php?month=2026-05" \
  -H "X-Employee-Token: <TOKEN>" -H "X-Tenant-Id: <TID>"
# 4) أعد توليد الكود من الإدارة ← يجب أن يُلغى الـ token ويعطي 401 على الطلب التالي.
```
**معايير القبول:** هاتف خاطئ → 403، كود منتهٍ → 404، token صحيح → 200، بعد إعادة التوليد → 401.

---

## القسم ب — تطبيق الموظف (`medjat_app` / Flutter)

> الأنماط مأخوذة من `medjat_central`: طبقة `CRUD` + `data_source` لكل ميزة + `GetxController` + `GetBuilder`/`Obx` + `StatusRequest`.
> **أعد استخدام** ما هو موجود في `medjat_app` (معظم الشاشات موجودة). المطلوب أساساً **استبدال طبقة المصادقة** وتوصيل الترويسات.

### ب-1) إزالة مصادقة Firebase (مع إبقاء Messaging/Crashlytics/Analytics)
1. **`pubspec.yaml`:** احذف `firebase_auth` و`google_sign_in`. أبقِ `firebase_core` (لازم لـ messaging)، `firebase_messaging`، `firebase_crashlytics`, `firebase_analytics`, `firebase_remote_config`, `firebase_app_check`.
2. **أضف** `device_info_plus: ^11.0.0` (لقراءة موديل الجهاز) — اختياري؛ يمكن الاكتفاء بـ `Platform.isAndroid`. أبقِ `flutter_secure_storage` (موجود) لتخزين الـ token و`device_id`.
3. **`lib/main.dart`:** لا تحذف تهيئة Firebase (messaging تحتاجها). احذف فقط أي استدعاء خاص بـ Auth إن وُجد. التهيئة الحالية سليمة.
4. احذف الأصول/الأكواد الخاصة بزر Google.

### ب-2) `token_storage_service.dart` — أضف device_id
الموجود يكفي للـ token (`saveToken/getToken`) وبيانات المستخدم. **أضف** مفتاح `device_id` ثابت:
```dart
static const _deviceIdKey = 'device_id';
static Future<String> getOrCreateDeviceId() async {
  var id = await _storage.read(key: _deviceIdKey);
  if (id == null || id.isEmpty) {
    id = DateTime.now().microsecondsSinceEpoch.toString() +
         '-' + (1000 + (DateTime.now().millisecond)).toString();
    // الأفضل: استخدم Uuid().v4() إن أضفت حزمة uuid، أو randomBytes
    await _storage.write(key: _deviceIdKey, value: id);
  }
  return id;
}
```
> الـ `device_id` يجب أن يكون **ثابتاً عبر تشغيلات التطبيق** (لذلك يُخزَّن مرة واحدة).

### ب-3) `lib/core/class/crud.dart` — تبديل الترويسات
هذه أهم خطوة. انسخ ملف CRUD من `medjat_central` كأساس، ثم **استبدل منطق الترويسات**: احذف كل ما يخص `FirebaseAuth` و`X-Firebase-Token`، وأضف `X-Employee-Token` من التخزين الآمن. أبقِ `X-Tenant-Id`، `Basic Auth` (SECURITY_USER/KEY من `.env`)، فحص الاتصال، و`handleResponse` كما هي.

```dart
Future<Map<String, String>> _headers() async {
  final headers = _baseHeaders();                       // Basic auth + Content-Type
  final token = await TokenStorageService.getToken();
  if (token != null && token.isNotEmpty) {
    headers['X-Employee-Token'] = token;
  }
  final userData = await TokenStorageService.getUserData();
  if (userData != null) {
    try {
      final tenantId = (jsonDecode(userData) as Map)['tenant_id'];
      if (tenantId != null && tenantId != 0) {
        headers['X-Tenant-Id'] = tenantId.toString();
      }
    } catch (_) {}
  }
  return headers;
}
```
- في `getData`: احذف فروع `FirebaseAuth ... params['token']`. أبقِ تمرير `tenant_id` كـ query إن لم يُضف كترويسة (احتياطي).
- في `handleResponse`: عند **401** — أضف معالجاً مركزياً (في الـ controllers) يسجّل الخروج محلياً ويوجّه لشاشة الدخول.

### ب-4) `lib/core/constant/id/app_links.dart`
استبدل بالكامل (لاحظ أننا أزلنا activate_employee و me القديمة):
```dart
class AppLinks {
  AppLinks._();
  static String get base => dotenv.env['API_HOST'] ?? '';

  // Auth (phone + code)
  static String get employeeLogin  => '$base/app/auth/employee_login.php';
  static String get employeeLogout => '$base/app/auth/employee_logout.php';
  static String get updateProfile  => '$base/app/auth/update_profile.php';
  static String get registerFcm    => '$base/app/auth/update_fcm_token.php';
  static String get notificationPrefs => '$base/app/auth/notification_prefs.php';

  // Profile / me
  static String get myProfile => '$base/app/employees/my_profile.php';

  // Attendance
  static String get checkIn  => '$base/app/attendance/check_in.php';
  static String get checkOut => '$base/app/attendance/check_out.php';
  static String get attendanceSync => '$base/app/attendance/sync_offline.php';
  static String attendanceMonth(String m) =>
      '$base/app/attendance/get_my_attendance.php?month=$m';

  // Payroll
  static String payrollSlipMonth(String m) => '$base/app/payroll/get_slip.php?month=$m';
  static String payrollPdf(String m) => '$base/app/payroll/get_slip.php?month=$m&format=pdf';

  // Leaves
  static String get leaveApply   => '$base/app/leaves/apply.php';
  static String get leaveBalance => '$base/app/leaves/my_balance.php';

  // Notifications
  static String get notifications => '$base/app/notifications/list.php';
  static String notificationRead(int id) => '$base/app/notifications/read.php?id=$id';
}
```

### ب-5) `user_model.dart`
الموجود مناسب. تأكد أن `fromJson` يقرأ `profile_image` (أضِف map: `photoUrl: json['profile_image'] ?? json['photo_url']`). لا حاجة لحقل email بعد الآن (اجعله اختيارياً افتراضياً `''`).

### ب-6) `auth_data.dart` — أعد كتابتها بالكامل
```dart
class AuthData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> login({
    required String phone,
    required String activationCode,
  }) async {
    final deviceId = await TokenStorageService.getOrCreateDeviceId();
    final info = await PackageInfo.fromPlatform();           // app_version
    return _crud.postData(AppLinks.employeeLogin, {
      'phone': phone.trim(),
      'activation_code': activationCode.trim().toUpperCase(),
      'device_id': deviceId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'device_model': /* device_info_plus أو null */ null,
      'app_version': info.version,
    }, auth: false);     // لا يحتاج X-Employee-Token (لا يوجد بعد)
  }

  Future<void> logout() async {
    try { await _crud.postData(AppLinks.employeeLogout, {}); } catch (_) {}
    await TokenStorageService.clearAll();      // يمسح token + user (يبقى device_id إن أردت — انقله قبل clearAll أو استخدم delete مفاتيح محددة)
  }

  Future<UserModel?> getCachedUser() async {
    final j = await TokenStorageService.getUserData();
    if (j == null) return null;
    try { return UserModel.fromJson(jsonDecode(j)); } catch (_) { return null; }
  }

  Future<Map<String, dynamic>> getProfile() => _crud.getData(AppLinks.myProfile);
}
```
> **انتبه:** `clearAll()` يمسح `device_id` أيضاً. عند تسجيل الخروج اقرأ الـ device_id واحفظه بعد المسح، أو احذف فقط مفاتيح `auth_token` و`user_data`. الأفضل إضافة `clearSession()` في `TokenStorageService` تحذف هذين المفتاحين فقط.

### ب-7) `auth_controller.dart` — أعد كتابتها بالكامل
احذف كل شيء عن Firebase/Google/email/activation. الجديد:
```dart
class AuthController extends GetxController {
  final AuthData _authData = Get.find<AuthData>();
  final status = StatusRequest.none.obs;
  UserModel? user;

  Future<void> login({required String phone, required String code}) async {
    status.value = StatusRequest.loading; update();
    final res = await _authData.login(phone: phone, activationCode: code);
    if (res['status'] == StatusRequest.success && res['data']?['token'] != null) {
      final data = res['data'] as Map<String, dynamic>;
      await TokenStorageService.saveToken(data['token'] as String);
      final emp = data['employee'] as Map<String, dynamic>;
      user = UserModel.fromJson(emp);
      await TokenStorageService.saveUserData(jsonEncode(user!.toJson()));
      status.value = StatusRequest.success;
      PushNotificationService.registerTokenNow();    // يسجّل FCM عبر X-Employee-Token
      Get.offAllNamed<void>(AppRoutes.home);
    } else {
      status.value = StatusRequest.failure;
      final code = res['statusCode'];
      final msg = code == 403 ? 'رقم الهاتف لا يطابق كود التفعيل'
                : code == 404 ? 'كود التفعيل غير صالح أو منتهي'
                : (res['message'] as String?) ?? 'تعذّر تسجيل الدخول';
      Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> logout() async {
    await _authData.logout();
    user = null;
    Get.offAllNamed<void>(AppRoutes.login);
  }

  Future<bool> isLoggedIn() async {
    final hasToken = await TokenStorageService.hasToken();
    if (!hasToken) return false;
    user = await _authData.getCachedUser();
    return user != null;
  }
}
```

### ب-8) `splash_screen.dart`
احذف اعتماد `FirebaseAuth`. المنطق الجديد:
```dart
Future<void> _init() async {
  await Future.delayed(const Duration(milliseconds: 1200));
  if (!mounted) return;
  final ok = await Get.find<AuthController>().isLoggedIn();
  Get.offAllNamed<void>(ok ? AppRoutes.home : AppRoutes.login);
}
```

### ب-9) `login_screen.dart` — أعد بناؤها
شاشة واحدة بحقلين فقط: **رقم الهاتف** + **كود التفعيل**. احذف email/password/Google وزر التبديل.
- حقل الهاتف: `TextInputType.phone`، validator غير فارغ.
- حقل الكود: `TextInputType.text`، 6 خانات، `textCapitalization: TextCapitalization.characters`، validator طول ≥ 4.
- زر `PrimaryButton('دخول')` → `controller.login(phone:..., code:...)`، مع `isLoading` من `status`.
- نص توضيحي: "اطلب رقم هاتفك وكود التفعيل من إدارة الشركة".
- استخدم `PrimaryInput` و`PrimaryButton` الموجودة، ونفس أسلوب الثيم في الشاشة الحالية.

### ب-10) `app_pages.dart` (Bindings) و`app_routes.dart`
- في `AppBindings.dependencies()`: أبقِ `CRUD`, `AuthData`, `ProfileData`, `PayrollData`, `LeaveData`, `NotificationData`, الخدمات، و`AuthController` (permanent). لا تغيير جوهري.
- احذف أي مرجع لشاشات/منطق Firebase.
- المسارات الحالية مناسبة (splash, login, home(TabShell), scanQr, payroll, leaves, notifications, myProfile, myDocuments, settings). أبقِها.

### ب-11) ميزات الموظف (تتصل بالـ endpoints المعدّلة)
كل هذه موجودة في `medjat_app` وتعمل عبر طبقة `CRUD`؛ بعد تبديل الترويسات (ب-3) ستعمل تلقائياً مقابل المصادقة الجديدة. **تحقق من كل ميزة:**

1. **طلب إجازة (الأهم):** `leave_controller.dart` + `leave_data.dart` + `leave_screen.dart` (موجودة).
   - `getBalance()` → `AppLinks.leaveBalance` (= my_balance.php الجديد).
   - `apply()` → `AppLinks.leaveApply`. الحقول: `date, type(annual|sick|personal|unpaid), reason?, start_date?, end_date?`.
   - الشاشة: اختيار النوع، تاريخ من/إلى، سبب، زر تقديم؛ عرض الرصيد. تعامل مع 409 (تداخل).

2. **الحضور/الانصراف (QR + GPS):** `attendance_controller.dart`, `home_controller.dart`, `scan_qr_screen.dart`.
   - check_in يحتاج `branch_id, latitude, longitude, qr_code`. مزامنة offline عبر Hive موجودة.
   - تأكد أن `home` يقرأ `get_my_attendance` لتحديد حالة اليوم (checked_in/out).

3. **قسيمة الراتب:** `payroll_controller.dart`, `payroll_screen.dart` → `payrollSlipMonth(month)`، وعرض/تنزيل PDF عبر `getBytes` (موجود في CRUD) ثم `open_filex`.

4. **ملفي الشخصي:** `profile_controller.dart`, `my_profile_screen.dart` → `myProfile` (my_profile.php). تعديل بيانات محدودة عبر `update_profile.php` (الموجود في الإدارة — تأكد أنه يقبل مصادقة الموظف؛ إن كان يستخدم `authenticateUser` فبدّله إلى `authenticateEmployee` أو أنشئ `update_my_profile.php`).

5. **مستنداتي:** `my_documents_screen.dart` → استخدم بيانات `my_profile.php` (ترجع documents)، أو endpoint مخصص إن لزم.

6. **الإشعارات:** `notification_controller.dart`, `notifications_screen.dart` → `notifications` + `notificationRead(id)`. تعمل عبر admin_id المرتبط.

7. **الإعدادات + تسجيل الخروج:** `settings_screen.dart` → زر خروج يستدعي `AuthController.logout()`؛ حذف الحساب (إن وُجد) يلغي الـ token فقط.

### ب-12) `push_notification_service.dart`
- يجب أن يُسجّل FCM token عبر `CRUD.postData(AppLinks.registerFcm, {...})` (الذي يرسل `X-Employee-Token`).
- لا تعتمد على Firebase **Auth**؛ FCM (Messaging) مستقل ويعمل دون مصادقة Firebase. تأكد أن استدعاء `registerTokenNow()` يحدث **بعد** نجاح login (لأن الترويسة تحتاج token).

---

## القسم ج — قائمة تحقق نهائية (Checklist)

### Backend
- [ ] `models/EmployeeAuthTokenModel.php`: + `issue`, `findActiveByPlain`, `revokeByPlain`.
- [ ] `models/ActivationCodeModel.php`: + `markUsedByDevice`.
- [ ] `core/Auth.php`: + `authenticateEmployee` (دون لمس `authenticateUser`).
- [ ] `app/auth/employee_login.php` (جديد).
- [ ] `app/auth/employee_logout.php` (جديد).
- [ ] `app/leaves/my_balance.php` (جديد، للموظف).
- [ ] `app/employees/my_profile.php` (جديد، للموظف).
- [ ] تعديل: `leaves/apply.php`, `attendance/{check_in,check_out,get_my_attendance,sync_offline}.php`, `payroll/get_slip.php`, `auth/update_fcm_token.php`, `auth/notification_prefs.php`, `notifications/{list,read}.php`, و`auth/update_profile.php` (أو نسخة موظف) → `authenticateEmployee`.
- [ ] اختبار curl لكل الحالات (أ-8).

### Flutter
- [ ] `pubspec.yaml`: حذف `firebase_auth`, `google_sign_in`؛ (اختياري) إضافة `device_info_plus`.
- [ ] `crud.dart`: ترويسة `X-Employee-Token` بدل Firebase.
- [ ] `token_storage_service.dart`: + `getOrCreateDeviceId`, + `clearSession`.
- [ ] `app_links.dart`: التحديث الكامل.
- [ ] `auth_data.dart`, `auth_controller.dart`, `splash_screen.dart`, `login_screen.dart`: إعادة كتابة.
- [ ] حذف أي import لـ `firebase_auth`/`google_sign_in` في كل المشروع (`grep -rn "firebase_auth\|google_sign_in" lib/`).
- [ ] التحقق من كل ميزة (ب-11) على جهاز حقيقي مع باك-إند فعلي.
- [ ] `flutter analyze` نظيف + بناء Android/iOS.

### معايير القبول النهائية
1. موظف بهاتف وكود صحيحين → يدخل ويصل للرئيسية، ويبقى مسجلاً بعد إعادة فتح التطبيق.
2. كود خاطئ/منتهٍ → رسالة واضحة، لا دخول.
3. هاتف لا يطابق الكود → رسالة "رقم الهاتف لا يطابق كود التفعيل".
4. تقديم طلب إجازة ينجح ويظهر للإدارة، وإشعار يصل للمدير.
5. الحضور بالـ QR + GPS يعمل، والمزامنة offline تعمل.
6. قسيمة الراتب تُعرض/تُنزَّل.
7. إعادة توليد الكود من الإدارة → التطبيق يُخرَج تلقائياً (401) عند الطلب التالي ويعود لشاشة الدخول.
8. لا أثر لـ Firebase Auth في الكود؛ الإشعارات (FCM) ما زالت تعمل.

---

## ملاحظات مهمة للمنفّذ
- **لا تكسر تطبيق الإدارة:** أي ملف مشترك (get_balance, get_profile, update_profile) — أنشئ نسخة موظف بدل تعديل المنطق القائم، إلا إذا تأكدت أن التعديل يدعم المسارين.
- **الأمان:** الـ token الصريح يظهر مرة واحدة في رد login فقط؛ يُخزَّن هاشه (SHA-256) في قاعدة البيانات. يُخزَّن في الجهاز عبر `flutter_secure_storage` فقط.
- **رقم الهاتف فريد لكل tenant** فقط؛ لهذا نعتمد على **الكود** (فريد عالمياً) لتحديد الموظف، والهاتف كتحقق ثانٍ.
- **طبّع رقم الهاتف** (إزالة مسافات/شرطات/+) قبل المقارنة في الـ backend وقبل الإرسال إن أمكن.
- التزم بأنماط `medjat_central` في تسمية الملفات والمجلدات و`StatusRequest` و`HandlingDataRequest`.
