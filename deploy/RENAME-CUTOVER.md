# Renaming the live system from `medjat` to `permedjat`

The repository has already been renamed. Nothing on the server has. This is the
one-off, ordered runbook for the other side, plus the short list of things that
are deliberately staying as they are.

Read section 1 before running anything: the failure mode here is not a broken
deploy, it is a silently dead installed base.

---

## 0. What has to exist first

| | |
|---|---|
| `permedjat.com` | bought, in Cloudflare, DNS proxied, Full-strict, origin certificate covering `permedjat.com` and `*.permedjat.com` |
| A fresh DB backup | `/usr/local/bin/medjat-backup.sh` once, by hand, before anything |
| A maintenance window | sections 3-6 stop the site for a few minutes |

Host map, old to new:

| old | new |
|---|---|
| `medjatapp.com`, `www.` | `permedjat.com`, `www.` |
| `api.medjatapp.com` | `api.permedjat.com` |
| `app.medjatapp.com` | `app.permedjat.com` |
| `grafana.medjatapp.com` | `grafana.permedjat.com` |
| `db.medjatapp.com` | `db.permedjat.com` |

---

## 1. The old domain is retired last, not first

The destination is `permedjat.com` alone. The order that gets there without an
outage switches the old domain off at the **end**.

Every build already in Google Play, the App Store and AppGallery calls
`https://api.medjatapp.com/backend`, and the older ones call `/backend_medjet`.
Those strings are frozen inside binaries on people's phones. Deleting the DNS
record does not migrate those users, it takes them offline with no way back:
the replacement apps carry **new package ids**, so they are different listings
that a phone will never receive as an update.

So:

1. **Add** `permedjat.com` beside `medjatapp.com`. Both resolve to the same
   origin, document root and database. Nothing is duplicated; only `server_name`
   grows. That is sections 2-7.
2. Ship the new apps, on the new ids and the new domain (sections 9-11).
3. **Measure** rather than guess. Section 15 turns "is anyone still calling the
   old host?" into a number.
4. Retire `medjatapp.com` once that number is zero, per section 15.

Jumping straight to step 4 is the one action in this document that cannot be
undone by putting something back.

The `/backend_medjet` location block follows the same rule: it lives until the
old host is retired, then goes with it.

---

## 2. Nginx

```bash
ssh permedjat   # see section 8 first — the SSH alias is renamed too

cd /etc/nginx
mv snippets/medjat-common.conf   snippets/permedjat-common.conf
mv sites-available/medjat-web.conf     sites-available/permedjat-web.conf
mv sites-available/medjat-devices.conf sites-available/permedjat-devices.conf
rm -f sites-enabled/medjat-web.conf sites-enabled/medjat-devices.conf
ln -s ../sites-available/permedjat-web.conf     sites-enabled/permedjat-web.conf
ln -s ../sites-available/permedjat-devices.conf sites-enabled/permedjat-devices.conf
```

Then copy the three files from `deploy/nginx/` in this repo over them — they
already carry the new paths, the new zone names (`permedjat_devices`,
`permedjat_rate_limit`) and the new `server_name` lists.

Each `server_name` must name **both** domains:

```nginx
server_name api.permedjat.com api.medjatapp.com;
```

Do not reload yet — the paths those files point at do not exist until section 3.

---

## 3. Filesystem paths

```bash
systemctl stop medjat-web.service
mv /var/www/medjat      /var/www/permedjat
mv /var/www/medjat-web  /var/www/permedjat-web
```

The public URL does **not** move. `api.permedjat.com/backend` is a `location
/backend` under `root /var/www/permedjat`, so renaming the parent directory
changes nothing a client can see. That is why section 1 works.

---

## 4. Database

MySQL 8 has no `RENAME DATABASE`. The tables move individually, which is a
metadata-only operation — no dump, no reload, no downtime beyond the seconds it
takes. The `schema_migrations` ledger travels with them, so `check-drift.sh`
stays truthful across the move.

```bash
mysql -uroot -p <<'SQL'
CREATE DATABASE permedjat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL

# generate and run one RENAME TABLE for every table
mysql -uroot -p -N -B -e "
  SELECT CONCAT('RENAME TABLE ', GROUP_CONCAT('\`medjat\`.\`', TABLE_NAME, '\` TO \`permedjat\`.\`', TABLE_NAME, '\`' SEPARATOR ', '), ';')
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA='medjat' AND TABLE_TYPE='BASE TABLE';" | mysql -uroot -p

mysql -uroot -p <<'SQL'
RENAME USER 'medjat'@'localhost' TO 'permedjat'@'localhost';
GRANT ALL PRIVILEGES ON permedjat.* TO 'permedjat'@'localhost';
DROP DATABASE medjat;
FLUSH PRIVILEGES;
SQL
```

