#!/usr/bin/env bash
#
# Permedjat migration runner.
#
# Applies every dated .sql file in this directory exactly once, in filename
# order, and records what it applied in the `schema_migrations` table. A file
# already recorded there is skipped, so running this twice is a no-op.
#
# It deliberately does NOT touch schema.sql on a database that already has
# tables. schema.sql is the bootstrap for an empty database only; replaying it
# over a live one is what let local and production drift apart in the first
# place, because it silently recreated tables that migrations had dropped.
#
#   ./migrate.sh --status      what is applied, what is pending
#   ./migrate.sh --dry-run     show what would run, change nothing
#   ./migrate.sh               apply pending migrations
#   ./migrate.sh --bootstrap   load schema.sql into an EMPTY database, then apply
#
# Connection comes from the environment (defaults target local MAMP):
#   DB_HOST DB_PORT DB_NAME DB_USER DB_PASS MYSQL_BIN
#
# Production is reached by exporting those first and running this ON the server
# — MySQL there does not listen publicly:
#   ssh permedjat 'cd /var/www/permedjat/backend/database/migrations && \
#     DB_PORT=3306 DB_USER=permedjat DB_PASS=... ./migrate.sh --status'

set -euo pipefail

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-8889}"
DB_NAME="${DB_NAME:-permedjat}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-root}"
MYSQL_BIN="${MYSQL_BIN:-/Applications/MAMP/Library/bin/mysql80/bin/mysql}"
[ -x "$MYSQL_BIN" ] || MYSQL_BIN="$(command -v mysql)"

DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="apply"
case "${1:-}" in
  --status)    MODE="status" ;;
  --dry-run)   MODE="dry" ;;
  --bootstrap) MODE="bootstrap" ;;
  "")          ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

mysql_run() { "$MYSQL_BIN" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" ${DB_PASS:+-p"$DB_PASS"} "$DB_NAME" "$@" 2>&1 | grep -v 'Using a password' || true; }
mysql_val() { "$MYSQL_BIN" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" ${DB_PASS:+-p"$DB_PASS"} "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

echo "Database: ${DB_NAME}@${DB_HOST}:${DB_PORT} (user ${DB_USER})"

if ! mysql_val "SELECT 1" >/dev/null 2>&1; then
  echo "✗ cannot connect" >&2; exit 1
fi

# --- the ledger -------------------------------------------------------------
mysql_run -e "CREATE TABLE IF NOT EXISTS \`schema_migrations\` (
  \`filename\`   VARCHAR(191) NOT NULL,
  \`checksum\`   CHAR(64)     NOT NULL,
  \`applied_at\` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  \`applied_by\` VARCHAR(64)  NULL,
  PRIMARY KEY (\`filename\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;" >/dev/null

TABLE_COUNT="$(mysql_val "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}'")"

if [ "$MODE" = "bootstrap" ]; then
  # 1 = the ledger we just created; anything more means this is a live database.
  if [ "${TABLE_COUNT:-0}" -gt 1 ]; then
    echo "✗ refusing --bootstrap: ${DB_NAME} already has ${TABLE_COUNT} tables."
    echo "  schema.sql is for an empty database. To rebuild local from production:"
    echo "  ssh permedjat 'mysqldump ... permedjat' | mysql ... permedjat"
    exit 1
  fi
  echo "→ loading schema.sql into empty database"
  mysql_run < "$DIR/schema.sql"
  BOOTSTRAPPED=1
fi

sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" | awk '{print $1}'; }

# schema.sql is a dump of the CURRENT production schema, not an early snapshot
# that the migrations then evolve. So a freshly bootstrapped database is already
# at the latest state and every migration must be recorded as applied without
# being run — replaying them would re-create tables that later migrations
# dropped, and re-run the destructive drops (one of which removes `candidates`,
# still queried by AuditLogModel).
if [ "${BOOTSTRAPPED:-0}" = "1" ]; then
  echo "→ recording all migrations as baseline (schema.sql already includes them)"
  n=0
  while IFS= read -r path; do
    f="$(basename "$path")"
    case "$f" in schema.sql|schema.sql.bak) continue ;; esac
    mysql_run -e "INSERT IGNORE INTO schema_migrations (filename, checksum, applied_by)
                  VALUES ('$f', '$(sha "$path")', 'bootstrap')" >/dev/null
    n=$((n+1))
  done < <(find "$DIR" -maxdepth 1 -name '*.sql' | sort)
  echo "  ✓ ${n} migrations baselined"
fi

# --- work out what is pending ----------------------------------------------
APPLIED_LIST="$(mysql_val "SELECT filename FROM schema_migrations")"
pending=(); applied=0; changed=()

while IFS= read -r path; do
  f="$(basename "$path")"
  case "$f" in schema.sql|schema.sql.bak) continue ;; esac
  if grep -Fxq "$f" <<<"$APPLIED_LIST"; then
    applied=$((applied+1))
    rec="$(mysql_val "SELECT checksum FROM schema_migrations WHERE filename='$f'")"
    [ "$rec" = "$(sha "$path")" ] || changed+=("$f")
  else
    pending+=("$f")
  fi
done < <(find "$DIR" -maxdepth 1 -name '*.sql' | sort)

echo "Applied: ${applied}   Pending: ${#pending[@]}"

if [ ${#changed[@]} -gt 0 ]; then
  echo
  echo "⚠  these files changed AFTER they were applied — the database does not"
  echo "   reflect their current contents. Write a NEW migration instead of"
  echo "   editing an applied one:"
  printf '     %s\n' "${changed[@]}"
fi

if [ ${#pending[@]} -eq 0 ]; then
  echo "✓ nothing to do — database is up to date"
  exit 0
fi

echo
echo "Pending migrations:"
printf '  • %s\n' "${pending[@]}"

if [ "$MODE" = "status" ] || [ "$MODE" = "dry" ]; then
  echo
  echo "(no changes made)"
  exit 0
fi

# --- apply ------------------------------------------------------------------
echo
for f in "${pending[@]}"; do
  echo "→ $f"
  # DDL does not roll back in MySQL, so stop at the first failure rather than
  # ploughing on and leaving the schema half-migrated.
  err="$("$MYSQL_BIN" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" ${DB_PASS:+-p"$DB_PASS"} "$DB_NAME" < "$DIR/$f" 2>&1 | grep -v 'Using a password' || true)"
  if [ -n "$err" ]; then
    echo "  ✗ FAILED: $err" >&2
    echo "  stopped. Fix this migration, then re-run — the ones before it are recorded." >&2
    exit 1
  fi
  mysql_run -e "INSERT INTO schema_migrations (filename, checksum, applied_by)
                VALUES ('$f', '$(sha "$DIR/$f")', '$(whoami)@$(hostname -s)')" >/dev/null
  echo "  ✓ applied"
done

echo
echo "✓ done — $(mysql_val "SELECT COUNT(*) FROM schema_migrations") migrations recorded"
