#!/bin/bash
#
# Pings healthchecks.io only when the alerting pipeline is actually able to
# deliver: Alertmanager answering, and the sender that talks to WhatsApp and
# Telegram answering.
#
# This closes the one blind spot the rest of the system cannot cover. If
# medjat-alerts.service dies, every Prometheus alert is written to a socket
# nobody is listening on — the server stays healthy, healthchecks keeps getting
# its liveness beacon, and the first sign of trouble is a real outage that never
# reaches your phone. The classic "who watches the watcher" hole, and the only
# honest answer is: something outside the machine, told by us that we are able
# to speak.
#
# Deliberately does NOT send a message to test the channels themselves. That
# would either spam every 15 minutes or need state to suppress; the daily 09:00
# pulse already proves the channels end to end once a day.

set -uo pipefail

PING="https://hc-ping.com/49ee08aa-10a9-4902-8b34-61df6ec06962"

fail() {
    curl -fsS -m 10 --retry 2 "${PING}/fail" --data-raw "$1" >/dev/null 2>&1 || true
    echo "$1" >&2
    exit 1
}

curl -fsS -m 5 http://127.0.0.1:9093/-/healthy >/dev/null 2>&1 \
    || fail "alertmanager not answering on 9093"

curl -fsS -m 5 http://127.0.0.1:9099/ >/dev/null 2>&1 \
    || fail "medjat-alerts sender not answering on 9099"

curl -fsS -m 10 --retry 2 "$PING" >/dev/null 2>&1
