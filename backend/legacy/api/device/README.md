# Attendance terminals (ZKTeco ADMS / push)

`iclock.php` is the endpoint fingerprint and face terminals talk to. It is the
only entry point in this codebase that is not opened by a signed-in human, so
it deserves its own notes.

## How the connection works

The device dials **out**. Nothing here ever connects to the device, which is
what makes the whole thing work behind a customer's router with no port
forwarding, no static IP, and no VPN:

```
terminal ──▶ GET  /iclock/cdata?SN=..&options=all   handshake, we reply config
terminal ──▶ POST /iclock/cdata?SN=..&table=ATTLOG  punches      → "OK: n"
terminal ──▶ POST /iclock/cdata?SN=..&table=OPERLOG user list    → "OK"
terminal ──▶ GET  /iclock/getrequest?SN=..          command poll → "OK" or "C:1:.."
terminal ──▶ POST /iclock/devicecmd?SN=..           command result
```

Every response is plain text with HTTP 200. **A device that receives anything
else re-sends the same batch forever and records nothing new**, so the endpoint
swallows its own errors on purpose.

## Authentication

The firmware has nowhere to put a token, so the serial number is the identity.
That is safe because of what an unknown serial can actually do: create an
`unclaimed` row and be told `OK`. It cannot reach any company's data until
someone with `manage_company_settings` types that serial into permedjat_central,
and a serial already claimed by another company is refused.

`config/bootstrap.php` skips the app-secret Basic gate for this file only, via
the `PERMEDJAT_DEVICE_ENDPOINT` constant defined at the top of `iclock.php`.

## Server setup (once)

The device connects over **plain HTTP on a dedicated port**, direct to the
origin — not through Cloudflare. Two reasons:

1. Older ZK firmware has weak or no TLS and does not send SNI, so it cannot
   complete a Cloudflare handshake.
2. The firewall only accepts 80/443 from Cloudflare ranges, so a device hitting
   the origin on those ports is dropped.

Point the device at the **IP address**, not a hostname: no DNS record is
created, so this does not publish the origin behind Cloudflare.

### 1. nginx

Add `/etc/nginx/sites-available/permedjat-devices` (see `nginx-devices.conf` next
to this file), then:

```bash
ln -s /etc/nginx/sites-available/permedjat-devices /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### 2. Firewall

```bash
ufw allow 8090/tcp comment 'attendance terminals'
```

If the customer's site has a static public IP, restrict it instead — the
endpoint is small, but a port open to the whole internet is still a port:

```bash
ufw allow from <customer-ip> to any port 8090 proto tcp
```

### 3. Device menu (ZKTeco)

`Menu → Comm → Cloud Server Setting` (older firmware: `Comm → Ethernet →
ADMS`):

| Field | Value |
|---|---|
| Server Mode / Enable Domain Name | OFF (use IP) |
| Server Address | `178.104.90.133` |
| Server Port | `8090` |
| Enable Proxy Server | OFF |

Then `Menu → System → Date/Time` — check the clock and timezone. The device's
wall clock is what lands in the attendance table.

### 4. Verify

```bash
# From anywhere:
curl "http://178.104.90.133:8090/iclock/cdata?SN=TEST123&options=all"
# Expect: GET OPTION FROM: TEST123 ...
```

Then in permedjat_central the device shows as **seen but unclaimed** until its
serial is registered.

## Bringing up an unfamiliar model

Firmware differs in small undocumented ways. Turn on `debug_logging` for the
device (device settings in the app, or
`UPDATE attendance_devices SET debug_logging = 1 WHERE serial_number = '..'`)
and every request and response is captured verbatim in `device_protocol_logs`:

```sql
SELECT created_at, method, path, query_string, LEFT(body, 400), response
FROM device_protocol_logs ORDER BY id DESC LIMIT 20;
```

Turn it back off when done — it is pruned after 48 hours, but it stores whole
request bodies.

## Things that are deliberate

- **Punches are stored before they are judged.** The terminal deletes its local
  copy once we answer OK, so `device_punches` is the only surviving record. A
  punch that cannot be used yet gets a `state`, never a discard.
- **`auto` direction, not the device's status byte.** Staff do not press F1/F2,
  so the status byte reads "check-in" all day. First tap of the day is the
  check-in, the last is the check-out, and a tap within 16 hours of an open
  check-in closes that shift instead of starting a new day (night shifts).
- **Times are company local, read from MySQL.** PHP runs in UTC on this server
  and MySQL runs on local time; anything comparing a device timestamp against
  "now" in PHP would be hours wrong. `DevicePunchIngestor::now()` is the only
  approved source of "now" on this path.
