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

## 1. The old domain is retired last, but it is retired

The destination is `permedjat.com` alone, and it is reachable, because the
**application ids did not change**. `com.khawarizmie.medjat*` is a store
listing's primary key, not a brand: the display name is editable, the id is
not. Keeping it means the rebrand reaches existing customers as an ordinary
update — same listing, same install, same Firebase project, same push tokens.

That is what makes retiring `medjatapp.com` a normal migration rather than a
cliff. Everyone can be moved onto the new host; nobody is stranded on a build
that cannot be replaced.

The order:

1. **Add** `permedjat.com` beside `medjatapp.com`. Both resolve to the same
   origin, document root and database. Only `server_name` grows. Sections 2-7.
2. Ship an app update that points at `permedjat.com`, and rename the listings.
   Section 11 — it is a normal release.
3. Raise `medjat_*_min_version` in Remote Config so the stragglers are walled
   into updating. This is why those keys were left on their old names: the
   console already holds them and every published build already reads them.
4. Watch the old host go quiet, then retire it. Section 15.

Only step 4 is irreversible, and by the time you reach it the traffic is gone.

The `/backend_medjet` location block retires with the host.

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

The association files are unchanged in substance: same package names, same
SHA-256 fingerprints, because neither the application id nor the signing
certificate moved. The only change is *where* they are served.

Serve `.well-known/assetlinks.json` and `apple-app-site-association` from
**both** hosts for the whole transition — installed apps verify against
`medjatapp.com`, updated ones against `permedjat.com`.

The iOS `Runner.entitlements` `applinks:` entries now name `permedjat.com`.
That is a normal rebuild against the existing bundle id and provisioning
profile; nothing in the developer portal changes.

The custom URL schemes (`medjatcentral://`, `medjat://`) were deliberately left
alone. An installed app registers them and the backend emits them, and those
two halves do not ship together — changing both at once breaks every
invitation link for anyone who has not updated yet.

---

## 10. Firebase — unchanged, and that is the point

Nothing to do. The Firebase project stays `medjat`, because the application ids
stay and a Firebase app is keyed by application id.

So none of the following happens: no new project, no `flutterfire configure`,
no regenerated `google-services.json` or `GoogleService-Info.plist`, no
invalidated FCM tokens, no `auth:export` / `auth:import` of every user, no lost
Crashlytics history, no Remote Config rebuilt from scratch.

A Firebase project id was never renameable anyway. Keeping the application ids
turned that from a migration into a non-event.

Two things still point at the project by name, correctly, and stay:
`medjat.firebaseapp.com` in the desktop shell's `AUTH_HOSTS` and in
`backend/legacy/public/auth-action.html`.

The one Firebase item that is real: if you want the auth emails to come from
`permedjat.com`, add that domain in Authentication → Templates → customise, and
paste the two `firebase*._domainkey` CNAMEs it issues. Section 15 covers mail.

---

## 11. The apps — an ordinary release

No new listings. For each of the four apps:

1. Point it at `permedjat.com` (already done in the repo) and bump the version.
2. Build and upload to the same listing, signed with the same upload keystore.
3. Rename the listing and update its graphics — the title, the short and full
   description, the screenshots and the feature graphic. Those are editable
   fields on an existing app in both stores, plus Huawei AppGallery.
4. Once adoption is where you want it, raise `medjat_*_min_version` in Remote
   Config to wall the remainder into updating.

The store assets under `store_assets/` still carry the old wordmark and have to
be re-exported. `make_feature_graphic.py` renders one of them.

`REVIEW_DEMO_CODE=MEDJAT2026` and the demo phone are printed in the store
review notes. Change them together with the listing text or the reviewer is
handed a code that no longer works.

---

## 12. What was deliberately left alone

Kept because an already-installed client has the value baked in and the two
sides do not ship together:

| | |
|---|---|
| `com.khawarizmie.medjat*` | application and bundle ids — a listing's primary key |
| the Kotlin package dirs, iOS RunnerTests ids, desktop appId | must match the above |
| `assetlinks.json` / AASA package names + SHA-256 | same ids, same signing certificate |
| `medjatcentral://`, `medjat://` | schemes an installed app registers |
| `window.medjat` | the bridge the web app reads from the desktop shell |
| `medjat_*_min_version`, `*_maintenance_enabled` | Remote Config keys published builds read |
| `maintenance_<slug>` FCM topics, and the `medjat_app` / `medjat_central` / `medjat_kiosk` / `medjat_admin` slugs the topic name is built from | published builds subscribe to these |
| Firebase project `medjat`, `medjat.firebaseapp.com` | keyed by application id; unchanged, section 10 |

Kept because it is a credential or an external resource, not a name:

| | |
|---|---|
| `SECURITY_USER=khawarizmie_medjat` | shared secret. Rotating it means the server env, four apps and the web app in one shot |
| `REVIEW_DEMO_CODE=MEDJAT2026` | printed in the store review notes; change it with the listing |
| S3 bucket `medjat-documents` | a new bucket plus copying every object |

Kept until section 15 retires it:

| | |
|---|---|
| `medjatapp.com`, its DNS and TLS | serves the installs that have not updated yet |
| `/backend_medjet` URL prefix | the oldest builds call it |

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

Section 11 is a normal app release: it reverses by shipping another one.

Section 15 does not reverse, which is why it is gated on a measurement rather
than a date.

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

- The updated apps are live in all three stores — same listings, section 11.
- `medjat_*_min_version` has been raised in Remote Config, so anyone still on a
  build that calls the old host is walled into updating. This is the lever that
  actually empties the old domain, and it works because the ids, the project and
  the keys all stayed put.
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
