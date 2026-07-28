# Medjat Development Guidelines

Last updated: 2026-07-23

**Medjat** is a multi-tenant HR SaaS (attendance, shifts, leaves, payroll, documents) for the
Egypt / North-Africa market. UIs are **Arabic-first (RTL)** with English support in the management
apps. One PHP backend serves three Flutter apps plus one Next.js web port.

```
Medjat/
├── backend_medjet/          ← PHP 8.x REST API on MySQL 8 — the core (Hostinger)
├── front_end/
│   ├── medjat_app/          ← Employee app (Android/iOS) — attendance, payslips, requests
│   ├── medjat_central/      ← Company HR/management app (Android/iOS)
│   ├── medjat_central_web/  ← Next.js 16 web port of medjat_central (Vercel)
│   └── medjat_admin/        ← Internal super-admin panel (Android)
└── web_pages/               ← Static pages (privacy, delete-account, support, join deep-links)
```

Each subproject has its own `README.md` (and `medjat_app` its own `CLAUDE.md`) with deeper detail.

## Tech Stack

- **Backend:** PHP 8.x, MySQL 8. One endpoint per file under `app/<module>/`; shared logic in `core/`.
  Deps via Composer: `kreait/firebase-php` (FCM + Remote Config), `mpdf/mpdf`, `phpoffice/phpword`.
- **Flutter apps:** Dart 3.11 / Flutter, **GetX** state management (GetxController, GetBuilder, Obx),
  MVVM layering (`core/` `data/` `logic/` `view/`), `http` via a `CRUD` class, Firebase (Auth,
  Messaging, Remote Config, Crashlytics), `flutter_dotenv` (`.env` required), Cairo font, RTL.
- **medjat_central_web:** TypeScript 5, React 19, Next.js 16 (App Router), TanStack Query (server
  state), Zustand, React Hook Form + Zod, shadcn/Base UI, Tailwind, Recharts, axios.

## Backend layout (`backend_medjet/`)

- `app/<module>/` — endpoints. Modules include: auth, employees, attendance, shifts, schedule,
  breaks, leaves, payroll, deductions, allowances, bonuses, loans, settlements, bulk_adjustments,
  documents, assets, branches, categories, managers, roles, biometric, reports, dashboard,
  notifications, settings, tenant, audit, support, admin, admin_support, admin_app_control, cron.
- `core/` — `Auth`/`AdminAuth`, `BaseApi`/`AdminBaseApi`, `TenantMiddleware` + `PermissionMiddleware`
  (isolation + permissions), `PayrollCalculator`/`PayrollCache`/`PayslipPdfService`,
  `SettlementCalculator`, `AttendanceMethodResolver`, `GpsService`, `NotificationService` +
  `RemoteConfigService`, `EmailService`, `RateLimiter`, `Validator`, `Response`.
- `config/` — `bootstrap.php`, `database.php`, `firebase.php`, `cors.php`, `env.php`.
- `migrations/` — hand-written, dated `.sql` files. `models/`, `lang/` (i18n), `cron/`, `uploads/`,
  `join.php` + `well_known.php` (join links + deep links).

## Key backend conventions

- **Writes require POST**, not PUT (`Auth::requirePost`) — PUT is unreliable on Hostinger shared
  hosting. Web/app data sources must POST for mutations.
- **Multi-tenant isolation** is enforced by `TenantMiddleware`; **permissions** by
  `PermissionMiddleware`. Frontend nav/tab/menu gates must match each endpoint's required permission,
  or a low-permission user hits a 403 that surfaces as a generic "an error occurred".
- **Roles:** companies have no owner. `general_manager` is the top role and can be granted to anyone;
  the API enforces equal-or-lower when assigning roles/permissions.
- **DB migrations:** `schema.sql` uses MariaDB-only `ADD COLUMN IF NOT EXISTS`. The live DB is
  MySQL 8, so new schema changes need a hand-written dated migration run manually against production.
- **Payroll:** approving a cycle re-snapshots full-cycle figures (frozen for approved/paid, live
  estimate for draft).

## Local development

- **Backend:** run against **MAMP**. MySQL on `127.0.0.1:8889`, `root`/`root`, database `medjat`.
  Use the MAMP PHP binary, not system php:
  `/Applications/MAMP/bin/php/php8.4.15/bin/php`.
- **Flutter apps:** `flutter run --dart-define-from-file=.env`. Point the app at the MAMP backend;
  for Android use `adb reverse` + a cleartext debug manifest. Lint with `flutter analyze lib` (bare
  `flutter analyze` scans FlutterFire example files under `build/` and reports phantom errors).
- **medjat_central_web:** `npm run dev` (or `dev:https`), `npm run build`, `npm run lint`,
  `npm test` (vitest), `npm run test:e2e` (playwright).

## Deployment

- **Backend:** Hostinger shared hosting at `api.medjatapp.com/backend_medjet` (3 cron jobs; HTTP
  crons need both `key=` and `cron_secret=`). No VPS — deploy is manual file upload.
- **medjat_central_web:** Vercel at `app.medjatapp.com`. Root `medjatapp.com` stays on Hostinger for
  landing/deep-links. Add Vercel domain to Firebase authorized domains.
- **Android release:** signed with upload keystore at `android/app/upload-keystore.jks` (gitignored),
  wired via `key.properties` in `build.gradle.kts`; `flutter build appbundle --release` for store.
- **Firebase:** project `medjat`. Maintenance/force-update is driven by Remote Config; the admin
  toggle also pushes an FCM topic for instant effect.

## Specs

Feature specs live in `specs/` (spec-kit): `001-rebuild-employee-app`, `002-admin-support-control`,
`003-medjat-central-web`.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
