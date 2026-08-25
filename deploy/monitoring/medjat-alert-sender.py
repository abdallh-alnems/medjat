#!/usr/bin/env python3
"""
Receives Alertmanager webhooks and sends them to WhatsApp and Telegram.

Why a local service instead of Alertmanager's own integrations: Alertmanager
speaks Slack, PagerDuty, e-mail and generic webhooks — it does not speak
WhatsApp, and its Telegram support cannot be made to say the same sentence in
Arabic that WhatsApp gets. Putting the formatting here keeps the message
identical on both channels and makes adding or dropping a channel a change to
one file.

Design rules this follows:
  * Never crash the receiver. If a channel fails, log it and carry on with the
    other. Alertmanager retries the webhook; a 500 loop would repeat the
    messages that *did* work.
  * Never put a secret in an alert body — CallMeBot relays through a third
    party, so the text says "MySQL is down", never a credential.
  * Send in Arabic. The person reading it at 3am should not be translating.

Config lives in /etc/medjat-alerts.env (mode 600):
    TELEGRAM_TOKEN=...
    TELEGRAM_CHAT_ID=...
    WHATSAPP_PHONE=+201023809407
    WHATSAPP_APIKEY=...
    HEARTBEAT_HOUR=9                  # Cairo hour the daily pulse is sent at
    HEARTBEAT_WHATSAPP_DAY=daily      # 'daily', 'off', or 0=Mon .. 6=Sun
Any missing value simply disables that channel, so the service runs from the
moment it is installed and starts sending as soon as a key is filled in.

Usage:
    medjat-alert-sender.py                 run the webhook receiver (systemd)
    medjat-alert-sender.py --test          send a test message to every channel
"""

import json
import logging
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer

CONFIG_PATH = "/etc/medjat-alerts.env"
# systemd StateDirectory=medjat-alerts creates and owns this.
STATE_PATH = "/var/lib/medjat-alerts/heartbeat.date"
LISTEN = ("127.0.0.1", 9099)
CAIRO = timezone(timedelta(hours=3))  # Africa/Cairo, DST-free since 2023 rules
TIMEOUT = 15

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("medjat-alerts")


def load_config() -> dict:
    """Read the env file on every send, so a new key takes effect without a restart."""
    cfg = {}
    try:
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                cfg[key.strip()] = value.strip().strip('"').strip("'")
    except FileNotFoundError:
        log.warning("%s not found — no channel is configured yet", CONFIG_PATH)
    return cfg


