# Medjat Development Guidelines

Last updated: 2026-08-03

**Medjat** is a multi-tenant HR SaaS (attendance, shifts, leaves, payroll, documents) for the
Egypt / North-Africa market. UIs are **Arabic-first (RTL)**; medjat_app, medjat_central and the web
app also ship English (medjat_admin is Arabic-only). One PHP backend serves four Flutter apps, one
Next.js web port, and a desktop shell that wraps that web port.

```
Medjat/
├── backend_medjet/          ← PHP 8.x REST API on MySQL 8 — the core (Hetzner VPS)
├── front_end/
│   ├── medjat_app/          ← Employee app (Android/iOS) — attendance, payslips, requests
│   ├── medjat_central/      ← Company HR/management app (Android/iOS)
│   ├── medjat_central_web/  ← Next.js 16 web port of medjat_central (self-hosted)
│   ├── medjat_central_desktop/ ← Electron shell over the web app → .dmg / .exe
│   ├── medjat_kiosk/        ← Branch kiosk (Android tablet) — shared-device attendance
│   ├── medjat_admin/        ← Internal super-admin panel (Android)
│   ├── packages/            ← medjat_shared — code shared between the Flutter apps
│   └── web_pages/           ← Static promo/landing + privacy, delete-account, support
└── specs/                   ← spec-kit feature specs
```

Each subproject has its own `README.md` (and `medjat_app` its own `CLAUDE.md`) with deeper detail.

## Tech Stack

- **Backend:** PHP 8.x, MySQL 8. One endpoint per file under `app/<module>/`; shared logic in `core/`.
  Deps via Composer: `kreait/firebase-php` (FCM + Remote Config), `mpdf/mpdf`, `phpoffice/phpword`.
  Live server runs **PHP 8.5 / MySQL 8.4** — code is developed on 8.4 (MAMP), so watch for 8.5
  deprecations in the server logs.
- **Flutter apps:** Dart 3.11 / Flutter, **GetX** state management (GetxController, GetBuilder, Obx),
  MVVM layering (`core/` `data/` `logic/` `view/`), `http` via a `CRUD` class, Firebase (Auth,
  Messaging, Remote Config, Crashlytics), `flutter_dotenv` (`.env` required), RTL.
  Fonts: **IBM Plex Sans Arabic** (Arabic) + **Geist** (Latin/numerals) — not Cairo.
- **medjat_central_web:** TypeScript 5, React 19, Next.js 16 (App Router), TanStack Query (server
  state), Zustand, React Hook Form + Zod, shadcn/Base UI, Tailwind, Recharts, axios.

## Backend layout (`backend_medjet/`)

- `app/<module>/` — endpoints. Modules: auth, employees, attendance, shifts, schedule, breaks,
  leaves, payroll, deductions, allowances, bonuses, loans, settlements, bulk_adjustments, documents,
  assets, branches, categories, managers, roles, biometric, devices, performance, warnings, reports,
  dashboard, notifications, settings, tenant, audit, support, admin, admin_support,
  admin_app_control, cron.
- `core/` — `Auth`/`AdminAuth`, `BaseApi`/`AdminBaseApi`, `TenantMiddleware` + `PermissionMiddleware`
  (isolation + permissions), `PayrollCalculator`/`PayrollCache`/`PayslipPdfService`,
  `SettlementCalculator`, `AttendanceMethodResolver`, `GpsService`, `NetworkVerifier` (WiFi),
  `FaceMatchService` + `BiometricEnrollment` (face), `ZktecoAdms` + `DevicePunchIngestor`
  (terminals), `TenantClock` (per-tenant time), `ApprovalEngine`/`ApprovalDispatcher`,
  `NotificationService` + `RemoteConfigService` + `SmartAlertService`, `EmailService`/`AuthEmail`,
  `I18n`, `RateLimiter`, `Validator`, `Response`.
- `config/` — `bootstrap.php`, `database.php`, `firebase.php`, `cors.php`, `env.php`.
  `config/env.php` is gitignored; the live one is hand-written on the server.
- `migrations/` — hand-written, dated `.sql` files. `models/`, `lang/` (i18n), `scripts/`,
  `app/cron/`, `uploads/`, `join.php` + `well_known.php` (join links + deep links),
  `device/iclock.php` (attendance terminals — see `device/README.md`).

## Key backend conventions

- **Writes require POST**, not PUT (`Auth::requirePost`) — PUT was unreliable on the old shared
  host and the apps in the store still speak POST. Web/app data sources must POST for mutations.
- **Multi-tenant isolation** is enforced by `TenantMiddleware`; **permissions** by
  `PermissionMiddleware`. Frontend nav/tab/menu gates must match each endpoint's required permission,
  or a low-permission user hits a 403 that surfaces as a generic "an error occurred".