Check for views, routines and triggers first — locally there were none, and a
`RENAME TABLE` would leave any of them pointing at the old schema:

```sql
SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*) FROM information_schema.TABLES
 WHERE TABLE_SCHEMA='medjat' GROUP BY 1,2;
SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='medjat';
SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='medjat';
```

Then edit `/var/www/permedjat/backend/config/env.php` by hand — it is gitignored
and lives only on the server — so `DB_DSN` says `dbname=permedjat` and `DB_USER`
says `permedjat`. `backend/legacy/deploy.sh` now passes `DB_USER=permedjat`, so
it will fail loudly until this is done, which is the behaviour we want.

---

## 5. systemd

```bash
cd /etc/systemd/system
mv medjat-web.service    permedjat-web.service
mv medjat-alerts.service permedjat-alerts.service
mv /var/lib/medjat-alerts /var/lib/permedjat-alerts
mv /etc/default/medjat-alerts.env /etc/default/permedjat-alerts.env   # if present

usermod  -l permedjat-alerts medjat-alerts
groupmod -n permedjat-alerts medjat-alerts
chown -R permedjat-alerts:permedjat-alerts /var/lib/permedjat-alerts

systemctl daemon-reload
systemctl disable medjat-web.service medjat-alerts.service 2>/dev/null || true
systemctl enable --now permedjat-web.service permedjat-alerts.service
```

`WorkingDirectory=` inside `permedjat-web.service` must read
`/var/www/permedjat-web/central`; the copy in `deploy/monitoring/` already does.

---

## 6. Cron

```bash
cd /usr/local/bin
for f in medjat-cron-absences medjat-cron-alerts medjat-cron-kiosk-purge \
         medjat-backup medjat-alert-sender medjat-node-metrics \
         medjat-alerting-selftest; do
  [ -e "$f.sh" ] && mv "$f.sh" "per$f.sh"
  [ -e "$f.py" ] && mv "$f.py" "per$f.py"
done

mv /etc/cron.d/medjat            /etc/cron.d/permedjat
mv /etc/cron.d/medjat-monitoring /etc/cron.d/permedjat-monitoring
mv /var/log/medjat-cron.log      /var/log/permedjat-cron.log
```

Then install `deploy/monitoring/cron/permedjat.crontab` over `/etc/cron.d/permedjat`
— it already carries the new script names, the new log path and
`/var/www/permedjat/...`.

The two HTTP cron scripts must keep passing **both** `key=` and `cron_secret=`.
That has bitten this system before; the renamed copies preserve it.

Also rotate the logrotate stanza if one names the old log file.

---

## 7. Monitoring

- `prometheus.yml` — the textfile collector directory and the job labels.
- `permedjat-alerts.rules.yml` — the alert names (`permedjat-server-alive`,
  `permedjat-leave-rollover`, `permedjat-absences`, `permedjat-daily-alerts`,
  `permedjat-backup`, …) and the metric names (`permedjat_nginx_*`,
  `permedjat_backup_age_seconds`). Renaming a metric **breaks its history** —
  Prometheus keeps the old series under the old name. Either accept the gap or
  keep the old metric name and rename only the alert.
- The textfile `.prom` written by `permedjat-node-metrics.sh`.
- Grafana dashboards query the old metric names; update the panels.
- Healthchecks.io ping URLs are opaque UUIDs and do not change.

---

## 8. The SSH alias — already done

`backend/legacy/deploy.sh` and `frontend/web/manager/deploy-web.sh` both default
to a host called `permedjat`, overridable with `PERMEDJAT_SSH_HOST`. The block in
`~/.ssh/config` on the Mac has been renamed to match, and the key file with it:

```
Host permedjat                              # was: Host medjat
    IdentityFile ~/.ssh/permedjat_hetzner   # was: medjat_hetzner
```

Nothing changed on the server side — the key material and the authorized_keys
entry are untouched, only the local filename. `ssh permedjat` is verified
working. `ssh medjat` no longer resolves.

---

## 9. Deep links

`.well-known/assetlinks.json` and `apple-app-site-association` now carry
`com.khawarizmie.medjat*`. They must be served from **both** domains, because
the installed apps verify against `medjatapp.com` and the new ones against
`permedjat.com`.

The SHA-256 certificate fingerprints in `assetlinks.json` are still the old
ones. A new Play listing gets a **new** Play App Signing certificate, so those
fingerprints have to be replaced with the ones Play shows for the new app —
after the listing exists, not before. Until then, Android App Links will not
verify for the new build.

