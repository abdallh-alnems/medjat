# Medjat backend

The PHP backend for Medjat: a multi-tenant HR SaaS (attendance, shifts, leaves,
payroll, documents) for the Egypt / North-Africa market. One API serves four
Flutter apps, a Next.js web port, a desktop shell over that web port, and the
ZKTeco attendance terminals.

Laravel 13 on PHP 8.4 (local, MAMP) / 8.5 (live), MySQL 8.4.

## One URL for everything

```
POST /v1/payroll/approve
```

Every endpoint lives under `/v1`. There is no second, older shape: the port
carried one for a while so published app builds would keep working, and it was
removed once those builds turned out to be pre-release. What is left is the
surface the clients should have been written against.

Versioning is in the path rather than a header because it is the shape a
client can see in a log, a bug report and a curl command without knowing
anything about this API's conventions.

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
│   ├── Console/             CLI entry points, where the subject has any
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
│   └── Http/                the request and response envelope, and the
│                            middleware: the four principals and the two gates
│
├── Models/                  Eloquent, for tables with real behaviour
├── Mail/                    transactional mail
├── Providers/  Exceptions/
└── Support/                 Value: narrowing `mixed` from query rows
```

A subject owns *all* its entry points. The scheduled jobs are the clearest
case: `medjat:run-alerts` on the command line and `/app/cron/run_alerts.php`
over HTTP are two doors into one piece of work, so the commands live in
`Modules/Cron/Console/` beside the code they run rather than in Laravel's
default `app/Console/Commands`. That costs one explicit registration in
`bootstrap/app.php` and buys a subject you can read in one directory.

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

- **The terminals** (`/iclock/{action}`) — the firmware has no field for a
  secret, so a serial number is the whole authorisation model, and an unclaimed
  serial can do nothing but say hello. Never rate-limited either: a device polls
  every ten seconds by design.
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

**Announcements happen after the answer.** A push or a transactional email is
telling somebody about something that has already happened, so it has no
business on the request's critical path — the old backend flushed the response
first and sent afterwards, and losing that put an SMTP round trip inside every
sign-in. `Shared\Async\AfterResponse::run()` puts it back. Not the queue: a
queued job needs a worker this project has never run, and every notification in
the product would stop the first time it died. The exception is the operator's
own password-reset send, which reports failure honestly because somebody is
watching one named account and "the email never arrived" is the support call.

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
php artisan test               # against real MySQL, not SQLite
```

The suite runs under `DatabaseTransactions` against MySQL, because SQLite would
not reproduce the ENUM truncation, the `NULL` handling in unique keys, or the
timezone disagreement that caused most of the bugs worth having tests for.

It needs nothing in the database beyond the schema. Each test builds the rows it
asserts on through `Tests\Support\CreatesFixtures` and rolls them back, so a
run leaves the database exactly as it found it and no test can see another's
settings:

```php
$tenantId = $this->createTenant(['cycle_start_day' => 26]);
$employee = $this->createEmployee($tenantId);
```

## The schema

`database/migrations/` builds the whole thing — 85 tables, 368 indexes and 179
foreign keys — from an empty database:

```bash
php artisan migrate
```

Foreign keys are all added in one final migration rather than inline, so table
migrations never have to be ordered by dependency: a graph that is tedious to
maintain and easy to break with one new relation.

These migrations were generated from the running production schema and then
checked back against it column by column, index by index and key by key, rather
than being trusted because they ran without error. The three tables the old
backend's ledger still creates — `expense_claims`, `kiosk_pins` and
`shift_swap_requests` — are deliberately absent: each was dropped by a migration
that now lives in the old `migrations/archive/`, and no code in either backend
refers to them.

## Deploying

Same four rules as the old backend, for the same reasons:

1. **Never edit a file on the server.** Edit it here, then run `./deploy.sh`. A
   file changed over SSH is invisible to git and gets reverted by the next
   deploy.
2. **Never run SQL on the server by hand.** Write a migration and let the deploy
   apply it.
3. **Never edit a migration that has already run** — write a new one.
4. **Read `--dry-run` before you run the real thing.**

