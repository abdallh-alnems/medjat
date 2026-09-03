# Alerting — Prometheus → Alertmanager → WhatsApp + Telegram

Installed 2026-08-25. Like the nginx config, none of this is deployed by
`deploy.sh`; the files here are the record of what lives on the server, so a
rebuilt machine can be brought back to the same state.

Before this, the server had Prometheus and Grafana collecting metrics and **no
way to tell anyone anything**: no rule files, no Alertmanager, no external
check. Every outage was discovered by a customer.

## What runs where

| Piece | Where | Purpose |
|---|---|---|
| `prometheus.yml` | `/etc/prometheus/prometheus.yml` | scrape + alerting wiring |
| `permedjat-alerts.rules.yml` | `/etc/prometheus/rules/permedjat-alerts.yml` | the 12 rules |
| `permedjat-alerting-selftest.sh` | `/usr/local/bin/`, cron `*/15` | pings healthchecks only if the pipeline can deliver |
| `alertmanager.yml` | `/etc/prometheus/alertmanager.yml` | grouping, repeat, routing |
| `permedjat-alert-sender.py` | `/usr/local/bin/` | webhook → WhatsApp + Telegram |
| `permedjat-alerts.service` | `/etc/systemd/system/` | runs the sender on :9099 |
| `permedjat-node-metrics.sh` | `/usr/local/bin/`, cron `*/5` | backup age + nginx 5xx |
| credentials | `/etc/permedjat-alerts.env` (0640, **not in git**) | channel keys |

Everything binds to `127.0.0.1`. Nothing new is exposed to the internet, so no
UFW or Cloudflare change was needed.

Two packages were installed: `prometheus-alertmanager` and
`prometheus-blackbox-exporter`. Alertmanager needs
`--cluster.listen-address=` in `/etc/default/prometheus-alertmanager` — this
host has no private IP, and its gossip mesh refuses to start without one.
`node-exporter` gained `--collector.systemd` (service up/down) and
`--collector.textfile.directory` (the two metrics above).

## What gets alerted, and what does not

Twelve rules, split by whether they stop people working:

