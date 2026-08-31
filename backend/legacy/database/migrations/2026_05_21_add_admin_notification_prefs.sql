-- Migration: admin_notification_prefs
-- Date: 2026-05-21
-- Per-admin notification preferences for SmartAlertService

CREATE TABLE IF NOT EXISTS `admin_notification_prefs` (
  `admin_id` int unsigned NOT NULL,
  `tenant_id` int unsigned DEFAULT NULL,
  `prefs` json NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`admin_id`),
  KEY `idx_notif_prefs_tenant` (`tenant_id`),
  CONSTRAINT `admin_notification_prefs_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
