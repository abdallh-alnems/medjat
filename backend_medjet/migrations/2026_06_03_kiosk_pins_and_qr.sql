-- Kiosk OTP PINs table
CREATE TABLE IF NOT EXISTS `kiosk_pins` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `station_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED NOT NULL,
    `tenant_id` INT UNSIGNED NOT NULL,
    `pin_hash` VARCHAR(255) NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `used_at` DATETIME DEFAULT NULL,
    `created_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_station_active` (`station_id`, `used_at`, `expires_at`),
    INDEX `idx_tenant` (`tenant_id`),
    INDEX `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Extend recognition_logs method enum to include 'qr'
ALTER TABLE `station_recognition_logs`
    MODIFY COLUMN `verification_method` ENUM('face','fingerprint','both','qr') NOT NULL DEFAULT 'face';

-- Add 'out_of_range' to result enum
ALTER TABLE `station_recognition_logs`
    MODIFY COLUMN `result` ENUM('success','low_confidence','no_match','spoofing_detected','manual_fallback','too_soon','out_of_range') NOT NULL DEFAULT 'success';
