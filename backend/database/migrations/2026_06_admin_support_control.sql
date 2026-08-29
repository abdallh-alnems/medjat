-- 002-admin-support-control: super_admin_devices table for support-team push
-- FK → super_admins (cascade on delete)

CREATE TABLE IF NOT EXISTS `super_admin_devices` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `admin_id` INT UNSIGNED NOT NULL,
    `fcm_token` VARCHAR(500) NOT NULL,
    `platform` ENUM('android','ios','web') DEFAULT 'android',
    `device_id` VARCHAR(100) NULL,
    `device_model` VARCHAR(100) NULL,
    `app_version` VARCHAR(20) NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY `uq_admin_device` (`admin_id`, `device_id`),
    KEY `idx_token` (`fcm_token`(50)),

    CONSTRAINT `fk_super_admin_devices_admin`
        FOREIGN KEY (`admin_id`) REFERENCES `super_admins`(`id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