- **critical** (WhatsApp + Telegram): API down (through Cloudflare *and* at the
  origin, which separates "our server is broken" from "the path to it is
  broken"), web app down, `mysql`/`nginx`/`php-fpm`/`permedjat-web` not running,
  disk under 7%.
- **warning** (Telegram only): disk under 20%, memory under 10%, promo site
  down, backup older than 30h, more than 20 server errors in five minutes, a
  monitoring target unreachable.
- **heartbeat**: a `Watchdog` rule that always fires. It is the answer to the
  only question a silent alerting system cannot answer: is nothing wrong, or is
  nothing working?

  Alertmanager pokes the sender every 15 minutes and the **sender** decides when
  to actually send: once per calendar day, at or after `HEARTBEAT_HOUR` (09:00
  Cairo), remembered in `/var/lib/permedjat-alerts/heartbeat.date`. A bare
  `repeat_interval: 24h` was the obvious way and the wrong one — it counts from
  the last send, so the hour drifts and resets on every restart, and "what time
  does it arrive?" has no answer. "At or after" also means a server that was
  down at 09:00 still sends when it returns rather than skipping the day, which
  would look exactly like a failure.

  `HEARTBEAT_WHATSAPP_DAY` controls whether WhatsApp gets it too: `daily`,
  `off`, or a weekday number (0=Mon). Set to `daily` on 2026-08-25 because
  WhatsApp is currently the **only** channel — six silent days a week would make
  silence ambiguous again, which is the one thing the pulse exists to prevent.
  Move it to a single weekday once Telegram carries the daily one, so WhatsApp
  stays reserved for things that matter.

Deliberately absent: CPU spikes, load average, per-endpoint latency. They fire
often, mean little here, and an alert that gets ignored costs more than it saves.

## Channels

`permedjat-alert-sender.py` receives the Alertmanager webhook, formats one Arabic
message, and fans it out. A channel with no credentials is simply skipped, so
the service runs from the moment it is installed and starts sending the instant
a key is filled in — no restart needed, the env file is read on every send.

**Telegram** (`@permedjat_alerts_bot`, live) — official API, free, no extra phone
number. A bot cannot open a conversation, so the chat id only exists after the
recipient presses Start; recover it with:

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates"
```

**WhatsApp (CallMeBot)** (live) — free and **unofficial**: one person's hobby
service, "personal use only", no SLA, and its first bot number was already full
when we registered. The recipient authorises it once by messaging
`I allow callmebot to send me messages`; the bot replies with an API key. Treat
it as the secondary channel — the text passes through a third party, so alert
bodies say *what* is broken and never carry a credential. The daily heartbeat is
what reveals it if it dies quietly. For an official channel later: Meta's
WhatsApp Cloud API, which needs a dedicated number and business verification.

Test both without waiting for an outage:

```bash
sudo -u permedjat-alerts /usr/local/bin/permedjat-alert-sender.py --test
```

## The outside layer — healthchecks.io (added 2026-08-25)

Everything above runs on the machine it watches, so a machine that dies takes
its own alerting with it and you learn about it from the *absence* of the 09:00
pulse, hours later. healthchecks.io closes that: the server pings **out**, and
silence is what triggers the alarm — a dead man's switch, so no part of the
detection lives on the box being watched.

Project `permedjat`, free Hobbyist plan (20 checks, we use 7):

| Check | Expected | Grace | Pinged by |
|---|---|---|---|
| `permedjat-server-alive` | every 15 min | 20 min | cron in `/etc/cron.d/permedjat-monitoring` |
| `permedjat-backup` | `0 2 * * *` | 3 h | `permedjat-backup.sh` |
| `permedjat-absences` | `50 23 * * *` | 2 h | `permedjat-cron-run.sh` |
| `permedjat-leave-rollover` | `0,30 0 * * *` | 2 h | `&&` in `/etc/cron.d/permedjat` |
| `permedjat-daily-alerts` | `0 7 * * *` | 2 h | `permedjat-cron-run.sh` |
| `permedjat-kiosk-purge` | `30 3 * * *` | 3 h | `permedjat-cron-run.sh` |
| `permedjat-alerting-alive` | every 15 min | 20 min | `permedjat-alerting-selftest.sh` |

`permedjat-alerting-alive` is the one that watches the watcher. It pings only
when Alertmanager (9093) *and* the sender (9099) both answer, because if the
sender dies every Prometheus alert is written to a socket nobody is listening
on: the machine stays healthy, the liveness beacon keeps arriving, and the first
sign of trouble is a real outage that never reaches a phone. Verified by
stopping `permedjat-alerts.service` and confirming the check reported `/fail`.

**Two bugs this uncovered, both silent, both fixed here:**

1. The three cron wrappers ran `curl -s` with no `-f`, so they exited 0 whatever
   the server answered — a 500, a PHP fatal, an HTML error page. Wiring a
   success beacon to that would have been worse than no monitoring: a nightly
   "the job ran fine" while the job failed. `permedjat-cron-run.sh` now requires a
   2xx **and** a body saying the endpoint finished (`"status":"success"` or
   `"ok"`), and pings `/fail` with the response otherwise.
2. `permedjat-backup.sh` piped `mysqldump | gzip` without `pipefail`. A mysqldump
   dying half way still exited 0, because gzip compressed the truncated stream
   and succeeded — a healthy-looking backup that cannot be restored. Fixed with
   `set -euo pipefail`, an `ERR` trap that pings `/fail`, and a minimum-size
   check as a second line of defence.

Watch the ownership: three of these crons run as **www-data**, so
`permedjat-cron-run.sh` and its wrappers are `750 root:www-data`. Setting them
`root:root` locks cron out and every one of them stops silently.

**Message language.** Our own sender speaks Arabic. healthchecks' own wording
is English and cannot be changed, so the WhatsApp webhook carries a
percent-encoded Arabic sentence with `$NAME` left literal for substitution:

```
...&text=%F0%9F%94%B4%20%D9%85%D9%90%D8%AF%D8%AC%D8%A7%D8%AA%20%E2%80%94%20%D8%AA%D9%88%D9%82%D9%91%D9%81%3A%20$NAME
```

Telegram deliberately keeps healthchecks' own English bot. Routing it through
our bot instead would give Arabic and one unified conversation, but it means
storing our bot token in a third party's settings — not worth it for wording,
and the separate sender is itself a signal: a message from HealthchecksBot means
the server went quiet, one from Permedjat Alerts means the server is alive and
complaining.

Check names stay ASCII (`permedjat-backup`) on purpose: they are identifiers that
map to scripts on the server, and an Arabic name in a 3am message would have to
be translated back before you knew which file to open.

Ping URLs are secrets in the sense that anyone holding one can fake a beacon and
hide a real failure — they live in server-side scripts, never in this repo. The
project API key is in [[permedjat-server-credentials]].

## Still missing

**An external HTTP check.** healthchecks proves the machine and its jobs are
alive; it says nothing about whether the world can *reach* the API. If the
server is healthy but Cloudflare, DNS or nginx is broken, beacons keep arriving
and healthchecks stays quiet. A free UptimeRobot monitor on
`api.permedjat.com` (set to treat **401** as success) closes that last gap.

### Two more things found while auditing this

- **blackbox_exporter was listening on `*:9115`**, not localhost. UFW blocks the
  port, so it was not reachable — but an exposed blackbox exporter is an open
  probe primitive: anyone reaching it can make this server fetch arbitrary URLs
  on their behalf. Now bound to `127.0.0.1` in
  `/etc/default/prometheus-blackbox-exporter`. Defence in depth, not either/or.
- **`/var/log/permedjat-cron.log` had no rotation** and grew forever. Weekly, 8
  kept, in `/etc/logrotate.d/permedjat`. Needs `su root syslog` — without it
  logrotate refuses `/var/log` on Ubuntu as "insecure permissions".

Backups of the pre-change files are in `/root/*.bak-20260825`.
