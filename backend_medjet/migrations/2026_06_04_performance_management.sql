-- ============ PERFORMANCE MANAGEMENT — Phase 1 ============
-- Run once per database (MAMP local + production).
-- Compatible with MySQL 8 (no MariaDB-specific syntax).

-- ============ PERFORMANCE CYCLES ============

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

-- ============ PERFORMANCE GOALS / KPIs ============

CREATE TABLE IF NOT EXISTS `performance_goals` (
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
  CONSTRAINT `performance_goals_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_goals_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_goals_ibfk_3` FOREIGN KEY (`cycle_id`) REFERENCES `performance_cycles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `performance_goals_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ PERFORMANCE REVIEWS ============
-- PerformanceModel currently expects this table but it never existed.
-- Creating it fully: old columns (rating, review, reviewer_id) + new ones.

CREATE TABLE IF NOT EXISTS `performance_reviews` (
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
  CONSTRAINT `performance_reviews_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_reviews_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `performance_reviews_ibfk_3` FOREIGN KEY (`cycle_id`) REFERENCES `performance_cycles` (`id`) ON DELETE SET NULL,
  CONSTRAINT `performance_reviews_ibfk_4` FOREIGN KEY (`reviewer_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
