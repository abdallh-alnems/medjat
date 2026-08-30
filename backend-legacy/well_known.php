<?php
// Serves the deep-link association files with the correct content type.
// Routed here from .htaccess so the global "*.json Require all denied" rule
// does not block /.well-known/assetlinks.json, and so the extension-less
// apple-app-site-association is returned as application/json.

$map = [
    'assetlinks' => '.well-known/assetlinks.json',
    'aasa'       => '.well-known/apple-app-site-association',
];

$key = $_GET['f'] ?? '';
$path = isset($map[$key]) ? __DIR__ . '/' . $map[$key] : null;

if ($path === null || !is_file($path)) {
    http_response_code(404);
    exit;
}

header('Content-Type: application/json');
header('Cache-Control: public, max-age=3600');
readfile($path);