The iOS `Runner.entitlements` `applinks:` entries were renamed too, which means
a new provisioning profile for the new bundle id.

---

## 10. Firebase — this is a new project, not a rename

**A Firebase project id cannot be changed.** Only the display name can. The
repo therefore still points at project `medjat` in exactly six places, on
purpose:

```
frontend/mobile/{employee,kiosk,manager,superadmin}/android/app/google-services.json
frontend/mobile/{employee,manager}/ios/Runner/GoogleService-Info.plist
frontend/mobile/{employee,manager}/lib/core/constant/firebase_options.dart
frontend/mobile/{employee,manager}/firebase.json
frontend/desktop/manager/src/main.js          (AUTH_HOSTS)
backend/legacy/public/auth-action.html        (authDomain, projectId)
```

Editing the id in those files next to API keys and app ids that belong to the
old project produces a file that simply fails to connect. They are regenerated,
not renamed:

1. Create a Firebase project `permedjat`.
2. Register the four Android apps and two iOS apps under their **new**
   identifiers (section 11).
3. `flutterfire configure` in each app directory — it rewrites
   `google-services.json`, `GoogleService-Info.plist` and `firebase_options.dart`.
4. Update `AUTH_HOSTS` and `auth-action.html` to `permedjat.firebaseapp.com`,
   and the web app's `NEXT_PUBLIC_FIREBASE_*` values in `.env.local` on the server.
5. Add the new service-account JSON at `FIREBASE_CREDENTIALS_PATH`.

What does not survive the move:

- **Every FCM token is invalidated.** Push stops for everyone until each device
  registers against the new project. Data-only maintenance and force-update
  messages included.
- **Auth users do not move by themselves.** Export with
  `firebase auth:export` and import with `firebase auth:import --hash-algo=SCRYPT`
  plus the old project's hash parameters, or every account has to sign up again.
- **Crashlytics and Analytics history stays behind.** It cannot be transferred.
- **Remote Config is empty.** Recreate every key. The keys themselves were
  renamed in this repo (`medjat_app_min_version`,
  `maintenance_medjat_kiosk`, …), and published builds read the **old**
  names — so the old project's Remote Config must keep working for them while
  the new one serves the new builds.
- The custom email-action domain and the branded verification/reset templates
  are configured per project and must be set up again.

---

## 11. Store listings — these are new apps

`applicationId` and `PRODUCT_BUNDLE_IDENTIFIER` are the primary key of a store
listing. Changing them does not rename an app; it creates a different one.

| | old | new |
|---|---|---|
| Employee (Android) | `com.khawarizmie.medjat` | `com.khawarizmie.medjat` |
| Manager (Android) | `com.khawarizmie.medjat_central` | `com.khawarizmie.medjat_central` |
| Kiosk (Android) | `com.khawarizmie.medjat.kiosk` | `com.khawarizmie.medjat.kiosk` |
| Super-admin (Android) | `com.khawarizmie.medjat_admin` | `com.khawarizmie.medjat_admin` |
| Employee (iOS) | `com.khawarizmie.medjat` | `com.khawarizmie.medjat` |
| Manager (iOS) | `com.khawarizmie.medjat-central` | `com.khawarizmie.medjat-central` |

Consequences, so they are not a surprise:

- Existing installs **never** update to the new app. They keep running the old
  build against the old domain, which is why section 1 exists.
- Ratings, reviews and install counts start at zero.
- Play App Signing issues a new upload/signing certificate → new SHA-256 for
  `assetlinks.json` (section 9).
- App Store Connect needs new app records, new bundle ids in the developer
  portal, new provisioning profiles, and a fresh review.
- Huawei AppGallery (`com.khawarizmie.medjat`) is a third listing to recreate.
- The store URLs in `config/permedjat.php` (`STORE_URL_*`) point at listings
  that do not exist yet. Set them only once the new listings are live, or the
  `/join` page hands people a dead link.
- The store screenshots and feature graphics under `store_assets/` are rendered
  images with the old wordmark in them. They have to be re-exported.

Plan a migration message inside the old apps — the admin panel's maintenance /
force-update screen is the existing channel for exactly this.

---

## 12. What was deliberately left alone

| | why |
|---|---|
| `/backend_medjet` URL prefix | published builds call it; it retires together with the old host, section 15 |
| `medjatapp.com` and its DNS/TLS | kept alive until section 15 says it is safe to switch off |
| `SECURITY_USER=khawarizmie_medjat` | a shared credential, not a name. Rotating it means changing it in the server env, all four apps and the web app in one shot |
| `REVIEW_DEMO_CODE=MEDJAT2026` | printed in the store review notes; change it with the listing |
| S3 bucket `medjat-documents` | renaming a bucket means creating a new one and copying every object |
| `~/.ssh/medjat_hetzner` | a local filename |
| Firebase project `medjat` | cannot be renamed — section 10 |
| Remote Config keys in published builds | old builds read the old keys; both sets must exist during the transition |
| Client storage keys | `permedjat-auth`, `permedjat-tenant`, `permedjat_emp_session`, … were renamed in the repo, which signs every web user out once on the deploy after the cutover. Expected, worth announcing |

