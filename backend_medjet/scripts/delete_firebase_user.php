<?php
// One-off: delete a Firebase Auth user by UID (and email fallback).
// Usage: php delete_firebase_user.php <uid> [email]
require_once __DIR__ . '/../config/firebase.php';

$uid   = $argv[1] ?? 'Gx65JxpNCTU06MVZiixOjj9D4t63';
$email = $argv[2] ?? 'nimss.dev@gmail.com';

$auth = FirebaseInit::getAuth();
if ($auth === null) {
    fwrite(STDERR, "Firebase auth unavailable (credentials missing)\n");
    exit(1);
}

// Resolve UID by email if needed
try {
    $user = $auth->getUser($uid);
    echo "Found by UID: {$user->uid} ({$user->email})\n";
} catch (\Throwable $e) {
    echo "UID lookup failed ({$e->getMessage()}); trying email...\n";
    try {
        $user = $auth->getUserByEmail($email);
        $uid = $user->uid;
        echo "Found by email: {$user->uid} ({$user->email})\n";
    } catch (\Throwable $e2) {
        echo "User not found in Firebase (already deleted?): {$e2->getMessage()}\n";
        exit(0);
    }
}

try {
    $auth->deleteUser($uid);
    echo "DELETED Firebase user: {$uid}\n";
} catch (\Throwable $e) {
    fwrite(STDERR, "Delete failed: {$e->getMessage()}\n");
    exit(1);
}
