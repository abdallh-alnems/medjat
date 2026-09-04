#!/usr/bin/env bash
#
# The only supported way to change the live backend.
#
# Edit code locally → commit → run this. Never edit files on the server and
# never run SQL there by hand: both are invisible to the repo, and that is
# exactly how local and production drifted apart (a whole ZKTeco feature sat
# undeployed for a day while two migrations sat unapplied for six weeks).
#
#   ./deploy.sh --dry-run    show what would change, touch nothing
#   ./deploy.sh              push code, apply pending migrations, verify
#   ./deploy.sh --code-only  push code, skip migrations
#
# Requires a `permedjat` host in ~/.ssh/config.

set -euo pipefail

REMOTE="${PERMEDJAT_SSH_HOST:-permedjat}"
REMOTE_DIR="/var/www/permedjat/backend"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
API_URL="https://api.permedjat.com/backend"

DRY=0; CODE_ONLY=0
case "${1:-}" in
  --dry-run)   DRY=1 ;;
  --code-only) CODE_ONLY=1 ;;
  "")          ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

step() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

step "1/5  Checking connectivity"
ssh -o ConnectTimeout=15 "$REMOTE" 'echo "  ✓ $(hostname) reachable"'

step "2/5  Code changes"
RSYNC_FLAGS=(-rc --delete --itemize-changes --exclude-from="$LOCAL_DIR/.deployignore")
[ "$DRY" = "1" ] && RSYNC_FLAGS+=(-n)
CHANGES="$(rsync "${RSYNC_FLAGS[@]}" "$LOCAL_DIR/" "$REMOTE:$REMOTE_DIR/")"
if [ -z "$CHANGES" ]; then
  echo "  ✓ server already matches local"
else
  echo "$CHANGES" | sed 's/^/  /'
  # A leading * is rsync's delete marker — worth a second look before it lands.
  if echo "$CHANGES" | grep -q '^\*deleting'; then
    echo
    echo "  ⚠  the run above DELETES files on the server (listed with *deleting)."
    echo "     If any of those are server-owned, add them to .deployignore first."
  fi
fi

if [ "$DRY" = "1" ]; then
  step "Dry run — nothing was changed"
  ssh "$REMOTE" "cd $REMOTE_DIR/database/migrations && \
    DB_PORT=3306 DB_USER=permedjat DB_PASS=\$(cd $REMOTE_DIR && php -r 'require \"config/env.php\"; echo getenv(\"DB_PASS\");') \
    MYSQL_BIN=\$(command -v mysql) ./migrate.sh --status"
  exit 0
fi

step "3/5  Database migrations"
if [ "$CODE_ONLY" = "1" ]; then
  echo "  (skipped — --code-only)"
else
  ssh "$REMOTE" "cd $REMOTE_DIR/database/migrations && chmod +x migrate.sh && \
    DB_PORT=3306 DB_USER=permedjat DB_PASS=\$(cd $REMOTE_DIR && php -r 'require \"config/env.php\"; echo getenv(\"DB_PASS\");') \
    MYSQL_BIN=\$(command -v mysql) ./migrate.sh" | sed 's/^/  /'
fi

step "4/5  Reloading PHP"
ssh "$REMOTE" "chown -R www-data:www-data $REMOTE_DIR/api $REMOTE_DIR/core $REMOTE_DIR/database 2>/dev/null; \
  systemctl reload php8.5-fpm && echo '  ✓ php-fpm reloaded'"

step "5/5  Smoke test"
FAILED=0

# Reachability: no credentials, so the app-key gate must answer 401. A 500 means
# the deploy broke bootstrap, and it is better to find out now than from a user.
# One endpoint per top-level group — a broken include usually breaks a whole
# directory, and these three cover every include depth in the tree.
for ep in "app/auth/login.php" "admin/auth/login.php" "app/cron/run_alerts.php"; do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_URL/api/$ep")"
  case "$CODE" in
    401|403) echo "  ✓ api/$ep → $CODE" ;;
    *) echo "  ✗ api/$ep → $CODE (expected 401/403; 500 means bootstrap is broken)" >&2; FAILED=1 ;;
  esac
done

# The deny rule. These paths hold the database password, JWT_SECRET and
# OTP_HMAC_SECRET; a restructure that moves a directory out from under the rule
# exposes them silently, so assert it rather than trusting it.
for secret in "config/env.php" "core/Auth.php" "database/migrations/" "cron/cron_leave_rollover.php" "tools/seed_superadmin.php"; do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$API_URL/$secret")"
  if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    echo "  ✓ $secret blocked ($CODE)"
  else
    echo "  ✗ $secret returned $CODE — IT IS PUBLICLY READABLE" >&2; FAILED=1
  fi
done

if [ "$FAILED" = "1" ]; then
  echo >&2
  echo "  Check the server logs: ssh $REMOTE 'tail -50 /var/log/nginx/error.log'" >&2
  exit 1
fi

printf '\n\033[1;32m✓ deployed\033[0m\n'
