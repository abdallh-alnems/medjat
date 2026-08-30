-- Support / Tickets feature
-- MySQL 8 compatible (no MariaDB-specific syntax)
-- Run: mysql -u root -proot -h 127.0.0.1 -P 8889 medjat < migrations/2026_06_support.sql

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
  `unread_for_user` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 = support reply unread by user',
  `unread_for_support` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = user message unread by support',
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

ALTER TABLE `notifications`
  MODIFY COLUMN `type` enum('general','attendance','payroll','leave','warning','system','subscription','invite','support')
  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general';
