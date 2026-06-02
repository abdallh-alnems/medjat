# Contract: Employee feature endpoints

**Feature**: `001-rebuild-employee-app`. All protected; send Basic auth + `X-Employee-Token` + `X-Tenant-Id`.
Pattern for **[EDIT]** files — replace the management-auth preamble:

```php
// OLD
$auth = Auth::authenticateUser(db());
$tenantId = TenantMiddleware::requireTenant();
$employee = EmployeeModel::findByAdminId($auth['admin_id'], $tenantId);
if (!$employee) { Response::fail('Employee profile not found', 404); }
// NEW
$auth = Auth::authenticateEmployee(db());
$tenantId = $auth['tenant_id'];   // trusted from token
$employee = $auth['employee'];    // pre-resolved
```
For shared endpoints that ALSO serve the management app, do **not** edit in place — create the employee sibling listed below.

---

## Leave
- **POST `app/leaves/apply.php`** **[EDIT]** — body `{date, type, reason?, start_date?, end_date?}`, `type ∈ {annual,sick,personal,unpaid}`. 409 `leave_overlap` on overlap. Manager notified via existing `SmartAlertService` (unchanged). Success `{leave_id, message}`.
- **GET `app/leaves/my_balance.php`** **[NEW sibling]** — employee self balance (same shape as `get_balance.php` returns: `{total, used, remaining, ...}` for `?year=`). Do NOT edit shared `get_balance.php` (it serves admin via `?employee_id=`).

## Attendance (personal, QR+GPS)
- **POST `app/attendance/check_in.php`** **[EDIT]** — body `{branch_id, latitude, longitude, qr_code?}`. Rejects: 404 branch; 400 `Invalid QR code for this branch`; 400 `GPS_OUT_OF_RANGE`. Success `{message, time, branch}`.
- **POST `app/attendance/check_out.php`** **[EDIT]** — analogous.
- **GET `app/attendance/get_my_attendance.php?month=YYYY-MM`** **[EDIT]** — month grid; app derives today's checked_in/out state.
- **POST `app/attendance/sync_offline.php`** **[EDIT]** — body `{records:[...]}` batch; returns `{synced, failed}`. Gated by company offline-attendance setting.

## Payroll
- **GET `app/payroll/get_slip.php?month=YYYY-MM`** **[EDIT]** — default current month; 404/not-found when no slip (app shows "no slip available"). Success = slip object.
- **PDF**: `?format=pdf` (or existing `get_slip_pdf.php`) fetched via `CRUD.getBytes` then `open_filex`.

## Profile / documents
- **GET `app/employees/my_profile.php`** **[NEW sibling]** — returns `$auth['employee']` + `leave_balance` + `documents` (simplified from shared `get_profile.php`, which serves admin). View-only; no employee edit endpoint (profile editing is out of scope, FR-019).

## Notifications + FCM
- **POST `app/auth/update_fcm_token.php`** **[EDIT]** — switch to `authenticateEmployee`; use `$auth['admin_id']` (guaranteed linked after login). 409 if no linked account. Body `{fcm_token, ...}`.
- **POST `app/auth/notification_prefs.php`** **[EDIT]** — uses `$auth['admin_id']`.
- **GET `app/notifications/list.php`** **[EDIT]** — uses `$auth['admin_id']`.
- **POST `app/notifications/read.php?id=`** **[EDIT]** — uses `$auth['admin_id']`.

---

## App `app_links.dart` **[EDIT]** target set
> File path is `lib/core/constant/id/app_links.dart` (the dir is `constant/id`, not `constant/api`).
```
employeeLogin  = /app/auth/employee_login.php
employeeLogout = /app/auth/employee_logout.php
registerFcm    = /app/auth/update_fcm_token.php
notificationPrefs = /app/auth/notification_prefs.php
myProfile      = /app/employees/my_profile.php
checkIn        = /app/attendance/check_in.php
checkOut       = /app/attendance/check_out.php
attendanceSync = /app/attendance/sync_offline.php
attendanceMonth(m) = /app/attendance/get_my_attendance.php?month=m
payrollSlipMonth(m) = /app/payroll/get_slip.php?month=m
payrollPdf(m)  = /app/payroll/get_slip.php?month=m&format=pdf
leaveApply     = /app/leaves/apply.php
leaveBalance   = /app/leaves/my_balance.php
notifications  = /app/notifications/list.php
notificationRead(id) = /app/notifications/read.php?id=id
```
Remove: `activateEmployee`, `me`.
