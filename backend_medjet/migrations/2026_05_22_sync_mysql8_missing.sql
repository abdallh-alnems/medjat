-- ============================================
-- Migration: Sync columns/tables that never applied on MySQL 8.0
-- Date: 2026-05-22
-- Reason: schema.sql used `ADD COLUMN IF NOT EXISTS` (MariaDB-only),
--         which aborts on MySQL 8.0, so this block never ran on the
--         live DB. These statements are MySQL 8.0 compatible.
-- ============================================

-- أ. employees — الحقول البيومترية
ALTER TABLE `employees`
    ADD COLUMN `face_photo_url` VARCHAR(500) NULL AFTER `face_embedding`,
    ADD COLUMN `face_enrolled_at` DATETIME NULL AFTER `face_photo_url`,
    ADD COLUMN `face_quality_score` DECIMAL(4,3) NULL AFTER `face_enrolled_at`,
    ADD COLUMN `fingerprint_template` BLOB NULL AFTER `face_quality_score`,
    ADD COLUMN `fingerprint_enrolled_at` DATETIME NULL AFTER `fingerprint_template`,
    ADD COLUMN `biometric_enrollment_status`
        ENUM('not_enrolled','face_only','fingerprint_only','both')
        DEFAULT 'not_enrolled' AFTER `fingerprint_enrolled_at`,
    ADD COLUMN `has_linked_account` BOOLEAN DEFAULT FALSE AFTER `biometric_enrollment_status`;

-- ب. tenants / branches — allow_offline_attendance
ALTER TABLE `tenants`
    ADD COLUMN `allow_offline_attendance` TINYINT(1) NOT NULL DEFAULT 1
        COMMENT 'Company-level toggle for offline attendance capture'
        AFTER `manual_attendance_admin_ids`;

ALTER TABLE `branches`
    ADD COLUMN `allow_offline_attendance` TINYINT(1) DEFAULT NULL
        COMMENT 'NULL = inherit tenant; 1 = forced on; 0 = forced off'
        AFTER `station_anti_spoofing_enabled`;

-- ج. required_documents — حقول الإشعار والنطاق
ALTER TABLE `required_documents`
    ADD COLUMN `notification_days_before` INT DEFAULT 30
        COMMENT 'Days before expiry to send notification',
    ADD COLUMN `category` VARCHAR(50) DEFAULT 'general'
        COMMENT 'identity|contract|certificate|insurance|general',
    ADD COLUMN `sort_order` INT DEFAULT 0,
    ADD COLUMN `scope_type` ENUM('all','branch','employees') NOT NULL DEFAULT 'all'
        COMMENT 'all=every employee, branch=single branch, employees=specific list',
    ADD COLUMN `scope_branch_id` INT UNSIGNED NULL,
    ADD INDEX `idx_reqdoc_scope_branch` (`scope_branch_id`);

-- د. employee_documents — حقول المراجعة
ALTER TABLE `employee_documents`
    ADD COLUMN `notes` TEXT NULL,
    ADD COLUMN `rejected_reason` VARCHAR(500) NULL,
    ADD COLUMN `verified_at` DATETIME NULL,
    ADD COLUMN `verified_by` INT UNSIGNED NULL;

-- هـ. required_document_employees (M2M document ↔ employee لنطاق employees)
CREATE TABLE IF NOT EXISTS `required_document_employees` (
    `required_document_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `tenant_id` INT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`required_document_id`, `employee_id`),
    INDEX `idx_rde_employee` (`employee_id`, `tenant_id`),
    INDEX `idx_rde_tenant` (`tenant_id`),
    FOREIGN KEY (`required_document_id`) REFERENCES `required_documents`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
