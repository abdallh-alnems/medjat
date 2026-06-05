-- ============================================================
-- Engagement Module — Announcements + Kudos + Surveys/eNPS
-- Run ONCE per database (local MAMP or production Hostinger).
-- Compatible with MySQL 8 (no ADD COLUMN IF NOT EXISTS).
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
  `submitted_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
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
