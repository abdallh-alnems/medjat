-- ============================================
-- Employee Categories & Document Category Scope
-- ============================================

SET FOREIGN_KEY_CHECKS = 0;

-- 1. employee_categories
CREATE TABLE IF NOT EXISTS `employee_categories` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `color` VARCHAR(20) DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_category_tenant_name` (`tenant_id`, `name`),
    INDEX `idx_ecat_tenant` (`tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. employee_category_assignments (M2M employee ↔ category)
CREATE TABLE IF NOT EXISTS `employee_category_assignments` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `category_id` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uniq_emp_cat` (`employee_id`, `category_id`),
    INDEX `idx_eca_tenant` (`tenant_id`),
    INDEX `idx_eca_category` (`category_id`, `tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`category_id`) REFERENCES `employee_categories`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Expand scope_type to include 'category'
ALTER TABLE `required_documents`
    MODIFY COLUMN `scope_type` ENUM('all','branch','employees','category') NOT NULL DEFAULT 'all'
    COMMENT 'all=every employee, branch=single branch, employees=specific list, category=by employee category';

-- 4. required_document_categories (M2M document ↔ category for scope=category)
CREATE TABLE IF NOT EXISTS `required_document_categories` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `required_document_id` INT UNSIGNED NOT NULL,
    `category_id` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uniq_rdoc_cat` (`required_document_id`, `category_id`),
    INDEX `idx_rdc_tenant` (`tenant_id`),
    INDEX `idx_rdc_category` (`category_id`, `tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`required_document_id`) REFERENCES `required_documents`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`category_id`) REFERENCES `employee_categories`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
