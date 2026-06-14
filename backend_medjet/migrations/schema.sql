-- ============================================
-- Medjat — Database Schema (snapshot)
-- Regenerated from live DB to match reality. MySQL 8.0 compatible.
-- Non-destructive: CREATE TABLE IF NOT EXISTS (safe to re-run).
-- Date: 2026-05-22 (updated: payroll_statutory_settings)
-- ============================================

SET FOREIGN_KEY_CHECKS = 0;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `admin_devices` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned NOT NULL,
  `fcm_token` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `platform` enum('android','ios','web') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'android',
  `device_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_model` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `app_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_admin` (`admin_id`,`device_id`),
  KEY `idx_device_token` (`fcm_token`(50)),
  CONSTRAINT `admin_devices_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `admin_notification_prefs` (
  `admin_id` int unsigned NOT NULL,
  `tenant_id` int unsigned DEFAULT NULL,
  `prefs` json NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`admin_id`),
  KEY `idx_notif_prefs_tenant` (`tenant_id`),
  CONSTRAINT `admin_notification_prefs_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `admins` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `firebase_uid` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tenant_id` int unsigned DEFAULT NULL COMMENT 'Null = user signed in but not joined a company yet',
  `branch_id` int unsigned DEFAULT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `auth_provider` enum('email','google','apple','employee_code') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'email',
  `role` enum('general_manager','hr','branch_manager','attendance','viewer','employee','pending') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `last_login_at` timestamp NULL DEFAULT NULL,
  `last_login_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `active_device_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Most recent device that logged in; other devices are signed out on their next request',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `firebase_uid` (`firebase_uid`),
  KEY `idx_admin_tenant` (`tenant_id`),
  KEY `idx_admin_branch` (`branch_id`),
  KEY `idx_admin_firebase` (`firebase_uid`),
  KEY `idx_admin_email` (`email`),
  CONSTRAINT `admins_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `admins_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `attendance` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `employee_id` int unsigned NOT NULL,
  `date` date NOT NULL,
  `check_in_time` time DEFAULT NULL,
  `check_out_time` time DEFAULT NULL,
  `check_in_latitude` decimal(10,7) DEFAULT NULL,
  `check_in_longitude` decimal(10,7) DEFAULT NULL,
  `worked_minutes` int unsigned DEFAULT '0',
  `overtime_minutes` int unsigned DEFAULT '0',
  `late_minutes` int unsigned DEFAULT '0',
  `early_leave_minutes` int unsigned DEFAULT '0',
  `check_in_method` enum('qr_gps','qr_gps_face','manual','kiosk','offline') COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps',
  `check_out_method` enum('qr_gps','qr_gps_face','manual','kiosk','offline','auto') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recognition_method` enum('manual','qr_gps','station_face','station_fingerprint','station_both','station_qr') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recognition_confidence` decimal(4,3) DEFAULT NULL,
  `station_id` int unsigned DEFAULT NULL,
  `status` enum('present','absent','leave','holiday','weekly_off') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'present',
  `is_offline` tinyint(1) NOT NULL DEFAULT '0',
  `is_vpn` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'VPN detected on device at check-in (advisory)',
  `is_mock_location` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Mock-location flag reported by client (advisory)',
  `synced_at` timestamp NULL DEFAULT NULL COMMENT 'When offline record was synced',
  `recorded_by` int unsigned DEFAULT NULL COMMENT 'User who manually recorded this',
  `deduction_mode` enum('auto','days','amount') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto' COMMENT 'How an absent day is deducted: auto=company rule, days=value*daily rate, amount=fixed value',
  `deduction_value` decimal(10,2) DEFAULT NULL COMMENT 'Days count (mode=days) or fixed amount (mode=amount)',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_attendance_emp_date` (`employee_id`,`date`),
  KEY `idx_att_tenant_date` (`tenant_id`,`date`),
  KEY `idx_att_branch_date` (`branch_id`,`date`),
  KEY `idx_att_status` (`status`),
  KEY `recorded_by` (`recorded_by`),
  CONSTRAINT `attendance_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `attendance_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `attendance_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `attendance_ibfk_4` FOREIGN KEY (`recorded_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `attendance_security_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `reason` enum('mock_location','rooted','jailbroken','vpn','gps_out_of_range') COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` enum('blocked','flagged') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'blocked',
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'android | ios',
  `app_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_seclog_tenant_date` (`tenant_id`,`created_at`),
  KEY `idx_seclog_employee` (`employee_id`),
  CONSTRAINT `seclog_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `seclog_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `admin_id` int unsigned DEFAULT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payload` json DEFAULT NULL,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_tenant` (`tenant_id`),
  KEY `idx_audit_action` (`action`),
  KEY `idx_audit_target` (`target_type`,`target_id`),
  KEY `idx_audit_admin` (`admin_id`),
  CONSTRAINT `audit_log_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `audit_log_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `bonus_rules` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `rule_key` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rule_type` enum('numeric','text','boolean') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'numeric',
  `rule_value` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_bonus_rule` (`tenant_id`,`rule_key`),
  CONSTRAINT `bonus_rules_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `branches` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `latitude` decimal(10,7) NOT NULL DEFAULT '0.0000000',
  `longitude` decimal(10,7) NOT NULL DEFAULT '0.0000000',
  `qr_code` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `attendance_methods` json DEFAULT NULL COMMENT 'Branch override; NULL inherits tenants.attendance_methods',
  `gps_radius_meters` int unsigned NOT NULL DEFAULT '100' COMMENT 'Allowed GPS radius for check-in in meters',
  `cycle_start_day` tinyint unsigned DEFAULT NULL COMMENT 'Per-branch override of attendance cycle start day; NULL = inherit company',
  `allow_offline_attendance` tinyint(1) DEFAULT NULL COMMENT 'NULL = inherit tenant; 1 = forced on; 0 = forced off',
  PRIMARY KEY (`id`),
  UNIQUE KEY `qr_code` (`qr_code`),
  KEY `idx_branch_tenant` (`tenant_id`),
  CONSTRAINT `branches_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `custom_roles` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `admin_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Scope: null = all branches',
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `permissions` json NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_role_admin` (`tenant_id`,`admin_id`),
  KEY `idx_custrole_tenant` (`tenant_id`),
  KEY `user_id` (`admin_id`),
  KEY `branch_id` (`branch_id`),
  CONSTRAINT `custom_roles_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `custom_roles_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE,
  CONSTRAINT `custom_roles_ibfk_3` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `deduction_rules` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `rule_key` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rule_type` enum('numeric','text','boolean') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'numeric',
  `rule_value` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_deduction_rule` (`tenant_id`,`rule_key`),
  CONSTRAINT `deduction_rules_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `late_deduction_tiers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `threshold_minutes` int unsigned NOT NULL,
  `deduction_days` decimal(5,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_tenant_threshold` (`tenant_id`,`threshold_minutes`),
  CONSTRAINT `late_deduction_tiers_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employee_activation_codes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `code` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp NULL DEFAULT NULL,
  `used_by_firebase_uid` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_code` (`code`),
  UNIQUE KEY `uniq_token` (`token`),
  KEY `idx_act_employee` (`employee_id`),
  KEY `idx_act_tenant` (`tenant_id`),
  KEY `idx_act_expires` (`expires_at`),
  CONSTRAINT `employee_activation_codes_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_activation_codes_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employee_auth_tokens` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `token_hash` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_model` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform` enum('android','ios') COLLATE utf8mb4_unicode_ci NOT NULL,
  `app_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `issued_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked_at` timestamp NULL DEFAULT NULL,
  `revoke_reason` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token_hash` (`token_hash`),
  UNIQUE KEY `uniq_active_token_per_emp` (`employee_id`,`revoked_at`),
  KEY `idx_emptoken_tenant` (`tenant_id`),
  KEY `idx_emptoken_hash` (`token_hash`),
  CONSTRAINT `employee_auth_tokens_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_auth_tokens_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employee_categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `color` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_category_tenant_name` (`tenant_id`,`name`),
  KEY `idx_ecat_tenant` (`tenant_id`),
  CONSTRAINT `employee_categories_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employee_category_assignments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `category_id` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_emp_cat` (`employee_id`,`category_id`),
  KEY `idx_eca_tenant` (`tenant_id`),
  KEY `idx_eca_category` (`category_id`,`tenant_id`),
  CONSTRAINT `employee_category_assignments_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_category_assignments_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_category_assignments_ibfk_3` FOREIGN KEY (`category_id`) REFERENCES `employee_categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employee_documents` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `required_document_id` int unsigned DEFAULT NULL,
  `file_path` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `original_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_size` int unsigned DEFAULT NULL,
  `mime_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('uploaded','expired','required','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'uploaded',
  `expires_at` date DEFAULT NULL,
  `uploaded_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `rejected_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `verified_at` datetime DEFAULT NULL,
  `verified_by` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_emp_doc` (`employee_id`,`required_document_id`),
  KEY `idx_edoc_tenant` (`tenant_id`),
  KEY `idx_edoc_expires` (`expires_at`),
  KEY `required_document_id` (`required_document_id`),
  KEY `uploaded_by` (`uploaded_by`),
  CONSTRAINT `employee_documents_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_documents_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_documents_ibfk_3` FOREIGN KEY (`required_document_id`) REFERENCES `required_documents` (`id`) ON DELETE SET NULL,
  CONSTRAINT `employee_documents_ibfk_4` FOREIGN KEY (`uploaded_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employees` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `admin_id` int unsigned DEFAULT NULL,
  `employee_code` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Internal staff number',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `job_title` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `department` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `national_id` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nationality` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `iqama_number` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Residency / iqama number',
  `iqama_expiry` date DEFAULT NULL,
  `passport_number` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `passport_expiry` date DEFAULT NULL,
  `work_permit_number` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Work permit / labor card',
  `work_permit_expiry` date DEFAULT NULL,
  `contract_type` enum('permanent','fixed_term','part_time','temporary') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contract_start` date DEFAULT NULL,
  `contract_end` date DEFAULT NULL,
  `health_insurance_expiry` date DEFAULT NULL,
  `base_salary` decimal(12,2) unsigned NOT NULL DEFAULT '0.00',
  `hire_date` date DEFAULT NULL,
  `work_start_time` time NOT NULL DEFAULT '09:00:00',
  `work_end_time` time NOT NULL DEFAULT '17:00:00',
  `annual_leave_days` int DEFAULT NULL COMMENT 'NULL = inherit tenant default; number = per-employee override',
  `weekly_off_days` set('saturday','sunday','monday','tuesday','wednesday','thursday','friday') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Recurring weekly days off for this employee',
  `auto_terminate_at` date DEFAULT NULL COMMENT 'Auto-terminate the employee on this date (fixed-term workers); NULL = open-ended',
  `terminated_at` date DEFAULT NULL COMMENT 'تاريخ إنهاء الخدمة — يُستخدم لحساب الدوران والقوى العاملة',
  `shift_id` int unsigned DEFAULT NULL,
  `shift_type` enum('fixed','rotating') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'fixed',
  `status` enum('pending_activation','active','terminated','on_leave','suspended') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending_activation',
  `profile_image` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_embedding` blob COMMENT 'For ML Kit face verification (v2)',
  `bank_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bank_account_number` varchar(34) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bank_iban` varchar(34) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bank_swift` varchar(11) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_enrolled_at` datetime DEFAULT NULL,
  `face_quality_score` decimal(4,3) DEFAULT NULL,
  `fingerprint_enrolled_at` datetime DEFAULT NULL,
  `biometric_enrollment_status` enum('not_enrolled','face_only','fingerprint_only','both') COLLATE utf8mb4_unicode_ci DEFAULT 'not_enrolled',
  `has_linked_account` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_emp_phone_tenant` (`tenant_id`,`phone`),
  KEY `idx_emp_tenant` (`tenant_id`),
  KEY `idx_emp_branch` (`branch_id`),
  KEY `idx_emp_status` (`status`),
  KEY `idx_emp_admin` (`admin_id`),
  KEY `idx_emp_shift` (`shift_id`),
  KEY `idx_emp_iqama_expiry` (`tenant_id`,`iqama_expiry`),
  KEY `idx_emp_passport_expiry` (`tenant_id`,`passport_expiry`),
  KEY `idx_emp_workpermit_expiry` (`tenant_id`,`work_permit_expiry`),
  KEY `idx_emp_contract_end` (`tenant_id`,`contract_end`),
  KEY `idx_emp_health_expiry` (`tenant_id`,`health_insurance_expiry`),
  KEY `idx_emp_terminated_at` (`tenant_id`,`terminated_at`),
  CONSTRAINT `employees_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employees_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `employees_ibfk_3` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_emp_shift` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `holidays` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Null = all branches',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` date NOT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_holiday_branch_date` (`tenant_id`,`branch_id`,`date`),
  KEY `idx_holiday_date` (`date`),
  KEY `branch_id` (`branch_id`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `holidays_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `holidays_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `holidays_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `leaves` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `date` date NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `type` enum('annual','sick','personal','unpaid','weekly_off','converted_from_absence') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'annual',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` timestamp NULL DEFAULT NULL,
  `rejected_by` int unsigned DEFAULT NULL,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_leave_tenant` (`tenant_id`),
  KEY `idx_leave_emp_date` (`employee_id`,`date`),
  KEY `idx_leave_status` (`status`),
  KEY `approved_by` (`approved_by`),
  KEY `rejected_by` (`rejected_by`),
  CONSTRAINT `leaves_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `leaves_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `leaves_ibfk_3` FOREIGN KEY (`approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `leaves_ibfk_4` FOREIGN KEY (`rejected_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `leave_year_balances` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `year` smallint NOT NULL,
  `entitlement_days` int NOT NULL COMMENT 'Entitlement for this year at row-generation time',
  `carried_over_days` int NOT NULL DEFAULT '0' COMMENT 'Days carried over from the previous year',
  `carryover_encashed_days` int NOT NULL DEFAULT '0' COMMENT 'Days that were cashed out for this year instead of carried',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_lyb_employee_year` (`employee_id`,`year`),
  KEY `idx_lyb_tenant` (`tenant_id`),
  CONSTRAINT `fk_lyb_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_lyb_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `leave_carryover_policies` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `scope_type` enum('tenant','branch','category','employee') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'tenant',
  `scope_id` int unsigned DEFAULT NULL COMMENT 'branch/category/employee id; NULL for tenant scope',
  `min_seniority_months` int unsigned NOT NULL DEFAULT '0' COMMENT 'Seniority tier threshold in months (0 = applies to everyone)',
  `carryover_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '0 = remaining is dropped (unless legal_min/encash apply)',
  `carryover_max_days` int DEFAULT NULL COMMENT 'Max days carried; NULL = unlimited',
  `expiry_months` int unsigned DEFAULT NULL COMMENT 'Carried days expire N months into the new year; NULL = never',
  `encash_excess` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Pay out days above the cap instead of dropping them',
  `legal_min_carry_days` int unsigned DEFAULT NULL COMMENT 'Statutory floor that must be carried or encashed, never forfeited',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_lcp_scope` (`tenant_id`,`scope_type`,`scope_id`,`min_seniority_months`),
  KEY `idx_lcp_tenant` (`tenant_id`),
  CONSTRAINT `fk_lcp_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `leave_encashments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `source_year` smallint NOT NULL COMMENT 'Year whose remaining balance is being cashed out',
  `days` int NOT NULL DEFAULT '0',
  `daily_rate` decimal(12,2) NOT NULL DEFAULT '0.00',
  `amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `status` enum('pending','paid','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `payroll_month` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'YYYY-MM where it was paid',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_enc_employee_year` (`employee_id`,`source_year`),
  KEY `idx_enc_tenant` (`tenant_id`),
  KEY `idx_enc_month` (`tenant_id`,`payroll_month`),
  CONSTRAINT `fk_enc_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_enc_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `login_attempts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `identifier` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Email / phone / ip',
  `identifier_type` enum('email','phone','ip','employee_code') COLLATE utf8mb4_unicode_ci NOT NULL,
  `tenant_id` int unsigned DEFAULT NULL,
  `admin_id` int unsigned DEFAULT NULL,
  `success` tinyint(1) NOT NULL DEFAULT '0',
  `failure_reason` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_login_identifier_time` (`identifier`,`created_at`),
  KEY `idx_login_ip_time` (`ip`,`created_at`),
  KEY `idx_login_admin` (`admin_id`)
) ENGINE=InnoDB AUTO_INCREMENT=89 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `manager_invitations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('hr','branch_manager','attendance','viewer') COLLATE utf8mb4_unicode_ci NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Scope: null = all branches',
  `permissions` json DEFAULT NULL,
  `token_hash` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'SHA-256 of invite token',
  `expires_at` timestamp NOT NULL COMMENT '72 hours from creation',
  `accepted_at` timestamp NULL DEFAULT NULL,
  `accepted_admin_id` int unsigned DEFAULT NULL,
  `cancelled_at` timestamp NULL DEFAULT NULL,
  `invited_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token_hash` (`token_hash`),
  KEY `idx_invite_tenant` (`tenant_id`),
  KEY `idx_invite_email` (`email`),
  KEY `idx_invite_expires` (`expires_at`),
  KEY `branch_id` (`branch_id`),
  KEY `invited_by` (`invited_by`),
  KEY `accepted_user_id` (`accepted_admin_id`),
  CONSTRAINT `manager_invitations_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manager_invitations_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `manager_invitations_ibfk_3` FOREIGN KEY (`invited_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `manager_invitations_ibfk_4` FOREIGN KEY (`accepted_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `manual_bonuses` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mb_emp_month` (`employee_id`,`month`),
  KEY `idx_mb_tenant_month` (`tenant_id`,`month`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `manual_bonuses_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_bonuses_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_bonuses_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `manual_deductions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_md_emp_month` (`employee_id`,`month`),
  KEY `idx_md_tenant_month` (`tenant_id`,`month`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `manual_deductions_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_deductions_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_deductions_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL COMMENT 'Null = system-wide from super admin',
  `admin_id` int unsigned DEFAULT NULL,
  `employee_id` int unsigned DEFAULT NULL COMMENT 'For Employee-app recipients',
  `type` enum('general','attendance','payroll','leave','warning','system','invite','support','approval') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title_ar` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `body_ar` text COLLATE utf8mb4_unicode_ci,
  `data` json DEFAULT NULL,
  `sent_via` set('push','email','in_app') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'in_app',
  `read_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_tenant` (`tenant_id`),
  KEY `idx_notif_emp_read` (`employee_id`,`read_at`),
  KEY `idx_notif_type` (`type`),
  KEY `idx_notif_admin_read` (`admin_id`,`read_at`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `payroll` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `base_salary` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_deductions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_bonuses` decimal(12,2) NOT NULL DEFAULT '0.00',
  `net_salary` decimal(12,2) NOT NULL DEFAULT '0.00',
  `working_days` int unsigned NOT NULL DEFAULT '0',
  `present_days` int unsigned NOT NULL DEFAULT '0',
  `absent_days` int unsigned NOT NULL DEFAULT '0',
  `overtime_total_minutes` int unsigned NOT NULL DEFAULT '0',
  `breakdown` json DEFAULT NULL,
  `status` enum('draft','approved','paid') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` timestamp NULL DEFAULT NULL,
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_payroll_emp_month` (`employee_id`,`month`),
  KEY `idx_payroll_tenant_month` (`tenant_id`,`month`),
  KEY `idx_payroll_status` (`status`),
  KEY `branch_id` (`branch_id`),
  KEY `approved_by` (`approved_by`),
  CONSTRAINT `payroll_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `payroll_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `payroll_ibfk_3` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `payroll_ibfk_4` FOREIGN KEY (`approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `recurring_leaves` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `day_of_week` enum('saturday','sunday','monday','tuesday','wednesday','thursday','friday') COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'weekly_off',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_recleave_tenant` (`tenant_id`),
  KEY `branch_id` (`branch_id`),
  CONSTRAINT `recurring_leaves_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `recurring_leaves_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `required_document_categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `required_document_id` int unsigned NOT NULL,
  `category_id` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_rdoc_cat` (`required_document_id`,`category_id`),
  KEY `idx_rdc_tenant` (`tenant_id`),
  KEY `idx_rdc_category` (`category_id`,`tenant_id`),
  CONSTRAINT `required_document_categories_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `required_document_categories_ibfk_2` FOREIGN KEY (`required_document_id`) REFERENCES `required_documents` (`id`) ON DELETE CASCADE,
  CONSTRAINT `required_document_categories_ibfk_3` FOREIGN KEY (`category_id`) REFERENCES `employee_categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `required_document_employees` (
  `required_document_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `tenant_id` int unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`required_document_id`,`employee_id`),
  KEY `idx_rde_employee` (`employee_id`,`tenant_id`),
  KEY `idx_rde_tenant` (`tenant_id`),
  CONSTRAINT `required_document_employees_ibfk_1` FOREIGN KEY (`required_document_id`) REFERENCES `required_documents` (`id`) ON DELETE CASCADE,
  CONSTRAINT `required_document_employees_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `required_document_employees_ibfk_3` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `required_documents` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `expiry_days` int unsigned DEFAULT NULL COMMENT 'Days before expiry, null = no expiry',
  `is_required` tinyint(1) NOT NULL DEFAULT '1',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `notification_days_before` int DEFAULT '30' COMMENT 'Days before expiry to send notification',
  `category` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'general' COMMENT 'identity|contract|certificate|insurance|general',
  `sort_order` int DEFAULT '0',
  `scope_type` enum('all','branch','employees','category') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'all' COMMENT 'all=every employee, branch=single branch, employees=specific list, category=by employee category',
  `scope_branch_id` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_reqdoc_tenant` (`tenant_id`),
  KEY `idx_reqdoc_scope_branch` (`scope_branch_id`),
  CONSTRAINT `required_documents_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `shifts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'NULL = available for all branches',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'e.g. "Morning", "Evening", "Night"',
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_shift_tenant` (`tenant_id`),
  KEY `idx_shift_branch` (`branch_id`),
  CONSTRAINT `shifts_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shifts_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `employee_shift_schedule` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `shift_id` int unsigned DEFAULT NULL COMMENT 'NULL = rest / off day',
  `work_date` date NOT NULL,
  `status` enum('draft','published') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `created_by` int unsigned DEFAULT NULL COMMENT 'admin who last set this cell',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_sched_emp_date` (`employee_id`,`work_date`),
  KEY `idx_sched_tenant_date` (`tenant_id`,`work_date`),
  KEY `idx_sched_shift` (`shift_id`),
  KEY `idx_sched_admin` (`created_by`),
  CONSTRAINT `fk_sched_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sched_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sched_shift` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sched_admin` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `super_admin_audit_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned DEFAULT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payload` json DEFAULT NULL,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_saalog_admin` (`admin_id`),
  KEY `idx_saalog_action` (`action`),
  CONSTRAINT `super_admin_audit_log_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `super_admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `super_admin_sessions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned NOT NULL,
  `token_hash` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` timestamp NOT NULL,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token_hash` (`token_hash`),
  KEY `idx_session_hash` (`token_hash`),
  KEY `idx_session_admin` (`admin_id`),
  CONSTRAINT `super_admin_sessions_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `super_admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `super_admins` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` enum('readonly','admin','superadmin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'admin',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `last_login_at` timestamp NULL DEFAULT NULL,
  `last_login_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `tenants` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `timezone` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Africa/Cairo',
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'EGP',
  `country_code` CHAR(2) COLLATE utf8mb4_unicode_ci NULL DEFAULT 'EG' COMMENT 'ISO 3166-1 alpha-2; يحدّد مُصدِّر الرواتب الافتراضي',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `attendance_methods` json DEFAULT NULL COMMENT 'Enabled methods, e.g. ["qr_gps","manual"]',
  `manual_attendance_admin_ids` json DEFAULT NULL COMMENT 'NULL = all admins with manage_attendance; array = restricted set',
  `allow_offline_attendance` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Company-level toggle for offline attendance capture',
  `default_annual_leave_days` int NOT NULL DEFAULT '0' COMMENT 'Default annual leave entitlement for all employees (0 until admin sets it)',
  `leave_carryover_max_days` int DEFAULT NULL COMMENT 'NULL = no carryover; number = max days carried to next year',
  `auto_rollover_enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = cron runs year-end rollover automatically on Jan 1',
  `apply_legal_seniority_entitlement` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = bump annual entitlement to >=30 days after 10 years service (Egyptian labour law)',
  `cycle_start_day` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Attendance cycle start day (1-28); cycle labeled by its end month',
  `week_start_day` tinyint unsigned NOT NULL DEFAULT '6' COMMENT 'Weekly schedule start weekday (ISO: 1=Mon..7=Sun, default 6=Sat)',
  `commercial_register` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Commercial registration number shown on letters',
  `company_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_phone` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `warnings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `type` enum('verbal','written','final','device_change','system') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'verbal',
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `issued_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_warn_tenant` (`tenant_id`),
  KEY `idx_warn_emp` (`employee_id`),
  KEY `issued_by` (`issued_by`),
  CONSTRAINT `warnings_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `warnings_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `warnings_ibfk_3` FOREIGN KEY (`issued_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `payroll_statutory_settings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `social_insurance_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `si_employee_rate` decimal(5,2) DEFAULT NULL,
  `si_min_wage` decimal(12,2) DEFAULT NULL,
  `si_max_wage` decimal(12,2) DEFAULT NULL,
  `income_tax_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `income_tax_brackets` json DEFAULT NULL,
  `tax_personal_exemption` decimal(12,2) DEFAULT NULL,
  `eosb_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `eosb_days_per_year` decimal(5,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_statutory_tenant` (`tenant_id`),
  CONSTRAINT `fk_statutory_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

CREATE TABLE IF NOT EXISTS `employee_loans` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `type` enum('loan','advance') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'loan',
  `total_amount` decimal(12,2) NOT NULL,
  `installment_amount` decimal(12,2) NOT NULL,
  `installments_count` int unsigned NOT NULL DEFAULT '1',
  `installments_paid` int unsigned NOT NULL DEFAULT '0',
  `start_month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `status` enum('pending','active','completed','cancelled','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_by` int unsigned DEFAULT NULL,
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_loan_tenant_status` (`tenant_id`,`status`),
  KEY `idx_loan_employee` (`employee_id`),
  KEY `created_by` (`created_by`),
  KEY `approved_by` (`approved_by`),
  CONSTRAINT `employee_loans_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_loans_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_loans_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `employee_loans_ibfk_4` FOREIGN KEY (`approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

CREATE TABLE IF NOT EXISTS `loan_installments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `loan_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `seq` int unsigned NOT NULL DEFAULT '1',
  `amount` decimal(12,2) NOT NULL,
  `status` enum('pending','paid') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_loan_month` (`loan_id`,`month`),
  KEY `idx_inst_emp_month` (`employee_id`,`month`,`status`),
  KEY `idx_inst_tenant` (`tenant_id`),
  CONSTRAINT `loan_installments_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `loan_installments_ibfk_2` FOREIGN KEY (`loan_id`) REFERENCES `employee_loans` (`id`) ON DELETE CASCADE,
  CONSTRAINT `loan_installments_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

CREATE TABLE IF NOT EXISTS `asset_custody` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `type` enum('money','equipment','device','vehicle','document','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'equipment',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `value` decimal(12,2) DEFAULT NULL,
  `currency` varchar(8) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SAR',
  `serial_no` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` int unsigned NOT NULL DEFAULT '1',
  `assign_photo_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `return_photo_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('assigned','return_requested','returned') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'assigned',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `return_note` text COLLATE utf8mb4_unicode_ci,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `assigned_at` date NOT NULL,
  `assigned_by` int unsigned DEFAULT NULL,
  `return_requested_at` timestamp NULL DEFAULT NULL,
  `returned_at` timestamp NULL DEFAULT NULL,
  `return_approved_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_asset_tenant_status` (`tenant_id`,`status`),
  KEY `idx_asset_employee` (`employee_id`),
  KEY `assigned_by` (`assigned_by`),
  KEY `return_approved_by` (`return_approved_by`),
  CONSTRAINT `asset_custody_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `asset_custody_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `asset_custody_ibfk_3` FOREIGN KEY (`assigned_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `asset_custody_ibfk_4` FOREIGN KEY (`return_approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- Seed data
-- ============================================

INSERT IGNORE INTO `super_admins` (`username`, `password_hash`, `display_name`, `role`, `is_active`) VALUES
('superadmin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Super Admin', 'superadmin', 1);
-- Password: password

CREATE TABLE IF NOT EXISTS `support_tickets` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `opened_by_admin_id` int unsigned NOT NULL COMMENT 'admins.id who opened it',
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category` enum('technical','billing','feature_request','account','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'other',
  `priority` enum('low','normal','high','urgent') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'normal',
  `status` enum('open','pending_support','pending_user','resolved','closed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `assigned_super_admin_id` int unsigned DEFAULT NULL COMMENT 'super_admins.id handling it',
  `last_message_at` timestamp NULL DEFAULT NULL,
  `last_message_preview` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `unread_for_user` tinyint(1) NOT NULL DEFAULT 0,
  `unread_for_support` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_support_tickets_tenant` (`tenant_id`,`status`),
  KEY `idx_support_tickets_opened_by` (`opened_by_admin_id`),
  KEY `idx_support_tickets_status` (`status`,`last_message_at`),
  CONSTRAINT `support_tickets_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `support_tickets_ibfk_2` FOREIGN KEY (`opened_by_admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `support_messages` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `ticket_id` int unsigned NOT NULL,
  `sender_type` enum('user','support','system') COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_admin_id` int unsigned DEFAULT NULL COMMENT 'admins.id if sender_type=user',
  `sender_super_admin_id` int unsigned DEFAULT NULL COMMENT 'super_admins.id if sender_type=support',
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `attachment_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_support_messages_ticket` (`ticket_id`,`id`),
  CONSTRAINT `support_messages_ibfk_1` FOREIGN KEY (`ticket_id`) REFERENCES `support_tickets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ ATS ============

CREATE TABLE IF NOT EXISTS `job_openings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `title` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `department` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `employment_type` enum('full_time','part_time','contract','temporary') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'full_time',
  `openings_count` int unsigned NOT NULL DEFAULT '1',
  `status` enum('open','on_hold','closed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_job_tenant_status` (`tenant_id`,`status`),
  KEY `idx_job_branch` (`branch_id`),
  CONSTRAINT `job_openings_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `job_openings_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `job_openings_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `candidates` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `job_opening_id` int unsigned DEFAULT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(190) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cv_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'referral|walk_in|agency|manual...',
  `stage` enum('applied','screening','interview','offer','hired','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'applied',
  `expected_salary` decimal(12,2) DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `converted_employee_id` int unsigned DEFAULT NULL COMMENT 'set when stage=hired and converted',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cand_tenant_stage` (`tenant_id`,`stage`),
  KEY `idx_cand_job` (`job_opening_id`),
  KEY `idx_cand_emp` (`converted_employee_id`),
  CONSTRAINT `candidates_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `candidates_ibfk_2` FOREIGN KEY (`job_opening_id`) REFERENCES `job_openings` (`id`) ON DELETE SET NULL,
  CONSTRAINT `candidates_ibfk_3` FOREIGN KEY (`converted_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `candidates_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ ONBOARDING ============

CREATE TABLE IF NOT EXISTS `onboarding_templates` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title_ar` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `task_type` enum('document','asset','account','generic') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'generic',
  `description` text COLLATE utf8mb4_unicode_ci,
  `sort_order` int unsigned NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_onbtpl_tenant` (`tenant_id`,`is_active`,`sort_order`),
  CONSTRAINT `onboarding_templates_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `onboarding_tasks` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `template_id` int unsigned DEFAULT NULL COMMENT 'source template row, NULL for manually added',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `task_type` enum('document','asset','account','generic') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'generic',
  `status` enum('pending','completed','skipped') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `sort_order` int unsigned NOT NULL DEFAULT '0',
  `completed_by` int unsigned DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_onbtask_tenant_emp` (`tenant_id`,`employee_id`,`status`),
  CONSTRAINT `onboarding_tasks_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `onboarding_tasks_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `onboarding_tasks_ibfk_3` FOREIGN KEY (`template_id`) REFERENCES `onboarding_templates` (`id`) ON DELETE SET NULL,
  CONSTRAINT `onboarding_tasks_ibfk_4` FOREIGN KEY (`completed_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ PERFORMANCE MANAGEMENT ============

CREATE TABLE IF NOT EXISTS `performance_cycles` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_ar` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `period_type` enum('monthly','quarterly','semi_annual','annual','custom') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'quarterly',
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `status` enum('draft','active','closed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pcycle_tenant_status` (`tenant_id`,`status`),
  CONSTRAINT `performance_cycles_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_cycles_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `performance_goals` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `cycle_id` int unsigned DEFAULT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `metric` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_value` decimal(14,2) DEFAULT NULL,
  `current_value` decimal(14,2) NOT NULL DEFAULT '0.00',
  `weight` tinyint unsigned NOT NULL DEFAULT '0',
  `progress` tinyint unsigned NOT NULL DEFAULT '0',
  `status` enum('not_started','in_progress','completed','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'not_started',
  `due_date` date DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pgoal_tenant_emp` (`tenant_id`,`employee_id`,`status`),
  KEY `idx_pgoal_cycle` (`cycle_id`),
  CONSTRAINT `performance_goals_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_goals_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_goals_ibfk_3` FOREIGN KEY (`cycle_id`) REFERENCES `performance_cycles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `performance_goals_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `performance_reviews` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `cycle_id` int unsigned DEFAULT NULL,
  `reviewer_id` int unsigned DEFAULT NULL,
  `reviewer_type` enum('manager','self','peer','subordinate') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'manager',
  `rating` decimal(3,2) DEFAULT NULL,
  `strengths` text COLLATE utf8mb4_unicode_ci,
  `areas_for_improvement` text COLLATE utf8mb4_unicode_ci,
  `review` text COLLATE utf8mb4_unicode_ci,
  `status` enum('draft','submitted') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'submitted',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_prev_tenant_emp` (`tenant_id`,`employee_id`),
  KEY `idx_prev_cycle` (`cycle_id`),
  CONSTRAINT `performance_reviews_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_reviews_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_reviews_ibfk_3` FOREIGN KEY (`cycle_id`) REFERENCES `performance_cycles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `performance_reviews_ibfk_4` FOREIGN KEY (`reviewer_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============ ANALYTICS DASHBOARDS ============
CREATE TABLE IF NOT EXISTS `analytics_dashboards` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `admin_id` int unsigned NOT NULL COMMENT 'صاحب اللوحة — لكل مسؤول لوحته',
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Default',
  `layout` json NOT NULL COMMENT 'مصفوفة widgets: [{key,type,filters,position,size}]',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dash_tenant_admin` (`tenant_id`,`admin_id`),
  CONSTRAINT `analytics_dashboards_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `analytics_dashboards_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ SCHEDULING INTELLIGENCE ============

CREATE TABLE IF NOT EXISTS `employee_availability` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `kind` enum('weekly','date') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'weekly',
  `day_of_week` tinyint unsigned DEFAULT NULL COMMENT '0=Sun..6=Sat',
  `specific_date` date DEFAULT NULL COMMENT 'for kind=date',
  `availability` enum('available','preferred','unavailable') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'available',
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_avail_tenant_emp` (`tenant_id`,`employee_id`,`kind`),
  KEY `idx_avail_date` (`specific_date`),
  CONSTRAINT `employee_availability_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_availability_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `open_shifts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'NULL = all branches eligible',
  `shift_id` int unsigned NOT NULL,
  `work_date` date NOT NULL,
  `slots` tinyint unsigned NOT NULL DEFAULT '1',
  `slots_filled` tinyint unsigned NOT NULL DEFAULT '0',
  `status` enum('open','filled','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `notes` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_openshift_tenant_status` (`tenant_id`,`status`,`work_date`),
  KEY `idx_openshift_branch` (`branch_id`),
  CONSTRAINT `open_shifts_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_3` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `open_shift_claims` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `open_shift_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `status` enum('pending','approved','rejected','withdrawn') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `decided_by` int unsigned DEFAULT NULL,
  `decided_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_claim_shift_emp` (`open_shift_id`,`employee_id`),
  KEY `idx_claim_tenant_status` (`tenant_id`,`status`),
  KEY `idx_claim_employee` (`employee_id`),
  CONSTRAINT `open_shift_claims_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_2` FOREIGN KEY (`open_shift_id`) REFERENCES `open_shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_4` FOREIGN KEY (`decided_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `shift_swap_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `requester_employee_id` int unsigned NOT NULL,
  `requester_date` date NOT NULL,
  `target_employee_id` int unsigned NOT NULL,
  `target_date` date NOT NULL,
  `status` enum('pending_target','pending_manager','approved','rejected','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending_target',
  `requester_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_responded_at` timestamp NULL DEFAULT NULL,
  `decided_by` int unsigned DEFAULT NULL,
  `decided_at` timestamp NULL DEFAULT NULL,
  `decision_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_swap_tenant_status` (`tenant_id`,`status`),
  KEY `idx_swap_requester` (`requester_employee_id`),
  KEY `idx_swap_target` (`target_employee_id`),
  CONSTRAINT `shift_swap_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shift_swap_requests_ibfk_2` FOREIGN KEY (`requester_employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shift_swap_requests_ibfk_3` FOREIGN KEY (`target_employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shift_swap_requests_ibfk_4` FOREIGN KEY (`decided_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- Engagement Module — Announcements + Kudos + Surveys/eNPS
-- Mirror of migrations/2026_06_07_engagement.sql
-- ============================================================

-- ============ ANNOUNCEMENTS ============
CREATE TABLE IF NOT EXISTS `announcements` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title_ar` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `body_ar` text COLLATE utf8mb4_unicode_ci,
  `category` enum('general','policy','event','celebration','urgent') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general',
  `audience_type` enum('all','branch','category','employee') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'all',
  `audience_id` int unsigned DEFAULT NULL COMMENT 'branch_id | employee_category_id | employee_id depending on audience_type; null for all',
  `is_pinned` tinyint(1) NOT NULL DEFAULT '0',
  `status` enum('draft','published','archived') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `published_at` timestamp NULL DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ann_tenant_status` (`tenant_id`,`status`,`published_at`),
  KEY `idx_ann_audience` (`tenant_id`,`audience_type`,`audience_id`),
  CONSTRAINT `announcements_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `announcements_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ ANNOUNCEMENT READ RECEIPTS ============
CREATE TABLE IF NOT EXISTS `announcement_reads` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `announcement_id` int unsigned NOT NULL,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `read_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_ann_emp` (`announcement_id`,`employee_id`),
  KEY `idx_annread_tenant` (`tenant_id`),
  CONSTRAINT `announcement_reads_ibfk_1` FOREIGN KEY (`announcement_id`) REFERENCES `announcements` (`id`) ON DELETE CASCADE,
  CONSTRAINT `announcement_reads_ibfk_2` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `announcement_reads_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ KUDOS ============
CREATE TABLE IF NOT EXISTS `kudos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `recipient_employee_id` int unsigned NOT NULL,
  `sender_employee_id` int unsigned DEFAULT NULL COMMENT 'Sender is an employee from the employee app',
  `sender_admin_id` int unsigned DEFAULT NULL COMMENT 'Sender is an admin from medjat_admin',
  `badge` enum('teamwork','innovation','leadership','customer_service','above_beyond','reliability','thank_you') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'thank_you',
  `message` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `visibility` enum('public','private') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'public',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_kudos_tenant_recipient` (`tenant_id`,`recipient_employee_id`),
  KEY `idx_kudos_tenant_public` (`tenant_id`,`visibility`,`created_at`),
  CONSTRAINT `kudos_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `kudos_ibfk_2` FOREIGN KEY (`recipient_employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `kudos_ibfk_3` FOREIGN KEY (`sender_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `kudos_ibfk_4` FOREIGN KEY (`sender_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ SURVEYS ============
CREATE TABLE IF NOT EXISTS `surveys` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title_ar` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `type` enum('enps','pulse','custom') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'custom',
  `is_anonymous` tinyint(1) NOT NULL DEFAULT '1',
  `audience_type` enum('all','branch','category') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'all',
  `audience_id` int unsigned DEFAULT NULL,
  `status` enum('draft','active','closed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_survey_tenant_status` (`tenant_id`,`status`),
  CONSTRAINT `surveys_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `surveys_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ SURVEY QUESTIONS ============
CREATE TABLE IF NOT EXISTS `survey_questions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `survey_id` int unsigned NOT NULL,
  `tenant_id` int unsigned NOT NULL,
  `question` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `question_ar` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `qtype` enum('enps','rating','scale','text','single_choice','multi_choice') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'rating',
  `options` json DEFAULT NULL COMMENT 'For choice types: ["..","..."]',
  `is_required` tinyint(1) NOT NULL DEFAULT '1',
  `sort_order` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_sq_survey` (`survey_id`,`sort_order`),
  KEY `idx_sq_tenant` (`tenant_id`),
  CONSTRAINT `survey_questions_ibfk_1` FOREIGN KEY (`survey_id`) REFERENCES `surveys` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_questions_ibfk_2` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ SURVEY RESPONSES ============
CREATE TABLE IF NOT EXISTS `survey_responses` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `survey_id` int unsigned NOT NULL,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned DEFAULT NULL COMMENT 'null for anonymous surveys',
  PRIMARY KEY (`id`),
  KEY `idx_sr_survey` (`survey_id`),
  KEY `idx_sr_tenant` (`tenant_id`),
  CONSTRAINT `survey_responses_ibfk_1` FOREIGN KEY (`survey_id`) REFERENCES `surveys` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_responses_ibfk_2` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_responses_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ SURVEY ANSWERS ============
CREATE TABLE IF NOT EXISTS `survey_answers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `response_id` int unsigned NOT NULL,
  `question_id` int unsigned NOT NULL,
  `tenant_id` int unsigned NOT NULL,
  `answer_value` int DEFAULT NULL COMMENT 'For numeric types: enps 0-10 / rating 1-5 / scale',
  `answer_text` text COLLATE utf8mb4_unicode_ci COMMENT 'Text or JSON for multi_choice options',
  PRIMARY KEY (`id`),
  KEY `idx_sa_response` (`response_id`),
  KEY `idx_sa_question` (`question_id`),
  KEY `idx_sa_tenant` (`tenant_id`),
  CONSTRAINT `survey_answers_ibfk_1` FOREIGN KEY (`response_id`) REFERENCES `survey_responses` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_answers_ibfk_2` FOREIGN KEY (`question_id`) REFERENCES `survey_questions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_answers_ibfk_3` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ SURVEY COMPLETIONS (prevents duplicate submission while preserving anonymity) ============
CREATE TABLE IF NOT EXISTS `survey_completions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `survey_id` int unsigned NOT NULL,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `completed_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_survey_emp` (`survey_id`,`employee_id`),
  KEY `idx_sc_tenant` (`tenant_id`),
  CONSTRAINT `survey_completions_ibfk_1` FOREIGN KEY (`survey_id`) REFERENCES `surveys` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_completions_ibfk_2` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `survey_completions_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ APPROVAL CHAINS ============
CREATE TABLE IF NOT EXISTS `approval_chains` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_ar` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `request_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'leave|loan|bonus|warning|document|generic',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `min_amount` decimal(14,2) DEFAULT NULL COMMENT 'Condition: context amount >= this (NULL=no min)',
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Condition: request branch = this (NULL=all branches)',
  `priority` int NOT NULL DEFAULT '0' COMMENT 'Higher wins when multiple chains match',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_chain_tenant_type_active` (`tenant_id`,`request_type`,`is_active`),
  KEY `idx_chain_branch` (`branch_id`),
  CONSTRAINT `approval_chains_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chains_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chains_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ APPROVAL CHAIN STEPS ============
CREATE TABLE IF NOT EXISTS `approval_chain_steps` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `chain_id` int unsigned NOT NULL,
  `step_order` tinyint unsigned NOT NULL COMMENT 'Starts at 1, sequential',
  `approver_type` enum('role','admin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'role',
  `approver_role` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'When approver_type=role',
  `approver_admin_id` int unsigned DEFAULT NULL COMMENT 'When approver_type=admin',
  `label` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Descriptive name for the step',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_chain_step_order` (`chain_id`,`step_order`),
  KEY `idx_step_tenant` (`tenant_id`),
  KEY `idx_step_admin` (`approver_admin_id`),
  CONSTRAINT `approval_chain_steps_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chain_steps_ibfk_2` FOREIGN KEY (`chain_id`) REFERENCES `approval_chains` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chain_steps_ibfk_3` FOREIGN KEY (`approver_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ APPROVAL REQUESTS ============
CREATE TABLE IF NOT EXISTS `approval_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `chain_id` int unsigned DEFAULT NULL COMMENT 'Referential; SET NULL if chain deleted (steps are snapshot)',
  `entity_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` int unsigned NOT NULL,
  `requested_by_admin_id` int unsigned DEFAULT NULL,
  `requested_by_employee_id` int unsigned DEFAULT NULL,
  `context_amount` decimal(14,2) DEFAULT NULL COMMENT 'Amount used for conditional matching (audit)',
  `current_step` tinyint unsigned NOT NULL DEFAULT '1',
  `total_steps` tinyint unsigned NOT NULL,
  `status` enum('pending','approved','rejected','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `decided_at` timestamp NULL DEFAULT NULL COMMENT 'Final decision timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_req_tenant_status` (`tenant_id`,`status`),
  KEY `idx_req_entity` (`tenant_id`,`entity_type`,`entity_id`),
  CONSTRAINT `approval_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_requests_ibfk_2` FOREIGN KEY (`chain_id`) REFERENCES `approval_chains` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ APPROVAL REQUEST STEPS ============
CREATE TABLE IF NOT EXISTS `approval_request_steps` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `request_id` int unsigned NOT NULL,
  `step_order` tinyint unsigned NOT NULL,
  `approver_type` enum('role','admin') COLLATE utf8mb4_unicode_ci NOT NULL,
  `approver_role` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `approver_admin_id` int unsigned DEFAULT NULL,
  `label` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('pending','approved','rejected','skipped') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `decided_by` int unsigned DEFAULT NULL COMMENT 'admins.id who decided this step',
  `decided_at` timestamp NULL DEFAULT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_reqstep_order` (`request_id`,`step_order`),
  KEY `idx_reqstep_tenant_status` (`tenant_id`,`status`),
  KEY `idx_reqstep_admin` (`approver_admin_id`),
  CONSTRAINT `approval_request_steps_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_request_steps_ibfk_2` FOREIGN KEY (`request_id`) REFERENCES `approval_requests` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_request_steps_ibfk_3` FOREIGN KEY (`approver_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ BREAK REQUESTS ============
CREATE TABLE IF NOT EXISTS `break_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `date` date NOT NULL COMMENT 'يوم العمل المطلوب فيه الإذن/البريك',
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `duration_minutes` smallint unsigned NOT NULL DEFAULT 0 COMMENT 'محسوبة في PHP وقت الإدراج',
  `type` varchar(100)
        COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'نوع/وصف الطلب يُدخله المستخدم بحرية',
  `deduct_from_salary` tinyint(1) NOT NULL DEFAULT 0
        COMMENT 'هل يُخصم من الراتب بنظام الساعة؟ يُحدَّد عند الإنشاء أو الموافقة',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `status` enum('pending','approved','rejected','postponed','cancelled')
        COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `decided_by` int unsigned DEFAULT NULL COMMENT 'admins.id الذي اتخذ القرار',
  `decided_at` timestamp NULL DEFAULT NULL,
  `decision_note` text COLLATE utf8mb4_unicode_ci COMMENT 'سبب الرفض / ملاحظة الموافقة أو التأجيل',
  `suggested_date` date DEFAULT NULL COMMENT 'وقت بديل مقترح عند التأجيل',
  `suggested_start_time` time DEFAULT NULL,
  `suggested_end_time` time DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_break_tenant` (`tenant_id`),
  KEY `idx_break_emp_date` (`employee_id`,`date`),
  KEY `idx_break_status` (`status`),
  KEY `decided_by` (`decided_by`),
  CONSTRAINT `break_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `break_requests_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `break_requests_ibfk_3` FOREIGN KEY (`decided_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

