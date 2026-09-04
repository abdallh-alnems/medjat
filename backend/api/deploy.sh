#!/usr/bin/env bash
#
# The only supported way to change the live API.
#
# Same rule as the old backend's deploy.sh, for the same reason: edit code here,
# then run this. A file changed over SSH is invisible to git and gets silently
# reverted by the next deploy, and ad-hoc SQL is how production once had four
# tables local had never heard of.
#
#   ./deploy.sh --dry-run     show what would change, touch nothing
#   ./deploy.sh               push code, install deps, migrate, cache, verify
#   ./deploy.sh --code-only   push code and reload, skip migrations
#
# Requires a `permedjat` host in ~/.ssh/config.
#
# NOT for the cutover itself. The first time this application meets the
# production database, its `migrations` table is empty while the schema is
# already there, and `artisan migrate` would try to CREATE TABLE tenants and
# stop. Run `php artisan permedjat:baseline --pretend` on the server once, read the
# plan, run it for real, and only then use this script. See README, "Cutover".

set -euo pipefail

REMOTE="${PERMEDJAT_SSH_HOST:-permedjat}"
REMOTE_DIR="${PERMEDJAT_REMOTE_DIR:-/var/www/permedjat/api}"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
API_URL="${PERMEDJAT_API_URL:-https://api.permedjat.com/backend}"
PHP_FPM="${PERMEDJAT_PHP_FPM:-php8.5-fpm}"

DRY=0; CODE_ONLY=0
case "${1:-}" in
  --dry-run)   DRY=1 ;;
  --code-only) CODE_ONLY=1 ;;
  "")          ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

step() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

step "1/7  Checking connectivity"
ssh -o ConnectTimeout=15 "$REMOTE" 'echo "  ✓ $(hostname) reachable"'

step "2/7  Code changes"
RSYNC_FLAGS=(-rc --delete --itemize-changes --exclude-from="$LOCAL_DIR/.deployignore")
[ "$DRY" = "1" ] && RSYNC_FLAGS+=(-n)
CHANGES="$(rsync "${RSYNC_FLAGS[@]}" "$LOCAL_DIR/" "$REMOTE:$REMOTE_DIR/")"
if [ -z "$CHANGES" ]; then
  echo "  ✓ server already matches local"
else
  echo "$CHANGES" | sed 's/^/  /'
  # A leading * is rsync's delete marker. .deployignore exists to keep
  # server-owned paths — .env, uploads/, vendor/ — out of that list, so anything
  # showing up here is worth reading before it lands.
  if echo "$CHANGES" | grep -q '^\*deleting'; then
    echo
    echo "  ⚠  the run above DELETES files on the server (listed with *deleting)."
    echo "     If any of those are server-owned, add them to .deployignore first."
  fi
fi

if [ "$DRY" = "1" ]; then
  step "Pending migrations"
  ssh "$REMOTE" "cd $REMOTE_DIR && php artisan migrate:status" | sed 's/^/  /'
  step "Dry run — nothing was changed"
  exit 0
fi

step "3/7  Dependencies"
# --no-dev, because vendor/ is excluded from the rsync: shipping the local tree
# would put phpunit, phpstan and their transitive dependencies in production.
ssh "$REMOTE" "cd $REMOTE_DIR && composer install --no-dev --optimize-autoloader --no-interaction --no-progress" \
  | sed 's/^/  /'

step "4/7  Database migrations"
if [ "$CODE_ONLY" = "1" ]; then
  echo "  (skipped — --code-only)"
else
  # Shown before it runs. A migration list is the one part of a deploy that
  # cannot be undone by deploying again.
  ssh "$REMOTE" "cd $REMOTE_DIR && php artisan migrate --force --no-interaction" | sed 's/^/  /'
fi

step "5/7  Caches"
# config:cache is what makes env() return null outside config/, which is why
# every tuned value in this application lives in config/permedjat.php. Rebuilt
# rather than merely cleared: a cold cache means the first request after every
# deploy pays for compiling all of it.
ssh "$REMOTE" "cd $REMOTE_DIR && \
  php artisan config:cache && \
  php artisan route:cache && \
  php artisan view:cache && \
  php artisan event:cache" | sed 's/^/  /'

step "6/7  Permissions and PHP reload"
ssh "$REMOTE" "chown -R www-data:www-data $REMOTE_DIR/storage $REMOTE_DIR/bootstrap/cache 2>/dev/null; \
  systemctl reload $PHP_FPM && echo '  ✓ php-fpm reloaded'"

step "7/7  Smoke test"
FAILED=0

# Liveness. /up is Laravel's health route and the only endpoint that should
# answer 200 without credentials.
CODE="$(curl -s -o /dev/null -w '%{http_code}' "$API_URL/up")"
if [ "$CODE" = "200" ]; then
  echo "  ✓ /up → 200"
else
  echo "  ✗ /up → $CODE (the application is not booting)" >&2; FAILED=1
fi

# The guards are in place. No credentials, so each must refuse — a 200 here
# means a route lost its middleware, and a 500 means the deploy broke bootstrap.
# One per principal, because a broken guard usually breaks every route using it.
for ep in "v1/auth/admin/login" "v1/employees" "v1/admin/tenants"; do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API_URL/$ep")"
  case "$CODE" in
    401|403|405|422) echo "  ✓ $ep → $CODE" ;;
    *) echo "  ✗ $ep → $CODE (expected a refusal; 500 means bootstrap is broken)" >&2; FAILED=1 ;;
  esac
done

# The docroot is public/, so nothing below should be reachable at all. Asserted
# rather than assumed: a vhost pointed one directory too high serves .env — the
# database password, the app secret and the Firebase path — as plain text, and
# it fails silently because every other URL keeps working.
for secret in ".env" "composer.json" "artisan" "app/Shared/Time/TenantClock.php" "storage/logs/laravel.log"; do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$API_URL/$secret")"
  if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
    echo "  ✓ $secret blocked ($CODE)"
  else
    echo "  ✗ $secret returned $CODE — IT IS PUBLICLY READABLE" >&2; FAILED=1
  fi
done

# Employee evidence: payslips, identity documents, face captures. Stored on a
# private disk outside the docroot and streamed only by a controller that checks
# who is asking, so a direct URL must find nothing.
CODE="$(curl -s -o /dev/null -w '%{http_code}' "$API_URL/uploads/")"
if [ "$CODE" = "403" ] || [ "$CODE" = "404" ]; then
  echo "  ✓ uploads/ blocked ($CODE)"
else
  echo "  ✗ uploads/ returned $CODE — EMPLOYEE DOCUMENTS ARE PUBLICLY READABLE" >&2; FAILED=1
fi

if [ "$FAILED" = "1" ]; then
  echo >&2
  echo "  Check the logs:" >&2
  echo "    ssh $REMOTE 'tail -50 /var/log/nginx/error.log'" >&2
  echo "    ssh $REMOTE 'tail -50 $REMOTE_DIR/storage/logs/laravel.log'" >&2
  exit 1
fi

printf '\n\033[1;32m✓ deployed\033[0m\n'
