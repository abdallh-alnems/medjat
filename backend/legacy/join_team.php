<?php
// Landing page for team-invitation links: https://<domain>/.../join_team.php?code=XXXX
//
// Email clients only allow http(s) links, so the invitation email points here.
// This page then bridges into the Permedjat management app via its custom scheme
// (permedjatcentral://join?code=...). If the app is installed it opens straight to
// the join screen; otherwise the visitor gets web/store fallbacks. Standalone
// (no bootstrap / no auth) — it only reads the code from the URL.

$code = isset($_GET['code']) ? trim((string) $_GET['code']) : '';
// Invitation codes are 8 hex chars, but stay tolerant.
$valid = $code !== '' && preg_match('/^[A-Za-z0-9]{4,32}$/', $code) === 1;

$appUrl = $valid ? 'permedjatcentral://join?code=' . rawurlencode($code) : '';

$webBase = rtrim((string) (getenv('CENTRAL_WEB_URL') ?: ''), '/');
$webUrl  = ($valid && $webBase !== '')
    ? $webBase . '/onboarding?code=' . rawurlencode($code)
    : '';

// TODO: replace with the real store listing URLs once published.
$playStoreUrl = 'https://play.google.com/store/apps/details?id=com.khawarizmie.permedjat_central';
$appStoreUrl  = 'https://apps.apple.com/app/permedjat/idREPLACE_WITH_APPSTORE_ID';

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>الانضمام إلى الفريق على Permedjat</title>
  <style>
    body{font-family:'IBM Plex Sans Arabic',Tahoma,Arial,sans-serif;background:#f9f9f9;margin:0;padding:24px;color:#1a1a1a}
    .card{max-width:480px;margin:40px auto;background:#fff;border-radius:14px;padding:32px;box-shadow:0 2px 12px rgba(0,0,0,.06);text-align:center}
    h1{font-size:20px;margin:0 0 12px}
    p{color:#444;font-size:15px;line-height:1.7;margin:0 0 16px}
    .code{display:inline-block;border:2px solid #2E7D6B;border-radius:8px;padding:12px 24px;font-size:26px;font-weight:700;letter-spacing:5px;color:#2E7D6B;margin:8px 0 20px}
    .btn{display:block;background:#2E7D6B;color:#fff;text-decoration:none;padding:14px 20px;border-radius:10px;font-weight:600;font-size:16px;margin:10px 0}
    .btn.alt{background:#fff;color:#2E7D6B;border:1.5px solid #2E7D6B}
    .stores{margin-top:18px;display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
    .stores a{flex:1;min-width:140px;background:#f1f1f1;color:#333;text-decoration:none;padding:10px;border-radius:8px;font-size:13px}
    .muted{color:#888;font-size:13px;margin-top:18px}
  </style>
</head>
<body>
  <main class="card">
    <h1>دعوة للانضمام إلى الفريق</h1>
    <?php if ($valid): ?>
      <p>اضغط الزر أدناه لفتح تطبيق Permedjat للإدارة والانضمام إلى الشركة. إن لم يفتح التطبيق تلقائيًا، استخدم رمز الدعوة:</p>
      <div class="code"><?= htmlspecialchars($code, ENT_QUOTES) ?></div>
      <a class="btn" id="openApp" href="<?= htmlspecialchars($appUrl, ENT_QUOTES) ?>">فتح التطبيق والانضمام</a>
      <?php if ($webUrl !== ''): ?>
        <a class="btn alt" href="<?= htmlspecialchars($webUrl, ENT_QUOTES) ?>">فتح من المتصفح</a>
      <?php endif; ?>
      <div class="stores">
        <a href="<?= htmlspecialchars($playStoreUrl, ENT_QUOTES) ?>">تحميل من Google Play</a>
        <a href="<?= htmlspecialchars($appStoreUrl, ENT_QUOTES) ?>">تحميل من App Store</a>
      </div>
      <p class="muted">إن لم يكن لديك حساب بعد، ثبّت التطبيق وأنشئ حسابًا بنفس بريدك الإلكتروني، وستظهر لك الدعوة تلقائيًا.</p>
      <script>
        // Try to hand off to the app immediately (works on most mobile browsers).
        (function () {
          var url = <?= json_encode($appUrl) ?>;
          if (url) { setTimeout(function () { window.location.href = url; }, 300); }
        })();
      </script>
    <?php else: ?>
      <p>رابط الدعوة غير صالح أو منتهي. اطلب دعوة جديدة من إدارة الشركة.</p>
      <div class="stores">
        <a href="<?= htmlspecialchars($playStoreUrl, ENT_QUOTES) ?>">تحميل من Google Play</a>
        <a href="<?= htmlspecialchars($appStoreUrl, ENT_QUOTES) ?>">تحميل من App Store</a>
      </div>
    <?php endif; ?>
  </main>
</body>
</html>
