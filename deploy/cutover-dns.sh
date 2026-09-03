#!/usr/bin/env bash
#
# Creates the permedjat.com DNS records in Cloudflare, mirroring the shape of
# the medjatapp.com zone. Additive only: it never touches the old zone, and it
# skips any record that already exists, so re-running it is a no-op.
#
#   CF_API_TOKEN=<token> ./cutover-dns.sh --dry-run
#   CF_API_TOKEN=<token> ./cutover-dns.sh
#
# The token needs Zone:Read + DNS:Edit **on the permedjat.com zone**. The token
# currently in use is scoped to medjatapp.com alone and cannot see this zone.
#
# What this script deliberately does NOT create, because the value is issued by
# a provider per-domain and cannot be guessed — see the tail of this file:
#   the DKIM CNAMEs, the firebase= verification TXT, and the ftp A record.

set -euo pipefail

DOMAIN="permedjat.com"
ORIGIN="178.104.90.133"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

: "${CF_API_TOKEN:?set CF_API_TOKEN to a token that can edit the $DOMAIN zone}"

api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "https://api.cloudflare.com/client/v4$path" \
      -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" --data "$body"
  else
    curl -sS -X "$method" "https://api.cloudflare.com/client/v4$path" \
      -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json"
  fi
}

jget() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }

echo "→ locating the $DOMAIN zone"
ZONE=$(api GET "/zones?name=$DOMAIN" | jget "d['result'][0]['id'] if d.get('result') else ''")
if [ -z "$ZONE" ]; then
  echo "   the token cannot see a zone called $DOMAIN." >&2
  echo "   Either the domain is not in this Cloudflare account, or the token is" >&2
  echo "   scoped to a different zone. See the note at the bottom of this file." >&2
  exit 2
fi
echo "   zone $ZONE"

existing=$(api GET "/zones/$ZONE/dns_records?per_page=200" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(' '.join(r['type']+'|'+r['name'] for r in d.get('result',[])))")

add() { # add <type> <name> <content> <proxied> [priority]
  local type="$1" name="$2" content="$3" proxied="$4" prio="${5:-}"
  local fqdn="$name"; [ "$name" = "@" ] && fqdn="$DOMAIN"
  case " $existing " in
    *" $type|$fqdn "*) printf '   = %-6s %-28s already present\n' "$type" "$fqdn"; return 0 ;;
  esac
  local body="{\"type\":\"$type\",\"name\":\"$fqdn\",\"content\":\"$content\",\"ttl\":1,\"proxied\":$proxied"
  [ -n "$prio" ] && body="$body,\"priority\":$prio"
  body="$body}"
  if [ "$DRY" = 1 ]; then printf '   + %-6s %-28s %s\n' "$type" "$fqdn" "$content"; return 0; fi
  local out; out=$(api POST "/zones/$ZONE/dns_records" "$body")
  if [ "$(printf '%s' "$out" | jget "d['success']")" = "True" ]; then
    printf '   + %-6s %-28s %s\n' "$type" "$fqdn" "$content"
  else
    printf '   ! %-6s %-28s %s\n' "$type" "$fqdn" "$(printf '%s' "$out" | jget "[e['message'] for e in d.get('errors',[])]")" >&2
  fi
}

echo "→ web records (proxied — these are what Cloudflare fronts)"
add A     "@"               "$ORIGIN"   true
add A     "api.$DOMAIN"     "$ORIGIN"   true
add A     "app.$DOMAIN"     "$ORIGIN"   true
add A     "grafana.$DOMAIN" "$ORIGIN"   true
add A     "db.$DOMAIN"      "$ORIGIN"   true
add CNAME "www.$DOMAIN"     "$DOMAIN"   true

echo "→ mail records (DNS-only — proxying these breaks mail)"
add MX  "@" "mx1.hostinger.com" false 5
add MX  "@" "mx2.hostinger.com" false 10
add TXT "@" "v=spf1 include:_spf.mail.hostinger.com include:_spf.firebasemail.com ~all" false
add TXT "_dmarc.$DOMAIN" "v=DMARC1; p=quarantine" false

echo "→ autoconfig (matches the old zone; harmless if the mailbox is elsewhere)"
add CNAME "autoconfig.$DOMAIN"   "autoconfig.mail.hostinger.com"   false
add CNAME "autodiscover.$DOMAIN" "autodiscover.mail.hostinger.com" false

cat <<'NOTE'

Not created here, because each value is minted by a provider for one specific
domain and cannot be copied from medjatapp.com:

  hostingermail-{a,b,c}._domainkey   DKIM. Add permedjat.com to the Hostinger
                                     mail account first; it then shows the three
                                     CNAME targets to paste in.
  firebase1._domainkey               DKIM for Firebase's transactional mail.
  firebase2._domainkey               Firebase console → Authentication →
                                     Templates → customise domain. It issues
                                     mail-permedjat-com.dkim1... targets.
  TXT  firebase=<project>            Domain verification, issued when the domain
                                     is added to the (new) Firebase project.
  A    ftp                           Pointed at the old Hostinger box. Dead
                                     weight; do not recreate it.

Until SPF, DKIM and DMARC all pass on permedjat.com, mail sent as
noreply@permedjat.com is unauthenticated and will be filed as spam. Verify with
a test to a Gmail address and read the Authentication-Results header before
pointing the application at the new sender.
NOTE
