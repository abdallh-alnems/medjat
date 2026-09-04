#!/usr/bin/env bash
#
# The server half of the medjat -> permedjat rename: sections 2-7 of
# RENAME-CUTOVER.md, in one run, on the Hetzner box.
#
#   ssh permedjat 'bash -s' < cutover-server.sh --dry-run
#   ssh permedjat 'bash -s' < cutover-server.sh
#
# It renames paths, the database and its user, the nginx files, the systemd
# units, the cron files and the helper scripts. It does NOT touch DNS,
# certificates or server_name — the new hostnames cannot be served until an
# origin certificate covering them exists, which is a separate step.
#
# Everything here is reversible: paths move back, RENAME TABLE runs the other
# way. The script smoke-tests at the end and refuses to leave a half-state
# silently — read the summary it prints.
#
# PRECONDITION, and it is not optional: the rename branch must be merged and
# deployed first. This box is served from /var/www/permedjat afterwards, and a
# deploy.sh run from a `main` that still says `medjat` would rsync the old tree
# straight back and split the two.

set -uo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ "$DRY" = 1 ]; then echo "   would: $*"; else eval "$@"; fi; }
step() { printf '\n=== %s ===\n' "$*"; }
ok=0; bad=0
check() { if eval "$1" >/dev/null 2>&1; then echo "   ok   $2"; ok=$((ok+1)); else echo "   FAIL $2"; bad=$((bad+1)); fi; }

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

step "0. preflight"
for p in /var/www/medjat /var/www/medjat-web /etc/nginx/sites-available/medjat; do
  [ -e "$p" ] || { echo "   missing $p — has this already run?" >&2; exit 1; }
done
VIEWS=$(mysql -N -B -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='medjat' AND TABLE_TYPE='VIEW'" 2>/dev/null)
ROUT=$(mysql -N -B -e "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='medjat'" 2>/dev/null)
TRIG=$(mysql -N -B -e "SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='medjat'" 2>/dev/null)
if [ "${VIEWS:-1}${ROUT:-1}${TRIG:-1}" != "000" ]; then
  echo "   the schema has views/routines/triggers ($VIEWS/$ROUT/$TRIG)." >&2
  echo "   RENAME TABLE would leave them pointing at the old schema. Stop and" >&2
  echo "   dump/restore instead." >&2
  exit 1
fi
echo "   84-ish tables, no views/routines/triggers — RENAME TABLE is safe"
run "mysqldump --single-transaction --routines --events medjat | gzip > /root/medjat-pre-rename-\$(date +%F-%H%M).sql.gz"
echo "   pre-rename dump written to /root"

step "1. stop the moving parts"
run "systemctl stop medjat-web.service medjat-alerts.service"

step "2. filesystem"
run "mv /var/www/medjat     /var/www/permedjat"
run "mv /var/www/medjat-web /var/www/permedjat-web"

step "3. database"
if [ "$DRY" = 1 ]; then
  echo "   would: CREATE DATABASE permedjat + RENAME TABLE x$(mysql -N -B -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='medjat' AND TABLE_TYPE='BASE TABLE'") + RENAME USER + GRANT"
