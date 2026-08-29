-- Migration: multi-method attendance + attendance stations
-- MySQL 8.0 compatible (no `ADD COLUMN IF NOT EXISTS`, which is MariaDB-only).
-- Brings an already-created DB up to the schema in schema.sql.

-- ── tenants: multi-method config ──
ALTER TABLE tenants
    ADD COLUMN attendance_methods JSON NULL
        COMMENT 'Enabled methods, e.g. ["qr_gps","manual","station"]' AFTER attendance_method,
    ADD COLUMN manual_attendance_admin_ids JSON NULL
        COMMENT 'NULL = all admins with manage_attendance; array = restricted set' AFTER attendance_methods;

-- backfill from the legacy single-value column
UPDATE tenants
SET attendance_methods = JSON_ARRAY(attendance_method)
WHERE attendance_methods IS NULL;

-- ── branches: per-branch override + station settings ──
ALTER TABLE branches
    ADD COLUMN attendance_methods JSON NULL
        COMMENT 'Branch override; NULL inherits tenants.attendance_methods' AFTER attendance_method,
    ADD COLUMN station_enabled TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN station_methods ENUM('face_only','fingerprint_only','both_available') DEFAULT 'face_only',
    ADD COLUMN station_gps_radius_meters INT DEFAULT 30,
    ADD COLUMN station_confidence_threshold DECIMAL(3,2) DEFAULT 0.85,
    ADD COLUMN station_admin_pin_hash VARCHAR(255) NULL,
    ADD COLUMN station_anti_spoofing_enabled TINYINT(1) NOT NULL DEFAULT 1;

-- ── attendance_stations ──
CREATE TABLE IF NOT EXISTS `attendance_stations` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED NOT NULL,
    `device_token` VARCHAR(255) UNIQUE NOT NULL,
    `device_name` VARCHAR(100) NOT NULL,
    `activation_qr_payload` TEXT DEFAULT NULL,
    `activation_qr_expires_at` TIMESTAMP NULL DEFAULT NULL,
    `is_activated` TINYINT(1) NOT NULL DEFAULT 0,
    `activated_at` TIMESTAMP NULL DEFAULT NULL,
    `last_sync_at` TIMESTAMP NULL DEFAULT NULL,
    `last_heartbeat_at` TIMESTAMP NULL DEFAULT NULL,
    `last_known_lat` DECIMAL(10,7) DEFAULT NULL,
    `last_known_lng` DECIMAL(10,7) DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `is_locked` TINYINT(1) NOT NULL DEFAULT 0,
    `locked_reason` VARCHAR(255) DEFAULT NULL,
    `locked_at` TIMESTAMP NULL DEFAULT NULL,
    `created_by_user_id` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `deactivated_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_station_tenant` (`tenant_id`),
    INDEX `idx_station_branch` (`branch_id`),
    INDEX `idx_station_token` (`device_token`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`created_by_user_id`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── station_recognition_logs ──
CREATE TABLE IF NOT EXISTS `station_recognition_logs` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED NOT NULL,
    `station_id` INT UNSIGNED NOT NULL,
    `matched_employee_id` INT UNSIGNED DEFAULT NULL,
    `verification_method` ENUM('face','fingerprint','both') NOT NULL,
    `confidence_score` DECIMAL(4,3) DEFAULT NULL,
    `result` ENUM('success','low_confidence','no_match','spoofing_detected','manual_fallback','too_soon') NOT NULL,
    `failure_reason` VARCHAR(255) DEFAULT NULL,
    `captured_image_path` VARCHAR(500) DEFAULT NULL,
    `gps_lat` DECIMAL(10,7) DEFAULT NULL,
    `gps_lng` DECIMAL(10,7) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_reclog_tenant` (`tenant_id`),
    INDEX `idx_reclog_branch` (`branch_id`),
    INDEX `idx_reclog_station` (`station_id`),
    INDEX `idx_reclog_employee` (`matched_employee_id`),
    INDEX `idx_reclog_created` (`created_at`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`station_id`) REFERENCES `attendance_stations`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`matched_employee_id`) REFERENCES `employees`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── attendance: station fields ──
ALTER TABLE attendance
    ADD COLUMN recognition_method
        ENUM('manual','qr_gps','station_face','station_fingerprint','station_both') NULL AFTER check_out_method,
    ADD COLUMN recognition_confidence DECIMAL(4,3) NULL AFTER recognition_method,
    ADD COLUMN station_id INT UNSIGNED NULL AFTER recognition_confidence;
