-- ============================================
-- Medjat — Database Schema (snapshot)
-- Regenerated from live DB to match reality. MySQL 8.0 compatible.
-- Non-destructive: CREATE TABLE IF NOT EXISTS (safe to re-run).
-- Date: 2026-05-22 (updated: payroll_statutory_settings)
-- ============================================

SET FOREIGN_KEY_CHECKS = 0;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `activation_codes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `code_hash` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'SHA-256 of the 6-char code',
  `code_preview` varchar(6) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Plain code, shown to admin until used',
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Phone number to verify against',
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp NULL DEFAULT NULL,
  `used_device_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `used_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attempt_count` int unsigned NOT NULL DEFAULT '0',
  `generated_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_actcode_tenant` (`tenant_id`),
  KEY `idx_actcode_emp` (`employee_id`),
  KEY `idx_actcode_hash` (`code_hash`),
  KEY `idx_actcode_expires` (`expires_at`),
  KEY `generated_by` (`generated_by`),
  CONSTRAINT `activation_codes_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `activation_codes_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `activation_codes_ibfk_3` FOREIGN KEY (`generated_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
CREATE TABLE IF NOT EXISTS `admin_sessions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned NOT NULL,
  `token_hash` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `refresh_token_hash` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform` enum('android','ios','web') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_at` timestamp NOT NULL,
  `revoked_at` timestamp NULL DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token_hash` (`token_hash`),
  KEY `idx_session_hash` (`token_hash`),
  KEY `idx_session_expires` (`expires_at`),
  KEY `idx_session_admin` (`admin_id`),
  CONSTRAINT `admin_sessions_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
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
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Null for Google/Apple-only accounts',
  `auth_provider` enum('email','google','apple','employee_code') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'email',
  `role` enum('general_manager','hr','branch_manager','attendance','viewer','employee','pending') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `two_factor_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `two_factor_secret` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `last_login_at` timestamp NULL DEFAULT NULL,
  `last_login_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
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
  `check_out_latitude` decimal(10,7) DEFAULT NULL,
  `check_out_longitude` decimal(10,7) DEFAULT NULL,
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
  `is_rooted_device` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Root/jailbreak flag reported by client (advisory)',
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
CREATE TABLE IF NOT EXISTS `attendance_stations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned NOT NULL,
  `device_token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `activation_qr_payload` text COLLATE utf8mb4_unicode_ci,
  `activation_qr_expires_at` timestamp NULL DEFAULT NULL,
  `is_activated` tinyint(1) NOT NULL DEFAULT '0',
  `activated_at` timestamp NULL DEFAULT NULL,
  `last_sync_at` timestamp NULL DEFAULT NULL,
  `last_heartbeat_at` timestamp NULL DEFAULT NULL,
  `last_known_lat` decimal(10,7) DEFAULT NULL,
  `last_known_lng` decimal(10,7) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `is_locked` tinyint(1) NOT NULL DEFAULT '0',
  `locked_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `locked_at` timestamp NULL DEFAULT NULL,
  `created_by_user_id` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `deactivated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `device_token` (`device_token`),
  KEY `idx_station_tenant` (`tenant_id`),
  KEY `idx_station_branch` (`branch_id`),
  KEY `idx_station_token` (`device_token`),
  KEY `created_by_user_id` (`created_by_user_id`),
  CONSTRAINT `attendance_stations_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `attendance_stations_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `attendance_stations_ibfk_3` FOREIGN KEY (`created_by_user_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
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
  `attendance_method` enum('qr_gps','gps_only') COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Branch-level override; NULL inherits tenants.attendance_method',
  `attendance_methods` json DEFAULT NULL COMMENT 'Branch override; NULL inherits tenants.attendance_methods',
  `gps_radius_meters` int unsigned NOT NULL DEFAULT '100' COMMENT 'Allowed GPS radius for check-in in meters',
  `cycle_start_day` tinyint unsigned DEFAULT NULL COMMENT 'Per-branch override of attendance cycle start day; NULL = inherit company',
  `station_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `station_methods` enum('face_only','fingerprint_only','both_available') COLLATE utf8mb4_unicode_ci DEFAULT 'face_only',
  `station_gps_radius_meters` int DEFAULT '30',
  `station_confidence_threshold` decimal(3,2) DEFAULT '0.85',
  `station_admin_pin_hash` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `station_anti_spoofing_enabled` tinyint(1) NOT NULL DEFAULT '1',
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
  `shift_id` int unsigned DEFAULT NULL,
  `shift_type` enum('fixed','rotating') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'fixed',
  `status` enum('pending_activation','active','terminated','on_leave','suspended') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending_activation',
  `profile_image` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_embedding` blob COMMENT 'For ML Kit face verification (v2)',
  `bank_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bank_account_number` varchar(34) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bank_iban` varchar(34) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bank_swift` varchar(11) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_photo_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_enrolled_at` datetime DEFAULT NULL,
  `face_quality_score` decimal(4,3) DEFAULT NULL,
  `fingerprint_template` blob,
  `fingerprint_enrolled_at` datetime DEFAULT NULL,
  `biometric_enrollment_status` enum('not_enrolled','face_only','fingerprint_only','both') COLLATE utf8mb4_unicode_ci DEFAULT 'not_enrolled',
  `has_linked_account` tinyint(1) DEFAULT '0',
  `deleted_at` timestamp NULL DEFAULT NULL,
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
  `is_paid` tinyint(1) NOT NULL DEFAULT '1',
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
  `type` enum('general','attendance','payroll','leave','warning','system','subscription','invite') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general',
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
CREATE TABLE IF NOT EXISTS `payment_transactions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `subscription_id` int unsigned DEFAULT NULL,
  `plan_id` int unsigned DEFAULT NULL,
  `amount` decimal(12,2) NOT NULL,
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'EGP',
  `provider` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'paymob',
  `provider_order_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `provider_transaction_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'card, wallet, kiosk, etc.',
  `status` enum('pending','success','failed','refunded','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `payload` json DEFAULT NULL,
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pay_tenant` (`tenant_id`),
  KEY `idx_pay_status` (`status`),
  KEY `idx_pay_provider_order` (`provider_order_id`),
  KEY `subscription_id` (`subscription_id`),
  KEY `plan_id` (`plan_id`),
  CONSTRAINT `payment_transactions_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `payment_transactions_ibfk_2` FOREIGN KEY (`subscription_id`) REFERENCES `subscriptions` (`id`) ON DELETE SET NULL,
  CONSTRAINT `payment_transactions_ibfk_3` FOREIGN KEY (`plan_id`) REFERENCES `plans` (`id`) ON DELETE SET NULL
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
  `leave_days` int unsigned NOT NULL DEFAULT '0',
  `late_total_minutes` int unsigned NOT NULL DEFAULT '0',
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
CREATE TABLE IF NOT EXISTS `plans` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_ar` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `max_employees` int unsigned NOT NULL DEFAULT '10',
  `max_branches` int unsigned NOT NULL DEFAULT '1',
  `features` json DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_plan_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
CREATE TABLE IF NOT EXISTS `station_recognition_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned NOT NULL,
  `station_id` int unsigned NOT NULL,
  `matched_employee_id` int unsigned DEFAULT NULL,
  `verification_method` enum('face','fingerprint','both') COLLATE utf8mb4_unicode_ci NOT NULL,
  `confidence_score` decimal(4,3) DEFAULT NULL,
  `result` enum('success','low_confidence','no_match','spoofing_detected','manual_fallback','too_soon') COLLATE utf8mb4_unicode_ci NOT NULL,
  `failure_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `captured_image_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gps_lat` decimal(10,7) DEFAULT NULL,
  `gps_lng` decimal(10,7) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_reclog_tenant` (`tenant_id`),
  KEY `idx_reclog_branch` (`branch_id`),
  KEY `idx_reclog_station` (`station_id`),
  KEY `idx_reclog_employee` (`matched_employee_id`),
  KEY `idx_reclog_created` (`created_at`),
  CONSTRAINT `station_recognition_logs_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `station_recognition_logs_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `station_recognition_logs_ibfk_3` FOREIGN KEY (`station_id`) REFERENCES `attendance_stations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `station_recognition_logs_ibfk_4` FOREIGN KEY (`matched_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `subscriptions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `plan_id` int unsigned NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `status` enum('active','expired','suspended','cancelled','trial') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  `payment_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `auto_renew` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_tenant_sub` (`tenant_id`),
  KEY `idx_sub_status` (`status`),
  KEY `plan_id` (`plan_id`),
  CONSTRAINT `subscriptions_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `subscriptions_ibfk_2` FOREIGN KEY (`plan_id`) REFERENCES `plans` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
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
  `two_factor_secret` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Mandatory TOTP for super admin',
  `two_factor_enabled` tinyint(1) NOT NULL DEFAULT '0',
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
  `domain` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `plan` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'starter' COMMENT 'Denormalized current plan name for fast checks',
  `timezone` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Africa/Cairo',
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'EGP',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `trial_ends_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `attendance_method` enum('qr_gps','gps_only') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'qr_gps' COMMENT 'Default attendance method for the tenant',
  `attendance_methods` json DEFAULT NULL COMMENT 'Enabled methods, e.g. ["qr_gps","manual","station"]',
  `manual_attendance_admin_ids` json DEFAULT NULL COMMENT 'NULL = all admins with manage_attendance; array = restricted set',
  `allow_offline_attendance` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Company-level toggle for offline attendance capture',
  `default_annual_leave_days` int NOT NULL DEFAULT '21' COMMENT 'Default annual leave entitlement for all employees',
  `leave_carryover_max_days` int DEFAULT NULL COMMENT 'NULL = no carryover; number = max days carried to next year',
  `cycle_start_day` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Attendance cycle start day (1-28); cycle labeled by its end month',
  `stamp_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Company stamp image for generated letters',
  `signature_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Authorized signatory image for generated letters',
  `commercial_register` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Commercial registration number shown on letters',
  `company_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_phone` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain` (`domain`)
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
  `si_employer_rate` decimal(5,2) DEFAULT NULL,
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

CREATE TABLE IF NOT EXISTS `expense_claims` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `category` enum('travel','meals','accommodation','supplies','medical','communication','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'other',
  `amount` decimal(12,2) NOT NULL,
  `currency` varchar(8) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SAR',
  `description` text COLLATE utf8mb4_unicode_ci,
  `expense_date` date NOT NULL,
  `receipt_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('pending','approved','rejected','reimbursed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `reviewed_by` int unsigned DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_exp_tenant_status` (`tenant_id`,`status`),
  KEY `idx_exp_employee` (`employee_id`),
  KEY `reviewed_by` (`reviewed_by`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `expense_claims_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `expense_claims_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `expense_claims_ibfk_3` FOREIGN KEY (`reviewed_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `expense_claims_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
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
  `status` enum('pending','active','completed','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
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

CREATE TABLE IF NOT EXISTS `document_templates` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `template_key` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'salary_certificate|employment_verification|bank_letter for system templates, NULL for custom',
  `name_ar` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_en` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body_ar` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Template body with {{placeholders}}',
  `body_en` text COLLATE utf8mb4_unicode_ci,
  `is_system` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = seeded default, cannot be deleted',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `sort_order` int NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_doctpl_tenant` (`tenant_id`),
  KEY `idx_doctpl_tenant_key` (`tenant_id`,`template_key`),
  CONSTRAINT `document_templates_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

CREATE TABLE IF NOT EXISTS `document_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `template_id` int unsigned DEFAULT NULL,
  `doc_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Snapshot of template_key/name at request time',
  `status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `extra_fields` json DEFAULT NULL COMMENT 'Free-form fields e.g. {"bank_name":"..","addressed_to":".."}',
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `pdf_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Generated PDF path once approved',
  `requested_by_employee` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = raised from employee app, 0 = issued by admin',
  `issued_by` int unsigned DEFAULT NULL COMMENT 'Admin who approved/issued',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_docreq_tenant_status` (`tenant_id`,`status`),
  KEY `idx_docreq_employee` (`employee_id`),
  KEY `idx_docreq_template` (`template_id`),
  KEY `issued_by` (`issued_by`),
  CONSTRAINT `document_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `document_requests_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `document_requests_ibfk_3` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL,
  CONSTRAINT `document_requests_ibfk_4` FOREIGN KEY (`issued_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- ============================================
-- Seed data
-- ============================================

INSERT IGNORE INTO `plans` (`name`, `name_ar`, `price`, `max_employees`, `max_branches`) VALUES
('starter',    'الباقة المبتدئة',   199.00, 10,     1),
('growth',     'باقة النمو',        399.00, 30,     3),
('pro',        'الباقة الاحترافية', 699.00, 100,    999999),
('enterprise', 'باقة المؤسسات',     0.00,   999999, 999999);

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

SET FOREIGN_KEY_CHECKS = 1;
