-- ============================================================
-- Medjat database schema
--
-- GENERATED from the live production database — do not hand-edit.
-- Regenerate with:
--   ssh medjat "mysqldump -umedjat -p... --no-data --skip-comments \
--     --skip-add-drop-table --routines \
--     --ignore-table=medjat.schema_migrations medjat" > schema.sql
--
-- This is a snapshot of the CURRENT schema, not a starting point that the
-- files in this directory then evolve. `migrate.sh --bootstrap` loads it into
-- an empty database and immediately records every migration as applied.
-- Never load it into a database that already has tables.
--
-- `schema_migrations` is deliberately NOT in here: migrate.sh owns that table
-- and creates it before loading this file.
-- ============================================================


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_devices` (
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
) ENGINE=InnoDB AUTO_INCREMENT=34 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_notification_prefs` (
  `admin_id` int unsigned NOT NULL,
  `tenant_id` int unsigned DEFAULT NULL,
  `prefs` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`admin_id`),
  KEY `idx_notif_prefs_tenant` (`tenant_id`),
  CONSTRAINT `admin_notification_prefs_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE,
  CONSTRAINT `admin_notification_prefs_chk_1` CHECK (json_valid(`prefs`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admins` (
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
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approval_chain_steps` (
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
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approval_chains` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_ar` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `request_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'leave|expense|loan|bonus|warning|document|generic',
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
  KEY `approval_chains_ibfk_3` (`created_by`),
  CONSTRAINT `approval_chains_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chains_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chains_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approval_request_steps` (
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
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `approval_requests` (
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
  KEY `approval_requests_ibfk_2` (`chain_id`),
  CONSTRAINT `approval_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_requests_ibfk_2` FOREIGN KEY (`chain_id`) REFERENCES `approval_chains` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `asset_custody` (
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
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance` (
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
  `check_in_method` enum('qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','device','manual','kiosk','offline') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps',
  `check_out_method` enum('qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','device','manual','kiosk','offline','auto') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recognition_method` enum('manual','qr_gps','mobile_face','device_fingerprint','device_face','device_card','device_password','station_face','station_fingerprint','station_both','station_qr') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recognition_confidence` decimal(4,3) DEFAULT NULL,
  `station_id` int unsigned DEFAULT NULL,
  `status` enum('present','absent','leave','holiday','weekly_off') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'present',
  `is_offline` tinyint(1) NOT NULL DEFAULT '0',
  `is_vpn` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'VPN detected on device at check-in (advisory)',
  `is_mock_location` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Mock-location flag reported by client (advisory)',
  `is_rooted_device` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Root/jailbreak flag reported by client (advisory)',
  `synced_at` timestamp NULL DEFAULT NULL COMMENT 'When offline record was synced',
  `recorded_by` int unsigned DEFAULT NULL COMMENT 'User who manually recorded this',
  `deduction_mode` enum('auto','days','amount') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto',
  `deduction_value` decimal(10,2) DEFAULT NULL,
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
) ENGINE=InnoDB AUTO_INCREMENT=211 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_devices` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `serial_number` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'SN as reported by the device, upper-cased',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `vendor` enum('zkteco','hikvision','other') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'zkteco',
  `model` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `firmware` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('unclaimed','active','disabled') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unclaimed',
  `direction_mode` enum('auto','device_status') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto',
  `min_interval_seconds` smallint unsigned NOT NULL DEFAULT '60',
  `clock_offset_minutes` smallint NOT NULL DEFAULT '0',
  `keep_unmatched` tinyint(1) NOT NULL DEFAULT '1',
  `debug_logging` tinyint(1) NOT NULL DEFAULT '0',
  `last_seen_at` datetime DEFAULT NULL,
  `last_ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_punch_at` datetime DEFAULT NULL,
  `user_count` smallint unsigned DEFAULT NULL COMMENT 'As last reported by the device',
  `claimed_by` int unsigned DEFAULT NULL,
  `claimed_at` datetime DEFAULT NULL,
  `first_seen_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_serial` (`serial_number`),
  KEY `idx_device_tenant` (`tenant_id`,`status`),
  KEY `idx_device_branch` (`tenant_id`,`branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_security_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `reason` enum('mock_location','rooted','jailbroken','vpn','gps_out_of_range','no_local_biometric') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` enum('blocked','flagged') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'blocked',
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `ip_address` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'android | ios',
  `app_version` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_seclog_tenant_date` (`tenant_id`,`created_at`),
  KEY `idx_seclog_employee` (`employee_id`),
  CONSTRAINT `seclog_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `seclog_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `admin_id` int unsigned DEFAULT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_tenant` (`tenant_id`),
  KEY `idx_audit_action` (`action`),
  KEY `idx_audit_target` (`target_type`,`target_id`),
  KEY `idx_audit_admin` (`admin_id`),
  CONSTRAINT `audit_log_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `audit_log_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `audit_log_chk_1` CHECK (json_valid(`payload`))
) ENGINE=InnoDB AUTO_INCREMENT=121 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bonus_rules` (
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
CREATE TABLE `branch_network_sightings` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `bssid` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ssid` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `client_ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `inside_geofence` tinyint(1) NOT NULL DEFAULT '0',
  `distance_meters` int DEFAULT NULL,
  `seen_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sighting_branch` (`tenant_id`,`branch_id`,`seen_at`),
  KEY `idx_sighting_bssid` (`tenant_id`,`branch_id`,`bssid`)
) ENGINE=InnoDB AUTO_INCREMENT=333 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `branch_networks` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned NOT NULL,
  `kind` enum('bssid','ip_v4','ip_cidr') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'bssid',
  `value` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'BSSID normalised to lower-case colon form, or an IPv4 / CIDR',
  `label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source` enum('captured','discovered','manual') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'discovered',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_branch_network` (`tenant_id`,`branch_id`,`kind`,`value`),
  KEY `idx_branch_network_lookup` (`tenant_id`,`branch_id`,`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `branches` (
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
  `attendance_methods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'Branch override; NULL inherits tenants.attendance_methods',
  `gps_radius_meters` int unsigned NOT NULL DEFAULT '100' COMMENT 'Allowed GPS radius for check-in in meters',
  `cycle_start_day` tinyint unsigned DEFAULT NULL COMMENT 'Per-branch override of attendance cycle start day; NULL = inherit company',
  `station_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `station_methods` enum('face_only','fingerprint_only','both_available') COLLATE utf8mb4_unicode_ci DEFAULT 'face_only',
  `station_gps_radius_meters` int DEFAULT '30',
  `station_confidence_threshold` decimal(3,2) DEFAULT '0.85',
  `station_admin_pin_hash` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `station_anti_spoofing_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `allow_offline_attendance` tinyint(1) DEFAULT NULL COMMENT 'NULL = inherit tenant; 1 = forced on; 0 = forced off',
  `face_match_threshold` decimal(4,3) DEFAULT NULL,
  `face_liveness_required` tinyint(1) DEFAULT NULL,
  `wifi_mode` enum('learning','enforcing','optional') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'learning = record only; enforcing = reject unknown networks; optional = GPS or WiFi',
  `wifi_match` enum('bssid','ip','either') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'bssid' COMMENT 'bssid = access point MAC; ip = public egress IP (works on iOS without entitlement)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `qr_code` (`qr_code`),
  KEY `idx_branch_tenant` (`tenant_id`),
  CONSTRAINT `branches_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `branches_chk_1` CHECK (json_valid(`attendance_methods`))
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `break_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `date` date NOT NULL COMMENT 'يوم العمل المطلوب فيه الإذن/البريك',
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `duration_minutes` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'محسوبة في PHP وقت الإدراج',
  `type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'نوع/وصف الطلب يُدخله المستخدم بحرية',
  `deduct_from_salary` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'هل يُخصم من الراتب بنظام الساعة؟ يُحدَّد عند الإنشاء أو الموافقة',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `status` enum('pending','approved','rejected','postponed','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
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
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bulk_adjustments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `kind` enum('bonus','deduction') COLLATE utf8mb4_unicode_ci NOT NULL,
  `scope_type` enum('all','branch','category','employee','shift') COLLATE utf8mb4_unicode_ci NOT NULL,
  `scope_id` int unsigned DEFAULT NULL COMMENT 'NULL for scope_type = all',
  `scope_name` varchar(190) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'snapshot label for display',
  `amount` decimal(12,2) NOT NULL COMMENT 'fixed money OR percent value (0-100)',
  `amount_type` enum('fixed','percent') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'fixed',
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ba_tenant_month` (`tenant_id`,`month`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `bulk_adjustments_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bulk_adjustments_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `candidates` (
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
  KEY `candidates_ibfk_4` (`created_by`),
  CONSTRAINT `candidates_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `candidates_ibfk_2` FOREIGN KEY (`job_opening_id`) REFERENCES `job_openings` (`id`) ON DELETE SET NULL,
  CONSTRAINT `candidates_ibfk_3` FOREIGN KEY (`converted_employee_id`) REFERENCES `employees` (`id`) ON DELETE SET NULL,
  CONSTRAINT `candidates_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `custom_roles` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `admin_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Scope: null = all branches',
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `permissions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_role_admin` (`tenant_id`,`admin_id`),
  KEY `idx_custrole_tenant` (`tenant_id`),
  KEY `user_id` (`admin_id`),
  KEY `branch_id` (`branch_id`),
  CONSTRAINT `custom_roles_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `custom_roles_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE,
  CONSTRAINT `custom_roles_ibfk_3` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `custom_roles_chk_1` CHECK (json_valid(`permissions`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deduction_rules` (
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
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_commands` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `device_id` int unsigned NOT NULL,
  `kind` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'sync_time, reboot, info, delete_user',
  `payload` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'The literal command line sent to the device',
  `state` enum('queued','sent','done','failed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'queued',
  `result_code` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sent_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_command_queue` (`device_id`,`state`,`id`),
  KEY `idx_command_tenant` (`tenant_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_protocol_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `device_id` int unsigned DEFAULT NULL,
  `serial_number` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `method` varchar(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `path` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `query_string` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `response` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `client_ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_protocol_device` (`device_id`,`id`),
  KEY `idx_protocol_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_punches` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL,
  `device_id` int unsigned NOT NULL,
  `device_user_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `employee_id` int unsigned DEFAULT NULL,
  `punched_at` datetime NOT NULL COMMENT 'Company local time (device wall clock + clock_offset_minutes)',
  `status_code` tinyint unsigned DEFAULT NULL COMMENT '0 in, 1 out, 2/3 break, 4/5 overtime',
  `verify_mode` tinyint unsigned DEFAULT NULL COMMENT '1 fingerprint, 4 card, 15 face, 0 password',
  `work_code` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direction` enum('in','out') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state` enum('applied','duplicate','unmatched','ignored','failed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unmatched',
  `note` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attendance_id` int unsigned DEFAULT NULL,
  `raw_line` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `received_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_punch` (`device_id`,`device_user_id`,`punched_at`),
  KEY `idx_punch_tenant_time` (`tenant_id`,`punched_at`),
  KEY `idx_punch_employee` (`tenant_id`,`employee_id`,`punched_at`),
  KEY `idx_punch_state` (`device_id`,`state`,`punched_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_users` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL,
  `device_id` int unsigned NOT NULL,
  `device_user_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'The PIN / User ID as stored on the device',
  `device_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Name as typed into the device, shown to help HR match people',
  `employee_id` int unsigned DEFAULT NULL,
  `card_number` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `privilege` tinyint unsigned DEFAULT NULL COMMENT '0 = user, 14 = device admin',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `linked_by` int unsigned DEFAULT NULL,
  `linked_at` datetime DEFAULT NULL,
  `last_punch_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_user` (`device_id`,`device_user_id`),
  KEY `idx_device_user_employee` (`tenant_id`,`employee_id`),
  KEY `idx_device_user_pending` (`tenant_id`,`device_id`,`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_activation_codes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `code` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Long opaque secret for join link / QR; same row as code',
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
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_allowances` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'housing|transport|food|communication|other (or custom key)',
  `label` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional human label, overrides the type translation in slips',
  `amount` decimal(12,2) NOT NULL,
  `start_month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM inclusive',
  `end_month` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'YYYY-MM inclusive; NULL = ongoing',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_alw_emp` (`employee_id`,`tenant_id`),
  KEY `idx_alw_tenant_active` (`tenant_id`,`start_month`,`end_month`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `fk_alw_admin` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_alw_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_alw_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_auth_tokens` (
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
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_availability` (
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
  KEY `employee_availability_ibfk_2` (`employee_id`),
  CONSTRAINT `employee_availability_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_availability_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `color` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `attendance_methods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'NULL = inherit; array = category override (unioned across an employees categories)',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_category_tenant_name` (`tenant_id`,`name`),
  KEY `idx_ecat_tenant` (`tenant_id`),
  CONSTRAINT `employee_categories_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_categories_chk_1` CHECK (json_valid(`attendance_methods`))
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_category_assignments` (
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
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_documents` (
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
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_loans` (
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
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_settlements` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `reason` enum('resignation','termination','end_of_contract','retirement','death','absconding','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'resignation',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `last_working_day` date NOT NULL,
  `hire_date` date DEFAULT NULL COMMENT 'Snapshot of service-start date used for the gratuity calc',
  `base_salary` decimal(12,2) NOT NULL DEFAULT '0.00',
  `daily_rate` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'base_salary / 30',
  `years_of_service` decimal(6,2) NOT NULL DEFAULT '0.00',
  `pending_salary` decimal(12,2) NOT NULL DEFAULT '0.00',
  `gratuity_days` decimal(7,2) NOT NULL DEFAULT '0.00',
  `gratuity_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `leave_balance_days` decimal(7,2) NOT NULL DEFAULT '0.00',
  `leave_encashment` decimal(12,2) NOT NULL DEFAULT '0.00',
  `other_additions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `outstanding_loans` decimal(12,2) NOT NULL DEFAULT '0.00',
  `other_deductions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_earnings` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_deductions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `net_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `line_items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'Custom editable rows [{label,kind,amount}]',
  `breakdown` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'Frozen computed snapshot captured at approval',
  `status` enum('draft','approved','paid') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `created_by` int unsigned DEFAULT NULL,
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_settlement_employee` (`tenant_id`,`employee_id`),
  KEY `idx_settlement_tenant` (`tenant_id`),
  KEY `idx_settlement_status` (`tenant_id`,`status`),
  KEY `fk_settlement_employee` (`employee_id`),
  KEY `fk_settlement_created_by` (`created_by`),
  KEY `fk_settlement_approved_by` (`approved_by`),
  CONSTRAINT `fk_settlement_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_settlement_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_settlement_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_settlement_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_settlements_chk_1` CHECK (json_valid(`line_items`)),
  CONSTRAINT `employee_settlements_chk_2` CHECK (json_valid(`breakdown`))
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_shift_schedule` (
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
  KEY `fk_sched_admin` (`created_by`),
  CONSTRAINT `fk_sched_admin` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_sched_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sched_shift` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sched_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_suspensions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `pay_mode` enum('unpaid','partial','full') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unpaid',
  `pay_percentage` decimal(5,2) DEFAULT NULL COMMENT 'Percent of salary paid during suspension when pay_mode=partial (0-100)',
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL COMMENT 'NULL = open-ended until manually ended',
  `status` enum('active','ended') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  `previous_status` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Employee status before suspension, restored on reactivation',
  `ended_at` datetime DEFAULT NULL,
  `ended_by` int unsigned DEFAULT NULL,
  `end_note` text COLLATE utf8mb4_unicode_ci,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_susp_tenant` (`tenant_id`),
  KEY `idx_susp_employee` (`employee_id`),
  KEY `idx_susp_status` (`status`),
  KEY `idx_susp_active` (`employee_id`,`status`),
  KEY `idx_susp_dates` (`employee_id`,`start_date`,`end_date`),
  KEY `fk_susp_created_by` (`created_by`),
  KEY `fk_susp_ended_by` (`ended_by`),
  CONSTRAINT `fk_susp_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_susp_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_susp_ended_by` FOREIGN KEY (`ended_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_susp_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employees` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `attendance_methods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'NULL = inherit (category/branch/tenant); array = employee override',
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
  `weekly_off_days` set('saturday','sunday','monday','tuesday','wednesday','thursday','friday') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `auto_terminate_at` date DEFAULT NULL COMMENT 'Auto-terminate the employee on this date (fixed-term workers); NULL = open-ended',
  `terminated_at` date DEFAULT NULL COMMENT 'تاريخ إنهاء الخدمة — يُستخدم لحساب الدوران والقوى العاملة',
  `shift_id` int unsigned DEFAULT NULL,
  `shift_type` enum('fixed','rotating') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'fixed',
  `status` enum('pending_activation','active','terminated','on_leave','suspended') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending_activation',
  `profile_image` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_embedding` blob COMMENT 'For ML Kit face verification (v2)',
  `face_photo_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_model_version` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Embedding model that produced face_embedding (e.g. mobilefacenet_v1)',
  `face_embedding_dim` smallint unsigned DEFAULT NULL COMMENT 'Number of dimensions in face_embedding',
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
  KEY `idx_emp_auto_terminate` (`tenant_id`,`status`,`auto_terminate_at`),
  KEY `idx_emp_terminated_at` (`tenant_id`,`terminated_at`),
  CONSTRAINT `employees_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employees_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `employees_ibfk_3` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_emp_shift` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE SET NULL,
  CONSTRAINT `employees_chk_1` CHECK (json_valid(`attendance_methods`))
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `face_challenges` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `nonce` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `challenge` enum('blink','turn_left','turn_right','smile') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `purpose` enum('check_in','check_out','enroll') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'check_in',
  `expires_at` datetime NOT NULL,
  `consumed_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_face_challenge_nonce` (`nonce`),
  KEY `idx_face_challenge_lookup` (`tenant_id`,`employee_id`,`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `face_verification_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `purpose` enum('check_in','check_out') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'check_in',
  `result` enum('matched','below_threshold','liveness_failed','not_enrolled','invalid_challenge','bad_embedding','model_mismatch') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `accepted` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Whether the punch was allowed through (log_only mode accepts below-threshold)',
  `match_score` decimal(4,3) DEFAULT NULL,
  `threshold` decimal(4,3) DEFAULT NULL,
  `liveness_passed` tinyint(1) NOT NULL DEFAULT '0',
  `challenge` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `selfie_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_mock_location` tinyint(1) NOT NULL DEFAULT '0',
  `is_rooted_device` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_fvl_employee` (`tenant_id`,`employee_id`,`created_at`),
  KEY `idx_fvl_result` (`tenant_id`,`result`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `holidays` (
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
CREATE TABLE `job_openings` (
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
  KEY `job_openings_ibfk_3` (`created_by`),
  CONSTRAINT `job_openings_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `job_openings_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL,
  CONSTRAINT `job_openings_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `late_deduction_tiers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `threshold_minutes` int unsigned NOT NULL,
  `deduction_days` decimal(5,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_tenant_threshold` (`tenant_id`,`threshold_minutes`),
  CONSTRAINT `late_deduction_tiers_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_carryover_policies` (
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
CREATE TABLE `leave_encashments` (
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
  CONSTRAINT `fk_enc_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_enc_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_year_balances` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `year` smallint NOT NULL,
  `entitlement_days` int NOT NULL COMMENT 'Entitlement for this year at row-generation time',
  `carried_over_days` int NOT NULL DEFAULT '0' COMMENT 'Days carried over from the previous year',
  `carryover_encashed_days` int NOT NULL DEFAULT '0' COMMENT 'Days that were cashed out for this year instead of carried',
  `carryover_expires_on` date DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_lyb_employee_year` (`employee_id`,`year`),
  KEY `idx_lyb_tenant` (`tenant_id`),
  CONSTRAINT `fk_lyb_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_lyb_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leaves` (
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
) ENGINE=InnoDB AUTO_INCREMENT=115 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `loan_installments` (
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
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_attempts` (
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
) ENGINE=InnoDB AUTO_INCREMENT=171 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `manager_invitations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('general_manager','hr','branch_manager','attendance','viewer') COLLATE utf8mb4_unicode_ci NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Scope: null = all branches',
  `permissions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
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
  CONSTRAINT `manager_invitations_ibfk_4` FOREIGN KEY (`accepted_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `manager_invitations_chk_1` CHECK (json_valid(`permissions`))
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `manual_bonuses` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `batch_id` int unsigned DEFAULT NULL,
  `amount` decimal(12,2) NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mb_emp_month` (`employee_id`,`month`),
  KEY `idx_mb_tenant_month` (`tenant_id`,`month`),
  KEY `created_by` (`created_by`),
  KEY `idx_mb_batch` (`batch_id`),
  CONSTRAINT `manual_bonuses_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_bonuses_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_bonuses_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `manual_bonuses_ibfk_batch` FOREIGN KEY (`batch_id`) REFERENCES `bulk_adjustments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `manual_deductions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `batch_id` int unsigned DEFAULT NULL,
  `amount` decimal(12,2) NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_md_emp_month` (`employee_id`,`month`),
  KEY `idx_md_tenant_month` (`tenant_id`,`month`),
  KEY `created_by` (`created_by`),
  KEY `idx_md_batch` (`batch_id`),
  CONSTRAINT `manual_deductions_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_deductions_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `manual_deductions_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `manual_deductions_ibfk_batch` FOREIGN KEY (`batch_id`) REFERENCES `bulk_adjustments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL COMMENT 'Null = system-wide from super admin',
  `admin_id` int unsigned DEFAULT NULL,
  `employee_id` int unsigned DEFAULT NULL COMMENT 'For Employee-app recipients',
  `type` enum('general','attendance','payroll','leave','warning','system','invite','support','approval') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title_ar` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `body_ar` text COLLATE utf8mb4_unicode_ci,
  `data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
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
  CONSTRAINT `notifications_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_chk_1` CHECK (json_valid(`data`))
) ENGINE=InnoDB AUTO_INCREMENT=167 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `onboarding_tasks` (
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
  KEY `onboarding_tasks_ibfk_2` (`employee_id`),
  KEY `onboarding_tasks_ibfk_3` (`template_id`),
  KEY `onboarding_tasks_ibfk_4` (`completed_by`),
  CONSTRAINT `onboarding_tasks_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `onboarding_tasks_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `onboarding_tasks_ibfk_3` FOREIGN KEY (`template_id`) REFERENCES `onboarding_templates` (`id`) ON DELETE SET NULL,
  CONSTRAINT `onboarding_tasks_ibfk_4` FOREIGN KEY (`completed_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `onboarding_templates` (
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
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `open_shift_claims` (
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
  KEY `open_shift_claims_ibfk_4` (`decided_by`),
  CONSTRAINT `open_shift_claims_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_2` FOREIGN KEY (`open_shift_id`) REFERENCES `open_shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_4` FOREIGN KEY (`decided_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `open_shifts` (
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
  KEY `open_shifts_ibfk_2` (`shift_id`),
  KEY `open_shifts_ibfk_4` (`created_by`),
  CONSTRAINT `open_shifts_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_3` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll` (
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
  `breakdown` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
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
  CONSTRAINT `payroll_ibfk_4` FOREIGN KEY (`approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `payroll_chk_1` CHECK (json_valid(`breakdown`))
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_line_overrides` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `month` char(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `line_kind` enum('deduction','bonus') COLLATE utf8mb4_unicode_ci NOT NULL,
  `line_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `line_date` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `line_desc` text COLLATE utf8mb4_unicode_ci,
  `line_hash` char(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'sha1(type|date|desc)',
  `waived` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = line removed for this month',
  `override_amount` decimal(12,2) DEFAULT NULL COMMENT 'replacement amount when not waived',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_override` (`tenant_id`,`employee_id`,`month`,`line_kind`,`line_hash`),
  KEY `idx_plo_emp_month` (`employee_id`,`month`,`tenant_id`),
  KEY `fk_plo_created_by` (`created_by`),
  CONSTRAINT `fk_plo_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_plo_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_plo_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_statutory_settings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `social_insurance_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `si_employee_rate` decimal(5,2) DEFAULT NULL,
  `si_min_wage` decimal(12,2) DEFAULT NULL,
  `si_max_wage` decimal(12,2) DEFAULT NULL,
  `income_tax_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `income_tax_brackets` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `tax_personal_exemption` decimal(12,2) DEFAULT NULL,
  `eosb_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `eosb_days_per_year` decimal(5,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_statutory_tenant` (`tenant_id`),
  CONSTRAINT `fk_statutory_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `payroll_statutory_settings_chk_1` CHECK (json_valid(`income_tax_brackets`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `performance_cycles` (
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
  KEY `performance_cycles_ibfk_2` (`created_by`),
  CONSTRAINT `performance_cycles_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_cycles_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `performance_goals` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `cycle_id` int unsigned DEFAULT NULL COMMENT 'optional: link goal to a cycle',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `metric` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'measurement unit / indicator, free text',
  `target_value` decimal(14,2) DEFAULT NULL,
  `current_value` decimal(14,2) NOT NULL DEFAULT '0.00',
  `weight` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'goal weight % (0-100)',
  `progress` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'completion % 0-100',
  `status` enum('not_started','in_progress','completed','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'not_started',
  `due_date` date DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pgoal_tenant_emp` (`tenant_id`,`employee_id`,`status`),
  KEY `idx_pgoal_cycle` (`cycle_id`),
  KEY `performance_goals_ibfk_2` (`employee_id`),
  KEY `performance_goals_ibfk_4` (`created_by`),
  CONSTRAINT `performance_goals_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_goals_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_goals_ibfk_3` FOREIGN KEY (`cycle_id`) REFERENCES `performance_cycles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `performance_goals_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `performance_reviews` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `cycle_id` int unsigned DEFAULT NULL,
  `reviewer_id` int unsigned DEFAULT NULL COMMENT 'admins.id — who entered/conducted the review',
  `reviewer_type` enum('manager','self','peer','subordinate') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'manager' COMMENT 'foundation for 360°',
  `rating` decimal(3,2) DEFAULT NULL COMMENT 'rating 0.00 - 5.00',
  `strengths` text COLLATE utf8mb4_unicode_ci,
  `areas_for_improvement` text COLLATE utf8mb4_unicode_ci,
  `review` text COLLATE utf8mb4_unicode_ci COMMENT 'general notes (backward-compatible column)',
  `status` enum('draft','submitted') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'submitted',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_prev_tenant_emp` (`tenant_id`,`employee_id`),
  KEY `idx_prev_cycle` (`cycle_id`),
  KEY `performance_reviews_ibfk_2` (`employee_id`),
  KEY `performance_reviews_ibfk_4` (`reviewer_id`),
  CONSTRAINT `performance_reviews_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_reviews_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_reviews_ibfk_3` FOREIGN KEY (`cycle_id`) REFERENCES `performance_cycles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `performance_reviews_ibfk_4` FOREIGN KEY (`reviewer_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `recurring_leaves` (
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
CREATE TABLE `required_document_categories` (
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
CREATE TABLE `required_document_employees` (
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
CREATE TABLE `required_documents` (
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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `shifts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'NULL = available for all branches',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'e.g. "Morning", "Evening", "Night"',
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `color` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Hex color for UI badge',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_shift_tenant` (`tenant_id`),
  KEY `idx_shift_branch` (`branch_id`),
  CONSTRAINT `shifts_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shifts_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `super_admin_audit_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned DEFAULT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_saalog_admin` (`admin_id`),
  KEY `idx_saalog_action` (`action`),
  CONSTRAINT `super_admin_audit_log_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `super_admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `super_admin_audit_log_chk_1` CHECK (json_valid(`payload`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `super_admin_devices` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int unsigned NOT NULL,
  `fcm_token` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `platform` enum('android','ios','web') COLLATE utf8mb4_unicode_ci DEFAULT 'android',
  `device_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_model` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `app_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_admin_device` (`admin_id`,`device_id`),
  KEY `idx_token` (`fcm_token`(50)),
  CONSTRAINT `fk_super_admin_devices_admin` FOREIGN KEY (`admin_id`) REFERENCES `super_admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `super_admin_sessions` (
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
CREATE TABLE `super_admins` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `support_messages` (
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `support_tickets` (
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
  `unread_for_user` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = support reply unread by user',
  `unread_for_support` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = user message unread by support',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_support_tickets_tenant` (`tenant_id`,`status`),
  KEY `idx_support_tickets_opened_by` (`opened_by_admin_id`),
  KEY `idx_support_tickets_status` (`status`,`last_message_at`),
  CONSTRAINT `support_tickets_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `support_tickets_ibfk_2` FOREIGN KEY (`opened_by_admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tenants` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `timezone` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Africa/Cairo',
  `timezone_is_explicit` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Admin actually chose this timezone (vs sitting on the column default)',
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'EGP',
  `country_code` char(2) COLLATE utf8mb4_unicode_ci DEFAULT 'EG' COMMENT 'ISO 3166-1 alpha-2; يحدّد مُصدِّر الرواتب الافتراضي',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `attendance_methods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'Enabled methods, e.g. ["qr_gps","manual","station"]',
  `manual_attendance_admin_ids` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin COMMENT 'NULL = all admins with manage_attendance; array = restricted set',
  `allow_offline_attendance` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Company-level toggle for offline attendance capture',
  `reject_mock_location` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Reject check-in/out when the device reports a mocked GPS location (Android only)',
  `require_local_biometric` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Require the phone fingerprint/FaceID gate on self check-in and check-out',
  `gps_latitude` decimal(10,7) DEFAULT NULL,
  `gps_longitude` decimal(10,7) DEFAULT NULL,
  `gps_radius_meters` int DEFAULT NULL,
  `default_annual_leave_days` int NOT NULL DEFAULT '21' COMMENT 'Default annual leave entitlement for all employees',
  `leave_carryover_max_days` int DEFAULT NULL COMMENT 'NULL = no carryover; number = max days carried to next year',
  `auto_rollover_enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1 = cron runs year-end rollover automatically on Jan 1',
  `apply_legal_seniority_entitlement` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1 = bump annual entitlement to >=30 days after 10 years service (Egyptian labour law)',
  `cycle_start_day` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Attendance cycle start day (1-28); cycle labeled by its end month',
  `week_start_day` tinyint unsigned NOT NULL DEFAULT '6' COMMENT 'Weekly schedule start weekday (ISO: 1=Mon..7=Sun, default 6=Sat)',
  `last_absence_date` date DEFAULT NULL COMMENT 'Last completed day absences were materialized (lazy on-access catch-up)',
  `commercial_register` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Commercial registration number shown on letters',
  `company_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_phone` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_match_threshold` decimal(4,3) NOT NULL DEFAULT '0.650' COMMENT 'Minimum cosine similarity to accept a face match (0-1)',
  `face_liveness_required` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Require the device to pass the server-issued liveness challenge',
  `face_enforce_mode` enum('log_only','enforce') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'log_only' COMMENT 'log_only = record the score but never reject (tuning phase); enforce = reject below threshold',
  PRIMARY KEY (`id`),
  CONSTRAINT `tenants_chk_1` CHECK (json_valid(`attendance_methods`)),
  CONSTRAINT `tenants_chk_2` CHECK (json_valid(`manual_attendance_admin_ids`))
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `warnings` (
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

