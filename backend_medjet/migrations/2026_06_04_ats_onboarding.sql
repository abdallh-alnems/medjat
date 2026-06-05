-- ATS + Onboarding — 2026-06-04
-- 4 new tables: job_openings, candidates, onboarding_templates, onboarding_tasks
-- MySQL 8 compatible (no IF NOT EXISTS on columns).

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
