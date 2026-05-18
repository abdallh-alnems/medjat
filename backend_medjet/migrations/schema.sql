-- ============================================
-- Medjat HR - Database Schema
-- Multi-tenant SaaS: Attendance, Payroll, HR
-- Aligned with PRD v1.1 (May 2026)
-- ============================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================
-- Plans & Subscriptions
-- ============================================

CREATE TABLE IF NOT EXISTS `plans` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL,
    `name_ar` VARCHAR(50) DEFAULT NULL,
    `price` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `max_employees` INT UNSIGNED NOT NULL DEFAULT 10,
    `max_branches` INT UNSIGNED NOT NULL DEFAULT 1,
    `features` JSON DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_plan_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `tenants` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `name_ar` VARCHAR(100) DEFAULT NULL,
    `domain` VARCHAR(100) DEFAULT NULL UNIQUE,
    `logo_url` VARCHAR(500) DEFAULT NULL,
    `owner_name` VARCHAR(100) NOT NULL,
    `owner_email` VARCHAR(150) NOT NULL,
    `owner_phone` VARCHAR(20) DEFAULT NULL,
    `plan` VARCHAR(50) NOT NULL DEFAULT 'starter' COMMENT 'Denormalized current plan name for fast checks',
    `timezone` VARCHAR(50) NOT NULL DEFAULT 'Africa/Cairo',
    `currency` VARCHAR(3) NOT NULL DEFAULT 'EGP',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `email_verified_at` TIMESTAMP NULL DEFAULT NULL,
    `trial_ends_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_tenant_email` (`owner_email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `subscriptions` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `plan_id` INT UNSIGNED NOT NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `status` ENUM('active','expired','suspended','cancelled','trial') NOT NULL DEFAULT 'active',
    `payment_method` VARCHAR(50) DEFAULT NULL,
    `auto_renew` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_tenant_sub` (`tenant_id`),
    INDEX `idx_sub_status` (`status`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`plan_id`) REFERENCES `plans`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `payment_transactions` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `subscription_id` INT UNSIGNED DEFAULT NULL,
    `plan_id` INT UNSIGNED DEFAULT NULL,
    `amount` DECIMAL(12,2) NOT NULL,
    `currency` VARCHAR(3) NOT NULL DEFAULT 'EGP',
    `provider` VARCHAR(30) NOT NULL DEFAULT 'paymob',
    `provider_order_id` VARCHAR(100) DEFAULT NULL,
    `provider_transaction_id` VARCHAR(100) DEFAULT NULL,
    `payment_method` VARCHAR(50) DEFAULT NULL COMMENT 'card, wallet, kiosk, etc.',
    `status` ENUM('pending','success','failed','refunded','cancelled') NOT NULL DEFAULT 'pending',
    `payload` JSON DEFAULT NULL,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_pay_tenant` (`tenant_id`),
    INDEX `idx_pay_status` (`status`),
    INDEX `idx_pay_provider_order` (`provider_order_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`subscription_id`) REFERENCES `subscriptions`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`plan_id`) REFERENCES `plans`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Branches
-- ============================================

CREATE TABLE IF NOT EXISTS `branches` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `address` TEXT DEFAULT NULL,
    `latitude` DECIMAL(10,7) NOT NULL DEFAULT 0,
    `longitude` DECIMAL(10,7) NOT NULL DEFAULT 0,
    `gps_radius` INT UNSIGNED NOT NULL DEFAULT 100 COMMENT 'Radius in meters',
    `qr_code` VARCHAR(50) DEFAULT NULL UNIQUE,
    `work_start_time` TIME DEFAULT '09:00:00',
    `work_end_time` TIME DEFAULT '17:00:00',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_branch_tenant` (`tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Admins (Management app users)
-- ============================================