- **Roles:** companies have no owner. `general_manager` is the top role and can be granted to anyone;
  the API enforces equal-or-lower when assigning roles/permissions.
- **Time is per tenant.** Resolve "now"/"today" through `core/TenantClock.php` (reads
  `tenants.timezone`, falls back to `Africa/Cairo`), never bare `date()`/`NOW()` — PHP runs UTC and
  MySQL runs the server zone, so they disagree by hours. Always use the zone *name*, never a fixed
  offset (Egypt has DST, the Gulf does not). Compute TTL/expiry comparisons **in SQL**
  (`DATE_ADD(NOW(), INTERVAL ? SECOND)`) so they are not born expired.
- **DB migrations:** write a dated `migrations/YYYY_MM_DD_thing.sql` and let `deploy.sh` apply it —
  applied files are recorded in `schema_migrations` on both databases, so re-running is a no-op.
  Target **MySQL 8**: it has no `ADD COLUMN IF NOT EXISTS` (that is MariaDB-only), so each migration
  runs once, in order. See the Deployment section for the full workflow.
- **Payroll:** approving a cycle re-snapshots full-cycle figures (frozen for approved/paid, live
  estimate for draft).

## Attendance

- **Methods** (`AttendanceMethodResolver::ALLOWED`): `qr_gps`, `gps_only`, `face_selfie`, `wifi_gps`,
  `device`, `manual`. Resolution order is **employee → category (union) → branch → tenant**.
  Self check-in from the employee app is valid for qr_gps / gps_only / face_selfie / wifi_gps;
  `manual` is admin-recorded and `device` comes from a terminal.
- **Never trust the client's verdict.** The phone extracts the face embedding, the **server** scores
  it (`FaceMatchService`) against a single-use nonce in `face_challenges`. Companies start in
  `face_enforce_mode = 'log_only'` (scored into `face_verification_logs`, nobody rejected), then
  switch to `enforce` once the threshold is tuned on real data.
- **WiFi is a constraint on top of the geofence, never a substitute** — GPS drifts indoors and WiFi
  leaks outdoors. Learning mode auto-discovers branch BSSIDs into `branch_networks`; one router
  usually exposes several BSSIDs (2.4/5 GHz), so approving only some locks people out.
- **Anti-spoofing:** `is_mock_location` is rejected server-side only when the company opts in
  (`tenants.reject_mock_location`, Android-only — iOS never reports it). Every block/flag is written
  to `attendance_security_logs`. Rooted devices are deliberately *not* blocked (common on cheap
  handsets, not evidence of cheating).
- **Terminals (ZKTeco ADMS):** the device dials out to `device/iclock.php` over **plain HTTP on port
  8090, direct to the origin** — old ZK firmware has weak/no TLS and sends no SNI, so it cannot pass
  Cloudflare. Every response must be HTTP 200 plain text or the device re-sends forever.

## Local development

- **Backend:** run against **MAMP**. MySQL on `127.0.0.1:8889`, `root`/`root`, database `medjat`.
  Use the MAMP PHP binary, not system php:
  `/Applications/MAMP/bin/php/php8.4.15/bin/php`.
- **Flutter apps:** `flutter run --dart-define-from-file=.env` (medjat_app) or `flutter run`
  (medjat_central / medjat_admin load `.env` as an asset). Point the app at the MAMP backend; for
  Android use `adb reverse` + a cleartext debug manifest. Lint with `flutter analyze lib` (bare
  `flutter analyze` scans FlutterFire example files under `build/` and reports phantom errors).
- **medjat_central_web:** `npm run dev` (or `dev:https`), `npm run build`, `npm run lint`,
  `npm test` (vitest), `npm run test:e2e` (playwright).

## Deployment

### Backend workflow — these four rules are not optional

There is no CI and no staging. The repo, the local MAMP database and the live server are kept in
step by hand, so the only thing preventing drift is following this every time:

1. **Never edit a file on the server.** Edit it here, then run `backend_medjet/deploy.sh`. A file
   changed over SSH is invisible to git and gets silently reverted by the next deploy.
2. **Never run SQL on the server by hand.** Write a dated `migrations/YYYY_MM_DD_thing.sql`, then
   `deploy.sh` applies it and records it. Ad-hoc SQL is the reason production once had four tables
   local had never heard of.
3. **Never edit a migration that has already been applied** — write a new one. `migrate.sh` stores
   each file's checksum and warns when an applied file changes underneath it.
