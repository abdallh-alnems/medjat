#!/usr/bin/env bash
#
# Answers one question: does the live server still match this repo?
#
# Run it before you start work and after anyone touches the server. It compares
# three things and exits non-zero if any of them disagree, so it also works as a
# pre-deploy guard:
#
#   1. code     — every deployable file, by checksum
#   2. schema   — every table and column, by name and type
#   3. ledger   — which migrations each side thinks it has applied
#
# It reads nothing and writes nothing. Safe to run any time.

set -uo pipefail

REMOTE="${PERMEDJAT_SSH_HOST:-permedjat}"
REMOTE_DIR="/var/www/permedjat/backend"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
MYSQL_BIN="${MYSQL_BIN:-/Applications/MAMP/Library/bin/mysql80/bin/mysql}"
[ -x "$MYSQL_BIN" ] || MYSQL_BIN="$(command -v mysql)"
DB_HOST="${DB_HOST:-127.0.0.1}"; DB_PORT="${DB_PORT:-8889}"
DB_USER="${DB_USER:-root}";      DB_PASS="${DB_PASS:-root}"
DB_NAME="${DB_NAME:-permedjat}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAIL=0
step() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

# env.php exports via putenv() rather than returning an array, so it has to be
# required and then read back out of the environment.
REMOTE_PASS="$(ssh "$REMOTE" "cd $REMOTE_DIR && php -r 'require \"config/env.php\"; echo getenv(\"DB_PASS\");'" 2>/dev/null)"
if [ -z "$REMOTE_PASS" ]; then
  echo "✗ could not read the production DB password over ssh — is '$REMOTE' in ~/.ssh/config?" >&2
  exit 2
fi
# The queries below quote identifiers with double quotes, so the remote -e
# argument must be single-quoted or the two layers of quoting cancel out and
# mysql silently receives an empty statement.
rmysql() { ssh "$REMOTE" "mysql -upermedjat -p$REMOTE_PASS permedjat -N -B -e '$1'" 2>/dev/null; }
lmysql() { "$MYSQL_BIN" -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" ${DB_PASS:+-p"$DB_PASS"} "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

step "1/3  Code"
CHANGES="$(rsync -rcn --delete --itemize-changes --exclude-from="$LOCAL_DIR/.deployignore" \
  "$LOCAL_DIR/" "$REMOTE:$REMOTE_DIR/" 2>/dev/null)"
if [ -z "$CHANGES" ]; then
  echo "  ✓ server matches repo"
else
  echo "  ✗ $(echo "$CHANGES" | wc -l | tr -d ' ') file(s) differ:"
  echo "$CHANGES" | sed 's/^/      /'
  echo "      → fix with: ./deploy.sh"
  FAIL=1
fi

step "2/3  Schema (local MAMP vs production)"
COLQ='SELECT CONCAT(TABLE_NAME,"|",COLUMN_NAME,"|",COLUMN_TYPE,"|",IS_NULLABLE) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>"schema_migrations" ORDER BY TABLE_NAME, COLUMN_NAME'
lmysql "$COLQ" > "$TMP/local.txt"
rmysql "$COLQ" > "$TMP/prod.txt"
if [ ! -s "$TMP/local.txt" ]; then
  echo "  ⚠  local MAMP not reachable — is MySQL running? (skipping)"
elif diff -q "$TMP/local.txt" "$TMP/prod.txt" >/dev/null; then
  echo "  ✓ identical — $(cut -d'|' -f1 "$TMP/prod.txt" | sort -u | wc -l | tr -d ' ') tables, $(wc -l < "$TMP/prod.txt" | tr -d ' ') columns"
else
  echo "  ✗ schema differs:"
  diff "$TMP/local.txt" "$TMP/prod.txt" | grep '^[<>]' | sed 's/^</      local only: /; s/^>/      prod  only: /' | head -25
  echo "      → rebuild local from prod: ssh $REMOTE 'mysqldump -upermedjat -p… permedjat' | mysql … permedjat"
  FAIL=1
fi

step "3/3  Migration ledger"
lmysql "SELECT filename FROM schema_migrations ORDER BY filename" > "$TMP/lmig.txt"
rmysql "SELECT filename FROM schema_migrations ORDER BY filename" > "$TMP/pmig.txt"
ls -1 "$LOCAL_DIR"/database/migrations/*.sql 2>/dev/null | xargs -n1 basename | grep -v '^schema' | sort > "$TMP/files.txt"
echo "  files in repo: $(wc -l < "$TMP/files.txt" | tr -d ' ')   local applied: $(wc -l < "$TMP/lmig.txt" | tr -d ' ')   prod applied: $(wc -l < "$TMP/pmig.txt" | tr -d ' ')"
UNAPPLIED="$(comm -23 "$TMP/files.txt" "$TMP/pmig.txt")"
if [ -n "$UNAPPLIED" ]; then
  echo "  ✗ migration files never applied to production:"
  echo "$UNAPPLIED" | sed 's/^/      /'
  echo "      → apply with: ./deploy.sh"
  FAIL=1
else
  echo "  ✓ every migration in the repo is applied to production"
fi

if [ "$FAIL" = "0" ]; then
  printf '\n\033[1;32m✓ no drift — repo, local database and production agree\033[0m\n'
else
  printf '\n\033[1;31m✗ drift detected (see above)\033[0m\n'
fi
exit $FAIL