CREATE TABLE IF NOT EXISTS `admins` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `firebase_uid` VARCHAR(128) DEFAULT NULL UNIQUE,
    `tenant_id` INT UNSIGNED DEFAULT NULL COMMENT 'Null = user signed in but not joined a company yet',
    `branch_id` INT UNSIGNED DEFAULT NULL,
    `name` VARCHAR(100) NOT NULL,
    `phone` VARCHAR(20) DEFAULT NULL,
    `email` VARCHAR(150) DEFAULT NULL,
    `password_hash` VARCHAR(255) DEFAULT NULL COMMENT 'Null for Google/Apple-only accounts',
    `auth_provider` ENUM('email','google','apple','employee_code') NOT NULL DEFAULT 'email',
    `role` ENUM('general_manager','hr','branch_manager','attendance','viewer','employee','pending') NOT NULL DEFAULT 'pending' COMMENT 'pending = no tenant joined yet',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `two_factor_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `two_factor_secret` VARCHAR(255) DEFAULT NULL,
    `email_verified_at` TIMESTAMP NULL DEFAULT NULL,
    `last_login_at` TIMESTAMP NULL DEFAULT NULL,
    `last_login_ip` VARCHAR(45) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_admin_tenant` (`tenant_id`),
    INDEX `idx_admin_branch` (`branch_id`),
    INDEX `idx_admin_firebase` (`firebase_uid`),
    INDEX `idx_admin_email` (`email`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_devices` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `admin_id` INT UNSIGNED NOT NULL,
    `fcm_token` VARCHAR(500) NOT NULL,
    `platform` ENUM('android','ios','web') NOT NULL DEFAULT 'android',
    `device_id` VARCHAR(100) DEFAULT NULL,
    `device_model` VARCHAR(100) DEFAULT NULL,
    `app_version` VARCHAR(20) DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_device_admin` (`admin_id`, `device_id`),
    INDEX `idx_device_token` (`fcm_token`(50)),
    FOREIGN KEY (`admin_id`) REFERENCES `admins`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_sessions` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `admin_id` INT UNSIGNED NOT NULL,
    `token_hash` VARCHAR(64) NOT NULL UNIQUE,
    `refresh_token_hash` VARCHAR(64) DEFAULT NULL,
    `device_id` VARCHAR(100) DEFAULT NULL,
    `platform` ENUM('android','ios','web') DEFAULT NULL,
    `ip` VARCHAR(45) DEFAULT NULL,
    `user_agent` VARCHAR(255) DEFAULT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `revoked_at` TIMESTAMP NULL DEFAULT NULL,
    `last_used_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_session_admin` (`admin_id`),
    INDEX `idx_session_hash` (`token_hash`),
    INDEX `idx_session_expires` (`expires_at`),
    FOREIGN KEY (`admin_id`) REFERENCES `admins`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Manager Invitations (PRD §3.3)
-- ============================================

CREATE TABLE IF NOT EXISTS `manager_invitations` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `email` VARCHAR(150) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `role` ENUM('hr','branch_manager','attendance','viewer') NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL COMMENT 'Scope: null = all branches',
    `permissions` JSON DEFAULT NULL,
    `token_hash` VARCHAR(64) NOT NULL UNIQUE COMMENT 'SHA-256 of invite token',
    `expires_at` TIMESTAMP NOT NULL COMMENT '72 hours from creation',
    `accepted_at` TIMESTAMP NULL DEFAULT NULL,
    `accepted_admin_id` INT UNSIGNED DEFAULT NULL,
    `cancelled_at` TIMESTAMP NULL DEFAULT NULL,
    `invited_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_invite_tenant` (`tenant_id`),
    INDEX `idx_invite_email` (`email`),
    INDEX `idx_invite_expires` (`expires_at`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`invited_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`accepted_admin_id`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Employees (HR Profile)
-- ============================================

CREATE TABLE IF NOT EXISTS `employees` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL,
    `admin_id` INT UNSIGNED DEFAULT NULL,
    `name` VARCHAR(100) NOT NULL,
    `phone` VARCHAR(20) DEFAULT NULL,
    `email` VARCHAR(150) DEFAULT NULL,
    `job_title` VARCHAR(100) DEFAULT NULL,
    `department` VARCHAR(100) DEFAULT NULL,
    `national_id` VARCHAR(20) DEFAULT NULL,
    `base_salary` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `hire_date` DATE DEFAULT NULL,
    `status` ENUM('pending_activation','active','terminated','on_leave','suspended') NOT NULL DEFAULT 'pending_activation',
    `profile_image` VARCHAR(500) DEFAULT NULL,
    `face_embedding` BLOB DEFAULT NULL COMMENT 'For ML Kit face verification (v2)',
    `deleted_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_emp_phone_tenant` (`tenant_id`, `phone`),
    INDEX `idx_emp_tenant` (`tenant_id`),
    INDEX `idx_emp_branch` (`branch_id`),
    INDEX `idx_emp_admin` (`admin_id`),
    INDEX `idx_emp_status` (`status`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`admin_id`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Employee Activation Codes (PRD §3.4)
-- One-time 6-character codes, 24h expiry, burned on use
-- ============================================

CREATE TABLE IF NOT EXISTS `activation_codes` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `code_hash` VARCHAR(64) NOT NULL COMMENT 'SHA-256 of the 6-char code',
    `code_preview` VARCHAR(6) DEFAULT NULL COMMENT 'Plain code, shown to admin until used',
    `phone` VARCHAR(20) NOT NULL COMMENT 'Phone number to verify against',
    `expires_at` TIMESTAMP NOT NULL,
    `used_at` TIMESTAMP NULL DEFAULT NULL,
    `used_device_id` VARCHAR(100) DEFAULT NULL,
    `used_ip` VARCHAR(45) DEFAULT NULL,
    `attempt_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `generated_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_actcode_tenant` (`tenant_id`),
    INDEX `idx_actcode_emp` (`employee_id`),
    INDEX `idx_actcode_hash` (`code_hash`),
    INDEX `idx_actcode_expires` (`expires_at`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`generated_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Employee Permanent Auth Tokens (PRD §3.4)
-- Device-bound long-lived tokens for the Employee app
-- One active token per employee (single-device binding)
-- ============================================

CREATE TABLE IF NOT EXISTS `employee_auth_tokens` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `token_hash` VARCHAR(64) NOT NULL UNIQUE,
    `device_id` VARCHAR(100) NOT NULL,
    `device_model` VARCHAR(100) DEFAULT NULL,
    `platform` ENUM('android','ios') NOT NULL,
    `app_version` VARCHAR(20) DEFAULT NULL,
    `issued_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_used_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `revoked_at` TIMESTAMP NULL DEFAULT NULL,
    `revoke_reason` VARCHAR(100) DEFAULT NULL,
    UNIQUE KEY `uniq_active_token_per_emp` (`employee_id`, `revoked_at`),
    INDEX `idx_emptoken_tenant` (`tenant_id`),
    INDEX `idx_emptoken_hash` (`token_hash`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Attendance
-- ============================================

CREATE TABLE IF NOT EXISTS `attendance` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `check_in_time` TIME DEFAULT NULL,
    `check_out_time` TIME DEFAULT NULL,
    `check_in_latitude` DECIMAL(10,7) DEFAULT NULL,
    `check_in_longitude` DECIMAL(10,7) DEFAULT NULL,
    `check_out_latitude` DECIMAL(10,7) DEFAULT NULL,
    `check_out_longitude` DECIMAL(10,7) DEFAULT NULL,
    `worked_minutes` INT UNSIGNED DEFAULT 0,
    `overtime_minutes` INT UNSIGNED DEFAULT 0,
    `late_minutes` INT UNSIGNED DEFAULT 0,
    `early_leave_minutes` INT UNSIGNED DEFAULT 0,
    `check_in_method` ENUM('qr_gps','qr_gps_face','manual','kiosk','offline') DEFAULT 'qr_gps',
    `check_out_method` ENUM('qr_gps','qr_gps_face','manual','kiosk','offline','auto') DEFAULT NULL,
    `status` ENUM('present','absent','leave','holiday','weekly_off') NOT NULL DEFAULT 'present',
    `is_offline` TINYINT(1) NOT NULL DEFAULT 0,
    `synced_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'When offline record was synced',
    `recorded_by` INT UNSIGNED DEFAULT NULL COMMENT 'User who manually recorded this',
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_attendance_emp_date` (`employee_id`, `date`),
    INDEX `idx_att_tenant_date` (`tenant_id`, `date`),
    INDEX `idx_att_branch_date` (`branch_id`, `date`),
    INDEX `idx_att_status` (`status`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`recorded_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Deduction & Bonus Rules
-- ============================================

CREATE TABLE IF NOT EXISTS `deduction_rules` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `rule_key` VARCHAR(50) NOT NULL,
    `rule_type` ENUM('numeric','text','boolean') NOT NULL DEFAULT 'numeric',
    `rule_value` VARCHAR(255) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_deduction_rule` (`tenant_id`, `rule_key`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bonus_rules` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `rule_key` VARCHAR(50) NOT NULL,
    `rule_type` ENUM('numeric','text','boolean') NOT NULL DEFAULT 'numeric',
    `rule_value` VARCHAR(255) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_bonus_rule` (`tenant_id`, `rule_key`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `manual_deductions` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `amount` DECIMAL(12,2) NOT NULL,
    `reason` TEXT NOT NULL,
    `month` VARCHAR(7) NOT NULL COMMENT 'YYYY-MM',
    `created_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_md_emp_month` (`employee_id`, `month`),
    INDEX `idx_md_tenant_month` (`tenant_id`, `month`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`created_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `manual_bonuses` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `amount` DECIMAL(12,2) NOT NULL,
    `reason` TEXT NOT NULL,
    `month` VARCHAR(7) NOT NULL COMMENT 'YYYY-MM',
    `created_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_mb_emp_month` (`employee_id`, `month`),
    INDEX `idx_mb_tenant_month` (`tenant_id`, `month`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`created_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Leaves (PRD §7)
-- ============================================

CREATE TABLE IF NOT EXISTS `leaves` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `date` DATE NOT NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    `type` ENUM('annual','sick','personal','unpaid','weekly_off','converted_from_absence') NOT NULL DEFAULT 'annual',
    `reason` TEXT DEFAULT NULL,
    `status` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    `approved_by` INT UNSIGNED DEFAULT NULL,
    `approved_at` TIMESTAMP NULL DEFAULT NULL,
    `rejected_by` INT UNSIGNED DEFAULT NULL,
    `rejection_reason` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_leave_tenant` (`tenant_id`),
    INDEX `idx_leave_emp_date` (`employee_id`, `date`),
    INDEX `idx_leave_status` (`status`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`approved_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`rejected_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `recurring_leaves` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL,
    `day_of_week` ENUM('saturday','sunday','monday','tuesday','wednesday','thursday','friday') NOT NULL,
    `type` VARCHAR(50) NOT NULL DEFAULT 'weekly_off',
    `reason` TEXT DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_recleave_tenant` (`tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `holidays` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL COMMENT 'Null = all branches',
    `name` VARCHAR(100) NOT NULL,
    `date` DATE NOT NULL,
    `is_paid` TINYINT(1) NOT NULL DEFAULT 1,
    `notes` TEXT DEFAULT NULL,
    `created_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_holiday_branch_date` (`tenant_id`, `branch_id`, `date`),
    INDEX `idx_holiday_date` (`date`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`created_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Payroll
-- ============================================

CREATE TABLE IF NOT EXISTS `payroll` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL,
    `month` VARCHAR(7) NOT NULL COMMENT 'YYYY-MM',
    `base_salary` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `total_deductions` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `total_bonuses` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `net_salary` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `working_days` INT UNSIGNED NOT NULL DEFAULT 0,
    `present_days` INT UNSIGNED NOT NULL DEFAULT 0,
    `absent_days` INT UNSIGNED NOT NULL DEFAULT 0,
    `leave_days` INT UNSIGNED NOT NULL DEFAULT 0,
    `late_total_minutes` INT UNSIGNED NOT NULL DEFAULT 0,
    `overtime_total_minutes` INT UNSIGNED NOT NULL DEFAULT 0,
    `breakdown` JSON DEFAULT NULL,
    `status` ENUM('draft','approved','paid') NOT NULL DEFAULT 'draft',
    `approved_by` INT UNSIGNED DEFAULT NULL,
    `approved_at` TIMESTAMP NULL DEFAULT NULL,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_payroll_emp_month` (`employee_id`, `month`),
    INDEX `idx_payroll_tenant_month` (`tenant_id`, `month`),
    INDEX `idx_payroll_status` (`status`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`approved_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Documents
-- ============================================

CREATE TABLE IF NOT EXISTS `required_documents` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `expiry_days` INT UNSIGNED DEFAULT NULL COMMENT 'Days before expiry, null = no expiry',
    `is_required` TINYINT(1) NOT NULL DEFAULT 1,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_reqdoc_tenant` (`tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `employee_documents` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `required_document_id` INT UNSIGNED DEFAULT NULL,
    `file_path` VARCHAR(500) NOT NULL,
    `original_name` VARCHAR(255) DEFAULT NULL,
    `file_size` INT UNSIGNED DEFAULT NULL,
    `mime_type` VARCHAR(50) DEFAULT NULL,
    `status` ENUM('uploaded','expired','required','rejected') NOT NULL DEFAULT 'uploaded',
    `expires_at` DATE DEFAULT NULL,
    `uploaded_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_emp_doc` (`employee_id`, `required_document_id`),
    INDEX `idx_edoc_tenant` (`tenant_id`),
    INDEX `idx_edoc_expires` (`expires_at`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`required_document_id`) REFERENCES `required_documents`(`id`) ON DELETE SET NULL,
    FOREIGN KEY (`uploaded_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Warnings & Performance
-- ============================================

CREATE TABLE IF NOT EXISTS `warnings` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `type` ENUM('verbal','written','final','device_change','system') NOT NULL DEFAULT 'verbal',
    `reason` TEXT NOT NULL,
    `issued_by` INT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_warn_tenant` (`tenant_id`),
    INDEX `idx_warn_emp` (`employee_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`issued_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Custom Roles & Permissions (PRD §4)
-- ============================================

CREATE TABLE IF NOT EXISTS `custom_roles` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `admin_id` INT UNSIGNED NOT NULL,
    `branch_id` INT UNSIGNED DEFAULT NULL COMMENT 'Scope: null = all branches',
    `name` VARCHAR(50) NOT NULL,
    `permissions` JSON NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_role_admin` (`tenant_id`, `admin_id`),
    INDEX `idx_custrole_tenant` (`tenant_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`admin_id`) REFERENCES `admins`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Notifications (PRD §10)
-- ============================================

CREATE TABLE IF NOT EXISTS `notifications` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED DEFAULT NULL COMMENT 'Null = system-wide from super admin',
    `admin_id` INT UNSIGNED DEFAULT NULL COMMENT 'Null = broadcast to tenant',
    `employee_id` INT UNSIGNED DEFAULT NULL COMMENT 'For Employee-app recipients',
    `type` ENUM('general','attendance','payroll','leave','warning','system','subscription','invite') NOT NULL DEFAULT 'general',
    `title` VARCHAR(255) NOT NULL,
    `title_ar` VARCHAR(255) DEFAULT NULL,
    `body` TEXT NOT NULL,
    `body_ar` TEXT DEFAULT NULL,
    `data` JSON DEFAULT NULL,
    `sent_via` SET('push','email','in_app') NOT NULL DEFAULT 'in_app',
    `read_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_notif_tenant` (`tenant_id`),
    INDEX `idx_notif_admin_read` (`admin_id`, `read_at`),
    INDEX `idx_notif_emp_read` (`employee_id`, `read_at`),
    INDEX `idx_notif_type` (`type`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`admin_id`) REFERENCES `admins`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Login attempts (Rate limiting / Security - PRD §3.6)
-- ============================================

CREATE TABLE IF NOT EXISTS `login_attempts` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(255) NOT NULL COMMENT 'Email / phone / ip',
    `identifier_type` ENUM('email','phone','ip','employee_code') NOT NULL,
    `tenant_id` INT UNSIGNED DEFAULT NULL,
    `admin_id` INT UNSIGNED DEFAULT NULL,
    `success` TINYINT(1) NOT NULL DEFAULT 0,
    `failure_reason` VARCHAR(100) DEFAULT NULL,
    `ip` VARCHAR(45) DEFAULT NULL,
    `user_agent` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_login_identifier_time` (`identifier`, `created_at`),
    INDEX `idx_login_ip_time` (`ip`, `created_at`),
    INDEX `idx_login_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Audit Log (per tenant)
-- ============================================

CREATE TABLE IF NOT EXISTS `audit_log` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `admin_id` INT UNSIGNED DEFAULT NULL,
    `action` VARCHAR(100) NOT NULL,
    `target_type` VARCHAR(50) DEFAULT NULL,
    `target_id` VARCHAR(50) DEFAULT NULL,
    `payload` JSON DEFAULT NULL,
    `ip` VARCHAR(45) DEFAULT NULL,
    `user_agent` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_audit_tenant` (`tenant_id`),
    INDEX `idx_audit_admin` (`admin_id`),
    INDEX `idx_audit_action` (`action`),
    INDEX `idx_audit_target` (`target_type`, `target_id`),
    FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`admin_id`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Super Admin
-- ============================================

CREATE TABLE IF NOT EXISTS `super_admins` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) NOT NULL UNIQUE,
    `email` VARCHAR(150) DEFAULT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `display_name` VARCHAR(100) DEFAULT NULL,
    `role` ENUM('readonly','admin','superadmin') NOT NULL DEFAULT 'admin',
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `two_factor_secret` VARCHAR(255) DEFAULT NULL COMMENT 'Mandatory TOTP for super admin',
    `two_factor_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `last_login_at` TIMESTAMP NULL DEFAULT NULL,
    `last_login_ip` VARCHAR(45) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `super_admin_sessions` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `admin_id` INT UNSIGNED NOT NULL,
    `token_hash` VARCHAR(64) NOT NULL UNIQUE,
    `expires_at` TIMESTAMP NOT NULL,
    `ip` VARCHAR(45) DEFAULT NULL,
    `user_agent` VARCHAR(255) DEFAULT NULL,
    `last_used_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_session_hash` (`token_hash`),
    INDEX `idx_session_admin` (`admin_id`),
    FOREIGN KEY (`admin_id`) REFERENCES `super_admins`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `super_admin_audit_log` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `admin_id` INT UNSIGNED DEFAULT NULL,
    `action` VARCHAR(100) NOT NULL,
    `target_type` VARCHAR(50) DEFAULT NULL,
    `target_id` VARCHAR(50) DEFAULT NULL,
    `payload` JSON DEFAULT NULL,
    `ip` VARCHAR(45) DEFAULT NULL,
    `user_agent` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_saalog_admin` (`admin_id`),
    INDEX `idx_saalog_action` (`action`),
    FOREIGN KEY (`admin_id`) REFERENCES `super_admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Seed Data
-- ============================================

INSERT IGNORE INTO `plans` (`name`, `name_ar`, `price`, `max_employees`, `max_branches`) VALUES
('starter',    'الباقة المبتدئة',   199.00, 10,     1),
('growth',     'باقة النمو',        399.00, 30,     3),
('pro',        'الباقة الاحترافية', 699.00, 100,    999999),
('enterprise', 'باقة المؤسسات',     0.00,   999999, 999999);

INSERT IGNORE INTO `super_admins` (`username`, `password_hash`, `display_name`, `role`, `is_active`) VALUES
('superadmin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Super Admin', 'superadmin', 1);
-- Password: password

SET FOREIGN_KEY_CHECKS = 1;
