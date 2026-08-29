SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `shifts` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL COMMENT 'NULL = available for all branches',
    `name` VARCHAR(100) NOT NULL COMMENT 'e.g. "Morning", "Evening", "Night"',
    `start_time` TIME NOT NULL,
    `end_time` TIME NOT NULL,
    `color` VARCHAR(7) DEFAULT NULL COMMENT 'Hex color for UI badge',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_shift_tenant` (`tenant_id`),
    INDEX `idx_shift_branch` (`branch_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `employees`
    ADD COLUMN `shift_id` INT UNSIGNED DEFAULT NULL AFTER `work_end_time`,
    ADD INDEX `idx_emp_shift` (`shift_id`),
    ADD CONSTRAINT `fk_emp_shift` FOREIGN KEY (`shift_id`) REFERENCES `shifts`(`id`) ON DELETE SET NULL;
