<?php
// Fallback landing page for employee join links: https://<domain>/join?token=...
//
// When the Permedjat app is installed, Android App Links / iOS Universal Links
// open the app directly and this page is never seen. It only renders when the
// link is opened where the app cannot handle it (desktop browser, or app not
// yet installed) — so it just points the employee to install the app. No
// sensitive data is shown; the token stays in the URL for the app to capture
// after install.

$token = isset($_GET['token']) ? trim((string) $_GET['token']) : '';
$valid = $token !== '' && preg_match('/^[a-f0-9]{16,64}$/i', $token) === 1;

// TODO: replace with the real store listing URLs once published.
$playStoreUrl = 'https://play.google.com/store/apps/details?id=com.khawarizmie.permedjat';
$appStoreUrl  = 'https://apps.apple.com/app/permedjat/idREPLACE_WITH_APPSTORE_ID';

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>الانضمام إلى Permedjat</title>
  <link rel="stylesheet" href="/public/join.css">
</head>
<body>
  <main class="card">
    <h1>تطبيق Permedjat للموظفين</h1>
    <?php if ($valid): ?>
      <p>لإكمال تسجيل الدخول، افتح هذا الرابط من على هاتفك بعد تثبيت التطبيق،
         وسيتم تسجيل دخولك تلقائياً.</p>
    <?php else: ?>
      <p>رابط التفعيل غير صالح أو منتهي. اطلب رابطاً جديداً من إدارة الشركة.</p>
    <?php endif; ?>
    <div class="stores">
      <a class="btn" href="<?= htmlspecialchars($playStoreUrl, ENT_QUOTES) ?>">تحميل من Google Play</a>
      <a class="btn" href="<?= htmlspecialchars($appStoreUrl, ENT_QUOTES) ?>">تحميل من App Store</a>
    </div>
  </main>
</body>
</html>
