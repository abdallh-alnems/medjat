SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `employee_activation_codes` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `code` VARCHAR(12) NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `used_at` TIMESTAMP NULL DEFAULT NULL,
    `used_by_firebase_uid` VARCHAR(128) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_code` (`code`),
    INDEX `idx_act_employee` (`employee_id`),
    INDEX `idx_act_tenant` (`tenant_id`),
    INDEX `idx_act_expires` (`expires_at`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
