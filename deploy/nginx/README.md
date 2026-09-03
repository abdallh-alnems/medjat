# Server-side nginx / Cloudflare rules that are **not** deployed by `deploy.sh`

`deploy.sh` rsyncs application code only. The nginx vhosts live on the server
(`/etc/nginx/sites-available/permedjat*`, `/etc/nginx/snippets/permedjat-common.conf`)
and are recorded here so a rebuilt server can be brought back to the same state.

## `uploads/` lockdown — 2026-08-15

**What was wrong.** `snippets/permedjat-common.conf` sets `root /var/www/permedjat` and
ends with `location / { try_files $uri $uri/ =404; }`. The deny list covered
`config|core|models|vendor|migrations|seeds|scripts|lang` but **not `uploads`**,
so every stored file was a public static file to anyone holding the URL:

```
GET /backend_medjet/uploads/payslips/1/payslip_2_2026-06_*.pdf → 200, 65997 bytes
```

That is payslips, identity documents, signatures, face captures — and, once web
attendance and the kiosk go live, punch photos and kiosk evidence. Directory
listing was already off (`403`), so it required knowing a filename, but any URL
that leaked stayed public forever. Cloudflare made it worse: the response was
cacheable (`cache-control: max-age=14400`), so a fetched payslip sat on the edge
for four hours independently of the origin.

Nothing legitimate ever fetched these paths — every consumer goes through an
authenticated PHP endpoint (`documents/view.php`, `payroll/get_slip_pdf.php`,
`support/attachment.php`, `employees/my_document_view.php`, `kiosk/capture.php`,
`attendance/punch_photo.php`). `kiosk/capture.php` even carries the comment
"uploads/ is not web-served", which was the assumption this closes.

**Origin fix** — in `/etc/nginx/snippets/permedjat-common.conf`, immediately after
the existing `config|core|models|...` deny line:

```nginx
# Employee evidence — payslips, identity documents, face and punch captures.
# Everything under uploads/ is served only through an authenticated PHP endpoint
# (documents/view.php, payroll/get_slip_pdf.php, attendance/punch_photo.php, ...).
# ^~ also beats the \.php$ block, so an uploaded script is never executed.
location ^~ /backend_medjet/uploads/ { deny all; }
location ^~ /uploads/ { deny all; }
```

Then `nginx -t && systemctl reload nginx`.

**Edge fix** — the origin rule cannot evict what Cloudflare already cached, and
the zone token has no cache-purge scope, so a WAF custom rule blocks the path
before cache instead (zone `permedjat.com`, phase `http_request_firewall_custom`):

```
action:     block
expression: (http.request.uri.path contains "/uploads/")
```

Recreate with:

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE/rulesets/phases/http_request_firewall_custom/entrypoint" \
  -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  --data '{"rules":[{"action":"block","description":"uploads/ is served only through authenticated PHP endpoints","expression":"(http.request.uri.path contains \"/uploads/\")","enabled":true}]}'
```

**Verify** (both layers, from outside):

```bash
curl -sI https://api.permedjat.com/backend_medjet/uploads/payslips/1/<any>.pdf | head -1   # 403
curl -s -o /dev/null -w '%{http_code}\n' https://api.permedjat.com/backend_medjet/app/auth/login.php  # 401, still alive
```

A backup of the pre-change snippet is at `/root/permedjat-common.conf.bak-20260815`.
