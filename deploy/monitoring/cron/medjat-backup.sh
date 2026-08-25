#!/bin/bash
#
# Nightly database dump, 02:00, 14-day retention.
#
# `pipefail` is the important line. Without it `mysqldump | gzip` exits 0 even
# when mysqldump dies half way through, because gzip happily compresses the
# truncated stream and succeeds — and the script would report a healthy backup
# that is actually unrestorable. That was the state of this file until
# 2026-08-25 and nothing would ever have revealed it except a restore attempt.

set -euo pipefail

DIR=/var/backups/medjat
PING="https://hc-ping.com/1d8746f8-385d-4906-a44e-c4446915b06e"

fail() {
    curl -fsS -m 10 --retry 3 "${PING}/fail" --data-raw "$1" >/dev/null 2>&1 || true
    echo "$1" >&2
    exit 1
}
trap 'fail "backup failed at line $LINENO"' ERR

mkdir -p "$DIR"
F="$DIR/medjat-$(date +%Y%m%d-%H%M).sql.gz"

mysqldump --single-transaction --routines --triggers --databases medjat | gzip > "$F"

# Second line of defence behind pipefail: a dump far below the smallest
# plausible size means the stream broke. Cheapest integrity check there is.
SIZE=$(stat -c %s "$F")
[ "$SIZE" -ge 20000 ] || fail "backup suspiciously small: ${SIZE} bytes"

find "$DIR" -name 'medjat-*.sql.gz' -mtime +14 -delete

curl -fsS -m 10 --retry 3 "$PING" --data-raw "ok ${SIZE} bytes" >/dev/null 2>&1
