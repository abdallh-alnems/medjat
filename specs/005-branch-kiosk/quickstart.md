# Quickstart: Branch Kiosk

**Feature**: `005-branch-kiosk` · **Date**: 2026-08-03

How to build, run, and verify this feature locally, and how to get it live
without breaking the four deployment rules.

---

## 0. Before you touch anything

```bash
backend_medjet/check-drift.sh
```

Code, schema, and the migration ledger must agree **before** you start. This
feature adds four migrations and widens two enums; starting from a drifted state
means you will not be able to tell your damage from the pre-existing damage.

---

## 1. Backend against MAMP

MySQL on `127.0.0.1:8889`, `root`/`root`, database `medjat`. Use the MAMP PHP
binary — system `php` is a different version:

```bash
PHP=/Applications/MAMP/bin/php/php8.4.15/bin/php

# lint everything new before it runs
$PHP -l backend_medjet/app/kiosk/identify.php
$PHP -l backend_medjet/core/KioskIdentifier.php
```

Apply the migrations locally:

```bash
backend_medjet/migrations/migrate.sh --status
backend_medjet/migrations/migrate.sh          # applies the four new files in order
```

### Seed a station without the app

Pairing needs a code, and a code needs an administrator. Shortcut for local work:

```sql
-- generate a pairing code by hand (mirrors create_pairing_code.php)
SET @code = 'TEST-0001';
INSERT INTO kiosk_codes (tenant_id, branch_id, purpose, code_hash, expires_at, created_by)
VALUES (4, 3, 'pair', SHA2(@code, 256), DATE_ADD(NOW(), INTERVAL 900 SECOND), 1);
```

Note `DATE_ADD(NOW(), ...)` — **compute expiry in SQL, never in PHP**. The server
runs UTC while MySQL runs the tenant zone; a PHP-computed `expires_at` arrives
already expired. This has bitten this codebase before.

Then redeem it:

```bash
curl -s -X POST http://localhost:8888/backend_medjet/app/kiosk/pair.php \
  -H 'Content-Type: application/json' \
  -d '{"code":"TEST-0001","device_id":"dev-local","device_model":"curl","app_version":"1.0.0","platform":"android"}'
```

Keep the returned `kiosk_token`; every later call sends it as `X-Kiosk-Token`.

### Exercise identification without a tablet

`identify.php` takes an embedding, not an image, so you can drive it from the
command line. Pull a known-good embedding out of an already-enrolled employee:

```sql
SELECT id, face_embedding_dim, HEX(face_embedding) FROM employees
 WHERE face_embedding IS NOT NULL AND branch_id = 3 LIMIT 1;
```

Feed it back and you should get `outcome: "matched"` with a score near 1.0 and a
`runner_up_score` far below it. That difference **is** the margin rule — if the
runner-up is close on your seed data, your test roster is too small or too
synthetic to prove anything.

---

## 2. The kiosk app

Its own project, Android only:

```bash
cd frontend/mobile/kiosk
cp .env.example .env      # set API_HOST, SECURITY_USER, SECURITY_KEY
flutter pub get
flutter run
```

For a physical tablet against local MAMP:

```bash
adb reverse tcp:8888 tcp:8888
```

Lint each project with `flutter analyze lib` — bare `flutter analyze` walks
FlutterFire example files under `build/` and reports phantom errors.

### The shared package

`frontend/mobile/shared/` holds the face pipeline and `mobilefacenet.tflite`,
and both apps depend on it by path. After changing anything in it, run
`flutter pub get` in **both** consumers — a path dependency is not re-resolved on
its own.

The reason it exists is worth keeping in mind while working on it: the server
compares embeddings from both products against one stored vector per employee.
A change here that reaches one app and not the other does not raise an error —
it silently stops matching people.

Confirm the two apps really are separate:

```bash
cd ../medjat_app  && flutter build apk --debug
cd ../medjat_kiosk && flutter build apk --debug

# different packages, and the employee APK must carry NEITHER
# RECEIVE_BOOT_COMPLETED NOR WAKE_LOCK
aapt dump permissions ../employee/build/app/outputs/flutter-apk/app-debug.apk
aapt dump permissions build/app/outputs/flutter-apk/app-debug.apk
```

Then exercise face check-in in `medjat_app` once. Its model now loads from
`packages/medjat_shared/assets/models/mobilefacenet.tflite`; a wrong asset key
surfaces as "face unavailable" at runtime, not as a build failure, so a green
build proves nothing here.