4. **Run `backend_medjet/check-drift.sh` before starting and after finishing.** It compares code
   (checksums), schema (every table + column) and the migration ledger, and exits non-zero on any
   disagreement.

```
backend_medjet/check-drift.sh          # do the three sides still agree?
backend_medjet/deploy.sh --dry-run     # what would change
backend_medjet/deploy.sh               # code + migrations + php reload + smoke test
backend_medjet/migrations/migrate.sh --status
```

`schema_migrations` (both databases) is the ledger of what has been applied. `schema.sql` is
**generated** from production (`mysqldump --no-data`, ledger excluded) — never hand-edit it; it is a
snapshot of the current schema, so `migrate.sh --bootstrap` loads it into an *empty* database and
immediately baselines every migration rather than replaying them. `migrations/archive/` holds the
old destructive drop migrations and must never be run (one drops `candidates`, still queried by
`models/AuditLogModel.php`). Rebuild local from production with a dump — never by replaying
migrations. SSH alias `medjat` is configured in `~/.ssh/config`.

- **Server:** single **Hetzner VPS** (Ubuntu 26.04, PHP 8.5 / MySQL 8.4 / Nginx) behind
  **Cloudflare** (proxied, Full-strict, origin IP hidden; UFW allows 80/443 from Cloudflare ranges
  only). Deploy is `rsync` from the Mac — no CI.
  - `api.medjatapp.com/backend_medjet` → PHP backend at `/var/www/medjat/backend_medjet`
  - `app.medjatapp.com` → Next.js via systemd `medjat-web.service` (`next start` on :3000)
  - `medjatapp.com` + `www` → static promo site (`front_end/web_pages`), plus `/join` and
    `/.well-known/*` deep links served from the backend copies
  - `grafana.medjatapp.com` (Grafana + Prometheus) and `db.medjatapp.com` (Adminer, basic-auth)
- **Cron:** `/etc/cron.d/medjat` (Africa/Cairo) — leave rollover 00:00+00:30 (CLI), catch-up absences
  23:50, daily alerts 07:00 (both via `/usr/local/bin/medjat-cron-*.sh`, which pass **both** `key=`
  and `cron_secret=`), mysqldump backup 02:00 with 14-day retention.
- **Android release:** signed with upload keystore at `android/app/upload-keystore.jks` (gitignored),
  wired via `key.properties` in `build.gradle.kts`; `flutter build appbundle --release` for store.
- **Firebase:** project `medjat`. Maintenance/force-update is driven by Remote Config; the admin
  toggle also pushes an FCM topic for instant effect.

## Specs

Feature specs live in `specs/` (spec-kit): `001-rebuild-employee-app`, `002-admin-support-control`,
`003-medjat-central-web`.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

## Active Technologies
- PHP 8.4 local (MAMP) / 8.5 live · TypeScript 5, React 19, Next.js 16 (App Router) + Existing `core/` services — `Auth`, `GpsService`, `NetworkVerifier`, `TenantClock`, `RateLimiter`, `Validator`, `Response`, `BiometricEnrollment` (photo-storage pattern). Web: TanStack Query, Zustand, React Hook Form + Zod, Tailwind, shadcn/Base UI, axios. (004-web-attendance-checkin)
- MySQL 8.4 (live) — additive migrations only; images to `backend_medjet/uploads/` (004-web-attendance-checkin)
- PHP 8.4 local (MAMP) / 8.5 live · Dart 3.11 / Flutter (GetX, MVVM) · TypeScript 5, React 19, Next.js 16 for the management web surface + Existing `core/` services — `Auth`, `FaceMatchService`, `BiometricEnrollment`, `GpsService`, `TenantClock`, `PermissionMiddleware`, `TenantMiddleware`, `RateLimiter`, `RemoteConfigService`, `I18n`, `Response`. Kiosk app: `camera`, `google_mlkit_face_detection`, `tflite_flutter` (all already in `medjat_app/pubspec.yaml`), `assets/models/mobilefacenet.tflite` (5.2 MB, BSD-3, already in the repo) (005-branch-kiosk)
- MySQL 8.4 (live) — four additive migrations, no drops or narrowing. Captures to `backend_medjet/uploads/kiosk/`, purged on a schedule (005-branch-kiosk)

## Recent Changes
- 004-web-attendance-checkin: Added PHP 8.4 local (MAMP) / 8.5 live · TypeScript 5, React 19, Next.js 16 (App Router) + Existing `core/` services — `Auth`, `GpsService`, `NetworkVerifier`, `TenantClock`, `RateLimiter`, `Validator`, `Response`, `BiometricEnrollment` (photo-storage pattern). Web: TanStack Query, Zustand, React Hook Form + Zod, Tailwind, shadcn/Base UI, axios.
