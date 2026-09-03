#!/usr/bin/env bash
#
# The only supported way to change the live web app (app.permedjatapp.com).
#
# Next.js ships as one build, not as individual files: whatever is in this
# directory is what goes live. So run --dry-run first and read the list.
#
#   ./deploy-web.sh --dry-run   show what would change, touch nothing
#   ./deploy-web.sh             push source, install, build, restart, verify
#
# Requires a `permedjat` host in ~/.ssh/config.

set -euo pipefail

REMOTE="${PERMEDJAT_SSH_HOST:-permedjat}"
REMOTE_DIR="/var/www/permedjat-web/central"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE="permedjat-web.service"
SITE_URL="https://app.permedjatapp.com"

DRY=0
case "${1:-}" in
  --dry-run) DRY=1 ;;
  "")        ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

step() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

step "1/6  Checking connectivity"
ssh -o ConnectTimeout=15 "$REMOTE" 'echo "  ✓ $(hostname) reachable"'

# The server's .env.local is hand-written and exists in no repo. It is excluded
# from the sync, but a copy costs nothing and turns "the site is down and the
# secrets are gone" into a one-line restore.
step "2/6  Backing up server .env.local"
ssh "$REMOTE" "cp -n $REMOTE_DIR/.env.local $REMOTE_DIR/.env.local.bak-\$(date +%F) 2>/dev/null; \
  ls -1 $REMOTE_DIR/.env.local* | sed 's|^|  |'"

step "3/6  Source changes"
RSYNC_FLAGS=(-rc --delete --itemize-changes --exclude-from="$LOCAL_DIR/.deployignore")
[ "$DRY" = "1" ] && RSYNC_FLAGS+=(-n)
CHANGES="$(rsync "${RSYNC_FLAGS[@]}" "$LOCAL_DIR/" "$REMOTE:$REMOTE_DIR/")"
if [ -z "$CHANGES" ]; then
  echo "  ✓ server already matches local"
else
  echo "$CHANGES" | sed 's/^/  /'
  if echo "$CHANGES" | grep -q '^\*deleting'; then
    echo
    echo "  ⚠  the run above DELETES files on the server (listed with *deleting)."
    echo "     If any are server-owned, add them to .deployignore first."
  fi
fi

if [ "$DRY" = "1" ]; then
  step "Dry run — nothing was changed"
  exit 0
fi

# npm ci, not npm install: the lockfile is the whole point of a reproducible
# deploy, and `install` will happily resolve something newer on the server than
# what was built and tested here.
#
# NOT --omit=dev: `next build` needs typescript, tailwind and the eslint config,
# all of which are devDependencies. Omitting them installs cleanly and then
# fails the build.
#
# The chown first: anything ever installed here as root leaves directories
# www-data cannot remove, and `npm ci` starts by deleting node_modules — so it
# dies with EACCES partway through. Cheap to run every time, and it keeps the
# tree matching the user the service runs as.
step "4/6  Installing and building on the server"
ssh "$REMOTE" "chown -R www-data:www-data $REMOTE_DIR && cd $REMOTE_DIR && \
  sudo -u www-data env HOME=$REMOTE_DIR npm ci --no-audit --no-fund && \
  sudo -u www-data env HOME=$REMOTE_DIR NODE_ENV=production npm run build" 2>&1 | tail -20 | sed 's/^/  /'

step "5/6  Restarting $SERVICE"
ssh "$REMOTE" "systemctl restart $SERVICE && sleep 4 && \
  systemctl is-active $SERVICE | sed 's/^/  service: /'"

step "6/6  Smoke test"
CODE="$(curl -s -o /dev/null -w '%{http_code}' "$SITE_URL")"
if [ "$CODE" = "200" ] || [ "$CODE" = "307" ] || [ "$CODE" = "302" ]; then
  echo "  ✓ site responding ($CODE)"
else
  echo "  ✗ site returned $CODE. Check the service:" >&2
  echo "    ssh $REMOTE 'journalctl -u $SERVICE -n 50 --no-pager'" >&2
  exit 1
fi

printf '\n\033[1;32m✓ deployed\033[0m\n'
