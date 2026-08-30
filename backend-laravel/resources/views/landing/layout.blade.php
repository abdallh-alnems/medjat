{{--
    The shared shell for the deep-link landing pages.

    These are the only HTML this backend serves, and they are seen by exactly
    one kind of visitor: somebody who opened an app link where the app could not
    handle it — a desktop browser, or a phone without the app installed. On a
    phone that has it, App Links and Universal Links open the app directly and
    none of this ever renders.

    Self-contained on purpose. A stylesheet would be a second request that has
    to succeed for a page whose whole job is to work on a stranger's device.
--}}
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex">
    <title>{{ $title }}</title>
    <style>
        body{font-family:'IBM Plex Sans Arabic',Tahoma,Arial,sans-serif;background:#f4f6f8;margin:0;padding:24px;color:#1a1a1a}
        .card{max-width:480px;margin:40px auto;background:#fff;border-radius:14px;padding:32px;box-shadow:0 2px 12px rgba(0,0,0,.06);text-align:center}
        h1{font-size:20px;margin:0 0 12px}
        p{color:#444;font-size:15px;line-height:1.7;margin:0 0 16px}
        .code{display:inline-block;border:2px solid #0E7C86;border-radius:8px;padding:12px 24px;font-size:26px;font-weight:700;letter-spacing:5px;color:#0E7C86;margin:8px 0 20px}
        .btn{display:block;background:#0E7C86;color:#fff;text-decoration:none;padding:14px 20px;border-radius:10px;font-weight:600;font-size:16px;margin:10px 0}
        .btn.alt{background:#fff;color:#0E7C86;border:1.5px solid #0E7C86}
        .stores{margin-top:18px;display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
        .stores a{flex:1;min-width:140px;background:#f1f1f1;color:#333;text-decoration:none;padding:10px;border-radius:8px;font-size:13px}
        .muted{color:#888;font-size:13px;margin-top:18px}
    </style>
</head>
<body>
<main class="card">
    <h1>{{ $heading }}</h1>
    @yield('body')
</main>
</body>
</html>
