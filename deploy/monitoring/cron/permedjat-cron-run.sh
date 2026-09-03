#!/bin/bash
#
# Runs one Permedjat cron endpoint over localhost and reports the *real* outcome
# to healthchecks.io.
#
# Usage: permedjat-cron-run.sh <endpoint.php> <healthchecks-uuid>
#
# Why this exists. The wrappers this replaces called `curl -s` with no `-f`, so
# they exited 0 whatever the server answered — a 500, a PHP fatal, an HTML
# error page. Wiring a success beacon to that would have produced the worst
# possible outcome: a monitor that reports "the job ran fine" every night while
# the job fails, which is more dangerous than no monitor at all because it
# actively reassures you.
#
# So success here means two things together: curl got a 2xx *and* the body says
# the endpoint finished its work. Anything else pings /fail with the response
# attached, which notifies immediately instead of waiting for the grace period.

set -uo pipefail

ENDPOINT="${1:?usage: permedjat-cron-run.sh <endpoint.php> <uuid>}"
UUID="${2:?usage: permedjat-cron-run.sh <endpoint.php> <uuid>}"
PING="https://hc-ping.com/${UUID}"

# The endpoints authenticate on a query parameter and send both key= and
# cron_secret=, which is what the published cron wrappers have always done.
SECRET="24f90498cfabccf4888efa11baad8eb9a60e8ccd6ebbc0f4"
URL="http://127.0.0.1/backend/api/app/cron/${ENDPOINT}?key=${SECRET}&cron_secret=${SECRET}"

resp=$(curl -sS -f --max-time 300 "$URL" -H "Host: api.permedjatapp.com" 2>&1)
rc=$?

echo "$resp"

# 'success' is what catchup_absences and run_alerts return; purge_kiosk_captures
# says 'ok'. Both are accepted rather than normalised, because changing what the
# endpoints return is a deploy and this is a monitoring wrapper.
if [ $rc -eq 0 ] && { [[ "$resp" == *'"status":"success"'* ]] || [[ "$resp" == *'"status":"ok"'* ]]; }; then
    curl -fsS -m 10 --retry 3 "$PING" >/dev/null 2>&1
    exit 0
fi

curl -fsS -m 10 --retry 3 "${PING}/fail" --data-raw "exit=${rc} ${resp:0:500}" >/dev/null 2>&1
exit 1
