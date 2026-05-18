-- ============================================
-- Migration: Rename users → admins
-- Date: May 2026
-- ============================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Rename tables
RENAME TABLE `users` TO `admins`;
RENAME TABLE `user_devices` TO `admin_devices`;
RENAME TABLE `user_sessions` TO `admin_sessions`;

-- Rename columns
ALTER TABLE `admin_devices` CHANGE `user_id` `admin_id` INT UNSIGNED NOT NULL;
ALTER TABLE `admin_sessions` CHANGE `user_id` `admin_id` INT UNSIGNED NOT NULL;
ALTER TABLE `employees` CHANGE `user_id` `admin_id` INT UNSIGNED DEFAULT NULL;
ALTER TABLE `custom_roles` CHANGE `user_id` `admin_id` INT UNSIGNED NOT NULL;
ALTER TABLE `notifications` CHANGE `user_id` `admin_id` INT UNSIGNED DEFAULT NULL;
ALTER TABLE `login_attempts` CHANGE `user_id` `admin_id` INT UNSIGNED DEFAULT NULL;
ALTER TABLE `audit_log` CHANGE `user_id` `admin_id` INT UNSIGNED DEFAULT NULL;
ALTER TABLE `manager_invitations` CHANGE `accepted_user_id` `accepted_admin_id` INT UNSIGNED DEFAULT NULL;

-- Update indexes
ALTER TABLE `admin_devices` DROP INDEX `uniq_device_user`, ADD UNIQUE KEY `uniq_device_admin` (`admin_id`, `device_id`);
ALTER TABLE `admin_sessions` DROP INDEX `idx_session_user`, ADD INDEX `idx_session_admin` (`admin_id`);
ALTER TABLE `admins` DROP INDEX `idx_user_tenant`, ADD INDEX `idx_admin_tenant` (`tenant_id`);
ALTER TABLE `admins` DROP INDEX `idx_user_branch`, ADD INDEX `idx_admin_branch` (`branch_id`);
ALTER TABLE `admins` DROP INDEX `idx_user_firebase`, ADD INDEX `idx_admin_firebase` (`firebase_uid`);
ALTER TABLE `admins` DROP INDEX `idx_user_email`, ADD INDEX `idx_admin_email` (`email`);
ALTER TABLE `employees` DROP INDEX `idx_emp_user`, ADD INDEX `idx_emp_admin` (`admin_id`);
ALTER TABLE `custom_roles` DROP INDEX `uniq_role_user`, ADD UNIQUE KEY `uniq_role_admin` (`tenant_id`, `admin_id`);
ALTER TABLE `notifications` DROP INDEX `idx_notif_user_read`, ADD INDEX `idx_notif_admin_read` (`admin_id`, `read_at`);
ALTER TABLE `login_attempts` DROP INDEX `idx_login_user`, ADD INDEX `idx_login_admin` (`admin_id`);
ALTER TABLE `audit_log` DROP INDEX `idx_audit_user`, ADD INDEX `idx_audit_admin` (`admin_id`);

-- Update role enum: owner → general_manager
ALTER TABLE `admins` MODIFY `role` ENUM('general_manager','hr','branch_manager','attendance','viewer','employee','pending') NOT NULL DEFAULT 'pending';
UPDATE `admins` SET `role` = 'general_manager' WHERE `role` = 'owner';

SET FOREIGN_KEY_CHECKS = 1;
