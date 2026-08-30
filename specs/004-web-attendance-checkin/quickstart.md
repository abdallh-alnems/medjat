# Quickstart — Web Attendance Check-In / Check-Out

**Feature**: `004-web-attendance-checkin` · **Branch**: `004-web-attendance-checkin`

How to run, exercise and ship this feature. Assumes the standing project setup
in `CLAUDE.md`.

---

## 1. Before you start

```bash
backend_medjet/check-drift.sh          # repo, local DB and production must agree first
```

Do this **before** writing anything. Starting from a drifted state means you
cannot tell your changes from someone else's later.

---

## 2. Local backend (MAMP)

MySQL on `127.0.0.1:8889`, user `root`, password `root`, database `medjat`. Use
the MAMP PHP binary, never system php:

```bash
/Applications/MAMP/bin/php/php8.4.15/bin/php -l backend_medjet/core/WebSessionService.php
```

Apply the feature's migrations locally:

```bash
backend_medjet/migrations/migrate.sh --status
backend_medjet/migrations/migrate.sh
```

**HTTPS is not optional for the front end.** Browser geolocation and camera are
secure-context APIs; over plain HTTP they fail silently or return "permission
denied" with no useful error. Use `npm run dev:https` and accept the local
certificate once.

---

## 3. Front end

```bash
cd frontend/web/central
npm run dev:https      # NOT `npm run dev` — see above
```

The employee surface lives at `/(employee)/…`, separate from the admin `(app)`
tree. It must import nothing from the admin routes — that isolation is the
mitigation recorded in the plan's Complexity Tracking, not a style preference.

---

## 4. Seeding a test employee

The channel is off by default (FR-021), so nothing works until you enable it:

```sql
-- 1) turn the channel on for the test tenant
UPDATE tenants SET web_attendance_enabled = 1 WHERE id = 1;

-- 2) give the employee a fresh activation code (or use reset_web_pin.php)
--    the code is single-use and expires in 24h

-- 3) make sure the branch has coordinates, or every punch fails the geofence
SELECT id, name, latitude, longitude, gps_radius_meters FROM branches WHERE tenant_id = 1;
```

Run these **locally only**. Never hand-run SQL on the server — that is rule 2 in
`CLAUDE.md`, and ad-hoc SQL is why production once carried tables local had never
heard of.

---

## 5. Exercising the endpoints

```bash
BASE=http://localhost:8888   # MAMP — DocumentRoot is backend_medjet itself, so there is NO /backend_medjet prefix

# Activate — consumes the code, sets the PIN, returns a session
curl -sX POST "$BASE/app/auth/employee_web_activate.php" \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+201000000000","activation_code":"AB12CD","pin":"482915","device_id":"test-browser-uuid"}'

# Sign in on later days
curl -sX POST "$BASE/app/auth/employee_web_login.php" \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+201000000000","pin":"482915","device_id":"test-browser-uuid"}'

TOKEN='<token from above>'

# What should the page show?
curl -sX POST "$BASE/app/attendance/web_status.php" -H "X-Employee-Token: $TOKEN"

# Check in
curl -sX POST "$BASE/app/attendance/check_in.php" \
  -H "X-Employee-Token: $TOKEN" -H 'Content-Type: application/json' \
  -d '{"branch_id":1,"latitude":30.0444,"longitude":31.2357,"photo_base64":"data:image/jpeg;base64,..."}'
```

Remember **every write is POST**, including logout. There is no PUT or DELETE
anywhere in this backend.

---

## 6. What to verify by hand

These are the paths that break in ways tests do not catch:

| Check | Expected | Requirement |
|---|---|---|
| Existing company, untouched settings | Web endpoints refuse; **app check-in unaffected** | SC-006 |
| Check out on the web | Session dies; reusing the token returns 401 | FR-004a |
| Check in on app → open the browser | Shows **checked in**, not an empty state | FR-009 |
| Session expires mid-shift | PIN sign-in restores access; open shift still closable | FR-004b |
| Two employees, one browser, one day | Both punches flagged — not just the second | FR-019 |
| Photo required, camera denied | Punch **refused**, nothing recorded | FR-017b |
| Punch from outside the geofence | Refused **and** written to `attendance_security_logs` | FR-012, FR-015 |
| Wrong PIN ×5 | Locked; only an admin reset clears it | FR-002b |
| Branch with only BSSID networks | Settings screen warns; no silent "verified" | FR-014, R-005 |
| Device clock set a day ahead | Recorded time is the tenant's, not the browser's | FR-010 |

The last one is worth doing properly — a browser's clock is user-editable with
**no permission prompt at all**, which makes it a weaker input than anything the
mobile app deals with.

---

## 7. Automated tests

```bash
cd frontend/web/central
npm test              # vitest — PIN validation, state machine, api client
npm run test:e2e      # playwright — activate → check in → check out
npm run lint
```

Playwright can grant and mock geolocation and camera. The **denied**-permission
paths are worth one manual pass on a real device: desktop Chrome's denial
behaviour is not the same as Safari iOS's.

There is no PHP test harness in this repo, so backend verification is the curl
sequence above plus the manual table.

---

## 8. Deploying

```bash
backend_medjet/check-drift.sh          # again — what changed under you?
backend_medjet/deploy.sh --dry-run     # read the file list and pending migrations
backend_medjet/deploy.sh               # code + migrations + php reload + smoke test
backend_medjet/check-drift.sh          # must come back clean
```

The front end is **not** deployed by `deploy.sh`. It is the systemd unit
`medjat-web.service` on Hetzner (`next start` on :3000 behind nginx), so it needs
its own build and restart.

**Ship with the channel off.** It is off by default in the migration, so a deploy
changes nothing for anyone until a company opts in — which is the whole point of
SC-006. Enable it for one willing company first and read
`attendance_security_logs` for a week before offering it more widely.