```
./deploy.sh --dry-run     # what would change, plus migrate:status
./deploy.sh               # code, deps, migrations, caches, reload, smoke test
./deploy.sh --code-only   # skip migrations
```

The smoke test is the part worth keeping honest. It asserts the application
boots, that each of the four guards still refuses an unauthenticated call, and —
because the docroot is `public/` and a vhost pointed one directory too high
fails *silently* while every other URL keeps working — that `.env`, the source
tree and `uploads/` are not readable over HTTP.

`config:cache` runs on every deploy, which is why every tuned value lives in
`config/medjat.php`: `env()` returns null outside `config/` once the cache
exists, and a limit that silently becomes its default is worse than one that is
wrong out loud.

## Cutover

The first time this application meets the production database is the one step
`deploy.sh` will not do for you.

Production has all 85 tables and an empty `migrations` table — the old backend
recorded applied files in `schema_migrations` instead. The migrations here build
every table from empty and none of them guards with `hasTable`, deliberately:
MySQL 8 has no `ADD COLUMN IF NOT EXISTS`, so each runs once, in order. Point
`artisan migrate` at production and it stops on `CREATE TABLE tenants`.

```bash
php artisan medjat:baseline --pretend   # read the plan
php artisan medjat:baseline             # adopt the schema
```

It records the migrations whose tables already exist as applied without running
them, and actually runs the ones whose tables are genuinely absent — which is
how Laravel's own `cache` and `jobs` tables get created, since the old backend
never had them. Deciding from the database rather than from the filenames is the
point: skipping a table that was never created is the failure worth preventing.

It is safe to repeat — anything already recorded is left alone — so an
interrupted run can simply be run again. After it, `artisan migrate` behaves
normally and `deploy.sh` is the whole story.

Three things the server must carry across, none of which lives in this repo:

- **`.env`**, hand-written, holding the database password, `SECURITY_USER` /
  `SECURITY_KEY`, `CRON_SECRET`, `FIREBASE_CREDENTIALS_PATH` and
  `CORS_ALLOWED_ORIGINS`. `.env.example` is the reference for what it must
  contain.
- **`UPLOADS_PATH`**, pointed at the existing `uploads/` directory. Payslips,
  identity documents and face captures are already in there and are referenced
  by path from rows in the database.
- **The nginx `real_ip` block** that maps `CF-Connecting-IP` onto `REMOTE_ADDR`.
  Without it every request appears to come from Cloudflare: one rate-limit
  bucket for the whole platform, and an attendance security log that records the
  wrong address for every entry. See `TRUSTED_PROXIES` in `.env.example` for the
  case where a proxy does *not* rewrite it.

## The API description

`docs/openapi.json` describes all 303 operations. Regenerate it after changing a
route:

```bash
php artisan medjat:openapi           # write it
php artisan medjat:openapi --check   # fail if it is stale (CI runs this)
```

It is generated from the routing table rather than from annotations, and says
only what it actually knows: the path, the verb, which of the four principals
authenticates it, which permission it demands, and the response envelope, which
is the same everywhere. Request bodies are described as "an object" because
handlers read them field by field rather than through a request class — there is
nothing to derive a schema from, and inventing one would be worse than saying so.

A test regenerates it and compares, so a new route fails the build until the
document is rewritten. That is the only way a description of three hundred
endpoints stays true.

## Messages

The API answers in the language of the `Accept-Language` header, Arabic or
English, falling back to `APP_LOCALE` for anything else.

Two kinds of message, and the difference decides where the text lives:

- **A refusal a person reads** — "this account is suspended", "no check-in for
  this date", "not enough annual leave" — goes through `__('messages.…')` and
  exists in both `lang/ar` and `lang/en`. There is one key per message rather
  than a parameterised `:entity not found`, because Arabic agrees adjectives
  with the noun's gender: a company is غير موجودة and an employee is غير موجود.
- **A contract violation** — `employee_id is required`, `scope_type must be
  category or employee` — stays in English. It fires only when a client sends a
  malformed request, so the reader is whoever is debugging that client, and a
  translated diagnostic helps nobody. These carry an `error_code`, so a client
  that wants to show its own wording can.

A test asserts the two files hold the same keys. One present in Arabic and
missing from English reaches an English speaker as the raw key.

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