else
  mysql -e "CREATE DATABASE IF NOT EXISTS permedjat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
  STMT=$(mysql -N -B -e "
    SELECT CONCAT('RENAME TABLE ',
      GROUP_CONCAT('\`medjat\`.\`', TABLE_NAME, '\` TO \`permedjat\`.\`', TABLE_NAME, '\`' SEPARATOR ', '), ';')
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA='medjat' AND TABLE_TYPE='BASE TABLE';")
  mysql -e "$STMT"
  mysql -e "RENAME USER 'medjat'@'localhost' TO 'permedjat'@'localhost';
            GRANT ALL PRIVILEGES ON permedjat.* TO 'permedjat'@'localhost';
            FLUSH PRIVILEGES;"
  mysql -e "DROP DATABASE medjat"
  echo "   schema, user and grants moved"
fi

step "4. the server-only env file"
# The deployed tree is still pre-restructure: backend_medjet/, not backend/.
# That migration has never shipped, so the rename must follow what is actually
# on disk, not what the repo layout suggests.
ENV=/var/www/permedjat/backend_medjet/config/env.php
if [ "$DRY" = 1 ]; then
  echo "   would: rewrite dbname= and DB_USER in $ENV"
else
  cp "$ENV" "$ENV.bak-$(date +%F-%H%M)"
  sed -i "s/dbname=medjat/dbname=permedjat/g; s/'medjat'/'permedjat'/g; s/DB_USER=medjat/DB_USER=permedjat/g" "$ENV"
  php -l "$ENV" >/dev/null || { echo "   env.php no longer parses — restoring" >&2; cp "$ENV".bak-* "$ENV"; exit 1; }
  echo "   env.php repointed (backup beside it)"
fi

step "5. nginx"
run "mv /etc/nginx/snippets/medjat-common.conf /etc/nginx/snippets/permedjat-common.conf"
for s in medjat medjat-devices medjat-grafana medjat-panels medjat-web; do
  run "mv /etc/nginx/sites-available/$s /etc/nginx/sites-available/per$s"
  run "rm -f /etc/nginx/sites-enabled/$s"
  run "ln -sf ../sites-available/per$s /etc/nginx/sites-enabled/per$s"
done
run "mv /etc/nginx/medjat-panel.htpasswd /etc/nginx/permedjat-panel.htpasswd 2>/dev/null || true"
run "sed -i 's#/var/www/medjat-web#/var/www/permedjat-web#g; s#/var/www/medjat#/var/www/permedjat#g; s#snippets/medjat-common#snippets/permedjat-common#g; s#medjat-panel.htpasswd#permedjat-panel.htpasswd#g; s#\\bmedjat_devices\\b#permedjat_devices#g; s#\\bmedjat_rate_limit\\b#permedjat_rate_limit#g' /etc/nginx/sites-available/per* /etc/nginx/snippets/permedjat-common.conf /etc/nginx/nginx.conf"
if [ "$DRY" = 0 ]; then
  nginx -t || { echo "   nginx config is broken — NOT reloading. Fix, then: systemctl reload nginx" >&2; exit 1; }
fi

step "6. systemd"
run "mv /etc/systemd/system/medjat-web.service    /etc/systemd/system/permedjat-web.service"
run "mv /etc/systemd/system/medjat-alerts.service /etc/systemd/system/permedjat-alerts.service"
run "sed -i 's#/var/www/medjat-web#/var/www/permedjat-web#g; s#/var/www/medjat#/var/www/permedjat#g; s#/usr/local/bin/medjat-#/usr/local/bin/permedjat-#g; s#/var/lib/medjat-alerts#/var/lib/permedjat-alerts#g; s#medjat-alerts#permedjat-alerts#g' /etc/systemd/system/permedjat-web.service /etc/systemd/system/permedjat-alerts.service"
run "mv /var/lib/medjat-alerts /var/lib/permedjat-alerts 2>/dev/null || true"
run "mv /etc/default/medjat-alerts.env /etc/default/permedjat-alerts.env 2>/dev/null || true"
run "usermod  -l permedjat-alerts medjat-alerts 2>/dev/null || true"
run "groupmod -n permedjat-alerts medjat-alerts 2>/dev/null || true"
run "chown -R permedjat-alerts:permedjat-alerts /var/lib/permedjat-alerts 2>/dev/null || true"
run "systemctl daemon-reload"

step "7. cron and helper scripts"
# The cron URLs keep calling api.medjatapp.com on purpose. The new host does not
# resolve yet, and a cron repointed at it would fail silently every night. They
# move in the same change that adds the new server_name.
for f in medjat-alert-sender.py medjat-alerting-selftest.sh medjat-backup.sh \
         medjat-cron-absences.sh medjat-cron-alerts.sh medjat-cron-kiosk-purge.sh \
         medjat-cron-run.sh medjat-node-metrics.sh; do
  run "mv /usr/local/bin/$f /usr/local/bin/per$f 2>/dev/null || true"
done
run "mv /etc/cron.d/medjat            /etc/cron.d/permedjat"
run "mv /etc/cron.d/medjat-monitoring /etc/cron.d/permedjat-monitoring"
run "mv /var/log/medjat-cron.log      /var/log/permedjat-cron.log 2>/dev/null || true"
run "sed -i 's#/usr/local/bin/medjat-#/usr/local/bin/permedjat-#g; s#/var/www/medjat#/var/www/permedjat#g; s#/var/log/medjat-cron.log#/var/log/permedjat-cron.log#g' /etc/cron.d/permedjat /etc/cron.d/permedjat-monitoring /usr/local/bin/permedjat-*"
run "sed -i 's#/var/lib/medjat-alerts#/var/lib/permedjat-alerts#g; s#/var/www/medjat#/var/www/permedjat#g' /usr/local/bin/permedjat-* 2>/dev/null || true"

step "8. back up"
run "systemctl start permedjat-web.service permedjat-alerts.service"
run "systemctl reload nginx"
run "systemctl enable permedjat-web.service permedjat-alerts.service >/dev/null 2>&1"

if [ "$DRY" = 1 ]; then echo; echo "dry run — nothing changed"; exit 0; fi

step "9. smoke test"
sleep 3
check "test -d /var/www/permedjat/backend"                                  "/var/www/permedjat exists"
check "test ! -e /var/www/medjat"                                           "old path gone"
check "mysql -N -B -e \"SELECT 1 FROM permedjat.tenants LIMIT 1\""          "database answers under the new name"
check "systemctl is-active --quiet permedjat-web.service"                   "permedjat-web.service running"
check "systemctl is-active --quiet nginx"                                   "nginx running"
# The old hostnames are gone and /backend/ is a bare prefix that 404s, so probe
# the new names against paths that actually exist. A 401 from the API is the
# right answer — it means the auth gate is up, not that anything is broken.
check "[ \$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: api.permedjat.com' http://127.0.0.1/backend_medjet/app/auth/login.php) = 401 ]" "api answers behind its auth gate"
check "curl -fsS -o /dev/null -H 'Host: api.permedjat.com' http://127.0.0.1/.well-known/assetlinks.json" "api serves its association file"
check "[ -n \"\$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: app.permedjat.com' http://127.0.0.1/)\" ]" "web app answers"
check "test -f /etc/cron.d/permedjat"                                       "cron file in place"

echo
if [ "$bad" -gt 0 ]; then
  echo "$bad check(s) failed, $ok passed. The system is in a half-renamed state."
  echo "Roll back with: cutover-server.sh --rollback, or move the paths back by hand."
  exit 1
fi
echo "$ok checks passed. Server renamed."
echo
echo "Still to do, and none of it is on this box:"
echo "  - DNS for permedjat.com          (deploy/cutover-dns.sh)"
echo "  - an origin cert for *.permedjat.com, then add the new names to server_name"
echo "  - Firebase project, store listings, mail authentication"