---

## 13. Verify

```bash
backend/legacy/check-drift.sh          # code, schema and ledger must agree
backend/legacy/deploy.sh --dry-run
curl -sI https://api.permedjat.com/backend/            # new domain
curl -sI https://api.medjatapp.com/backend/               # old domain still 200
curl -s  https://api.permedjat.com/.well-known/assetlinks.json
systemctl status permedjat-web.service permedjat-alerts.service
sudo -u www-data /usr/local/bin/permedjat-cron-absences.sh   # exits 0
```

## 14. Rollback

Sections 2–6 reverse cleanly: move the paths and units back, `RENAME TABLE` the
other way, reload. Nothing in them destroys data.

Sections 10 and 11 do not reverse. Do not start them until the rest has been
running for a while.

---

## 15. Retiring `medjatapp.com`

This is the last step of the migration and the only irreversible one. It is
gated on a measurement, not on a date.

### The precondition

Nobody is calling the old host any more. Two ways to know, use both:

**Cloudflare.** In the `medjatapp.com` zone, Analytics → Traffic, grouped by
hostname, over the last 30 days. `api.medjatapp.com` is the one that matters —
it is the app traffic. The promo host and `app.` can be redirected instead of
retired, so they do not gate anything.

**The origin.** Cloudflare only sees what reaches it; the access log is the
ground truth, and it also tells you *who* is still calling:

```bash
ssh permedjat

# requests to the old host in the last day, by path
awk '$0 ~ /medjatapp\.com/ {print $7}' /var/log/nginx/access.log \
  | sed 's/?.*//' | sort | uniq -c | sort -rn | head -20

# and by app version, if the apps send one
grep 'medjatapp\.com' /var/log/nginx/access.log \
  | grep -oE 'Permedjat/[0-9.]+|Medjat/[0-9.]+' | sort | uniq -c
```

If you want this as a running number rather than a spot check, add a
`server_name`-labelled counter to the nginx metrics that
`permedjat-node-metrics.sh` already exports, and put the old host on a Grafana
panel. Then the decision is a graph that reaches zero and stays there.

### Before it can reach zero

- The new apps are live in all three stores under the new ids.
- The old apps have told their users to move. The admin panel's maintenance /
  force-update screen is the channel: point the old builds' force-update message
  at the new listing, so opening the old app becomes a wall with a store link.
  Remote Config for the **old** Firebase project drives those builds, so it has
  to still exist at that point (section 10).
- The web app and the desktop shell are on `app.permedjat.com`, and anyone with
  the old URL bookmarked is being redirected (see below).

### The retirement itself

Do it in this order, and leave a week between the last two steps.

```bash
# 1. Stop serving the old host from the app; redirect it instead.
#    Everything that is a browser gets moved; everything that is an app gets a
#    301 it will not follow, which is the point — it shows up in the logs.
server {
    listen 443 ssl;
    server_name medjatapp.com www.medjatapp.com app.medjatapp.com api.medjatapp.com;
    return 301 https://permedjat.com$request_uri;   # api. -> api.permedjat.com
}

# 2. Watch the log for a week. Anything still arriving is a client that has to
#    be chased, not a client that will fix itself.

# 3. Remove the server block, then the DNS records in Cloudflare.
#    Keep the zone itself and the MX/SPF/DKIM/DMARC records if any mail
#    address on the old domain is still in use anywhere — a store listing, a
#    support address, an old invoice. Mail is the thing people forget.
```

### Mail moves before, not after

`noreply@medjatapp.com` sends the verification and reset mail. The repo now
points at `noreply@permedjat.com`, which will silently fail authentication
until `permedjat.com` has its own SPF, DKIM and DMARC records and the sender is
verified with the SMTP provider. Set that up and send a test through the real
path **before** section 2, or the first thing the new domain does is drop
everybody's password-reset mail into spam.

Firebase's custom email-action domain is configured per project and needs the
same treatment on the new project.

### What is not reversible

DNS and the server block come back in minutes. What does not come back is a
customer whose only copy of the app pointed at a host that stopped answering
while the replacement was not yet installable. That is what the precondition is
protecting, and it is the reason this section is numbered 15 and not 2.
