<?php

require_once __DIR__ . '/../config/bootstrap.php';

echo "Seeding super admin...\n";

$hash = password_hash('password', PASSWORD_BCRYPT);

try {
    Database::execute(
        "INSERT IGNORE INTO super_admins (username, password_hash, display_name, role, is_active) VALUES (?, ?, ?, ?, ?)",
        ['superadmin', $hash, 'Super Admin', 'superadmin', 1]
    );
    echo "Super admin created: username=superadmin password=password\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