def send_telegram(cfg: dict, text: str) -> bool:
    token = cfg.get("TELEGRAM_TOKEN")
    chat_id = cfg.get("TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        return False

    payload = urllib.parse.urlencode(
        {"chat_id": chat_id, "text": text, "disable_web_page_preview": "true"}
    ).encode()
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    try:
        with urllib.request.urlopen(url, data=payload, timeout=TIMEOUT) as resp:
            ok = resp.status == 200
            log.info("telegram: %s", "sent" if ok else f"http {resp.status}")
            return ok
    except Exception as exc:  # noqa: BLE001 - a channel failure must not stop the other
        log.error("telegram failed: %s", exc)
        return False


def send_whatsapp(cfg: dict, text: str) -> bool:
    phone = cfg.get("WHATSAPP_PHONE")
    apikey = cfg.get("WHATSAPP_APIKEY")
    if not phone or not apikey:
        return False

    # CallMeBot is rate-limited and occasionally slow; one retry covers the
    # common transient failure without turning an outage into a message storm.
    url = "https://api.callmebot.com/whatsapp.php?" + urllib.parse.urlencode(
        {"phone": phone, "text": text, "apikey": apikey}
    )
    for attempt in (1, 2):
        try:
            with urllib.request.urlopen(url, timeout=TIMEOUT) as resp:
                body = resp.read(200).decode("utf-8", "replace")
                ok = resp.status == 200 and "error" not in body.lower()
                log.info("whatsapp: %s", "sent" if ok else f"http {resp.status} {body[:80]}")
                if ok:
                    return True
        except Exception as exc:  # noqa: BLE001
            log.error("whatsapp attempt %d failed: %s", attempt, exc)
        time.sleep(3)
    return False


def now_cairo() -> str:
    return datetime.now(CAIRO).strftime("%Y-%m-%d %H:%M")


def format_alerts(payload: dict) -> tuple[str, str]:
    """Return (severity, message). Arabic, short, and specific about the impact."""
    alerts = payload.get("alerts", [])
    if not alerts:
        return "warning", "إنذار بلا تفاصيل"

    first = alerts[0]
    labels = first.get("labels", {})
    annotations = first.get("annotations", {})
    severity = labels.get("severity", "warning")
    status = payload.get("status", "firing")

    if severity == "heartbeat":
        return "heartbeat", f"💚 مِدجات — كل شيء يعمل\n🕐 {now_cairo()}"

    if status == "resolved":
        head = "✅ عاد للعمل"
    elif severity == "critical":
        head = "🔴 عطل حرج"
    else:
        head = "🟡 تحذير"

    lines = [f"{head}: {annotations.get('summary', labels.get('alertname', 'غير معروف'))}"]

    detail = annotations.get("detail")
    if detail:
        lines.append(detail)

    # Name every affected thing when a group carries more than one, so the
    # message is complete without opening a dashboard.
    if len(alerts) > 1:
        names = {a.get("labels", {}).get("name") or a.get("labels", {}).get("instance", "") for a in alerts}
        names.discard("")
        if names:
            lines.append("المتأثر: " + "، ".join(sorted(names)))

    lines.append(f"🕐 {now_cairo()}")
    return severity, "\n".join(lines)


def heartbeat_due(cfg: dict) -> bool:
    """One pulse per calendar day, at or after the configured Cairo hour.

    Alertmanager pokes this every 15 minutes; the decision of *when* the daily
    message goes out lives here, not there. Two reasons: a repeat_interval is
    measured from the last send, so its hour drifts and resets whenever the
    service restarts — and "at or after" means a server that was down at 09:00
    still sends its pulse when it comes back, instead of skipping the day and
    looking like a failure.
    """
    now = datetime.now(CAIRO)
    try:
        hour = int(cfg.get("HEARTBEAT_HOUR", "9"))
    except ValueError:
        hour = 9

    if now.hour < hour:
        return False

    try:
        with open(STATE_PATH, encoding="utf-8") as fh:
            if fh.read().strip() == now.strftime("%Y-%m-%d"):
                return False  # already sent today
    except FileNotFoundError:
        pass
    return True


def mark_heartbeat_sent() -> None:
    try:
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        with open(STATE_PATH, "w", encoding="utf-8") as fh:
            fh.write(datetime.now(CAIRO).strftime("%Y-%m-%d"))
    except OSError as exc:
        log.error("could not write heartbeat state: %s", exc)


def whatsapp_pulse_due(cfg: dict) -> bool:
    """Whether today's pulse also goes to WhatsApp.

    'daily' while WhatsApp is the only channel — six silent days a week would
    make silence ambiguous, which is the exact thing the pulse exists to fix.
    A weekday number is the setting to move to once Telegram carries the daily
    one, so WhatsApp stays reserved for things that matter and does not train
    the reader to swipe past it.
    """
    raw = (cfg.get("HEARTBEAT_WHATSAPP_DAY") or "daily").strip().lower()
    if raw in ("daily", "*", "all", "everyday"):
        return True
    if raw in ("off", "none", "never", ""):
        return False
    try:
        return datetime.now(CAIRO).weekday() == int(raw)
    except ValueError:
        log.warning("HEARTBEAT_WHATSAPP_DAY=%r not understood — sending daily", raw)
        return True


def dispatch(payload: dict) -> None:
    cfg = load_config()
    severity, message = format_alerts(payload)

    if severity == "heartbeat" and not heartbeat_due(cfg):
        return

    # Telegram gets everything: it is the channel that costs nothing to read.
    send_telegram(cfg, message)

    # WhatsApp is reserved for what actually stops people working, plus one
    # weekly pulse proving the channel itself is still alive. A phone that buzzes
    # for disk-space warnings is a phone that gets muted.
    if severity == "critical":
        send_whatsapp(cfg, message)
    elif severity == "heartbeat":
        if whatsapp_pulse_due(cfg):
            send_whatsapp(cfg, message)
        mark_heartbeat_sent()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 - required name
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"

        # Always answer 200. Alertmanager retries non-2xx, and a retry storm
        # would re-send every message that already went out fine.
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

        try:
            dispatch(json.loads(raw.decode("utf-8")))
        except Exception as exc:  # noqa: BLE001
            log.error("dispatch failed: %s", exc)

    def do_GET(self):  # noqa: N802
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"medjat-alert-sender ok")

    def log_message(self, *args):
        pass  # journald already timestamps; the default access log is noise


def main() -> int:
    if "--test" in sys.argv:
        cfg = load_config()
        msg = (
            "🔔 مِدجات — رسالة اختبار\n"
            "لو وصلتك هذه الرسالة فقناة الإنذار تعمل.\n"
            f"🕐 {now_cairo()}"
        )
        tg = send_telegram(cfg, msg)
        wa = send_whatsapp(cfg, msg)
        print(f"telegram: {'sent' if tg else 'not configured / failed'}")
        print(f"whatsapp: {'sent' if wa else 'not configured / failed'}")
        return 0 if (tg or wa) else 1

    log.info("listening on %s:%d", *LISTEN)
    HTTPServer(LISTEN, Handler).serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