---

## 3. Verifying the parts that are easy to get wrong

**Tenant time.** Set `tenants.timezone` to something far from the server zone
(`Asia/Dubai`), punch, and confirm `attendance.check_in_time` reflects Dubai. Bare
`date()` or `NOW()` anywhere in the write path shows up here as a multi-hour
offset.

**The margin rule.** Enroll two people, then present a capture that scores close
to both. Expect `outcome: "ambiguous"`, no attendance row, and a
`station_recognition_logs` row carrying both `match_score` and `runner_up_score`.
This is the single most important behaviour in the feature — a system that
silently picks the higher of two close scores is the failure mode 1:N exists to
avoid.

**Idempotency.** Send the same `punch.php` request twice with one
`idempotency_key`. Expect two `200`s, one attendance row. Then confirm
`attendance` gained exactly one row, not two.

**Revocation.** Revoke a station, then call `heartbeat.php` with its token.
Expect `401`, and confirm the tablet wipes local state rather than retrying.

**Permission separation.** Give a test user only `kiosk_access`. They must be
able to generate an access code and enroll, and must be refused on
`create_pairing_code.php` and `capture.php`. Then check the frontend hides both —
a visible control that 403s is the bug FR-061 exists to prevent.

**No biometrics at rest.** After a full session, inspect the tablet's app storage.
There must be no embedding, no roster, and no capture. If anything persists,
FR-025 is broken and the security argument for refusing offline operation was paid
for and not received.

---

## 4. Tuning before enforcing

Ship every tenant in `log_only`. Then:

```bash
curl -s -X POST .../app/kiosk/recognition_logs.php \
  -H "X-Firebase-Token: $TOKEN" \
  -d '{"branch_id":3,"view":"distribution"}'
```

Read the genuine and impostor distributions, set
`branches.station_match_threshold` and `station_match_margin` where they separate,
**then** switch to `enforce`.

Do not carry the 1:1 numbers over. `FaceMatchService::DEFAULT_THRESHOLD` is 0.450,
tuned for verifying one known person. Starting points for 1:N are **0.55 /
0.08**, and even those are guesses until a real branch has produced a few
thousand rows. Note also that `tenants.face_match_threshold` still carries a
column default of **0.650**, so existing tenant rows hold 0.650 regardless of what
the PHP constant says — read the data, not the constant.

---

## 5. Deploying

Never edit a file on the server; never run SQL by hand.

```bash
backend_medjet/deploy.sh --dry-run     # read this output properly
backend_medjet/deploy.sh               # code + migrations + php reload + smoke test
backend_medjet/check-drift.sh          # must come back clean
```

### Manual steps `deploy.sh` does not cover

Both of these were completed for the 2026-08-05 deploy; they are recorded here
because a fresh environment still needs them.

1. **Remote Config parameters.** ✅ Done — `medjat_kiosk_min_version` (`0.0.0`)
   and `medjat_kiosk_maintenance_enabled` (`false`) exist in project `medjat`
   (template v15). `RemoteConfigService::APPS` reads them by name; without them
   the kiosk entry resolves to `0.0.0` and no version gate exists.
2. **Cron.** ✅ Done — `/usr/local/bin/medjat-cron-kiosk-purge.sh` runs at 03:30
   from `/etc/cron.d/medjat`. Note it is called over **HTTP**, like the other
   crons: the endpoint authenticates on a query parameter, which a CLI
   invocation would not supply. Entry:
   ```
   30 3 * * * www-data /usr/bin/php /var/www/medjat/backend_medjet/app/cron/purge_kiosk_captures.php
   ```
   Until this runs, FR-056 is unmet and captures accumulate indefinitely.
3. **Uploads directory.** `backend_medjet/uploads/kiosk/` must exist and be
   writable by the web user.
4. **Kiosk APK distribution.** No store, so no pipeline. Build the release
   bundle, hand it to whoever installs tablets, and record which version went to
   which branch — `app/kiosk/list.php` will tell you what is actually out there,
   which is usually different from what you believe.

### Raising the minimum version later

Check the blast radius **first**:

```bash
curl -s -X POST .../app/kiosk/list.php -H "X-Firebase-Token: $TOKEN" -d '{}'
```

Every station with `below_min_version: true` stops recording attendance the
moment the minimum takes effect, and no store exists to update it. That is the
cost of direct installation, and it is why FR-054 exists.
