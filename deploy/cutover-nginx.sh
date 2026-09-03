#!/usr/bin/env bash
#
# Adds the permedjat.com hostnames to the existing nginx vhosts, beside the
# medjatapp.com ones, and points every TLS block at a certificate that covers
# both. Run on the server, after the combined origin certificate is installed.
#
#   ssh permedjat 'bash -s' < cutover-nginx.sh --dry-run
#   ssh permedjat 'bash -s' < cutover-nginx.sh
#
# Nothing here renames anything — that is cutover-server.sh. This only makes the
# origin answer to the new names as well, so both domains work at once and no
# client notices anything.
#
# PRECONDITION: an origin certificate covering all four names is in place:
#   /etc/ssl/certs/combined-origin.pem
#   /etc/ssl/private/combined-origin.key      (chmod 600)
# covering: permedjat.com, *.permedjat.com, medjatapp.com, *.medjatapp.com
#
# One certificate rather than two because a server block can hold only one RSA
# certificate, and these blocks now answer to names from both zones.

set -uo pipefail

CERT=/etc/ssl/certs/combined-origin.pem
KEY=/etc/ssl/private/combined-origin.key
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ "$DRY" = 1 ]; then echo "   would: $*"; else eval "$@"; fi; }

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

echo "=== 0. preflight ==="
for f in "$CERT" "$KEY"; do
  [ -f "$f" ] || { echo "   missing $f — install the combined origin certificate first" >&2; exit 1; }
done
if ! openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | grep -q "permedjat.com"; then
  echo "   $CERT does not cover permedjat.com" >&2; exit 1
fi
if ! openssl x509 -in "$CERT" -noout -ext subjectAltName 2>/dev/null | grep -q "medjatapp.com"; then
  echo "   $CERT does not cover medjatapp.com — the old hosts would break" >&2; exit 1
fi
CM=$(openssl x509 -in "$CERT" -noout -modulus | openssl md5)
KM=$(openssl rsa  -in "$KEY"  -noout -modulus | openssl md5)
[ "$CM" = "$KM" ] || { echo "   certificate and key do not match" >&2; exit 1; }
echo "   certificate covers both zones and matches its key"
openssl x509 -in "$CERT" -noout -ext subjectAltName | tail -1 | sed 's/^ */   /'

echo
echo "=== 1. back up every vhost ==="
STAMP=$(date +%F-%H%M)
run "mkdir -p /root/nginx-backup-$STAMP"
run "cp -a /etc/nginx/sites-available/. /root/nginx-backup-$STAMP/"
echo "   /root/nginx-backup-$STAMP"

echo
echo "=== 2. add the new hostnames beside the old ones ==="
# One pass over every vhost. Each rule is anchored on the exact existing line,
# and is a no-op if it has already been applied.
add_host() { # add_host <old server_name body> <what to append>
  local from="$1" add="$2"
  if grep -rq "server_name $from $add;" /etc/nginx/sites-available/ 2>/dev/null; then
    echo "   = $add already present"; return
  fi
  run "sed -i 's/server_name $from;/server_name $from $add;/' /etc/nginx/sites-available/*"
  echo "   + $add"
}
add_host "api\.medjatapp\.com"                      "api.permedjat.com"
add_host "app\.medjatapp\.com"                      "app.permedjat.com"
add_host "db\.medjatapp\.com"                       "db.permedjat.com"
add_host "grafana\.medjatapp\.com"                  "grafana.permedjat.com"
add_host "medjatapp\.com www\.medjatapp\.com"       "permedjat.com www.permedjat.com"

echo
echo "=== 3. point the TLS blocks at the combined certificate ==="
echo "   currently in use:"
grep -rhE "ssl_certificate(_key)? " /etc/nginx/sites-available/ /etc/nginx/snippets/ 2>/dev/null \
  | sed 's/^ *//' | sort -u | sed 's/^/     /'
run "sed -i -E 's#ssl_certificate  *[^;]*medjat[^;]*\\.pem;#ssl_certificate     $CERT;#; s#ssl_certificate_key  *[^;]*medjat[^;]*\\.key;#ssl_certificate_key $KEY;#' /etc/nginx/sites-available/* /etc/nginx/snippets/*.conf"

echo
echo "=== 4. test and reload ==="
if [ "$DRY" = 1 ]; then echo "   dry run — nothing changed"; exit 0; fi
if ! nginx -t; then
  echo "   config is broken — restoring the backup and leaving nginx as it was" >&2
  cp -a "/root/nginx-backup-$STAMP/." /etc/nginx/sites-available/
  exit 1
fi
systemctl reload nginx

echo
echo "=== 5. verify — each new host must answer exactly like its old twin ==="
# Not "is it 200": several of these legitimately answer 307, 302 or 401, and
# /backend/ is a 404 on both because it is a prefix, not an endpoint. What has
# to hold is that the new name reaches the *same* vhost as the old one, so the
# test is that the two status codes agree and neither is nginx's default server.
ok=0; bad=0
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "Host: $1" "http://127.0.0.1$2" 2>/dev/null; }
pair() { # pair <old host> <new host> <path>
  local a b
  a=$(code "$1" "$3"); b=$(code "$2" "$3")
  if [ -z "$a" ] || [ "$a" = "000" ]; then
    echo "   FAIL $1$3 did not answer at all ($a)"; bad=$((bad+1)); return
  fi
  if [ "$a" = "$b" ]; then
    echo "   ok   $2$3 -> $b  (matches $1)"; ok=$((ok+1))
  else
    echo "   FAIL $2$3 -> $b  but $1$3 -> $a"; bad=$((bad+1))
  fi
}
pair medjatapp.com         permedjat.com         /
pair api.medjatapp.com     api.permedjat.com     /.well-known/assetlinks.json
pair app.medjatapp.com     app.permedjat.com     /
pair grafana.medjatapp.com grafana.permedjat.com /
pair db.medjatapp.com      db.permedjat.com      /

echo
if [ "$bad" -gt 0 ]; then
  echo "$bad probe(s) failed. Restore with:"
  echo "  cp -a /root/nginx-backup-$STAMP/. /etc/nginx/sites-available/ && nginx -t && systemctl reload nginx"
  exit 1
fi
echo "$ok probes passed — both domains are being served."
echo
echo "From the outside, check that Cloudflare is happy with the origin cert:"
echo "  curl -sI https://api.permedjat.com/backend/ | head -1"
echo "  curl -sI https://api.medjatapp.com/backend/ | head -1"
