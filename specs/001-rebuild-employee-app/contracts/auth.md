# Contract: Authentication (employee)

**Feature**: `001-rebuild-employee-app`. All requests carry Basic auth (`SECURITY_USER:SECURITY_KEY`) + `Content-Type: application/json` like every other endpoint. Protected requests additionally send `X-Employee-Token` and `X-Tenant-Id`.

> Match field names exactly — the Flutter app and PHP backend are co-designed here.

---

## POST `app/auth/employee_login.php` **[NEW]** — no token required

**Request body**
```json
{
  "phone": "0501234567",
  "activation_code": "AB23CD",
  "device_id": "uuid-stable-per-device",
  "device_model": "Pixel 7",
  "platform": "android",
  "app_version": "1.0.0"
}
```
Rules: `platform ∈ {android, ios}` (default `android`). `phone`/`activation_code`/`device_id` required (422 if empty). `activation_code` upper-cased server-side. Phone normalized (strip space/dash/leading `+`) before compare.

**Success 200**
```json
{
  "success": true,
  "token": "<64-hex plaintext — store once in secure storage>",
  "employee": {
    "id": 12, "name": "...", "phone": "0501234567",
    "tenant_id": 3, "tenant_name": "...",
    "branch_id": 5, "branch_name": "...",
    "job_title": "...", "profile_image": "https://..."
  }
}
```

**Failure**
| HTTP | Code/meaning | App message (Arabic) |
|---|---|---|
| 422 | missing field | حقل مطلوب |
| 404 | code invalid/expired/used | كود التفعيل غير صالح أو منتهي |
| 403 | phone ≠ code owner | رقم الهاتف لا يطابق كود التفعيل |
| 403 | employee terminated | الحساب موقوف |
| 500 | tx failure | تعذّر تسجيل الدخول |

**Server side-effects (one transaction)**: `employees.status='active', has_linked_account=1`; ensure/link lightweight `admins` row (role `employee`) → sets `employees.admin_id`; `ActivationCodeModel::markUsedByDevice(codeId, device_id)`; `EmployeeAuthTokenModel::issue(...)` (revokes prior active token first).

---

## POST `app/auth/employee_logout.php` **[NEW]** — `X-Employee-Token`

**Request**: empty body. **Effect**: `EmployeeAuthTokenModel::revokeByPlain(token, 'employee_logout')`.
**Success 200**: `{ "success": true }`. (Always succeeds even if token already gone.)

---

## `Auth::authenticateEmployee(PDO): array` **[NEW backend helper]**

Reads token from `X-Employee-Token` (fallback body/query). Behavior:
1. No token → 401 `Employee token is required`.
2. `EmployeeAuthTokenModel::findActiveByPlain(token)` null → **401** `جلستك انتهت، يرجى تسجيل الدخول مجدداً` (this 401 is what the app's central handler catches → logout+login).
3. Resolve `EmployeeModel::findById(employee_id, tenant_id)`; not found → 404; `status='terminated'` → 403.
4. Return `['employee_id','employee','tenant_id','branch_id','admin_id','input']`.

**Must NOT** modify `Auth::authenticateUser` (management app).

---

## App-side auth behavior (for the implementer)
- `auth_data.dart`: `login(phone, code)` posts to `employee_login` with `auth:false` (no token yet); `logout()` posts to `employee_logout`; `getProfile()` GETs `my_profile`.
- `auth_controller.dart`: on success → `TokenStorageService.saveToken(token)`, save `UserModel`, register FCM (`registerFcm`) AFTER token saved, `Get.offAllNamed(home)`. Map 403→phone-mismatch, 404→code-invalid.
- `isLoggedIn()`: token present + cached user parses → true (route home from splash).
- **Central 401**: any protected response with HTTP 401 → `clearSession()` + route to `login` with "انتهت الجلسة".
