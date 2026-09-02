# Working in backend/api

Read `README.md` first — it describes the layout, the four principals, the rules
that bite, and how to deploy. This file is the short version for an agent.

## Before you push

Three gates, all of which must be green. CI runs the same three plus a check
that `docs/openapi.json` is current.

```bash
php vendor/bin/pint                    # formatting
php vendor/bin/phpstan analyse         # static analysis, level max
php artisan test                       # against real MySQL, not SQLite
php artisan medjat:openapi             # after adding or changing a route
```

Use the MAMP binary, not the system one:
`/Applications/MAMP/bin/php/php8.4.15/bin/php`. MySQL is on `127.0.0.1:8889`,
`root`/`root`.

## The traps, in the order they have actually bitten

- **Time is per tenant.** PHP runs UTC and MySQL runs the server's zone. Resolve
  "now" and "today" through `Shared\Time\TenantClock`, never a bare `date()` or
  `now()`, and compute expiries in SQL (`DATE_ADD(NOW(), INTERVAL ? SECOND)`) so
  they are not born expired. Zone *names*, never fixed offsets.
- **Read the enum before writing to it.** `SELECT COLUMN_TYPE FROM
  information_schema.COLUMNS`. MySQL truncates an unknown ENUM value silently,
  and six bugs here came from inferring values from surrounding code. The same
  goes for column names: check the schema rather than guessing from a sibling.
- **Writes are POST, not PUT.** The apps in the stores still speak POST.
- **Never trust a client's verdict.** The phone extracts a face embedding; the
  server scores it.
- **Migrations assume an empty database.** No `hasTable` guards, no MariaDB
  `IF NOT EXISTS` — each runs once, in order. Adopting an existing database is
  `php artisan medjat:baseline`, not `migrate`.
- **Slow side effects go through `Shared\Async\AfterResponse`**, not inline and
  not the queue. See README, "Rules that bite".

## Where things go

A subject with an HTTP surface is a Module; a subject without one, reached only
by other subjects, is Shared. Modules may depend on Shared and on each other;
nothing in Shared reaches back into a Module. A subject owns all its entry
points, including its console commands.

Everything this application configures lives in `config/medjat.php`, because
`env()` returns null outside `config/` once the configuration is cached — which
every deploy does.
