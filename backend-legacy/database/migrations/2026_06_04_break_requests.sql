-- Break Requests / Permission Requests
-- Created: 2026-06-04
-- Compatible with MySQL 8 and MariaDB

CREATE TABLE IF NOT EXISTS `break_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `date` date NOT NULL COMMENT 'يوم العمل المطلوب فيه الإذن/البريك',
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `duration_minutes` smallint unsigned NOT NULL DEFAULT 0 COMMENT 'محسوبة في PHP وقت الإدراج',
  `type` enum('break','permission','prayer','errand','medical','other')
        COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'break',
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
