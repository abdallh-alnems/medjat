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
# Requires an `medjat` host in ~/.ssh/config.

set -euo pipefail

REMOTE="${MEDJAT_SSH_HOST:-medjat}"
REMOTE_DIR="/var/www/medjat/backend_medjet"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
API_URL="https://api.medjatapp.com/backend_medjet"

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
  ssh "$REMOTE" "cd $REMOTE_DIR/migrations && \
    DB_PORT=3306 DB_USER=medjat DB_PASS=\$(cd $REMOTE_DIR && php -r 'require \"config/env.php\"; echo getenv(\"DB_PASS\");') \
    MYSQL_BIN=\$(command -v mysql) ./migrate.sh --status"
  exit 0
fi

step "3/5  Database migrations"
if [ "$CODE_ONLY" = "1" ]; then
  echo "  (skipped — --code-only)"
else
  ssh "$REMOTE" "cd $REMOTE_DIR/migrations && chmod +x migrate.sh && \
    DB_PORT=3306 DB_USER=medjat DB_PASS=\$(cd $REMOTE_DIR && php -r 'require \"config/env.php\"; echo getenv(\"DB_PASS\");') \
    MYSQL_BIN=\$(command -v mysql) ./migrate.sh" | sed 's/^/  /'
fi

step "4/5  Reloading PHP"
ssh "$REMOTE" "chown -R www-data:www-data $REMOTE_DIR/app $REMOTE_DIR/core $REMOTE_DIR/models 2>/dev/null; \
  systemctl reload php8.5-fpm && echo '  ✓ php-fpm reloaded'"

step "5/5  Smoke test"
# No credentials: the app-key gate must answer 401. A 500 here means the deploy
# broke bootstrap, and it is better to find out now than from a user.
CODE="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_URL/app/auth/login.php")"
if [ "$CODE" = "401" ]; then
  echo "  ✓ API healthy (401 without app key, as expected)"
else
  echo "  ✗ API returned $CODE — expected 401. Check the server logs:" >&2
  echo "    ssh $REMOTE 'tail -50 /var/log/nginx/error.log'" >&2
  exit 1
fi

printf '\n\033[1;32m✓ deployed\033[0m\n'
