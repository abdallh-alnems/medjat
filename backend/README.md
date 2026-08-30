# Medjat backend

The PHP backend for Medjat: a multi-tenant HR SaaS (attendance, shifts, leaves,
payroll, documents) for the Egypt / North-Africa market. One API serves four
Flutter apps, a Next.js web port, a desktop shell over that web port, and the
ZKTeco attendance terminals.

Laravel 13 on PHP 8.4 (local, MAMP) / 8.5 (live), MySQL 8.4.

## Two URLs for everything

Every endpoint answers on two paths:

```
POST /v1/payroll/approve          the current shape
POST /app/payroll/approve.php     the shape published app bundles call
```

The `.php` URLs are **permanent**, not a deprecation. `API_HOST` is compiled
into Flutter builds that are already in the stores and on people's phones; a
build from two years ago has to keep working, so those paths cannot be retired
on any schedule we control.

## Layout

Organised by **subject**, not by technical layer. Everything about payroll — the
rules, the endpoints, the multi-step actions — lives in one directory, because
that is the unit work actually arrives in. "Fix the overtime rounding" should
not mean opening three trees.

```
app/
├── Modules/<Subject>/       one per business subject (33 of them)
│   ├── Domain/              the rules. Framework-free where it can be, so a
│   │                        rule can be read without reading a request.
│   ├── Http/
│   │   ├── Controllers/     one class per screen or action
│   │   └── Requests/        validation worth naming
│   └── Services/            multi-step actions and anything talking outward
│
├── Shared/                  used by several modules, owned by none
│   ├── Access/              the permission catalogue
│   ├── Approvals/           the approval chain
│   ├── Face/                embeddings and matching — Attendance, Biometric
│   │                        and Kiosk all reach for it
│   ├── Security/            the log of blocked and flagged attempts
│   ├── Time/                TenantClock: "now" in the company's own zone
│   ├── RemoteConfig/        the version and maintenance gate
│   ├── Crew/  Contact/
│   └── Http/                the API request base class
│
├── Http/Middleware/         the four principals and the two gates
├── Models/                  Eloquent, for tables with real behaviour
├── Console/Commands/        the scheduled jobs
├── Mail/                    transactional mail
├── Providers/  Exceptions/
└── Support/                 Value: narrowing `mixed` from query rows
```

**The rule that decides where something goes:** a subject with an HTTP surface
is a Module; a subject without one, reached only by other subjects, is Shared.
Applied mechanically, so nobody has to argue about it. Modules may depend on
Shared and on each other; nothing in Shared reaches back into a Module.

```
routes/api.php            every route, grouped by module, gate visible on each
config/medjat.php         everything this application configures
resources/views/mail/     transactional email
resources/views/landing/  deep-link fallback pages
resources/well-known/     App Links / Universal Links association files
lang/{ar,en}/             Arabic first; the apps are Arabic-first and RTL
tests/Feature/            one directory per module
```

## Who can call what

Four principals, each with its own guard:

| Middleware | Who | Proof |
|---|---|---|
| `auth.admin` | a company's administrator | Firebase ID token |
| `auth.employee` | an employee | `X-Employee-Token` |
| `auth.kiosk` | a shared branch tablet | `X-Kiosk-Token` — resolves to a *branch*, never a person |
| `auth.super` | an operator of the product | bearer session, not scoped to any company |

Two gates sit in front of them:

- **`app.secret`** — HTTP Basic, carried by every published app build. Not
  authentication; the difference between our clients reaching an endpoint and
  everything reaching it. Off when unset, which is how local development runs.
- **`can.do:permission`** — the permission the caller must hold. Written on the
  route so it is visible in one place. `a|b` means either is enough.

Two things sit outside both, deliberately:

- **The terminals** (`/iclock/*`) — the firmware has no field for a secret, so a
  serial number is the whole authorisation model, and an unclaimed serial can do
  nothing but say hello. Never rate-limited either: a device polls every ten
  seconds by design.
- **The deep-link pages and association files** — the operating system fetches
  those before anybody has signed in.

## Rules that bite

**Time is per tenant.** PHP runs UTC and MySQL runs the server's zone, so they
disagree by hours. Resolve "now" and "today" through `Domain\Time\TenantClock`,
and compute every expiry **in SQL** (`DATE_ADD(NOW(), INTERVAL ? SECOND)`) so it
is not born expired. Use the zone *name*, never a fixed offset — Egypt has DST,
the Gulf does not.

**Writes are POST, not PUT.** The rule outlived the shared host that caused it,
but the apps in the stores still speak POST.

**Never trust a client's verdict.** The phone extracts a face embedding; the
*server* scores it. Companies start in `face_enforce_mode = log_only`, where
every attempt is scored and nobody is refused, until the threshold is tuned on
their own data.

**Read the enum before writing to it.** `SELECT COLUMN_TYPE FROM
information_schema.COLUMNS`. MySQL truncates an unknown ENUM value silently, and
six bugs in this codebase came from inferring values from surrounding code —
including break notifications that had never once sent.

## Running it

```bash
composer install
cp .env.example .env && php artisan key:generate   # see .env.example for the rest
php artisan migrate
php artisan serve
```

MySQL on `127.0.0.1:8889`, `root`/`root` under MAMP. Use the MAMP PHP binary,
not the system one: `/Applications/MAMP/bin/php/php8.4.15/bin/php`.

## Before you push

Three gates, all of which must be green:

```bash
php vendor/bin/pint            # formatting
php vendor/bin/phpstan analyse # static analysis, level max
php artisan test               # against a real MySQL dump, not SQLite
```

The suite runs under `DatabaseTransactions` against a copy of production's
schema, because SQLite would not reproduce the ENUM truncation, the `NULL`
handling in unique keys, or the timezone disagreement that caused most of the
bugs worth having tests for.

## Scheduled work

Three jobs, each reachable two ways — as an artisan command, and on the cron URL
the installed crontab currently calls with a shared secret:

```
medjat:run-alerts              07:00  the morning digest
medjat:catch-up-absences       23:50  the absence safety net
medjat:purge-kiosk-captures    03:30  retention: deletes stored face captures
```

`CRON_SECRET` unset refuses every cron request rather than accepting one. These
endpoints terminate employees and delete photographs.
