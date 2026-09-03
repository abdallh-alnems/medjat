#!/usr/bin/env bash
#
# Writes two facts node_exporter cannot know by itself into the textfile
# collector, every five minutes:
#
#   permedjat_backup_age_seconds   how old the newest database dump is
#   permedjat_nginx_5xx_last5m     server errors in the API access log
#
# Both exist because "the site answers 200" is not the same as "the product
# works". A backup that quietly stopped and an endpoint failing for one company
# are invisible to every uptime check, and are exactly the failures discovered
# far too late.
#
# Written atomically (write to .tmp, then mv) because node_exporter may read the
# file mid-write and would otherwise parse half a line and drop the whole file.

set -euo pipefail

OUT_DIR="/var/lib/prometheus/node-exporter"
OUT="$OUT_DIR/permedjat.prom"
TMP="$OUT.$$.tmp"
BACKUP_DIR="/var/backups/permedjat"
ACCESS_LOG="/var/log/nginx/access.log"

mkdir -p "$OUT_DIR"

{
  echo "# HELP permedjat_backup_age_seconds Age of the newest database backup."
  echo "# TYPE permedjat_backup_age_seconds gauge"
  newest=$(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1 || true)
  if [ -n "$newest" ]; then
    echo "permedjat_backup_age_seconds $(( $(date +%s) - $(stat -c %Y "$newest") ))"
  else
    # No backup at all is worse than an old one, so report an age that trips
    # every threshold rather than reporting nothing and looking healthy.
    echo "permedjat_backup_age_seconds 999999"
  fi

  echo "# HELP permedjat_nginx_5xx_last5m Server errors in the last five minutes."
  echo "# TYPE permedjat_nginx_5xx_last5m gauge"
  if [ -r "$ACCESS_LOG" ]; then
    # Combined log format puts the status code in field 9:
    #   ip - - [25/Aug/2026:00:46:48 +0300] "GET /x HTTP/2.0" 500 1234 ...
    # Only the tail is scanned: at this traffic level five minutes never exceeds
    # a few thousand lines, and scanning the whole file every five minutes would
    # grow into real CPU as the log does.
    cutoff=$(date -d '5 minutes ago' '+%d/%b/%Y:%H:%M:%S')
    count=$(tail -n 5000 "$ACCESS_LOG" 2>/dev/null | awk -v cutoff="$cutoff" '
      {
        # Field 4 is "[25/Aug/2026:00:46:48" — strip the bracket.
        ts = substr($4, 2)
        if (ts >= cutoff && $9 ~ /^5[0-9][0-9]$/) n++
      }
      END { print n + 0 }
    ')
    echo "permedjat_nginx_5xx_last5m ${count}"
  else
    echo "permedjat_nginx_5xx_last5m 0"
  fi
} > "$TMP"

chmod 644 "$TMP"
mv "$TMP" "$OUT"
