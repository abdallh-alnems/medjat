# Quickstart & Acceptance: Rebuild Employee App

**Feature**: `001-rebuild-employee-app` | **Date**: 2026-06-01

Implementer order is **backend → curl gate → Flutter**. Do not start Flutter until the curl gate passes.

---

## 0. Prereqs
- Backend running locally; set `HOST`, `BASIC` (base64 `user:key`), and pick a known employee whose `phone` you know.
- `export HOST="http://localhost:8080"` and `export BASIC="$(printf 'apiuser:secret' | base64)"`.

## 1. Backend acceptance (run BEFORE Flutter) — maps to spec acceptance criteria

```bash
# (admin) generate a code for the employee — via management app or:
#   POST app/employees/activation_code.php {employee_id} (needs admin Firebase auth)
# Then, employee login:
curl -sX POST "$HOST/app/auth/employee_login.php" \
  -H "Authorization: Basic $BASIC" -H 'Content-Type: application/json' \
  -d '{"phone":"0501234567","activation_code":"AB23CD","device_id":"dev-1","platform":"android","app_version":"1.0.0"}'
# EXPECT 200 success:true + token  (US1 #1, #5)

TOKEN="<paste token>"; TID="<tenant_id from response>"

# wrong phone → 403 (US1 #4)
curl -sX POST "$HOST/app/auth/employee_login.php" -H "Authorization: Basic $BASIC" -H 'Content-Type: application/json' \
  -d '{"phone":"0000000000","activation_code":"AB23CD","device_id":"dev-1","platform":"android"}'
# wrong/expired code → 404 (US1 #3)

# protected call works (US4 read)
curl -s "$HOST/app/attendance/get_my_attendance.php?month=2026-06" \
  -H "Authorization: Basic $BASIC" -H "X-Employee-Token: $TOKEN" -H "X-Tenant-Id: $TID"
# EXPECT 200

# leave apply + overlap (US3)
curl -sX POST "$HOST/app/leaves/apply.php" -H "Authorization: Basic $BASIC" \
  -H "X-Employee-Token: $TOKEN" -H "X-Tenant-Id: $TID" -H 'Content-Type: application/json' \
  -d '{"date":"2026-06-10","type":"annual","start_date":"2026-06-10","end_date":"2026-06-12"}'
# repeat same range → EXPECT 409 leave_overlap

# payroll no-slip month → not found state (US5)
curl -s "$HOST/app/payroll/get_slip.php?month=1999-01" -H "Authorization: Basic $BASIC" -H "X-Employee-Token: $TOKEN" -H "X-Tenant-Id: $TID"

# logout revokes (US2 #2)
curl -sX POST "$HOST/app/auth/employee_logout.php" -H "Authorization: Basic $BASIC" -H "X-Employee-Token: $TOKEN"
curl -s "$HOST/app/attendance/get_my_attendance.php?month=2026-06" -H "Authorization: Basic $BASIC" -H "X-Employee-Token: $TOKEN" -H "X-Tenant-Id: $TID"
# EXPECT 401  (central app handler would log out)

# re-issue invalidation (US2 #1): login again, then admin regenerates the code → next call 401
```

**Backend gate PASS criteria**: valid→200+token; wrong phone→403; bad code→404; valid token→200; after logout/re-issue→401; leave overlap→409.

## 2. Flutter build & run
```bash
cd frontend/mobile/employee
flutter pub get
grep -rn "firebase_auth\|google_sign_in" lib/   # MUST be empty (FR-022, SC-010)
flutter analyze                                  # MUST be clean (constitution Quality Gate)
flutter test                                     # unit + widget tests pass (constitution IV)
flutter run --dart-define-from-file=.env
```

## 3. Manual app verification (maps to user stories)
1. **US1** — enter phone+code → reach home; kill & reopen app → still signed in.
2. **US1 neg** — bad code → "كود التفعيل غير صالح أو منتهي"; mismatched phone → "رقم الهاتف لا يطابق كود التفعيل".
3. **US2** — admin regenerates code → next action returns to login with "انتهت الجلسة"; Settings → sign out works.
4. **US3** — view balance, submit leave, see it on management side + manager notified; overlap → conflict message.
5. **US4** — QR+GPS check-in at a branch; out-of-range → "outside branch range"; offline check-in syncs later.
6. **US5** — view + download payroll slip; empty month → "no slip available".
7. **US6** — profile view-only (no edit controls); notifications list + mark read; only own data.
8. **US7 (Kiosk)** — from login, enter Kiosk mode, scan admin pairing QR → roster shows; enrolled employee checks in by face/fingerprint; exit requires admin PIN; move device out of range → locked.
9. **Push** — receive a leave-decision notification (FCM still works without Firebase Auth).

## 4. Definition of Done (constitution Quality Gates)
- [ ] Backend curl gate passes (section 1)
- [ ] `flutter analyze` clean; `flutter test` green
- [ ] No `firebase_auth`/`google_sign_in` references; messaging/crashlytics retained
- [ ] All screens render correct Arabic RTL
- [ ] Tokens only in `flutter_secure_storage`; no hardcoded secrets
- [ ] Management app unaffected (smoke-test an admin flow) — FR-023/SC-008
